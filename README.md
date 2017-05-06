# snmp_smartd
SMART prober and parser with SNMP persist output

## Short about

###### nagion-plugin/

Nagios plugin checks return codes of smartctl command on all discovered drives. If non-zero code found, print problem description.

###### snmp-plugin/

SNMP plugin detects S.M.A.R.T. capable drives, parses S.M.A.R.T. output and exports data in SNMP oid tree over pass_persist.
