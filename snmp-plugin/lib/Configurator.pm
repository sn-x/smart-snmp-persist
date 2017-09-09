#!/usr/bin/perl -w

package Configurator;

use Data::Dumper;

our $interactive                = 1; # enable verbose output. disabled when using cached values
our $discovery_cache_expiry_age = 1; # expire device cache after 1 day. this prevent redundant discoveries, but ensures new drives are detected
our $discovery_cache_file       = "/tmp/smartd_discovered_devices_cache.txt"; # cache file path
our $parser_cache_file          = "/tmp/smartd_parsed_cache.xml";
our $parser_update_log          = "/tmp/smartd_parser_update.log";

# You shouldn't have to edit below here..
#

# hash contains: key=kernel driver, value=smartd driver
our %driver_map = (
        'megaraid_sas' => 'megaraid',
        '3w-9xxx'      => '3ware',
        'aacraid'      => 'scsi',
        'nvme'         => 'nvme',
        'mpt2sas'      => '',
        'ahci'         => '',
        'isci'         => ''
);

# requierments array
my @reqs = ('which', 'nohup', 'lsmod', 'grep', 'smartctl');
our %bin;

# generates hash with binary paths
for my $util (@reqs) {
	$path = `which $util`;
	chomp $path;
	$bin{$util} = $path;
	if (!$bin{$util}) {
		print "Missing \"" . $util . "\" binary. Please install it and try again.\n";
		exit(2)
	}
}

return 1;
