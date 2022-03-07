#!/bin/bash
###Version 1.1
#By Hayden
#As is script
### Need to use a couple of endpoints and mix and match. Complicated but can do it!
#UAPI /preview/computers = managementID + serial number 
#UAPI /preview/mdm = restart function
#Static Group of devices to restart + serial number /JSSResource
###UAPI TOOLING
command='RESTART_DEVICE' # can be  DELETE_USER, ENABLE_LOST_MODE, LOG_OUT_USER, RESTART_DEVICE, SETTINGS, SET_RECOVERY_LOCK for computers
device_type="COMPUTER" # can be Mobile Device
##############################################################################################################################
###
#######DETAILS
jssurl='' #jamf pro url with https
jssuser='' #admin user
jsspass='' #passowrd for jamf pro user
token_raw=$(printf "${jssuser}:${jsspass}" | iconv -t ISO-8859-1 | base64 -i -)
group_name_raw='' #This Group will be the group that we are targeting for the restart.
group_name=$(printf "%s\n" "${group_name_raw}" | sed 's/ /%20/g' ) ###Transform groupname for API
########
###UAPI Functions token####
api_token=$(curl -X POST ${jssurl}/api/v1/auth/token -H "accept: application/json" -H "Authorization: Basic ${token_raw}" | python -c 'import json,sys;obj=json.load(sys.stdin);print obj ["token"]')
#Computer List RAW
curl -X GET "${jssurl}/api/preview/computers?page=0&size=1000&pagesize=1000&page-size=1000&sort=name%3Aasc" -H "Accept: application/json" -H "Authorization: Bearer ${api_token}" > /tmp/computer_list_raw.json

#GetSerials from group and loop
jamfproserialraw=$(curl -sk --header "Authorization: Basic ${token_raw}" ${jssurl}/JSSResource/computergroups/name/${group_name} | xmllint --format - | awk -F'[<|>]' '/<serial_number>/{print $3}')

for mac_serial in ${jamfproserialraw};do
if grep -q "${mac_serial}" /tmp/computer_list_raw.json
then
	echo "Serial there can send reboot command"
###Get Management ID
management_id=$(cat /tmp/computer_list_raw.json | grep -A 11 "$mac_serial" | grep "managementId" | tr -d " " | tr -d ','| tr -d '"' | sed -r 's/^.{13}//')
echo "$management_id" >> /tmp/api_results.log
###UAPI Command to restart #### EXAMPLE WORKS!!!!!
out=$(curl -X POST ${jssurl}/api/preview/mdm/commands -H "Accept: application/json" -H "Authorization: Bearer ${api_token}" -H "Content-Type: application/json" -d "{\"clientData\":[{\"managementId\":\""${management_id}\"",\"clientType\":\"${device_type}\"}],\"commandData\":{\"commandType\":\"${command}\"}}")
echo "$out" >> /tmp/api_results.log
else
	echo "serial not there"
fi

done

echo "Results are printed to /tmp/api_results.log"