#!/usr/bin/perl -w

use strict;
use warnings;
use Data::Dumper;

BEGIN {
	$0 =~ /(.*)\/.*$/; # check if script was started with full path and try to parse path
	if ($1) { # path found
		push ( @INC, $1 . "/lib/"); # include full path with "lib/" in @INC
	}
	else {
		push ( @INC, "lib/"); # not started with full path, include only "lib/"
	}
}

use Discovery;
use Parser;
use Persist;

########################
#       START HERE
#
startup();

########################
#       FUNCTIONS
#

sub startup {
	if ((@ARGV) && $ARGV[0] eq "discovered_devices") {
		my %devices = Discovery->detect_drives();

		foreach my $device (keys %devices) {
			print "------------------------------------------------------------\n";
			print Dumper($devices{$device});
			print "------------------------------------------------------------\n";
		}
		exit;
	}
	elsif ((@ARGV) && $ARGV[0] eq "discovered_commands") {
		my @smartd_commands = Discovery->prepare_smartd_commands();
		foreach my $command (@smartd_commands) {
			print $command . "\n";
		}
		exit;
	}
	elsif ((@ARGV) && $ARGV[0] eq "discovered_cached") {
		my @smartd_commands = Discovery->cached_copy();
		foreach my $command (@smartd_commands) {
			print $command . "\n";
		}
		exit;
	}
	elsif ((@ARGV) && $ARGV[0] eq "smart_parsed") {
		my %smartd_data = Parser->parse_smartlog();
		print Dumper(\%smartd_data);
		exit;
	}
	elsif ((@ARGV) && $ARGV[0] eq "smart_cached") {
		my $smartd_data = Parser->fetch_parser_cache();
		print Dumper($smartd_data);
		exit;
	}
	elsif ((@ARGV) && $ARGV[0] eq "update_cache") {
		my $smartd_data = Parser->update_parser_cache();
		exit;
	}
	elsif ((@ARGV) && $ARGV[0] eq "snmp_persist") {
		my $smartd_data = Persist->persist();
		exit;
	}

	print "Use one of the below command line arguments:\n";
	print "\n";
	print "snmp_persist         -       snmp pass persist\n";
	print "smart_parsed         -       print to stdout\n";
	print "smart_cached         -       hourly cached results\n";
	print "discovered_devices   -       filtered devices list\n";
	print "discovered_commands  -       smartd commands\n";
	print "discovered_cached    -       daily cached results\n";
	print "update_cache         -       internal call to rebuild cache\n";
	exit;
}

