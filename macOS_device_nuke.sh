#!/bin/bash

###Jawa Script to wipe device
#1 - Have some sort of work flow that will put a device into a smart group (probably dangerous so use static) 
#2 - Have a web hook that detects group change to run this script.
#####DEVICES WILL BE WIPED IF THE COMMAND WORKS.
# - For M1 + T2 that are on MacOS12 if there is a boot strap token and no bios password or lock, the device will run the erase contents and settings.Other wise its a total re-install
jssuser="jssusername"
jsspass="password"
jssurl="jssurl"
groupname="GroupNameNoSpaces"
######
#Detects Changes from webhook
#convert to token incase someone is listening
token=$(printf "${jssuser}:${jsspass}" | iconv -t ISO-8859-1 | base64 -i -)
idraw=$(curl -sk --header "authorization: Basic ${token}" ${jssurl}/JSSResource/computergroups/name/${groupname} | xmllint --format - | xpath -e '//computer_group/computers/computer/id' 2>&1 | awk -F'<id>|</id>' '{print $2}')
for id in ${idraw};do
	curl -sk --header "authorization: Basic ${token}" ${jssurl}/JSSResource/computers/id/${id} | xmllint --format - > /tmp/${id}.xml
	devicename=$(cat /tmp/${id}.xml | xpath -e '//computer/general/name' 2>&1 | awk -F'<name>|</name>' '{print $2}')
	lastupdate=$(cat /tmp/${id}.xml | xpath -e '//computer/general/last_contact_time_epoch'  2>&1 | awk -F'<last_contact_time_epoch>|</last_contact_time_epoch>' '{print $2}')
	serialnumber=$(cat /tmp/${id}.xml | xpath -e '//computer/general/serial_number' 2>&1 | awk -F'<serial_number>|</serial_number>' '{print $2}')
	sleep 2
	curl -sk --header "authorization: Basic ${token}" ${jssurl}/JSSResource/computercommands/command/UnmanageDevice/id/${id} -X POST
done
rm /tmp/*.xml
