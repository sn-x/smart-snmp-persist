# snmp_smartd
SMART prober and parser with SNMP persist output

## Short about

###### nagion-plugin/

Nagios plugin check return codes of smartctl command on all discovered drives. On non-0, print problem description. It is easily extendable, all smart information is already available.

###### snmp-plugin/

SNMP plugin detects S.M.A.R.T. capable drives, parses S.M.A.R.T. output and exports data in SNMP oid tree over pass_persist.
