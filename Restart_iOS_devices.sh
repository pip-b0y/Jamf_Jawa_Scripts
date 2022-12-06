#!/bin/bash
#Script is as no official support for this script.


jssuser="" #API User
jsspass="" #API Password
jssurl="" #Jamf Pro URL https needed and port
groupname_raw="All Managed Devices" #dont worry about spaces we will fix this All Managed Clients is a Example!
log_path='/tmp/reboot_ios.log' 
time_stamp=$(date)

###Create a token incase of someone listening###
token=$(printf "${jssuser}:${jsspass}" | iconv -t ISO-8859-1 | base64 -i -)
#Script Start
echo "${time_stamp} mobile Devices selected targeting ${groupname_raw}" >> ${log_path}
groupname=$(printf "%s\n" "${groupname_raw}" | sed 's/ /%20/g' )
echo "${time_stamp} Gathering Mobile Device IDs" >> ${log_path}
mobile_device_id_raw=$(curl -sk --header "authorization: Basic ${token}" ${jssurl}/JSSResource/mobiledevicegroups/name/${groupname} | xmllint --format - | awk -F'[<|>]' '/<id>/{print $3}' | awk 'NR>0' )
for md_id in ${mobile_device_id_raw};do
echo "${time_stamp} sending reboot to ${md_id}" >> ${log_path}
curl -sk --header "authorization: Basic ${token}" ${jssurl}/JSSResource/mobiledevicecommands/command/RestartDevice/id/$md_id -X POST  >> ${log_path}
echo "${time_stamp} Reboot sent, moving to next device"  >> ${log_path}
done
