# smart-snmp-persist
SMART prober and parser with SNMP persist output

## Short about

###### lib/Parser.pm

It fetches a list of valid smartctl commands from **smart-disk-discovery.pl** and parses their output.

###### lib/Discovery.pm

Script uses **lshw** to probe for hardware info. It parses this data and tries to extract disk drives.
Discovered drives are probed for SMART capability. On success, the command is added to output.

###### lib/Persist.pm

Prepares SNMP OIDs and outputs with perist.

## Dependencies:

.. **SNMP::Extension::PassPersist**: https://metacpan.org/pod/SNMP::Extension::PassPersist

.. **File::Slurp**: https://metacpan.org/pod/File::Slurp

.. **Data::Dumper**: https://metacpan.org/pod/Data::Dumper

.. **XML::Simple**: https://metacpan.org/pod/XML::Simple

.. **lshw**: http://ezix.org/project/wiki/HardwareLiSter

.. **smartmontools**: https://www.smartmontools.org

apt: apt-get install libsnmp-extension-passpersist-perl libxml-simple-perl libfile-slurp-perl smartmontools lshw
yum: yum install 
