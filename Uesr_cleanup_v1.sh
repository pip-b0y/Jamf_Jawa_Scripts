#!/bin/bash
###Will delete users with no attachements meaning no managed apple id, mobile device, computer or vpp token
###This script is AS IS 
#Log created in /tmp
#User_cleanup
#Version 1
###Set Var##
jssuser=''
jsspass=''
jssurl='' #JSSURL with https
##################
#Token Generation#
token=$(printf "${jssuser}:${jsspass}" | iconv -t ISO-8859-1 | base64 -i -)
api_token_raw=$(curl -X POST ${jssurl}/api/v1/auth/token -H "accept: application/json" -H "Authorization: Basic ${token}")
api_token=$(echo ${api_token_raw} | awk -F '[:,{"}]' ' {print $6} ')
##################


####Script#####
user_id_raw=$(curl -sk --header "Authorization: Bearer ${api_token}" $jssurl/JSSResource/users | xmllint --format - | xpath -e '//users/user/id' 2>&1 | awk -F'<id>|</id>' '{print $2}')
for user_id in ${user_id_raw}; do
curl -sk --header "Authorization: Bearer ${api_token}" $jssurl/JSSResource/users/id/$user_id | xmllint --format - > /tmp/usercleanup_${user_id}.xml
username=$(cat /tmp/usercleanup_${user_id}.xml | xpath -e '//user/name' 2>&1 | awk -F'<name>|</name>' '{print $2}')
echo "###########" >> /tmp/UserDelete.log
echo "checking ${username} id of ${user_id} for a computer / mobiledevice / vpp assignment" >> /tmp/UserDelete.log

#computer object check
userdata_computer=$(cat /tmp/usercleanup_${user_id}.xml | xpath -e '//user/links/computers/computer/id' 2>&1 | awk -F'<id>|</id>' '{print $2}')
if [[ $userdata_computer = '' ]]; then
echo "$username has no computer assigned " >> /tmp/UserDelete.log


#check for mobile device object
userdata_mobiledevice=$(cat /tmp/usercleanup_${user_id}.xml | xpath -e '//user/links/mobile_devices/id' 2>&1 | awk -F'<id>|</id>' '{print $2}')
if [[ $userdata_mobiledevice = '' ]]; then
echo "$username has no mobile device assigned " >> /tmp/UserDelete.log


#Check for VPP
userdata_vpp=$(cat /tmp/usercleanup_${user_id}.xml | xpath -e '//user/links/vpp_assignments/id' 2>&1 | awk -F'<id>|</id>' '{print $2}')
if [[ $userdata_vpp = '' ]]; then
echo "$username has no vpp assignment" >> /tmp/UserDelete.log


#check of apple id could be in a roster
echo "checking appleid" >> /tmp/UserDelete.log
userdata_appleid=$(cat /tmp/usercleanup_${user_id}.xml | xpath -e '//user/roster_managed_apple_id' 2>&1 | awk -F'<roster_managed_apple_id>|</roster_managed_apple_id>' '{print $2}')
if [[  "${userdata_appleid}" = '' ]]; then
echo "$username has no managed appleid assigned" >> /tmp/UserDelete.log

###Procced with the delete###
echo "Warning $username has no device or vpp assignment will delete object" >> /tmp/UserDelete.log
apidelete=$(curl -sk --header "Authorization: Bearer ${api_token}" $jssurl/JSSResource/users/id/$user_id -X DELETE)
echo "$username is deleted results below" >> /tmp/UserDelete.log
echo "$apidelete" >> /tmp/UserDelete.log

else
echo "$username has a managed appleid assigned $userdata_appleid cant delete" >> /tmp/UserDelete.log
fi

else
echo "$username has a vpp assignment cant delete" >> /tmp/UserDelete.log
fi

else
echo "$username has a mobile device assigned cant delete user " >> /tmp/UserDelete.log
fi

else
echo "$username has a computer assigned cant delete user" >> /tmp/UserDelete.log
fi

###cleanup
rm /tmp/usercleanup_${user_id}.xml
done #accounted for

open /tmp/UserDelete.log
