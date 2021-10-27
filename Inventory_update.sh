#!/bin/bash
#1 - Create a profile in Apple Configuration with auto remove enabled (set it for 3 minutes)
#2 - Upload the profile to Jamf Pro and scope it to devices via self service
#3 - Create a smart group to look for that profile when installed
#Explain: The user installs the profile to put the device in the smart group, once the profile list commands. Jamf Pro will send a web hook (you need to set that up first)
#To then trigger this script. The inventory on the device will be updated and the profile will be removed with in that 3 miniute window. Testing made easy!
#A lock device message is sent to let you know that it is complete.
jssuser="JSSUSERNAME"
jsspass="PASSWORD"
jssurl="URL"
groupname="Group_Name_no_spaces"
#############
###Request Inventroy Update with profile that expires###
sleep 300
token=$(printf "${jssuser}:${jsspass}" | iconv -t ISO-8859-1 | base64 -i -)
idraw=$(curl -sk --header "authorization: Basic ${token}" ${jssurl}/JSSResource/mobiledevicegroups/name/${groupname} | xmllint --format - | xpath -e '//mobile_device_group/mobile_devices/mobile_device/id' 2>&1 | awk -F'<id>|</id>' '{print $2}')
for id in ${idraw};do
curl -sk --header "authorization: Basic ${token}" ${jssurl}/JSSResource/mobiledevices/id/${id} | xmllint --format - > /tmp/${id}.xml
devicename=$(cat /tmp/${id}.xml | xpath -e '//mobile_device/general/display_name' 2>&1 | awk -F'<display_name>|</display_name>' '{print $2}')
lastupdate=$(cat /tmp/${id}.xml | xpath -e '//mobile_device/general/last_inventory_update_epoch'  2>&1 | awk -F'<last_inventory_update_epoch>|</last_inventory_update_epoch>' '{print $2}')
serialnumber=$(cat /tmp/${id}.xml | xpath -e '//mobile_device/general/serial_number' 2>&1 | awk -F'<serial_number>|</serial_number>' '{print $2}')
curl -sk --header "authorization: Basic ${token}" ${jssurl}/JSSResource/mobiledevicecommands/command/UpdateInventory/id/${id} -X POST
curl -sk --header "authorization: Basic ${token}" ${jssurl}/JSSResource/mobiledevicecommands/command/BlankPush/id/${id} -X POST
sleep 3
curl -sk --header "authorization: Basic ${token}" ${jssurl}/JSSResource/mobiledevicecommands/command/DeviceLock/Inventory%20has%20been%20Updated/id/${id} -X POST
done
rm /tmp/*.xml
