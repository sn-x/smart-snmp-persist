#!/usr/local/bin/perl -w

use strict;
use warnings;
use Net::SNMP;
use Data::Dumper;

my $oid='.1.3.6.1.3.3';

nagios_output();

sub nagios_output {
	my $drives = find_drives();

	if ($drives) {
		print "OK: Discovered $drives drives\n"
	}

	exit(0);
}

sub find_drives {
	my $snmp_data = fetch_snmp_table();
	my $drive     = 1;
	my $found     = 0;
	my $results;

	while (%{$snmp_data}{$oid.".".$drive.".1.2"}) {
		#print Dumper(%{$snmp_data}{$oid.".".$drive.".1.2"});
		$found++;
		$drive++;
	}
	
	return $found;
}

sub fetch_snmp_table {
	my $snmp = Net::SNMP->session(
	                        -hostname  => '127.0.0.1',
	                        -community => 'public',
	);

	my $var = $snmp->get_table( -baseoid => $oid);

	if ($snmp->error) {
		print $snmp->error;
		exit(1);
	}

	$snmp->close;

	return $var;
}

