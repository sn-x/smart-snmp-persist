#!/usr/bin/perl -w

package Configurator;

our $lshw_bin                   = `which lshw`; # full path to lshw executable binary
our $smartctl_bin               = `which smartctl`; # full path to smartctl executable binary
our $interactive                = 1; # enable verbose output. disabled when using cached values
our $discovery_cache_expiry_age = 1; # expire device cache after 1 day. this prevent redundant discoveries, but ensures new drives are detected
our $discovery_cache_file       = "/tmp/smartd_discovered_devices_cache.txt"; # cache file path
our $parser_cache_file          = "/tmp/smartd_parsed_cache.xml";
our $parser_update_log          = "/tmp/smartd_parser_update.log";
our $persist_snmp_base_oid      = ".1.3.6.1.3.3."; # this must match with snmpd.conf

chomp $lshw_bin; # remove newline
chomp $smartctl_bin; # remove newline

return 1;
