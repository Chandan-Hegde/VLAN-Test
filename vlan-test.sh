#!/bin/sh
#
#Script to automate the vlan tag test
#Usage vlan-test.sh <test-vm-name> <VLAN_CFG_FILE> <server-name>
#uses file ./<site-name>-vlan-list to fetch the vlan and network config info


#colour codes to print
red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

SERVER=$3

#Have custome Port Group name like this
pg1="allow-all-vlan-via-uplink1"
pg2="allow-all-vlan-via-uplink2"

pgs="${pg1} ${pg2}"

for pg in ${pgs}
do

#Name of the VM with whose help we test the vlan tag
      TEST_VM=$1

#Invoke perl SDK script to attach NIC number two which is our vlan test NIC to particular port group or network
      newnet-vm.pl -vm $TEST_VM -nic 2 -pg $pg -type vds -server $SERVER

#Name of the vlan list file
      VLAN_CFG_FILE=$2

#List of vlans that are already configured in the test machine that is residing remotely
      vlan_interface_list_remote=$(ssh root@${TEST_VM} "nmcli connection show | grep vlan | cut -d ' ' -f 1 | cut -d '.' -f 2")

#fetch the vlan list from ./wdc_vlan_list CSV file
      vlan_list=$(cat ${VLAN_CFG_FILE}  | cut -d "," -f 1)

#Get the default interface like this. This was the most difficult line to write. you need to login to remote machine for this
      def_dev=`ssh root@\${TEST_VM} "nmcli dev | egrep ethernet | tail -n 1 | cut -d ' ' -f 1" `

      for vlan in $vlan_list
      do

            if echo "$vlan_interface_list_remote" | grep $vlan --quiet
            then
                 echo "###$vlan interface already exists in the $TEST_VM."
            else
                 echo "###Creating $vlan interface in $TEST_VM"

#fetch ip,mask and gateway from <VLAN_CFG_FILE>
                 ip=$(cat ${VLAN_CFG_FILE} | grep $vlan | cut -d "," -f 2)
                 prefix=$(cat ${VLAN_CFG_FILE} | grep $vlan | cut -d "," -f 3)
                 gateway=$(cat ${VLAN_CFG_FILE} | grep $vlan | cut -d "," -f 4)


#now use the necessary paramters to create vlan interface in the remote vlan test machine. you need to login to remote machine to do this
             ssh root@${TEST_VM} "nmcli con add type vlan con-name vlan-${def_dev}.${vlan} ifname ${def_dev}.${vlan} dev ${def_dev} id ${vlan} ip4 ${ip}/${prefix} ipv4.gateway ${gateway}"
             ssh root@${TEST_VM} "systemctl restart network"

#Now we need to invoke the script to add the routes and the rules which is there within the test machine. This I do only when I am creating that interface
             ssh root@${TEST_VM} "~/scripts/create-route-rule.sh"

            fi

      done


#Will also ping the gateway from respective interfaces to make sure that MAC learnig happens
      echo "###This is from within the test machine to respective gateway to make the MAC learning done"
      ssh root@${TEST_VM} "~/scripts/ping-vlan-gateway.sh"


#Now test the connectivity
      echo ""
      echo "${green}###Final report for to know if the vlan tagging is done for the uplinks vmnic teamed to  ${pg}###"
      vlan_ips=$(cat wdc_vlan_list  | cut -d "," -f 1,2)

      for vlan_ip in ${vlan_ips}
      do
           ip=$(echo "$vlan_ip" | cut -d "," -f 2)
           vlan=$(echo "$vlan_ip" | cut -d "," -f 1)

           ping -q -c3 ${ip} > /dev/null

           if [ $? -eq 0 ]
           then
                echo  "${green}###${ip} reaching ===> ${vlan} working"
           else
                echo  "${red}###${ip} is not reaching ===> ${vlan} not working"
           fi
      done

#resets the terminal colour
     echo "${reset}"

done
