#!/usr/bin/perl -w

package Discovery;

use strict;
use warnings;
use Configurator;
use File::Slurp;
use XML::Simple;
use Data::Dumper;

my $grep     = $Configurator::bin{"grep"};
my $lsmod    = $Configurator::bin{"lsmod"};
my $smartctl = $Configurator::bin{"smartctl"};

########################
#	FUNCTIONS
#

sub find_matching_modules {
        print "Trying to extract loaded modules from lsmod..\n" if ($Configurator::interactive);
        my @lsmod_output = `$lsmod`;
	my @matched_modules;

	foreach my $lsmod_line (@lsmod_output) {
		my $module = $1 if ($lsmod_line =~ /^([a-zA-Z0-9_]+)\ .*$/);
		push(@matched_modules, $module) if exists $Configurator::driver_map{$module};
	}

	return @matched_modules;
}

sub find_drives {
	my @possible_drives = `ls -1 -p /sys/dev/block/*\:*/uevent`;
	my @drives;

	foreach my $drive_info_path (@possible_drives) {
		if ($drive_info_path =~ /sys\/dev\/block\/(3|8|259):.+\/uevent/g) {
			my $drive_name = `$grep DEVNAME $drive_info_path` if (`$grep DEVTYPE=disk $drive_info_path`);
			if (defined($drive_name) && $drive_name ne "") {
				my $drive_path = "/dev/" . $1 if $drive_name =~ /DEVNAME=([a-z]+)/;
				push (@drives, $drive_path) if ($drive_path);
			}
		}
	}

	chomp @drives;

	return @drives;
}

sub prepare_smartd_commands {
        my @modules  = find_matching_modules(); # find registered modules matching our supported list
	my @available_drives = find_drives(); # find available drives on the system
	my @smartd_cmds;

	foreach my $drive (@available_drives) { # loop through discovered drives
		if (@modules) {
			foreach my $module (@modules) { # try with each module
				push(@smartd_cmds, jbodSMARTD($drive))		if ($module eq "ahci");
				push(@smartd_cmds, jbodSMARTD($drive))		if ($module eq "isci");
				push(@smartd_cmds, jbodSMARTD($drive))		if ($module eq "mpt2sas");
				push(@smartd_cmds, nvmeSMARTD($drive))		if ($module eq "nvme");
				push(@smartd_cmds, scsiSMARTD($drive))		if ($module eq "aacraid");
				push(@smartd_cmds, wareSMARTD($drive))		if ($module eq "3w-9xxx");
				push(@smartd_cmds, megaraidSMARTD($drive))	if ($module eq "megaraid_sas");
			}
		} else {
			push(@smartd_cmds, jbodSMARTD($drive));
		}
	}

	return @smartd_cmds;
}

sub cached_copy {
	$Configurator::interactive = 0;

	if ((! -e $Configurator::discovery_cache_file) || ((-M $Configurator::discovery_cache_file) > $Configurator::discovery_cache_expiry_age)) { # if file doesn't exist or if it's older than expiry age
		my @smartd_commands = prepare_smartd_commands(); # fetch commands
		write_file($Configurator::discovery_cache_file, map { "$_\n" } @smartd_commands); # save them to file, and add newlines
	}

	my @cached_info = read_file($Configurator::discovery_cache_file); # read file

	if (!@cached_info) {
		print "\n";
		print "ERROR: Drive cache file empty or missing.\n\n";
		print "There were no drives discovered or there is a permission issue with drive cache file\n";
		print "Drive cache file: " . $Configurator::discovery_cache_file . "\n\n";
		exit 2;
	}

	return sort_cache_info(@cached_info);
}

sub sort_cache_info {
	my (@cached_info) = @_;

	chomp (@cached_info);
	my %cached_info_hash   = map { $_, 1 } @cached_info;
	@cached_info = sort keys %cached_info_hash;	

	return @cached_info;
}

sub check_if_smart_supported {
	my ($command)  = @_;
	my @smart_data = `$command`;

	if (($? == 256) || ($? == 512)) {
		return 0; # 256 - command did not parse, 512 - device open failed
        }

	for my $smart_line (@smart_data) {
		return 0 if ($smart_line =~ "Device does not support SMART");
	}

	return 1;
}

#########################################
#	   SMARTD COMMAND GENERATORS
#

sub jbodSMARTD {
	my @self;
	my (@drives) = @_; # get input

	foreach my $drive (@drives) {
		my $command = $smartctl . " -a " . $drive; # specific command for jbods
		push (@self, ($command)) if (check_if_smart_supported($command)); # add smart command to array if smart capable
	}
	return @self; # return array of smartctl commands
}

sub nvmeSMARTD {
	my @self;
	my ($input)	 = @_; # get input
	my $handle	 = $1 if ($input->{handle} =~ /^.*:(.{1,4}:.{1,2}:.{1,2}\..)$/); # set handle if variable conatins PCI address (regex match)
	my $controller   = `ls \"/sys/bus/pci/devices/$handle/misc/\"`; # get controller name from disk location
	chomp $controller ; #remove newline from end of string

	my $command = $smartctl . " -a /dev/" . $controller . " -d " . $input->{driver}; # probe for drive
	push (@self, ($command)) if (check_if_smart_supported($command)); # add smart command to array if smart capable

	return @self; # return array of smartctl commands
}

sub scsiSMARTD {
	my @self;
	my ($input) = @_; # get input
	my $driver  = $Configurator::driver_map{$input->{driver}}; # translate kernel driver to smartd driver
	my @sg_devs = `ls /dev/sg*`; # fetch all scsi drives

	print "Probing for " . $Configurator::driver_map{$input->{driver}} . " drives. This could take some time..\n" if ($Configurator::interactive);

	foreach my $sg_dev (@sg_devs) {
		$? = 0; # because it's a new drive, we reset exit status
		chomp $sg_dev; # remove newline from end of string

		my $command = $smartctl . " -a " . $sg_dev . " -d " . $driver;
		push (@self, ($command)) if (check_if_smart_supported($command)); # add smart command to array if smart capable
	}

	return @self; # return array of smartctl commands
}

sub wareSMARTD {
	my @self;
	my ($input) = @_; # get input
	my $driver  = $Configurator::driver_map{$input->{driver}}; # translate kernel driver to smartd driver
	my @tw_devs = `ls /dev/tw*`; # fetch all virtual drives created by driver

	print "Probing for " . $Configurator::driver_map{$input->{driver}} . " drives. This could take some time..\n" if ($Configurator::interactive);
	foreach my $tw_dev (@tw_devs) {
		my $loop = 0; # because new it's adrive, we reset loop
		chomp $tw_dev; # remove newline from end of string
		my $command = $smartctl . " -a " . $tw_dev . " -d " . $driver;

		while (check_if_smart_supported($command . "," . $loop)) {
			push (@self, ($command . "," . $loop)) if (check_if_smart_supported($command . "," . $loop)); # add smart command to array if smart capable
			$loop++; # increment $loop
		}
	}

	return @self; # return array of smartctl commands
}

sub megaraidSMARTD {
	my @self;
	my ($input) = @_; # get input
	my $driver  = $Configurator::driver_map{$input->{driver}}; # translate kernel driver to smartd driver
	my $loop    = 0;

	# probe for drives
        if(!(keys %{$input->{drives}})) { # if array with drives is empty
                foreach my $logicalname ("/dev/sda".."/dev/sdz") { # try these drives
			$input->{drives}{$loop}{logicalname} = $logicalname;
			$loop++;
		}
	}

	print "Probing for " . $Configurator::driver_map{$input->{driver}} . " drives. This could take some time..\n" if ($Configurator::interactive);
	foreach my $drive (keys %{$input->{drives}}) {
		my $logicalname = $input->{drives}{$drive}{logicalname}; # logical name from lshw
		my $command = $smartctl . " -a " . $logicalname . " -d " . $driver;
		my $loop        = 0; # because it's a new drive, we reset loop

		while (check_if_smart_supported($command . "," . $loop)) {
			push (@self, ($command . "," . $loop)) if (check_if_smart_supported($command . "," . $loop)); # add smart command to array if smart capable
			$loop++; # increment $loop
		}
	}

	return @self; # return array of smartctl commands
}

return 1;
