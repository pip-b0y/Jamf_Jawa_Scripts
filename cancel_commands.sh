#!/bin/bash
##This script will need to be added twice to your JAWA server. One to cover Computers and the other mobile devices###
#Best to run out side of business hours incase of DEP devices enrolling.
###Note if you are running this in a ubuntu server. Save your self time and turn off dash. run sudo dpkg-reconfigure dash and select no :) 
##Varibles Start
jssuser="USERNAME"
jsspass="PASSWORD"
jssurl="https://YOURJAMFURL"
groupname_raw="All Managed Clients" #dont worry about spaces we will fix this
elements='2' #do in batches. this is the ammount of devices in one call
device_type='computers or mobiledevices' ##can be computers or mobiledevices
flush_type='Pending+Failed or pending or failed' #Can be Pending+Failed OR Failed OR Pending
wait_time='1' #time to wait between runs should be adjusted in seconds
start='0' #Usually will be set to 0
log_path='/usr/local/jawa/security/royal_flush.log' # for jawa make this /usr/local/jawa/security/royal_flush.log
time_stamp=$(date)
#Varibles End
###Create a token incase of someone listening###
token=$(printf "${jssuser}:${jsspass}" | iconv -t ISO-8859-1 | base64 -i -)
################################################################################
#
#
#
###Creating a single script to determine if a script should target computers or mobiledevices########
####SCRIPT Start
#
#
#
if [[ "${device_type}" == "mobiledevices" ]] ;then
echo "mobile Devices selected" >> ${log_path}
echo " ${time_stamp} Starting the Kessel run hopefully done in less than 12" >> ${log_path}
groupname=$(printf "%s\n" "${groupname_raw}" | sed 's/ /%20/g' )
echo "targeting ${groupname_raw} as ${groupname}" >> ${log_path}
mobile_device_id_raw=($(curl -sk --header "authorization: Basic ${token}" ${jssurl}/JSSResource/mobiledevicegroups/name/${groupname} | xmllint --format - | awk -F'[<|>]' '/<id>/{print $3}' | awk 'NR>0' ))
#build Array
list1=${#mobile_device_id_raw[@]}
echo "devices found ${list1}" >> ${log_path}
for ((i = 0 ; i < ${list1} ; i++)); do
id_list=$(echo ${mobile_device_id_raw[@]:$start:$elements} | sed 's/ /,/g')
if ! [ -z "${id_list}" ]; then
echo 'Processing '"${id_list}" >> ${log_path}
#cancel commands pending and failed
curl -sk --header "authorization: Basic ${token}" ${jssurl}/JSSResource/commandflush/mobiledevices/id/${id_list}/status/${flush_type} DELETE
else
echo 'Finished Processing' >> ${log_path}
break
fi
sleep ${wait_time}
(( start=start+${elements} ))
done
time_stamp2=$(date)
echo "${time_stamp2} finished the Kessel run" >> ${log_path}
#############################################################################
else
#############################################################################
echo "computers selected" >> ${log_path}
groupname=$(printf "%s\n" "${groupname_raw}" | sed 's/ /%20/g' )
echo " ${time_stamp} Starting the Kessel run hopefully done in less than 12" >> ${log_path}
echo "targeting ${groupname_raw} as ${groupname}" >> ${log_path}
computer_device_id_raw=($(curl -sk --header "authorization: Basic ${token}" ${jssurl}/JSSResource/computergroups/name/${groupname} | xmllint --format - | awk -F'[<|>]' '/<id>/{print $3}' | awk 'NR>0' ))
#Build Array
list1=${#computer_device_id_raw[@]}
echo "devices found ${list1}" >> ${log_path}
for ((i = 0 ; i < ${list1} ; i++)); do
id_list=$(echo ${computer_device_id_raw[@]:$start:$elements} | sed 's/ /,/g')
if ! [ -z "${id_list}" ]; then
echo 'Processing '"${id_list}" >> ${log_path}
#cancel commands pending and failed
curl -sk --header "authorization: Basic ${token}" ${jssurl}/JSSResource/commandflush/computers/id/${id_list}/status/${flush_type} DELETE
else
echo 'Finished Processing' >> ${log_path}
break
fi
sleep ${wait_time}
(( start=start+${elements} ))
done
time_stamp2=$(date)
echo "${time_stamp2} finished the Kessel run" >> ${log_path}
############################################################################
fi
