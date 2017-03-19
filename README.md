# smart-snmp-persist
SMART prober and parser with SNMP persist output

## Short about

###### lib/Parser.pm

Parses smartctl output

###### lib/Discovery.pm

Discoveres SMART capable disk drives

###### lib/Persist.pm

Provides pass persist output.

## Dependencies:

.. **SNMP::Extension::PassPersist**: https://metacpan.org/pod/SNMP::Extension::PassPersist

.. **File::Slurp**: https://metacpan.org/pod/File::Slurp

.. **Data::Dumper**: https://metacpan.org/pod/Data::Dumper

.. **XML::Simple**: https://metacpan.org/pod/XML::Simple

.. **lshw**: http://ezix.org/project/wiki/HardwareLiSter

.. **smartmontools**: https://www.smartmontools.org

apt: apt-get install libsnmp-extension-passpersist-perl libxml-simple-perl libfile-slurp-perl smartmontools lshw

yum: yum install 
