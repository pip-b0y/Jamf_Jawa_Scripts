#!/bin/bash
###Used in my Support test bench. Is intended to be used in Jamf JAWA, but if you do not have Jawa there is nothing stopping you from running this as is.
###This will enable RDP on devices that are in the specified smart group or static group 
###As is script.
jssuser="USERNAMEHERE"
jsspass="PASSWORDHERE"
jssurl="JAMFURL"
groupname="GROUPNAME-NO-SPACES"
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
    sleep 30
    curl -sk --header "authorization: Basic ${token}" ${jssurl}/JSSResource/computercommands/command/EnableRemoteDesktop/id/${id} -X POST >> /tmp/apiout.log
done
