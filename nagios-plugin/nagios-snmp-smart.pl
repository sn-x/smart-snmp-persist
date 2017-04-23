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

	problem("PROBLEM", "No drives discovered", "") if (!$drives);

	my $secondary_info = secondary_info($snmp_data_ref,$drives);
	my $problems_ref   = check_for_disk_problems($snmp_data_ref, $drives);

	if ($problems_ref) {
		my %problems_hash = %{$problems_ref};
	        problem($problems_hash{severity}, $problems_hash{info}, $secondary_info);
	}

	ok("Number of checked drives: " . $drives . ".\n", $secondary_info) if ($drives);
}

sub find_drives {
	my ($snmp_data_ref) = @_;
	my %snmp_data_hash  = %{$snmp_data_ref};
	my $drive           = 1;
	my $found           = 0;

	while ($snmp_data_hash{$snmp_baseoid . "." . $drive . ".1.2"}) {
		$found++;
		$drive++;
	}
	
	return $found;
}

sub secondary_info {
	my ($snmp_data_ref,$drives) = @_;
	my %snmp_data_hash          = %{$snmp_data_ref};
	my $secondary_info          = "";
	my $drive                   = 1;
	my $oid;

	return "\n" if (!$drives);

	until ($drive > $drives) {
		$oid = $snmp_baseoid . "." . $drive . ".1";
		$secondary_info .= "Model:\t\t"     . $snmp_data_hash{$oid . ".1"}   . "\n" if ($snmp_data_hash{$oid . ".1"});
		$secondary_info .= "Serial:\t\t"    . $snmp_data_hash{$oid . ".2"}   . "\n" if ($snmp_data_hash{$oid . ".2"});
		$secondary_info .= "Vendor:\t\t"    . $snmp_data_hash{$oid . ".3"}   . "\n" if ($snmp_data_hash{$oid . ".3"});
		$secondary_info .= "Size:\t\t"      . $snmp_data_hash{$oid . ".4"}   . "\n" if ($snmp_data_hash{$oid . ".4"});
		$secondary_info .= "Return code:\t" . $snmp_data_hash{$oid . ".100"} . "\n";
		$secondary_info .= "\n";
		$drive++;
	}

	return $secondary_info;
}

sub check_for_disk_problems {
	my ($snmp_data_ref, $drives) = @_;
	my %snmp_data_hash           = %{$snmp_data_ref};
	my $drive                    = 1;

        return "" if (!$drives);

        until ($drive > $drives) {
		my $oid = $snmp_baseoid . "." . $drive . ".1";

		return check_exit_codes($snmp_data_hash{$oid . ".100"})  if (check_exit_codes($snmp_data_hash{$oid . ".100"}));
		return check_smart_thold($snmp_data_hash{$oid . ".101"}) if (check_smart_thold($snmp_data_hash{$oid . ".101"}));

                $drive++;
        }

        return "";

}

sub check_exit_codes {
	my ($exit_code) = @_;
	my %self;

	if ($exit_code) {
		$self{severity} = "WARNING";
		$self{info}     = "Non-zero return code found. Check additional info in Nagios.";
	}

	return \%self if (%self);
}

sub check_smart_thold {

}

sub fetch_snmp_table {
	my ($session, $error) = Net::SNMP->session(
			-hostname  => $snmp_hostname,
			-community => $snmp_community,
			-timeout   => $snmp_timeout,
			-version   => 'snmpv2c',
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
	my ($primary_info, $secondary_info) = @_;

	print "OK: " . $primary_info . "\n";
	print $secondary_info;

	exit(0);
}

sub problem {
	my ($severity, $message, $secondary_info) = @_;

	print $severity . ": " . $message . "\n";
	print $secondary_info if ($secondary_info);

	exit(1) if ($severity =~ "WARNING");
	exit(2);
}
