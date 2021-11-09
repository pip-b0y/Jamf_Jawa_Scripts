#!/bin/bash
###To be used with Jawa. It will send updates to devices in batches so it is not all at once.
###this is to counter PIs that limit the mass actions
##this will download the lastest update that the device sees from Apple. It will not install a specific update
## If you are going to run this on a mac use BigSur or later :) 
jssuser="USERNAME"
jsspass="PASSWORD"
jssurl="https://YOURJAMFURL"
groupname_raw="testing_device" #dont worry about spaces we will fix this
command_to_run='1' #1 = download and let user install 2 = download, install and restart the device.
elements='20' #do in batches. this is the ammount of devices in one call
wait_time='1' #time to wait between runs should be adjusted in seconds
log_path='/tmp/updatedevice.log' # for jawa make this /usr/local/jawa/security/update_devices.log or what ever works for you!
time_stamp=$(date)
#Varibles End
###Create a token incase of someone listening###
token=$(printf "${jssuser}:${jsspass}" | iconv -t ISO-8859-1 | base64 -i -)
################################################################################
#
#
#
###########
####SCRIPT Start
#
#
#
echo " ${time_stamp} kicking off the build " >> ${log_path}
groupname=$(printf "%s\n" "${groupname_raw}" | sed 's/ /%20/g' )
echo "targeting ${groupname_raw} as ${groupname} maximum fire power" >> ${log_path}
mobile_device_id_raw=($(curl -sk --header "authorization: Basic ${token}" ${jssurl}/JSSResource/mobiledevicegroups/name/${groupname} | xmllint --format - | xpath -e '//mobile_device_group/mobile_devices/mobile_device/id' | awk -F'<id>|</id>' '{print $2}' | awk 'NR>0' ))
list1=${#mobile_device_id_raw[@]}
echo "devices found ${list1} the droids we are looking for" >> ${log_path}
for ((i = 0 ; i < ${list1} ; i++)); do
id_list=$(echo ${mobile_device_id_raw[@]:$start:$elements} | sed 's/ /,/g')
if ! [ -z "${id_list}" ]; then
echo 'Processing '"${id_list} Results below for this batch" >> ${log_path}
curl -sk --header "authorization: Basic ${token}" ${jssurl}/JSSResource/mobiledevicecommands/command/ScheduleOSUpdate/${command_to_run}/id/${id_list} -X POST >> ${log_path}
echo "" >> ${log_path}
else
echo 'Finished Processing' >> ${log_path}
break
fi
sleep ${wait_time}
(( start=start+${elements} ))
done
time_stamp2=$(date)
echo "${time_stamp2} finished the Kessel run" >> ${log_path}
####
