#!/usr/local/bin/perl -w

use strict;
use warnings;
use Net::SNMP;
use Data::Dumper;

my $snmp_timeout = 2; # snmp connect timeout in seconds

if (!$ARGV[2]) {
	print "$0 snmp_hostname snmp_community snmp_baseoid\n\n";
	exit 1;
}

my $snmp_hostname  = $ARGV[0];
my $snmp_community = $ARGV[1];
my $snmp_baseoid   = $ARGV[2];

print_results();

sub print_results {
	my $snmp_data_ref  = fetch_snmp_table();
	my $drives         = find_drives($snmp_data_ref);
	my $extended_info  = extended_info($snmp_data_ref,$drives);
	my $main_info      = "";

	$main_info .= "Discovered drives: " . $drives . ". " if ($drives);

	ok($main_info, $extended_info) if ($main_info);
	problem("PROBLEM", "No drives discovered");
}

sub find_drives {
	my ($snmp_data_ref) = @_;
	my %snmp_data_hash  = %{$snmp_data_ref};
	my $drive           = 1;
	my $found           = 0;

	while ($snmp_data_hash{$snmp_baseoid.".".$drive.".1.2"}) {
		$found++;
		$drive++;
	}
	
	return $found;
}

sub extended_info {
	my ($snmp_data_ref,$drives) = @_;
	my %snmp_data_hash          = %{$snmp_data_ref};
	my $extended_info           = "";
	my $drive                   = 1;

	return "\n" if (!$drives);
	
	until ($drive > $drives) {
		$extended_info .= "Model: "           . $snmp_data_hash{$snmp_baseoid.".".$drive.".1.1"}   . "\n" if ($snmp_data_hash{$snmp_baseoid.".".$drive.".1.1"});
		$extended_info .= "Serial: "          . $snmp_data_hash{$snmp_baseoid.".".$drive.".1.2"}   . "\n" if ($snmp_data_hash{$snmp_baseoid.".".$drive.".1.2"});
		$extended_info .= "Vendor: "          . $snmp_data_hash{$snmp_baseoid.".".$drive.".1.3"}   . "\n" if ($snmp_data_hash{$snmp_baseoid.".".$drive.".1.3"});
		$extended_info .= "Size: "            . $snmp_data_hash{$snmp_baseoid.".".$drive.".1.4"}   . "\n" if ($snmp_data_hash{$snmp_baseoid.".".$drive.".1.4"});
		$extended_info .= "SMART Exit code: " . $snmp_data_hash{$snmp_baseoid.".".$drive.".1.100"} . "\n";
		$extended_info .= "\n";
		$drive++;
	}

	return $extended_info;
}
sub fetch_snmp_table {
	my ($session, $error) = Net::SNMP->session(
			-hostname  => $snmp_hostname,
			-community => $snmp_community,
			-timeout   => $snmp_timeout,
			-retries   => 0
	);

	problem("PROBLEM", $error) if ($error);
	problem("PROBLEM", "Couldn't establish SNMP session. Check hostname.") if (!$session);

        my $results = $session->get_table(
                        -baseoid => $snmp_baseoid
        );

	$session->close;
	problem("PROBLEM", "Unable to retrieve SNMP table. Check community and oid.") if (!$results);

	return $results;
}

sub ok {
	my ($main_info, $extended_info) = @_;

	print "OK: " . $main_info . "\n";
	print $extended_info;
	exit(0);
}

sub problem {
	my ($severity, $message) = @_;

	print $severity . ": " . $message . "\n";
	exit(1) if ($severity =~ "WARNING");
	exit(2);
}
