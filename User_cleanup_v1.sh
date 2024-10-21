#!/bin/bash
###Will delete users with no attachements meaning no managed apple id, mobile device, computer or vpp token
###This script is AS IS 
#Log created in /tmp
#User_cleanup
#Version 1.1.1
#Changes:
# - Changed to modern authentication
# - General House Keeping of script
# Upcoming Changes
# - Reauth, the auth token can expire while working through the user list (known issue with script and large amounts of users)
###Set Var##
username=''
password=''
url='' #JSSURL with https
#Variable declarations
bearerToken=""
tokenExpirationEpoch="0"
#Functions
getBearerToken() {
	response=$(curl -s -u "$username":"$password" "$url"/api/v1/auth/token -X POST)
	bearerToken=$(echo "$response" | plutil -extract token raw -)
	tokenExpiration=$(echo "$response" | plutil -extract expires raw - | awk -F . '{print $1}')
	tokenExpirationEpoch=$(date -j -f "%Y-%m-%dT%T" "$tokenExpiration" +"%s")
}

checkTokenExpiration() {
	nowEpochUTC=$(date -j -f "%Y-%m-%dT%T" "$(date -u +"%Y-%m-%dT%T")" +"%s")
	if [[ tokenExpirationEpoch -gt nowEpochUTC ]]
	then
		echo "Token valid until the following epoch time: " "$tokenExpirationEpoch"
	else
		echo "No valid token available, getting new token"
		getBearerToken
	fi
}

invalidateToken() {
	responseCode=$(curl -w "%{http_code}" -H "Authorization: Bearer ${bearerToken}" $url/api/v1/auth/invalidate-token -X POST -s -o /dev/null)
	if [[ ${responseCode} == 204 ]]
	then
		echo "Token successfully invalidated"
		bearerToken=""
		tokenExpirationEpoch="0"
	elif [[ ${responseCode} == 401 ]]
	then
		echo "Token already invalid"
	else
		echo "An unknown error occurred invalidating the token"
	fi
}

####Script#####
counter=0
getBearerToken
curl -sk --header "Authorization: Bearer ${bearerToken}" $url/JSSResource/users | xmllint --format - > /tmp/users_raw.xml
user_id_raw=$(cat /tmp/users_raw.xml | xpath -e '//users/user/id' 2>&1 | awk -F'<id>|</id>' '{print $2}')
for user_id in ${user_id_raw}; do
	echo $user_id
	curl -sk --header "Authorization: Bearer ${bearerToken}" $url/JSSResource/users/id/$user_id | xmllint --format - > /tmp/usercleanup_${user_id}.xml
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
					apidelete=$(curl -sk --header "Authorization: Bearer ${bearerToken}" $url/JSSResource/users/id/$user_id -X DELETE)
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
