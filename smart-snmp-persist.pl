#!/usr/bin/perl -w

use strict;
use warnings;
use Data::Dumper;

BEGIN {
	$0 =~ /(.*)\/.*$/;
	if ($1) {
	    push ( @INC, $1 . "/lib/");
	}
	else {
		push ( @INC, "lib/");
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
        if (!@ARGV) {
                print "Use one of the below command line arguments:\n";
                print "\n";
                print "smart_parsed         -       print to stdout\n";
		print "smart_cached         -       hourly cached results\n";
                print "snmp_persist         -       snmp pass persist\n";
                print "discovered_devices   -       filtered devices list\n";
                print "discovered_commands  -       smartd commands\n";
                print "discovered_cached    -       daily cached results\n";
                exit;
        }

        if ((@ARGV) && $ARGV[0] eq "discovered_devices") {
                my %devices = Discovery->detect_drives();

                foreach my $device (keys %devices) {
                        print "------------------------------------------------------------\n";
                        print Dumper($devices{$device});
                        print "------------------------------------------------------------\n";
                }
        }
        elsif ((@ARGV) && $ARGV[0] eq "discovered_commands") {
                my @smartd_commands = Discovery->prepare_smartd_commands();

                foreach my $command (@smartd_commands) {
                        print $command . "\n";
                }
        }
        elsif ((@ARGV) && $ARGV[0] eq "discovered_cached") {
                my @smartd_commands = Discovery->cached_copy();

                foreach my $command (@smartd_commands) {
                        print $command . "\n";
                }
        }
        elsif ((@ARGV) && $ARGV[0] eq "smart_parsed") {
                my %smartd_data = Parser->parse_smartlog();
                print Dumper(\%smartd_data);
        }
        elsif ((@ARGV) && $ARGV[0] eq "smart_cached") {
                my $smartd_data = Parser->fetch_parser_cache();
                print Dumper($smartd_data);
        }
        elsif ((@ARGV) && $ARGV[0] eq "snmp_persist") {
                my $smartd_data = Persist->persist();
                #print Dumper($smartd_data);
        }
        else {
                print "Sorry. Unsupported argument: " . $ARGV[0] . " \n";
        }

}

