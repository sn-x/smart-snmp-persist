# nagios plugin for snmp-smart

Nagios config examples:

command definition (replace path with your values):
```define command{
        command_name    check_snmp_smart
        command_line    $USER1$/custom/nagios-snmp-smart.pl $HOSTADDRESS$ $ARG1$ $ARG2$
}
```

service definition (replace snmp-community and snmp-oid with your values):
```define service {
        use                     hourly-check
        hostgroup_name          workstations
        service_description     Check smart
        check_command           check_snmp_smart!snmp-community!snmp-oid
        retry_check_interval    10
        servicegroups           SMART
}
```


In action examples:

1) All OK: 

![nagios_ok](https://github.com/sn-x/snmp-smart/raw/master/git-homepage/nagios_ok.png)

2) Problem:

![nagios_problem](https://github.com/sn-x/snmp-smart/raw/master/git-homepage/nagios_ok.png)

