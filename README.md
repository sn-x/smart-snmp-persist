# snmp_smartd
SMART prober and parser with SNMP persist output

## Short about

###### bin/

snmp-plugin packed into a single file with all perl dependencies included.

###### nagion-plugin/

Nagios plugin currently only reports discovered drives. It is easily extendable, all information is already available.

###### snmp-plugin/

SNMP plugin detects S.M.A.R.T. capable drives, parses S.M.A.R.T. output and exports data in SNMP oid tree over pass_persist.
