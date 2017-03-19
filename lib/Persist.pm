#!/usr/bin/perl -w

package Persist;

use strict;
use warnings;
use File::Slurp;
use XML::Simple;
use SNMP::Extension::PassPersist;

my $base_oid   = ".1.3.6.1.3.3";
my $nvme_oid   = $base_oid . ".0";
my $disk_oid   = $base_oid . ".1";

return 1;
