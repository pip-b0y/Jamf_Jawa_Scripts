#!/bin/bash
#Version 1.0
#By Hayden
#Reinstall the Jamf Binary based off Device ID
#Target a subset of computers to re-install the Jamf Binary
#for Jamf Pro running version 10.36.X+ only
#Caution! This will cause the Jamf Pro Binary to kick off policies that may have already completed on the device 
#Varibles#
jssurl='' #Jamf Pro URL with https
jssuser='' #JamfPro User Name
jsspass='' #Jamf Pro Passowrd
token_raw=$(printf "${jssuser}:${jsspass}" | iconv -t ISO-8859-1 | base64 -i -)
group_name_raw='' #This Group will be the group that we are targeting for the restart.
group_name=$(printf "%s\n" "${group_name_raw}" | sed 's/ /%20/g' ) ###Transform groupname for API
#Auth Token#
echo "Generating token" >> /tmp/re_install_binary.log
api_token=$(curl -X POST ${jssurl}/api/v1/auth/token -H "accept: application/json" -H "Authorization: Basic ${token_raw}" | python -c 'import json,sys;obj=json.load(sys.stdin);print obj ["token"]')
###Get Computer ids to issue the command. Using the Classic api
computer_id_raw=$(curl -sk --header "Authorization: Bearer ${api_token}" ${jssurl}/JSSResource/computergroups/name/${group_name} | xmllint --format - | xpath -e '//computer_group/computers/computer/id' 2>&1 | awk -F'<id>|</id>' '{print $2}')
echo "Gathered IDs Starting loops" >> /tmp/re_install_binary.log
##Lets loop the IDs and Trigger the reinstall
for computer_id in ${computer_id_raw};do
api_post_data=$(curl -X POST ${jssurl}/api/v1/jamf-management-framework/redeploy/${computer_id} --header "accept: application/json" --header "Authorization: Bearer ${api_token}")
echo "${api_post_data}" >> /tmp/re_install_binary.log
done
#expire the token!
echo "Expiring API Token we are done here" >> /tmp/re_install_binary.log
curl -X POST ${jssurl}/api/v1/auth/invalidate-token --header "accept */*" --header "Authorization: Bearer ${api_token}"
exit