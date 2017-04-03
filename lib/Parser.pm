#!/usr/bin/perl -w

package Parser;

use strict;
use warnings;
use File::Slurp;
use Data::Dumper;
use XML::Simple;

sub fetch_parser_cache {
	my $cached_results = ""; # define empty variable;

	if ( ! -e $Configurator::parser_cache_file ) {
		update_parser_cache();
	}

	$cached_results = XMLin($Configurator::parser_cache_file); # parse XML string
	system("echo `date` >> /tmp/loop");
	system("nohup perl $0 update_cache > " . $Configurator::parser_update_log . " 2>&1 &"); # update cache in background

	return $cached_results;
}

sub update_parser_cache {
	my %parsed_data = parse_smartlog(); # fetch commands
	my $xml = XMLout(\%parsed_data,
				NoAttr   => 1,
				RootName => 'smart',
			);
	write_file($Configurator::parser_cache_file, $xml); # save them to file, and add newlines
}

sub parse_smartlog {
	my %self;
	my %smart_data = fetch_smart_data();

	for my $disk (keys %smart_data) {
		$self{$disk}{exitcode} = $smart_data{$disk}{exitcode};
		
		for my $smart_output_line (@{$smart_data{$disk}{data}}) {
			$self{$disk}{vendor}      = parse_smart_vendor($smart_output_line) if parse_smart_vendor($smart_output_line);
			$self{$disk}{model}       = parse_smart_model($smart_output_line)  if parse_smart_model($smart_output_line);
			$self{$disk}{serial}      = parse_smart_serial($smart_output_line) if parse_smart_serial($smart_output_line);

			if ($smart_output_line =~ "SMART Attributes Data Structure revision number") {
				$self{$disk}{big_table}   = "found";
				$self{$disk}{attributes}  = parse_smart_big_table(@{$smart_data{$disk}{data}})
			}

			if ($smart_output_line =~ "Error counter log:") {
				$self{$disk}{small_table} = "found";
				$self{$disk}{attributes}  = parse_smart_small_table(@{$smart_data{$disk}{data}})
			}

			if ($smart_output_line =~ "SMART/Health Information") {
				$self{$disk}{nvme} = "found";
				$self{$disk}{attributes}  = parse_smart_nvme(@{$smart_data{$disk}{data}})
			}
		}
	}

	return %self;
}

sub fetch_smart_data {
	my %self;
	my $loop = 1;
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

###                  ###
#     SMART PARSERS    #
###                  ###

sub parse_smart_big_table {
	my (@smart_output) = @_;
	chomp @smart_output;
	my %self;

	for my $smart_line (@smart_output) {
		if ($smart_line =~ /^\s*(\d{1,3})\s(\w*\-*\w+\-*\w+)\s*(0[xX][0-9a-fA-F]+)\s*(\d{1,3})\s*(\d{1,3})\s*(\d{1,3})\s*(.{1,8})\s*(\w*)\s*(-|.{1,8})\s*(\d*)|[h]\s*$/) {
			                               # $1 = smart id
			                               # $2 = description
			$self{"smart_".$1.".1"} = $4;  # 0-100% life left
			$self{"smart_".$1.".2"} = $5;  # worst
			$self{"smart_".$1.".3"} = $10; # raw value
		}
	}

	return \%self;
}

sub parse_smart_small_table {
	my (@smart_output) = @_;
	chomp @smart_output;
	my %self;
	my $type;

	for my $smart_line (@smart_output) {
		if ($smart_line =~ /^(\w+):\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+\.\d+)\s+(\d*)\s*$/) { 
			$type = "1" if ($1 == "read");
			$type = "2" if ($1 == "write");
			$type = "3" if ($1 == "verify");
			$self{"smart_1_".$type} = $2;	# "Errors Corrected by ECC - Fast"
			$self{"smart_2_".$type} = $3;	# "Errors Corrected by ECC - Delayed"
			$self{"smart_3_".$type} = $4;	# "Rereads and Rewrites"
			$self{"smart_4_".$type} = $5;	# "Total errors corrected"
			$self{"smart_5_".$type} = $6;	# "Correction alghoritm invocation"
			$self{"smart_6_".$type} = $7;	# "Gigabytes processed [10^9 bytes]"
			$self{"smart_7_".$type} = $8;	# "Total uncorrected errors"
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

	return $1 if ($self =~ /^Serial number:\s*(\w.*)$/i);
}

return 1;
