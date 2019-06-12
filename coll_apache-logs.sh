#!/bin/bash

# Requirements
#  mysql

# Echo script name and time (start)
echo -n "$0, start at "
date
echo ""

# Read config file
conffile=$1
if test -r "$conffile" -a -f "$conffile"
then
        . $conffile
else
        echo "Call: $0 <conffile>"
        exit
fi

# Check the parameter read from the config file and set
# default values if necessary
host=${host:-"localhost"}
port=${port:-3306}
database=${database:-"bruteforce"}
user=${user:-"bruteforce"}
password=${password:-""}

# MySQL command string
mysqlcmd="mysql -h $host -P $port -u $user -p$password \
				        -D $database"

# Create temporary file for the sshd logs
tempfile="/tmp/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13).txt"
touch $tempfile

# Search for all apache logs with message "script
# [...] not found or unable to stat" and pipe them to the
# temporary file
logfiles="/var/log/apache2/error.log*"
echo "Scanning $logfiles . . ."
for logfile in $logfiles; do
	echo "  - $logfile"
	filename=`basename $logfile`
	extension=${filename##*.}
	if [ "$extension" == "gz" ]
	then
		zcat $logfile | grep "not found or unable to stat" >> $tempfile
	else
		cat $logfile | grep "not found or unable to stat" >> $tempfile
	fi
done
sed -i -e "s/\[//g" $tempfile
sed -i -e "s/\]//g" $tempfile
echo "  Completed."
echo ""

# Count the lines in table apache_logs before inserting the latest log entries
n_before=$($mysqlcmd -N -e "select count(time) from apache_logs;")

# Loop through every log message, extract the data and store
# it into database
echo -n "Processing "
while read line; do
	IFS=' ' read -ra data <<< "$line"

	timestr="${data[0]} ${data[1]} ${data[2]} ${data[3]} ${data[4]}"
	time_unix=`date --utc --date "$timestr" +%s`
	process_id=${data[7]}
	source_ip=`echo ${data[9]} | awk -F ":" '{print $1}'`
	source_port=`echo ${data[9]} | awk -F ":" '{print $2}'`
	script=${data[11]}

	$mysqlcmd -e "insert ignore into apache_logs \
		(time,script,source_ip,source_port) values \
	       	($time_unix,\"$script\",\"$source_ip\",$source_port);"
	echo -n "."
done < $tempfile
echo " finished."

# Count the lines in table apache_logs after inserting the latest log entries
n_after=$($mysqlcmd -N -e "select count(time) from apache_logs;")
n_added=$((n_after-n_before))
echo "Added $n_added entries to database."

# Delete temporary file
rm $tempfile

# Echo script name and time (end)
echo -n "$0, end at "
date
echo ""

# SQL to set-up database for this script
# CREATE TABLE apache_logs (time real, script text, source_ip text, source_port integer);
# CREATE UNIQUE INDEX unique_time_stamp2 on apache_logs(time);
