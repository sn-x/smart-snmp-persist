#!/usr/bin/perl -w

package Parser;

use strict;
use warnings;
use File::Slurp;
use Data::Dumper;
use XML::Simple;

my %drives;
my $cache_file = "/tmp/smartd_parsed_cache.xml";
my $base_oid   = ".1.3.6.1.3.3";
my $nvme_oid   = $base_oid . ".0";
my $disk_oid   = $base_oid . ".1";

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
                        $self{$disk}{vendor} = parse_smart_vendor($smart_output_line) if parse_smart_vendor($smart_output_line);
                        $self{$disk}{model}  = parse_smart_model($smart_output_line)  if parse_smart_model($smart_output_line);
                        $self{$disk}{serial} = parse_smart_serial($smart_output_line) if parse_smart_serial($smart_output_line);
			$self{$disk}{attributes}  = parse_smart_big_table(@{$smart_data{$disk}{data}})   if ($smart_output_line =~ "SMART Attributes Data Structure revision number");
			$self{$disk}{attributes}  = parse_smart_small_table(@{$smart_data{$disk}{data}}) if ($smart_output_line =~ "Error counter log:");
			$self{$disk}{attributes}  = parse_smart_nvme(@{$smart_data{$disk}{data}})        if ($smart_output_line =~ "SMART/Health Information");
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
			$self{"smart_1.".$1.".0"} = $1;  # smart id
			$self{"smart_1.".$1.".1"} = $2;  # description
			$self{"smart_1.".$1.".2"} = $4;  # 0-100% life left
			$self{"smart_1.".$1.".3"} = $5;  # worst
			$self{"smart_1.".$1.".4"} = $10; # raw value
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
			my $unique = 0;

			$unique = 1 if ($1 =~ /^read:.*/);
			$unique = 2 if ($1 =~ /^write:.*/);
			$unique = 3 if ($1 =~ /^verify:.*/);

			$self{"2.".$unique.".0"} = $1;	# "read / write / verify"
			$self{"2.".$unique.".0"} = $2;	# "Errors Corrected by ECC - Fast"
			$self{"2.".$unique.".1"} = $3;	# "Errors Corrected by ECC - Delayed"
			$self{"2.".$unique.".2"} = $4;	# "Rereads and Rewrites"
			$self{"2.".$unique.".3"} = $5;	# "Total errors corrected"
			$self{"2.".$unique.".4"} = $6;	# "Correction alghoritm invocation"
			$self{"2.".$unique.".5"} = $7;	# "Gigabytes processed [10^9 bytes]"
			$self{"2.".$unique.".6"} = $8;	# "Total uncorrected errors"
                }
        }

        return \%self;
}

sub parse_smart_nvme {
        my (@smart_output) = @_;
        chomp @smart_output;
        my %self;

	foreach my $smart_line (@smart_output) {
		$self{"3.1"} = $1         if ($smart_line =~ /^Temperature:\s*(\d+).*$/);
		$self{"3.2"} = $1         if ($smart_line =~ /^Available Spare:\s*(\d+).*$/);
		$self{"3.3"} = "100" - $1 if ($smart_line =~ /^Percentage Used:\s*(\d+).*$/);
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
