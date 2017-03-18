#!/usr/bin/perl -w

use strict;
use warnings;
use Data::Dumper;
use lib 'lib/';
use Discovery qw(detect_drives prepare_smartd_commands cached_copy);
use Parser qw(detect_smartlog_version);

my $base_oid = ".1.3.6.1.3.3";
my $nvme_oid  = ".0";
my $disk_oid  = ".1";

my $cache     = "/tmp/smartd_cache";
my %drives;

########################
#       CORE
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
                print "smart_persist        -       snmp persist\n";
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
                my %smartd_data = Parser->detect_smartlog_version();
                print Dumper(\%smartd_data);
        }
        else {
                print "Sorry. Unsupported argument: " . $ARGV[0] . " \n";
        }

}

