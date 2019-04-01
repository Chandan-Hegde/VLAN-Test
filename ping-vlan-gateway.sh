#!/bin/sh
#
#Pings the vlan interface gateways

#list of vlan interface gateways
vlan_gateways=$(egrep "^GATEWAY" /etc/sysconfig/network-scripts/* | grep vlan | cut -d "=" -f 2)

for vlan_gateway in $vlan_gateways
do
        ping -q -c3 $vlan_gateway > /dev/null

        if [ $? -eq 0 ]
        then
                echo  "$vlan_gateway reaching"
        else
                echo  "$vlan_gateway not reaching"
        fi

done
