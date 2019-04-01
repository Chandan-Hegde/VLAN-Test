#!/bin/sh
#
# This script is written to print and check if the network configurations info that is obtained from the network config file is valid or not
# We can use those config info later to create ip routes and rules


for interface_file in $(ls /etc/sysconfig/network-scripts/ifcfg-vlan*);do

     #Looks like helps in opening the file and helps in reading configurations as <key>=value pair where value cal later be refered as ${key}
     . ${interface_file}

     #Get uniq table number from the vlan idenitifier where in vlan tagged interface the number after the period of ifcfg file
     tablenum=$(echo ${DEVICE} | sed "s/${PHYSDEV}.//g")

     #if ONBOOT configurationsis not set then rule addition is skipped
     if [ ${ONBOOT} != 'yes' ];then
        continue
     fi

     #creating entry in /etc/iproute2/rt_tables which allow us to use that table name with our further policy routes
     #conditional logic to make sure not to have duplicate entries
     if ! grep "^${tablenum} ${DEVICE}$" /etc/iproute2/rt_tables > /dev/null ;then
         echo "${tablenum} ${DEVICE}" >> /etc/iproute2/rt_tables
     fi

     #Get the network address from the ip address and the prefix using ipcalc
     network=$(ipcalc -n  ${IPADDR}/${PREFIX} | awk -F "=" '{print $2}')

     #creating ip routes
     echo "###Creating ip routes"
     ip route add ${network}/${PREFIX} dev ${DEVICE} src ${IPADDR} table ${DEVICE}
     ip route add default via ${GATEWAY} dev ${DEVICE} table ${DEVICE}


     #creating ip rules
     echo "###Creatiing ip rules"

     ip rule add from ${IPADDR}/${PREFIX} table ${DEVICE}
     ip rule add to ${IPADDR}/${PREFIX} table ${DEVICE}

done
