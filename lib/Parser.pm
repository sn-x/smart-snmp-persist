#!/usr/bin/perl -w

package Parser;

use strict;
use warnings;
use File::Slurp;
use Data::Dumper;
use XML::Simple;

my $cache_file = "/tmp/smartd_parsed_cache.xml";

########################
#       FUNCTIONS
#

sub parsed_cached_copy {
        my $expiry_age = "0.041"; # expire cache after 1 hour

        if ((! -e $cache_file) || ((-M $cache_file) > $expiry_age)) { # if file doesn't exist or if it's older than expiry age
                my %parsed_data = detect_smartlog_version(); # fetch commands
		my $xml = XMLout(\%parsed_data,
                      NoAttr => 1,
                      RootName=>'smart',
                     );
                write_file($cache_file, $xml); # save them to file, and add newlines
        }

	my $cached_results = XMLin($cache_file); # parse XML string
        return $cached_results if ($cached_results);
}

sub detect_smartlog_version {
	my %self;
	my %smart_data = fetch_smart_data();

	for my $disk (keys %smart_data) {
		$self{$disk}{exitcode} = $smart_data{$disk}{exitcode};
		for my $smart_output_line (@{$smart_data{$disk}{data}}) {
                        $self{$disk}{vendor}      = parse_smart_vendor($smart_output_line)               if parse_smart_vendor($smart_output_line);
                        $self{$disk}{model}       = parse_smart_model($smart_output_line)                if parse_smart_model($smart_output_line);
                        $self{$disk}{serial}      = parse_smart_serial($smart_output_line)               if parse_smart_serial($smart_output_line);
			$self{$disk}{big_table}   = parse_smart_big_table(@{$smart_data{$disk}{data}})   if ($smart_output_line =~ "SMART Attributes Data Structure revision number");
			$self{$disk}{small_table} = parse_smart_small_table(@{$smart_data{$disk}{data}}) if ($smart_output_line =~ "Error counter log:");
			$self{$disk}{nvme}        = parse_smart_nvme(@{$smart_data{$disk}{data}})        if ($smart_output_line =~ "SMART/Health Information");
		}
	}

	return %self;
}

sub fetch_smart_data {
	my %self;
	my $loop = 0;
	my @smartd_commands = Discovery->cached_copy();
	chomp @smartd_commands;

	for my $smart_command (@smartd_commands) {
		if ($smart_command) {
			my @smart_output = `$smart_command`;
			push (@{$self{"drive-".$loop}{data}}, values @smart_output);
			$self{"drive-".$loop}{exitcode} = $?;
			$loop++;
		}
	}

        return %self;
}

###                     ###
#     SMART PARSERS       #
###                     ###

sub parse_smart_big_table {
	my (@smart_output) = @_;
	chomp @smart_output;
	my %self;

	for my $smart_line (@smart_output) {
		if ($smart_line =~ /^\s*(\d{1,3})\s(\w*\-*\w+\-*\w+)\s*(0[xX][0-9a-fA-F]+)\s*(\d{1,3})\s*(\d{1,3})\s*(\d{1,3})\s*(.{1,8})\s*(\w*)\s*(-|.{1,8})\s*(\d*)|[h]\s*$/) {
			$self{"smart_".$1.".0"} = $1;  # smart id
			$self{"smart_".$1.".1"} = $2;  # description
			$self{"smart_".$1.".2"} = $4;  # 0-100% life left
			$self{"smart_".$1.".3"} = $5;  # worst
			$self{"smart_".$1.".4"} = $10; # raw value
		}
	}

	return \%self;
}

sub parse_smart_small_table {
        my (@smart_output) = @_;
        chomp @smart_output;
        my %self;

        for my $smart_line (@smart_output) {
		if ($smart_line =~ /^(\w+):\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+\.\d+)\s+(\d*)\s*$/) { 
			$self{"smart_".$1.".0"} = $2;	# "Errors Corrected by ECC - Fast"
			$self{"smart_".$1.".1"} = $3;	# "Errors Corrected by ECC - Delayed"
			$self{"smart_".$1.".2"} = $4;	# "Rereads and Rewrites"
			$self{"smart_".$1.".3"} = $5;	# "Total errors corrected"
			$self{"smart_".$1.".4"} = $6;	# "Correction alghoritm invocation"
			$self{"smart_".$1.".5"} = $7;	# "Gigabytes processed [10^9 bytes]"
			$self{"smart_".$1.".6"} = $8;	# "Total uncorrected errors"
                }
        }

        return \%self;
}

sub parse_smart_nvme {
        my (@smart_output) = @_;
        chomp @smart_output;
        my %self;

	foreach my $smart_line (@smart_output) {
		$self{smart_1} = $1         if ($smart_line =~ /^Temperature:\s*(\d+).*$/);
		$self{smart_2} = $1         if ($smart_line =~ /^Available Spare:\s*(\d+).*$/);
		$self{smart_3} = "100" - $1 if ($smart_line =~ /^Percentage Used:\s*(\d+).*$/);
	}

	return \%self;
}

sub parse_smart_vendor {
	my ($self) = @_;

	return $1 if ($self =~ /^Vendor:\s*(\w.*)$/);
	return $1 if ($self =~ /^Model Family:\s*(\w.*)$/);
}

sub parse_smart_model {
	my ($self) = @_;

	return $1 if ($self =~ /^Device Model:\s*(\w.*)$/);
	return $1 if ($self =~ /^Model Number:\s*(\w.*)$/);
	return $1 if ($self =~ /^Product:\s*(\w.*)$/)	
}

sub parse_smart_serial {
	my ($self) = @_;

	return $1 if ($self =~ /^Serial Number:\s*(\w.*)$/);
	return $1 if ($self =~ /^Serial number:\s*(\w.*)$/);
}

return 1;
