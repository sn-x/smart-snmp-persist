#!/usr/bin/perl -w

use strict;
use warnings;
use File::Slurp;
use Data::Dumper;
use XML::Simple;

my $SMARTCTL = `which smartctl`; # find smartctl exectable / can be replaced with full path to smartctl binary
chomp $SMARTCTL; # removes newline from end of string

my %SMARTD_TRANSLATION = ( # hash with: key: kernel driver, value: smartd driver
	'megaraid_sas' => 'megaraid',
	'3w-9xxx'      => '3ware',
	'aacraid'      => 'scsi',
	'nvme'         => 'nvme',
	'mpt2sas'      => '',
	'ahci'         => '',
	'isci'         => ''
);

########################
#	CORE
#
startup();

########################
#	FUNCTIONS
#

sub startup {
	if (!@ARGV) {
		print "Use one of the below command line argumnts:\n";
		print "\n";
		print "devices		-	filtered devices list\n";
		print "smartd		-	smartd commands\n"; 
		print "cached		-	daily cached results\n";
		exit;
	}

	if ((@ARGV) && $ARGV[0] eq "devices") {
		my %devices = detect_drives();

		foreach my $device (keys %devices) {
			print "------------------------------------------------------------\n";
			print Dumper($devices{$device});
			print "------------------------------------------------------------\n";
		}
	} 
	elsif ((@ARGV) && $ARGV[0] eq "smartd") {
		my @smartd_commands = prepare_smartd_commands();

		foreach my $command (@smartd_commands) {
			print $command . "\n";
		}
	}
	elsif ((@ARGV) && $ARGV[0] eq "cached") {
		my @smartd_commands = cached_copy();

		foreach my $command (@smartd_commands) {
			print $command . "\n";
		}
	}
	else {
		print "Sorry. Unsupported argument: " . $ARGV[0] . " \n";
	}
}

sub prepare_xml {
	my $lshw_bin = `which lshw`; # fetch full path 
	chomp $lshw_bin; # remove newline

	my @lshw_output = `$lshw_bin -xml -class storage -class disk`; # get xml from lshw command
	my @xml = @lshw_output[5 .. $#lshw_output]; # remove first 5 rows (header and comments)

	if ($xml[0] !~ "<list>") { # compatibility issue with legacy lshw (everything has to be inside a single block)
		unshift @xml, '<list>'; # prepend <list>
		push	@xml, '</list>'; # append </list>
	}

	my $xmlin  = join("\n", @xml); # create string from array
	my $xmlout = XMLin($xmlin, KeyAttr => []); # parse XML string

	return $xmlout; # return XML array
}

sub detect_drives {
	my %found_drives; # hash with discovered devices
	my $loop = 0; # reset $loop
	my $xml  = prepare_xml(); # get xml array 

        if ($xml->{node}) { # lets check if a node exists
                if(ref($xml->{node}) eq 'ARRAY') { # check if it is an array
			foreach my $list (@{$xml->{node}}) { # search through array
				$found_drives{$loop} = prepare_drive_hash($list) if ($list->{id}); # prepare drive to hash
				$loop++; # increment $loop
			}
		}

		if(ref($xml->{node}) eq 'HASH') {
			if(ref($xml->{node}->{node}) eq 'ARRAY') { # check if it is an array
				foreach my $list (@{$xml->{node}->{node}}) { # search through array
					$found_drives{$loop} = prepare_drive_hash($list) if ($list->{id}); # prepare drive to hash
					$loop++; # increment $loop
				}
			}
		}
	}
	return %found_drives;
}

sub prepare_drive_hash {
	my ($list) = @_;  # read input
	my %self;

	$self{type}   = $list->{id}; # type (storage, disk)
	$self{handle} = $list->{handle} if ($list->{handle}); # PCI handle (PCI:0000:00:00)
	$self{driver} = find_drivers($list) if find_drivers($list); # array whit devices that have drivers
	$self{drives} = find_jbods($list)  if find_jbods($list); # array whit devices that have drives

	return \%self;
}
	
sub find_drivers {
	my ($node) = @_;	# read input

	# search through array for devices with a driver
	if ($node->{configuration}->{setting}) {
		foreach my $setting (@{$node->{configuration}->{setting}}) {
			return $setting->{value} if ($setting->{id} =~ "driver");
		}
	}
}

sub find_jbods {
	my ($node) = @_; # read input
	my %disks; # create empty hash

	# search through array for devices with drives
	$disks{$node->{id}} = prepare_jbod_hash($node) if (($node->{id}) && ($node->{logicalname}));

	if ($node->{node}) { # check if node definition exists
		if(ref($node->{node}) eq 'HASH') { # check if it is a hash
			my $disk = $node->{node};
			$disks{$disk->{id}} = prepare_jbod_hash($disk) if (($disk->{id}) && $disk->{logicalname});
		}

		if(ref($node->{node}) eq 'ARRAY') { # check if it is an array
			foreach my $disk (@{$node->{node}}) { # if it is, loop through it
				$disks{$disk->{id}} = prepare_jbod_hash($disk) if (($disk->{id}) && $disk->{logicalname});
			}
		} 
	}

	return \%disks;
}

sub prepare_jbod_hash {
        my ($node) = @_;  # read input
        my %self; # create empty hash

	$self{logicalname} = $node->{logicalname}; # we need this for smartd command
	$self{serial}      = $node->{serial} if ($node->{serial}); # this only helps with debuging
	$self{product}     = $node->{product} if ($node->{product}); # this only helps with debuging

	return \%self;
}

sub prepare_smartd_commands {
	my @smartd_cmds; # empty array for smartd commands
	my %found_drives = detect_drives(); # fetch drives

	foreach my $drive_value (values %found_drives) { # loop through discovered drives
		if (($drive_value->{drives} && !$drive_value->{driver})) { # if we find a drive without a driver
			foreach my $drive (keys %{$drive_value->{drives}}) {			
				push(@smartd_cmds, jbodSMARTD($drive_value)) if ($drive =~ "disk"); # if its a disk use jbod
			}
		}

		if ($drive_value->{driver}) { # if a device has a driver
			if (\$SMARTD_TRANSLATION{$drive_value->{driver}}) { # check if the driver is supported and use configured function
				push(@smartd_cmds, jbodSMARTD($drive_value))     if ($drive_value->{driver} eq "ahci");
				push(@smartd_cmds, jbodSMARTD($drive_value))	 if ($drive_value->{driver} eq "isci");
				push(@smartd_cmds, jbodSMARTD($drive_value))	 if ($drive_value->{driver} eq "mpt2sas");
				push(@smartd_cmds, nvmeSMARTD($drive_value))	 if ($drive_value->{driver} eq "nvme");
				push(@smartd_cmds, scsiSMARTD($drive_value))	 if ($drive_value->{driver} eq "aacraid");
				push(@smartd_cmds, wareSMARTD($drive_value))	 if ($drive_value->{driver} eq "3w-9xxx");
				push(@smartd_cmds, megaraidSMARTD($drive_value)) if ($drive_value->{driver} eq "megaraid_sas");
			}
		}
	}

	return @smartd_cmds;
}

sub cached_copy {
	my $tmp_file = "/tmp/smartd_discovered.txt"; # cache file path 
	my $expiry_age = "1"; # expire cache after 1 day

	if ((! -e $tmp_file) || ((-M $tmp_file) > $expiry_age)) { # if file doesn't exist or if it's older than expiry age
		my @smartd_commands = prepare_smartd_commands(); # fetch commands
		write_file($tmp_file, map { "$_\n" } @smartd_commands); # save them to file, and add newlines
	}

	my @cached_file = read_file($tmp_file); # read file

	foreach my $cached_line (@cached_file) {
		print $cached_line; # print each line of file
	}
}

#########################################
#	   SMARTD COMMAND GENERATORS
#

sub jbodSMARTD {
	my @self;
	my ($input) = @_; # get input

	foreach my $drive (keys %{$input->{drives}}) {
		`$SMARTCTL -a $input->{drives}->{$drive}->{logicalname}`; # probe for drive
		push (@self, ($SMARTCTL . " -a " . $input->{drives}->{$drive}->{logicalname})) if (($? != 256) && ($? != 512)); # add smart command to array
	}
	return @self; # return array of smartctl commands
}

sub nvmeSMARTD {
	my @self;
	my ($input)	 = @_; # get input
	my $handle	 = $1 if ($input->{handle} =~ /^.*:(.{1,4}:.{1,2}:.{1,2}\..)$/); # set handle if variable conatins PCI address (regex match)
	my $controller   = `ls \"/sys/bus/pci/devices/$handle/misc/\"`; # get controller name from disk location
	chomp $controller ; #remove newline from end of string

	`$SMARTCTL . " -a /dev/" . $controller . " -d " . $input->{driver}`; # probe for drive
	push (@self, ($SMARTCTL . " -a /dev/" . $controller . " -d " . $input->{driver})) if ($? != 512); # add smart command to array

	return @self; # return array of smartctl commands
}

sub scsiSMARTD {
	my @self;
	my ($input) = @_; # get input
	my $driver  = $SMARTD_TRANSLATION{$input->{driver}}; # fetch smart driver
	my @sg_devs = `ls /dev/sg*`; # fetch all scsi drives

	print "Probing for " . $SMARTD_TRANSLATION{$input->{driver}} . " drives. This could take some time..\n";
	foreach my $sg_dev (@sg_devs) {
		$? = 0; # because it's a new drive, we reset exit status
		chomp $sg_dev; # remove newline from end of string

		`$SMARTCTL -a $sg_dev -d $driver`; # probe for drive
		if (($? != 256) && ($? != 512)) { # if smartd succeeded
			push (@self, ($SMARTCTL . " -a " . $sg_dev . " -d " . $driver)); # add smart command to array
		}
	}

	return @self; # return array of smartctl commands
}

sub wareSMARTD {
	my @self;
	my ($input) = @_; # get input
	my $driver  = $SMARTD_TRANSLATION{$input->{driver}}; # fetch smart driver
	my @tw_devs = `ls /dev/tw*`; # fetch all virtual drives created by driver

	print "Probing for " . $SMARTD_TRANSLATION{$input->{driver}} . " drives. This could take some time..\n";
	foreach my $tw_dev (@tw_devs) {
		my $loop = 0; # because new it's adrive, we reset loop
		$?       = 0; # because it's a new drive, we reset exit status
		chomp $tw_dev; # remove newline from end of string

		while (($? != 256) && ($? != 512)) { # work until exist status == 0
			`$SMARTCTL -a $tw_dev -d $driver,$loop`; # probe for drive
			if (($? != 256) && ($? != 512)) { # if smartd succeeded
				push (@self, ($SMARTCTL . " -a " . $tw_dev . " -d " . $driver . "," . $loop)); # add smart command to array
			}
		$loop++; # increment $loop
		}
	}

	return @self; # return array of smartctl commands
}

sub megaraidSMARTD {
	my @self;
	my ($input) = @_; # get input
	my $driver  = $SMARTD_TRANSLATION{$input->{driver}}; # fetch smart driver

	# probe for drives
	print "Probing for " . $SMARTD_TRANSLATION{$input->{driver}} . " drives. This could take some time..\n";
	foreach my $drive (keys %{$input->{drives}}) {
		my $logicalname = $input->{drives}{$drive}{logicalname}; # logical name from lshw
		my $loop        = 0; # because it's a new drive, we reset loop
		$?              = 0; # because it's a new drive, we reset exit status

		while (($? != 256) && ($? != 512)) { # exit loop if no drive detected 
			`$SMARTCTL -a $logicalname -d $driver,$loop`; # probe for drive
			if (($? != 256) && ($? != 512)) { # if smartd succeeded
				push (@self, ($SMARTCTL . " -a " . $logicalname . " -d " . $driver . "," . $loop)); # add smart command to array
			}
			$loop++; # increment $loop
		}
	}

        if(!(keys %{$input->{drives}})) { # if array with drives is empty
                foreach my $drive ("/dev/sda".."/dev/sdz") { # try these drives
                        my $loop = 0; # because it's a new drive, we reset loop
                        $?       = 0; # because it's a new drive, we reset exit status
                        while (($? != 256) && ($? != 512)) { # exit loop if no drive detected
                                `$SMARTCTL -a $drive -d $driver,$loop`; # probe for drive
                                if (($? != 256) && ($? != 512)) { # if smartd succeeded
                                        push (@self, ($SMARTCTL . " -a " . $drive . " -d " . $driver . "," . $loop)); # add smart command to array
                                }
                                $loop++; # increment $loop
                        }
                }
        }

	return @self; # return array of smartctl commands
}
