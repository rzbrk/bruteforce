#!/bin/bash

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
host=${host:-"rasputin.selfip.net"}
port=${port:-3306}
database=${database:-"bruteforce"}
user=${user:-"bruteforce"}
password=${password:-""}

# MySQL command string
mysqlcmd="mysql -h $host -P $port -u $user -p$password \
        -D $database"

# SSH logfile
logfile=$2

cnt=0

while read line; do
	# Get rid of the "auth.log" string at the beginning
	# of the line
	line=`sed -e "s/^auth.log[^:]*://" <<< $line`

	# Separate lines into columns (separation char " ")
	IFS=' ' read -ra data <<< "$line"

	# Cocatenate time string. In auth.log the year is
	# missing, so add it (2019) here. As we have multiple
	# logs per second we have to add "dummy microseconds"
	# to each line, because we need to have a unique
	# timestamp to distinguish separate log lines
	dummyms=`head /dev/urandom | tr -dc 0-9 | head -c 5`
	timestr="${data[0]} ${data[1]} ${data[2]}.$dummyms 2019"
	time_unix=`date --utc --date "$timestr" +%s.%N`
	proc_id=`sed -r 's/^sshd\[([0-9]+)\]:/\1/' <<< ${data[4]}`
	user=${data[7]}
	source_ip=${data[9]}
	source_port=${data[11]}

	#echo "$timestr $time_unix $source_ip $source_port $user $proc_id"

	$mysqlcmd -e "insert or ignore into ssh_logs \
		(time,user,source_ip,source_port) values \
		($time_unix,\"$user\",\"$source_ip\",$source_port);"

	cnt=$((cnt+1))
	echo $cnt

done < $logfile

