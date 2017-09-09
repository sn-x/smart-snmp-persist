#!/usr/bin/perl -w

BEGIN {
        $0 =~ /(.*)\/.*$/; # check if script was started with full path and try to parse path
        if ($1) { # path found
		push ( @INC, $1 . "/lib/"); # include full path with "/lib/" in @INC
        }
        else {
		push ( @INC, "lib/"); # not started with full path, include "lib/"
        }
}

use strict;
use warnings;
use Data::Dumper;
use Configurator;
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
		my @devices = Discovery->find_drives();

		print Dumper(@devices);
		exit;
	}

	if ((@ARGV) && $ARGV[0] eq "discovered_commands") {
		my @smartd_commands = Discovery->prepare_smartd_commands();
		foreach my $command (@smartd_commands) {
			print $command . "\n";
		}
		exit;
	}

	if ((@ARGV) && $ARGV[0] eq "discovered_cached") {
		my @smartd_commands = Discovery->cached_copy();
		foreach my $command (@smartd_commands) {
			print $command . "\n";
		}
		exit;
	}

	if ((@ARGV) && $ARGV[0] eq "smart_parsed") {
		my %smartd_data = Parser->parse_smartlog();
		print Dumper(\%smartd_data);
		exit;
	}

	if ((@ARGV) && $ARGV[0] eq "smart_cached") {
		my $smartd_data = Parser->fetch_parser_cache();
		print Dumper($smartd_data);
		exit;
	}

	if ((@ARGV) && $ARGV[0] eq "update_cache") {
		my $smartd_data = Parser->update_parser_cache();
		exit;
	}

	if ((@ARGV && $ARGV[1]) && $ARGV[0] eq "snmp_pass") {
		$Configurator::persist_snmp_base_oid = $ARGV[1];
		my $smartd_data = Persist->pass();
		exit;
	}

	print "Use one of the below command line arguments:\n";
	print "\n";
	print "snmp_pass <baseoid>  -    <baseoid> must match oid in snmpd.conf\n";
	print "smart_parsed         -    print to stdout\n";
	print "smart_cached         -    hourly cached results\n";
	print "discovered_devices   -    filtered devices list\n";
	print "discovered_commands  -    smartd commands\n";
	print "discovered_cached    -    daily cached results\n";
	print "update_cache         -    internal call to rebuild cache\n";
	exit;
}

