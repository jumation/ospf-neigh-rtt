# Add RTT of OSPF/OSPFv3 neighbors into SNMP agent

[Ospf-neigh-rtt.slax](https://github.com/jumation/ospf-neigh-rtt/blob/master/ospf-neigh-rtt.slax) is a Junos event script which automatically detects all OSPF and OSPFv3 neighbors, measures RTT of each directly connected neighbor using ping utility and makes the results available in Junos SNMP agent.  
**Such measurement method is suitable if high accuracy is not needed. For highly accurate RTT measurements RPM "icmp-ping" type probes with ["hardware-timestamp"](https://www.juniper.net/documentation/en_US/junos/topics/reference/configuration-statement/hardware-timestamp-edit-services.html), ITU-T Y.1731 ETH-DM with ["hardware-assisted-timestamping"](https://www.juniper.net/documentation/en_US/junos/topics/reference/configuration-statement/hardware-assisted-timestamping-edit-protocols-oam.html) in case of Ethernet links or external (Linux based) monitoring servers can be used.**


## Overview

For example, in case of following network topology, the `vmx1` router has four OSPFv2 neighbors and four OSPFv3 neighbors:

![Logical view of Junos virtual routers](https://github.com/jumation/ospf-neigh-rtt/blob/master/logical_view_of_virtual-routers.png)

This means, that `vmx1` periodically detects those neighbors, measures RTT of each neighbor and populates the SNMP agent with the results:

```
nms@nms:~$ snmpwalk -v 2c -c public vmx1 jnxUtilStringValue                                                    
JUNIPER-UTIL-MIB::jnxUtilStringValue.'rtt_10.10.1.1_ge-0/0/0.0_ge-0/0/1.0 vr1' = STRING: "29.7"               
JUNIPER-UTIL-MIB::jnxUtilStringValue.'rtt_10.10.2.1_ge-0/0/2.0_ge-0/0/3.0 vr2' = STRING: "37.7"               
JUNIPER-UTIL-MIB::jnxUtilStringValue.'rtt_10.10.3.1_ge-0/0/4.50_ge-0/0/5.50 vr3' = STRING: "5.8"              
JUNIPER-UTIL-MIB::jnxUtilStringValue.'rtt_10.10.4.1_lt-0/0/10.0_lt-0/0/10.1 vr4' = STRING: "0.2"              
JUNIPER-UTIL-MIB::jnxUtilStringValue.'rtt_fe80::206:a00:320e:fff5_ge-0/0/4.50_ge-0/0/5.50 vr3' = STRING: "5.8"
JUNIPER-UTIL-MIB::jnxUtilStringValue.'rtt_fe80::206:aff:fe0e:fff1_ge-0/0/0.0_ge-0/0/1.0 vr1' = STRING: "28.5" 
JUNIPER-UTIL-MIB::jnxUtilStringValue.'rtt_fe80::206:aff:fe0e:fff3_ge-0/0/2.0_ge-0/0/3.0 vr2' = STRING: "38.3" 
JUNIPER-UTIL-MIB::jnxUtilStringValue.'rtt_fe80::a00:dd00:2800:10e_lt-0/0/10.0_lt-0/0/10.1 vr4' = STRING: "0.1"
nms@nms:~$
```

Instance name seen above depends on neighbor IP address, interface name and interface description. Graphs generated based on those measurements can be seen below:

*RRDtool graph of `vmx1` router OSPFv3 neighbors:*
![RRDtool graph of RTT of vmx1 OSPFv3 neighbors](https://github.com/jumation/ospf-neigh-rtt/blob/master/vmx1_rtt.png)

*RRDtool graph of RTT between `vmx1`(10.10.1.0) and `vr1`(10.10.1.1) generated with [script](https://github.com/jumation/ospf-neigh-rtt/blob/master/ospf-neigh-rtt-db-update.bash):*
![RRDtool graph of RTT of vmx1 and vr1](https://github.com/jumation/ospf-neigh-rtt/blob/master/vmx1_ge-0-0-0.0_10.10.1.1.png)

*RRDtool graph of RTT between `vmx1` and `vr1` using Holt-Winters forecasting:*
![RRDtool graph of RTT of vmx1 and vr1 using Holt-Winters forecasting](https://github.com/jumation/ospf-neigh-rtt/blob/master/vmx1_ge-0-0-0.0_fe80::206:aff:fe0e:fff1.png)

*Grafana graph of RTT between `vmx1` and `vr3`:*
![Grafana graph of RTT of vmx1 and vr3](https://github.com/jumation/ospf-neigh-rtt/blob/master/vmx1_vr3_rtt.png)


## Installation

Copy(for example, using [scp](https://en.wikipedia.org/wiki/Secure_copy)) the [ospf-neigh-rtt.slax](https://github.com/jumation/ospf-neigh-rtt/blob/master/ospf-neigh-rtt.slax) to `/var/db/scripts/event/` directory and enable the script file under `[edit event-options event-script]`:

```
martin@vmx1> file list detail /var/db/scripts/event/ospf-neigh-rtt.slax 
-rw-r--r--  1 martin wheel     11223 May 5  13:49 /var/db/scripts/event/ospf-neigh-rtt.slax
total files: 1

martin@vmx1> show configuration event-options event-script | display inheritance no-comments 
file ospf-neigh-rtt.slax {
    checksum sha-256 6b1e7d317378276bf39c7b9a84d2df25e1233f07f1cde22f11bb189e0d456e8b;
}

martin@vmx1> 
```

Event policy is defined inside the [ospf-neigh-rtt.slax](https://github.com/jumation/ospf-neigh-rtt/blob/master/ospf-neigh-rtt.slax) script and thus no `policy` or event configuration under `event-options` is needed:
```
martin@vmx1> request system scripts event-scripts reload 
Event scripts loaded

martin@vmx1> show event-options event-scripts policies 
## Last changed: 2019-05-05 14:12:45 UTC
event-options {
    generate-event {
        300s time-interval 300 no-drift;
    }
    policy ospf-neigh-rtt {
        events 300s;
        then {
            event-script ospf-neigh-rtt.slax;
        }
    }
}

martin@vmx1> 
```

In case of two routing engines, the script needs to be copied to the `/var/db/scripts/event/` directory on both routing engines.


## License
[GNU General Public License v3.0](https://github.com/jumation/ospf-neigh-rtt/blob/master/LICENSE)
