#!/usr/bin/perl -w

package Configurator;

our $interactive                = 1; # enable verbose output. disabled when using cached values
our $discovery_cache_expiry_age = 1; # expire device cache after 1 day. this prevent redundant discoveries, but ensures new drives are detected
our $discovery_cache_file       = "/tmp/smartd_discovered_devices_cache.txt"; # cache file path
our $parser_cache_file          = "/tmp/smartd_parsed_cache.xml";
our $parser_update_log          = "/tmp/smartd_parser_update.log";
our $persist_snmp_base_oid      = ".1.3.6.1.3.3."; # this must match with snmpd.conf

our %driver_map = ( # hash contains: key -> kernel driver, value -> smartd driver
        'megaraid_sas' => 'megaraid',
        '3w-9xxx'      => '3ware',
        'aacraid'      => 'scsi',
        'nvme'         => 'nvme',
        'mpt2sas'      => '',
        'ahci'         => '',
        'isci'         => ''
);

our $which_bin = `which which`; # check if which works
chomp $which_bin; # remove newline

if (!$which_bin) {
	print "Missing \"which\" binary. Please install it and try again.\n";
	exit(2);
}

our $lshw_bin = `$which_bin lshw`; # full path to lshw executable binary
chomp $lshw_bin; # remove newline

if (!$lshw_bin) {
	print "Missing \"lshw\" binary. Please install it and try again.\n";
	exit(2);
}

our $smartctl_bin = `$which_bin smartctl`; # full path to smartctl executable binary
chomp $smartctl_bin; # remove newline

if (!$smartctl_bin) {
	print "Missing \"smartctl\" binary. Please install it and try again.\n";
	exit(2);
}

return 1;
