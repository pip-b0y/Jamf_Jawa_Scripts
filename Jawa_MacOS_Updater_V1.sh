#!/bin/bash
#By Hayden
#jawa_macOS_Updater_v1
#Code Name: Porygon_Z_V1
#MacOS Update via UAPI
#Notes for v1
#10.37.X + is required. Endpoints are not in Jamf Pro below 10.37.X
#Assumes you can various update actions
#Script runs per device rather all at once 
#Installs the latest version of MacOS
#Intended to be used with Jawa but can be used as a cron-tab
##############NOTE#########################################################
# - Will update devices to the LATEST VERSION OF THE VERSION THEY ARE RUNNING 
# - if running MacOS 11, it will install the latest version of MacOS 11
# - if running MacOS 12 it will install the latest version of MacOS 12
# - Update Action can be customised DOWNLOAD_AND_INSTALL or DOWNLOAD_ONLY
# - Deferal 0 should be install right away. and anything greater means a user can decline that many times
# - Deferal set to 0 by default
# - Use Bearer tokens and they will get expired at the end of the script.
# - AS IS SCRIPT TEST TEST TEST!
# - if there is something in here that can be done better let me know..... the version calculator is a little wild but hey!
###########################################################################


###Varibles####Should not change####
jssurl='' #jamf pro url with https
jssuser='' #admin user
jsspass='' #password for jamf pro user
token_raw=$(printf "${jssuser}:${jsspass}" | iconv -t ISO-8859-1 | base64 -i -)
group_name_raw='' #This Group will be the group that we are targeting for the restart.
group_name=$(printf "%s\n" "${group_name_raw}" | sed 's/ /%20/g' ) ###Transform groupname for API
work_space=$(ls /tmp/ | grep -w "MacOSUpdates")
date_time=$(date +%F+%H+%M+%s)
deferal='0' # number values only 0-99
update_action='DOWNLOAD_ONLY' #DOWNLOAD_AND_INSTALL or DOWNLOAD_ONLY
###################workspace creation##########################################################################
if [[ "$work_space" == "MacOSUpdates" ]]; then
	echo "its ran before - Rename"
	mv /tmp/MacOSUpdates /tmp/${date_time}MacOSUpdates
	mkdir /tmp/MacOSUpdates
else
	echo "not there lets create it"
	mkdir /tmp/MacOSUpdates
fi
############################################################################################
#authentication
echo "starting PorygonZ getting the api tokens to kick this off. Targeting ${group_name_raw}" >> /tmp/MacOSUpdates/runtime.log
api_token=$(curl -k -X POST ${jssurl}/api/v1/auth/token -H "accept: application/json" -H "Authorization: Basic ${token_raw}" | python -c 'import json,sys;obj=json.load(sys.stdin);print obj ["token"]')
echo "Getting OS Versions from Jamf Pro" >> /tmp/MacOSUpdates/runtime.log
curl -k -X GET ${jssurl}/api/v1/macos-managed-software-updates/available-updates -H "Accept: application/json" -H "Authorization: Bearer ${api_token}" -H "Content-Type: application/json" | python -c 'import json,sys;obj=json.load(sys.stdin);print obj ["availableUpdates"]' > /tmp/MacOSUpdates/jp_os_x_versions.json
#Breakup the file
##Update lists###Convert to single updates one line
echo "Breaking down the reply from ${jssurl}" >> /tmp/MacOSUpdates/runtime.log
raw_update_data=$(cat /tmp/MacOSUpdates/jp_os_x_versions.json)
IFS=', ' read -r -a array <<< "$raw_update_data"
for (( raw_update_data=1; raw_update_data<=(${#array[@]}-1); raw_update_data+=2 )); do
	echo ${array[$raw_update_data]} | tr -d "u'}]" >> /tmp/MacOSUpdates/os_x_versions_raw.log
done
echo "File Converted" >> /tmp/MacOSUpdates/runtime.log
#######
######Version Calculator#########
####Comment:Will add other versions as they are released. Will only do Updates to latest as it is secure and best practice
echo "running the calculator now" >> /tmp/MacOSUpdates/runtime.log
os_ver_file_raw=$(cat /tmp/MacOSUpdates/os_x_versions_raw.log)
for os_ver_file in ${os_ver_file_raw}; do
converted_os_ver_file=$(echo ${os_ver_file} | tr -d '.,')
num_ver=$(echo -n ${converted_os_ver_file} | wc -c )
#use less than 4 to determine if the version needs to be converted. all should have 4 digits ie 12.0.1 if 12.1 is really 12.1.0it should have a extra value added to the end. 
if [[ "${num_ver}" -lt "4" ]];then
#needs to be converted
converted1=$(echo ${converted_os_ver_file} | sed 's/$/0/')
echo "${converted1}" >> /tmp/MacOSUpdates/final_jp_ver.log
else
#number is fine
echo "${converted_os_ver_file}" >> /tmp/MacOSUpdates/final_jp_ver.log
echo 
fi
done
########################################
#
#
#
#########################################
#Get Newest version of macOS 11 and 12 (only care about this for now)#####Raw Values
ver_11_raw=$(cat /tmp/MacOSUpdates/final_jp_ver.log | grep  "11" | sort -n | tail -n 1)
ver_12_raw=$(cat /tmp/MacOSUpdates/final_jp_ver.log | grep  "12" | sort -n | tail -n 1)
touch /tmp/MacOSUpdates/${ver_11_raw}
touch /tmp/MacOSUpdates/${ver_12_raw}
#lets add the value
ver11_line_value=$(grep -n -m 1 ${ver_11_raw} /tmp/MacOSUpdates/final_jp_ver.log | sed 's/\([0-9]*\).*/\1/')
ver11_offical=$(sed -n "${ver11_line_value}p" /tmp/MacOSUpdates/os_x_versions_raw.log)
echo "${ver11_offical}" > /tmp/MacOSUpdates/${ver_11_raw}
ver12_line_value=$(grep -n -m 1 ${ver_12_raw} /tmp/MacOSUpdates/final_jp_ver.log | sed 's/\([0-9]*\).*/\1/')
ver12_offical=$(sed -n "${ver12_line_value}p" /tmp/MacOSUpdates/os_x_versions_raw.log)
echo "${ver12_offical}" > /tmp/MacOSUpdates/${ver_12_raw}
echo "${ver11_offical} has been detected as the latest version of MacOS 11" >> /tmp/MacOSUpdates/runtime.log
echo "${ver12_offical} has been detected as the latest version of MacOS 12" >> /tmp/MacOSUpdates/runtime.log
#################################################################################################
###Calculator end#######


###Grab Some Serial Numbers
echo "Getting the device Serial Numbers" >> /tmp/MacOSUpdates/runtime.log
jamfproserialraw=$(curl -k -H "Authorization: Bearer ${api_token}" ${jssurl}/JSSResource/computergroups/name/${group_name} | xmllint --format - | awk -F'[<|>]' '/<serial_number>/{print $3}')
for mac_serial in ${jamfproserialraw}; do
#GrabOS_version for serial
serial_os_ver_raw=$(curl -k -H "Authorization: Bearer ${api_token}" ${jssurl}/JSSResource/computers/serialnumber/${mac_serial} -X GET | xmllint --format - | xpath -e '//computer/hardware/os_version' 2>&1 | awk -F'<os_version>|</os_version>' '{print $2}' )
computer_id=$(curl -k -H "Authorization: Bearer ${api_token}" ${jssurl}/JSSResource/computers/serialnumber/${mac_serial} -X GET | xmllint --format - | xpath -e '//computer/general/id' 2>&1 | awk -F'<id>|</id>' '{print $2}')
#Convert OS Version ASAP
serial_os_ver=$(echo "${serial_os_ver_raw}" | tr -d '.,')
os_ver_logic=$(echo "${serial_os_ver}" | cut -c 1-2 )
echo "Running check for ${mac_serial} JamfProID ${computer_id} and is running ${serial_os_ver_raw}" >> /tmp/MacOSUpdates/runtime.log
if [[ "${os_ver_logic}" == "12" ]]; then
	echo "${mac_serial} is running MacOS12 going to check the update" >> /tmp/MacOSUpdates/runtime.log
##Will Check for update ability
if [[ "${serial_os_ver}" -lt "${ver_12_raw}" ]]; then
#issue the update for ver 12
echo "${mac_serial} needs to be updated issuing command for ${ver12_offical}" >> /tmp/MacOSUpdates/runtime.log
command_results1=$(curl -k -X POST ${jssurl}/api/v1/macos-managed-software-updates/send-updates -H "Accept: application/json" -H "Authorization: Bearer ${api_token}" -H "Content-Type: application/json" -d "{\"deviceIds\":[\"$computer_id\"],\"maxDeferrals\":${deferal},\"version\":\"${ver12_offical}\",\"updateAction\":\"${update_action}\"}")
echo " API COMMAND ${command_results1}" >> /tmp/MacOSUpdates/runtime.log
echo " Finished with ${mac_serial} moving to the next device" >> /tmp/MacOSUpdates/runtime.log
else
	echo "${mac_serial} is fine we can ignore moving on">> /tmp/MacOSUpdates/runtime.log
fi

else
echo "checking for earlier version 11 for ${mac_serial}" >> /tmp/MacOSUpdates/runtime.log
if [[ "${os_ver_logic}" -lt "11" ]]; then
	echo "${mac_serial} Running less than 11 Exiting running next device" >> /tmp/MacOSUpdates/runtime.log
else
	echo "${mac_serial} is running MacOS11 going to check the update" >> /tmp/MacOSUpdates/runtime.log
if [[ "${serial_os_ver}" -lt "${ver_11_raw}" ]]; then
echo "${mac_serial} needs to be updated issuing command for ${ver11_offical}" >> /tmp/MacOSUpdates/runtime.log
command_results2=$(curl -k -X POST ${jssurl}/api/v1/macos-managed-software-updates/send-updates -H "Accept: application/json" -H "Authorization: Bearer ${api_token}" -H "Content-Type: application/json" -d "{\"deviceIds\":[\"$computer_id\"],\"maxDeferrals\":${deferal},\"version\":\"${ver11_offical}\",\"updateAction\":\"${update_action}\"}")
echo "API COMMAND $command_results2" >> /tmp/MacOSUpdates/runtime.log
echo "Finished with ${mac_serial} moving to the next device" >> /tmp/MacOSUpdates/runtime.log
else
	echo "${mac_serial} is fine we can ignore checking next device" >> /tmp/MacOSUpdates/runtime.log
fi
fi
fi
done
echo "Expiring API Token we are done here" >> /tmp/MacOSUpdates/runtime.log
curl -k -X POST ${jssurl}/api/v1/auth/invalidate-token --header "accept */*" --header "Authorization: Bearer ${api_token}"