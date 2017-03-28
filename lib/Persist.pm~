#!/usr/bin/perl -w

package Persist;

use strict;
use warnings;
use File::Slurp;
use Data::Dumper;
use XML::Simple;
use SNMP::Extension::PassPersist;

my $base_oid    = ".1.3.6.1.3.3";
my $full_oid    = $base_oid . ".0";
my $small_oid   = $base_oid . ".1";
my $nvme_oid    = $base_oid . ".2";

############################################################

sub persist {
	my $extsnmp = SNMP::Extension::PassPersist->new(
	    backend_collect => \&update_tree,
	);
	
	$extsnmp->run;
}

sub update_tree {
    my ($self) = @_;
	my %tree = tree();
	
    $self->add_oid_tree(\%tree);
}

sub tree {
	my $self   = Parser->fetch_parser_cache();
	my %hash   = %$self;
	my $unique = 0;
	my @array;
	my $oid;
			
	foreach my $drive (keys %hash) {
		my $oid;
		$oid = unique_oid($hash{$drive}, $unique);

		push(@array, oid_tree($oid, $hash{$drive})) if $hash{$drive}{'big_table'};
		push(@array, oid_tree($oid, $hash{$drive})) if $hash{$drive}{'small_table'};
		push(@array, oid_tree($oid, $hash{$drive})) if $hash{$drive}{'nvme'};
	    
		$unique++;
	}

	return @array;
}

sub unique_oid {
	my ($hash, $unique) = @_;

	return $full_oid . "." . $unique  if (%$hash{'big_table'});
	return $small_oid . "." . $unique if (%$hash{'small_table'});
	return $nvme_oid . "." . $unique  if (%$hash{'nvme'});

	return 0;		
}

sub oid_tree {
	my ($oid,$self) = @_;
	my %device      = %{$self};
	my @array;

	push(@array, ($oid . ".1"   => ['string',  $device{'vendor'}]));		
	push(@array, ($oid . ".2"   => ['string',  $device{'model'}]));
	push(@array, ($oid . ".3"   => ['string',  $device{'serial'}]));
	push(@array, ($oid . ".100" => ['integer', $device{'exitcode'}]));

	for my $smart_id (keys %{$device{'big_table'}}) {
		my $original_id = $smart_id;
		$smart_id =~ s/smart_/./g;

		my $full_oid = $oid . ".101" . $smart_id;

		push(@array, ($full_oid => ['integer',  $device{'big_table'}{$original_id}]));		
	}
		
	return @array;
}

return 1;
