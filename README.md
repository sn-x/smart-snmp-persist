# smart-snmp-persist
SMART prober and parser with SNMP persist output

## Short about

###### lib/Parser.pm

It fetches a list of valid smartctl commands from **smart-disk-discovery.pl** and parses their output. Parsed data can be returned
through net-snmp pass persist feature.

###### lib/Discovery.pm

Script uses **lshw** to probe for hardware info. It parses this data and tries to extract disk drives.
Discovered drives are probed for SMART capability. On success, the command is added to output.

## Dependencies:

###### lib/Discovery.pm

..**File::Slurp**: https://metacpan.org/pod/File::Slurp

..**Data::Dumper**: https://metacpan.org/pod/Data::Dumper

..**XML::Simple**: https://metacpan.org/pod/XML::Simple

..**lshw**: http://ezix.org/project/wiki/HardwareLiSter

..**smartmontools**: https://www.smartmontools.org

Debian and derivatives: apt-get install libxml-simple-perl libfile-slurp-perl smartmontools lshw
###### lib/Parser.pm 

..**File::Slurp**: https://metacpan.org/pod/File::Slurp

..**Data::Dumper**: https://metacpan.org/pod/Data::Dumper

..**XML::Simple**: https://metacpan.org/pod/XML::Simple

..**smartmontools**: https://www.smartmontools.org

..**smart-disk-discovery.pl**


