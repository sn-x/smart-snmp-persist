#!/usr/bin/perl -w

package Persist;

use strict;
use warnings;
use File::Slurp;
use Data::Dumper;
use XML::Simple;
use SNMP::Extension::PassPersist;

sub pass {
	my $extsnmp = SNMP::Extension::PassPersist->new(
		backend_collect => \&update_tree,
	);

	$extsnmp->run;
}

sub update_tree {
	my ($self) = @_;
	my %tree   = tree();
	
	$self->add_oid_tree(\%tree);
}

sub tree {
	my $self   = Parser->fetch_parser_cache();
	my %hash   = %{$self};
	my $oid    = $Configurator::persist_snmp_base_oid;
	my $drive_oid;
	my @array;

	foreach my $drive (sort keys %hash) {
		$drive =~ /drive-(\d+)/;
		$drive_oid = $1;
		push(@array, oid_tree($oid, $drive_oid, $hash{$drive})) if $hash{$drive}{attributes};
	}

	return @array;
}

sub oid_tree {
	my ($oid, $drive_oid, $self) = @_;
	my %device      = %{$self};
	my @array;

	push(@array, ($oid . ".0.1." . $drive_oid => ['string',  $device{'model'}]))  if $device{'model'};
	push(@array, ($oid . ".0.2." . $drive_oid => ['string',  $device{'serial'}])) if $device{'serial'};
	push(@array, ($oid . ".0.3." . $drive_oid => ['string',  $device{'vendor'}])) if $device{'vendor'};
	push(@array, ($oid . ".0.4." . $drive_oid => ['string',  $device{'size'}]))   if $device{'size'};
	push(@array, ($oid . ".0.5." . $drive_oid => ['integer', $device{'exitcode'}]));

	for my $smart_id (keys %{$device{'attributes'}}) {
		my $original_id = $smart_id;
		$smart_id =~ s/smart_/./g;
		my $full_oid = $oid . ".1" . $smart_id . "." . $drive_oid;
		push(@array, ($full_oid => ['integer',  $device{'attributes'}{$original_id}]));		
	}
		
	return @array;
}

return 1;
