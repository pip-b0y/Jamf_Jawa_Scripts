#!/bin/bash
#version 1.3
#changelog: version 1.3 changes
# - Modified the plist / agent
# - Added full working paths into the script.
# - Removed keep alive caused script to run too frequently
# - Fixed Spelling error in StartInterval. Its not longer StrartInterval - d'oh 
########Details#########
#executes script to kill the jamf binary and kickstart it again in the event that it is stuck for unforseen reasons. 
#Script name checkpro.sh
#script path /Library/Application\ Support/JAMF/checkpro.sh
#plist name checkpro.plist
#plist path /Library/LaunchDaemons/checkpro.plist
#
#
#
currentuser=$(who | awk '/console/{print $1}')
###################
#Script to run#
cat << 'EOF' > /Library/Application\ Support/JAMF/checkpro.sh
###checks Jamf Binary status, needs to pass 2 checks
date_start=$(date)
date_end=$(date)
last_line_in_log=$(/usr/bin/tail -1 /var/log/jamf.log | /usr/bin/grep "The management framework will be enforced as soon as all policies are done executing")
binary_running=$(/bin/ps aux | /usr/bin/grep 'jamf' | /usr/bin/grep -p 'randomDelaySeconds 300' | /usr/bin/awk '{print $11,$12,$13,$14,$15}')
echo "{$date_start} starting the binary check" >> /var/log/jamfcheck.log
#checking to see if the logs has evidence of stuck binary
if [[  "${last_line_in_log}" =~ "The management framework will be enforced as soon as all policies are done executing." ]]; then
echo "binary stuck need to run the next check" >> /var/log/jamfcheck.log

#Check to see if the random checkin for logs is stuck
if [[ "${binary_running}" =~ "/usr/local/jamf/bin/jamf policy -stopConsoleLogs -randomDelaySeconds 300" ]]; then
	echo "binary running will kill the binary"  >> /var/log/jamfcheck.log
/usr/bin/sudo /usr/bin/killall jamf
/usr/bin/sudo /usr/local/bin/jamf policy
else
echo "not running its likely that its not stuck. But will run the kill." >> /var/log/jamfcheck.log
/usr/bin/sudo /usr/bin/killall jamf
/usr/bin/sudo /usr/local/bin/jamf policy
fi
else
echo "not stuck based off the last line so we can close for now." >> /var/log/jamfcheck.log
fi
echo "{$date_end} finished the binary check" >> /var/log/jamfcheck.log
EOF
#Change permissions on the script
/usr/bin/sudo /bin/chmod +x "/Library/Application Support/JAMF/checkpro.sh"

#Create plist
/usr/bin/sudo /usr/bin/defaults write /Library/LaunchDaemons/checkpro.plist Label -string "checkpro"
#Add script path
/usr/bin/sudo /usr/bin/defaults write /Library/LaunchDaemons/checkpro.plist ProgramArguments -array -string "/bin/sh" -string "/Library/Application Support/JAMF/checkpro.sh"
#Nice?
/usr/bin/sudo /usr/bin/defaults write /Library/LaunchDaemons/checkpro.plist Nice -integer "20"
#time to run in seconds runs every 31 minutes account for the random time that binary checks in
/usr/bin/sudo /usr/bin/defaults write /Library/LaunchDaemons/checkpro.plist StartInterval -integer "1860"
#set run at load
/usr/bin/sudo /usr/bin/defaults write /Library/LaunchDaemons/checkpro.plist RunAtLoad -boolean yes

#set ownership

/usr/bin/sudo /usr/sbin/chown root:wheel /Library/LaunchDaemons/checkpro.plist
/usr/bin/sudo /bin/chmod 644 /Library/LaunchDaemons/checkpro.plist

#load the plist
/bin/launchctl load /Library/LaunchDaemons/checkpro.plist
sleep 10
exit 0