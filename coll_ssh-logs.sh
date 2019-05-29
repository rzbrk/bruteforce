#!/bin/bash

# Database file
#db="/root/bad_logs.db"
db=$1

# Create temporary file for the sshd logs
tempfile="/tmp/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13).txt"
touch $tempfile

# Ask journalctl for all sshd logs with "Invalid user" and
# pipe them to the temporary file
journalctl -o short-unix -u ssh | grep "Invalid user" > $tempfile

# Loop through every log message, extract the data and store
# it into database
while read line; do
	IFS=' ' read -ra data <<< "$line"
	#echo ${data[@]}
	time_unix=${data[0]}
	proc_id=${data[2]}
	user=${data[5]}
	source_ip=${data[7]}
	source_port=${data[9]}

	sqlite3 $db "insert or ignore into ssh_logs \
		(time,user,source_ip,source_port) values \
	       	($time_unix,\"$user\",\"$source_ip\",$source_port);"
done < $tempfile

# Delete temporary file
rm $tempfile

# SQL to set-up database for this script
# CREATE TABLE ssh_logs (time real, user text, source_ip text, source_port integer);
# CREATE UNIQUE INDEX unique_time_stamp on ssh_logs(time);

