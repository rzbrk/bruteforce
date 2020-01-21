#!/bin/bash

# Requirements:
#  mysql
#  nmap

# Echo script name and time (start)
echo -n "$0, start at "
date
echo ""

# Scanning multiple hosts can take a very long time. If this
# script is scheduled by e.g. cron we should ensure not to
# run multiple instances of this script in parallel.
# Therefore, use lock file. The file descriptor 567 is an
# arbitrary number.
exec 567>/var/lock/scan_hosts || exit 1
	flock -n 567 || {
		echo "$0 already running ... exiting"
		exit 1
	}	

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
mysqlcmd="mysql -h $host -P $port -u $user --password=$password \
        -D $database"

# Limit time to scan host (default 10 minutes)
timeout=${2-10m}

# See if table hosts already has column nmap for nmap output.
# If not, create column
c_nmap_exists=$($mysqlcmd -N -B -e "select count(*) from \
	information_schema.columns where \
	table_schema=\"$database\" and table_name=\"hosts\" \
	and column_name=\"nmap\";")
if (( $c_nmap_exists != 1 ))
then
	$(mysqlcmd -e "alter table \"hosts\" add nmap text;")
fi

# Select all IP addresses where the nmap field is empty.
ips=$($mysqlcmd -N -B -e  "select ipAddr from hosts where \
	nmap is null;")

# For all IP addresses with empty field nmap perform a
# nmap scan
for ip in $ips
do
	# Create a temporary file to hold the sql statement
	# to update the database. The reason for this is that
	# the string returned from nmap can be too long to
	# be processed in a bash command.
	tempfile="/tmp/$(head /dev/urandom \
		| tr -dc A-Za-z0-9 | head -c 13).sql"
	touch $tempfile

	# Perform a fast (-T4) nmap scan for discovery of
	# operating system and services (-A). Output is
	# formatted to XML to make it easier to use parse
	# through the results for a detailed analysis.
	# The time spent to scan a host can be limited. If
	# no value is provided by command line argument a
	# default value of 10 minutes per host is assumed.
	echo "Scanning $ip . . ."
	
	echo -n "update hosts set nmap='" >> $tempfile
	echo -n `nmap --host-timeout $timeout -A -T4 $ip \
		-oX -` >> $tempfile
	echo -n "' where ipAddr=\"$ip\";" >> $tempfile
	
	# Save results to database
	$mysqlcmd < $tempfile
	#$mysqlcmd -e "update hosts \
	#	set nmap='${nmap_out}' where \
	#	ipAddr = \"$ip\";"

	# Delete tempfile
	rm $tempfile
done

# Echo script name and time (end)
echo -n "$0, end at "
date
echo ""

