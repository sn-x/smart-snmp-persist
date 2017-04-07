#!/usr/bin/perl -w

package Persist;

use strict;
use warnings;
use File::Slurp;
use Data::Dumper;
use XML::Simple;
use SNMP::Extension::PassPersist;

sub persist {
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
	my $unique = 1;
	my @array;
	my $oid;
			
	foreach my $drive (keys %hash) {
		$oid = unique_oid($hash{$drive}, $unique);
		push(@array, oid_tree($oid, $hash{$drive})) if $hash{$drive}{attributes};
		$unique++;
	}

	return @array;
}

sub unique_oid {
	my ($hash, $unique) = @_;

	return $Configurator::persist_snmp_base_oid . $unique . ".1" if (%{$hash}{'big_table'});
	return $Configurator::persist_snmp_base_oid . $unique . ".2" if (%{$hash}{'small_table'});
	return $Configurator::persist_snmp_base_oid . $unique . ".3" if (%{$hash}{'nvme'});

	return 0;		
}

sub oid_tree {
	my ($oid,$self) = @_;
	my %device      = %{$self};
	my @array;

	push(@array, ($oid . ".1"   => ['string',  $device{'model'}]))  if $device{'model'};
	push(@array, ($oid . ".2"   => ['string',  $device{'serial'}])) if $device{'serial'};
	push(@array, ($oid . ".3"   => ['string',  $device{'vendor'}])) if $device{'vendor'};
	push(@array, ($oid . ".100" => ['integer', $device{'exitcode'}]));

	for my $smart_id (keys %{$device{'attributes'}}) {
		my $original_id = $smart_id;
		$smart_id =~ s/smart_/./g;
		my $full_oid = $oid . ".101" . $smart_id;
		push(@array, ($full_oid => ['integer',  $device{'attributes'}{$original_id}]));		
	}
		
	return @array;
}

return 1;
