#!/bin/bash

# Requirements:
#  mysql
#  jq

# Echo script name and time (start)
echo -n "$0, start at "
date
echo ""

# Processing multiple hosts can take a long time. If this
# script is scheduled by e.g. cron we should ensure not to
# run multiple instances of this script in parallel.
# Therefore, use lock file. The file descriptor 678 is an
# arbitrary number.
exec 678>/var/lock/resolve_hostname || exit 1
        flock -n 678 || {
		echo "$0 already running ... exiting"
		exit 1
	}

# Clean string from special characters
clean_str () {
	string=$1
	# Remove any backslashes
	string=$(sed 's/\\//g' <<< $string)
	# Remove any "
	string=$(sed 's/\"//g' <<< $string)
	echo $string
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

# This script basically collects ip address from tables
# in the database and creates entry in tables hosts if
# this ip address is unknown so far (has no entry in
# table hosts). Any "source" table is good as long as
# contains a column "source_ip". Therefore, retrieve a
# list of tables in the database with such a column:
source_tables=$($mysqlcmd -N -B -e \
	"select distinct table_name \
	from information_schema.columns \
	where column_name=\"source_ip\" \
	and table_schema=\"bruteforce2\";")

# The variable n_ips is the number of unknown ips.
# Initialize this variable and loop over all tables
# found above to obtain n.
n_ips=0
for tbl in $source_tables
do
	n=$($mysqlcmd -N -B -e "select count($tbl.source_ip) \
	         from $tbl left join hosts \
	         on ($tbl.source_ip = hosts.ipAddr) \
	         where hosts.ipAddr is null;")
	n_ips=$((n_ips+n))
done

while (( n_ips > 0  ))
do

	# Search in all tables for unknown ip addresses to
	# process. Limit the number of ips to 1 per table for
	# each round of the while loop not to run in trouble
	# with long ip lists.
	echo ""
	echo -n "Search database for IP addresses to process ... "
	ips=""
	for tbl in $source_tables
	do
		ip=$($mysqlcmd -N -B -e "select $tbl.source_ip \
			from $tbl left join hosts on \
			($tbl.source_ip = hosts.ipAddr) \
			where hosts.ipAddr is null limit 1;")
		ips="$ips $ip"
	done
	echo "ready!"

	# Loop over all IPs in the above list, determine if 
	# we already looked up the information. If not query
	# extreme-ip-lookup.com and save information to
	# database.
	for ip in $ips
	do

		echo "Look up $ip"
		q=$(curl -s extreme-ip-lookup.com/json/$ip)
		now=$(date +%s)

		businessName=$(jq -r '.businessName' <<<$q)
		businessName=$(clean_str "$businessName")
		businessWebsite=$(jq -r '.businessWebsite' <<<$q)
		businessWebsite=$(clean_str "$businessWebsite")
		city=$(jq -r '.city' <<<$q)
		city=$(clean_str "$city")
		continent=$(jq -r '.continent' <<<$q)
		continent=$(clean_str "$continent")
		country=$(jq -r '.country' <<<$q)
		country=$(clean_str "$country")
		countryCode=$(jq -r '.countryCode' <<<$q)
		countryCode=$(clean_str "$countryCode")
		ipName=$(jq -r '.ipName' <<<$q)
		ipName=$(clean_str "$ipName")
		ipType=$(jq -r '.ipType' <<<$q)
		ipType=$(clean_str "ipType")
		isp=$(jq -r '.isp' <<<$q)
		isp=$(clean_str "$isp")
		lat=$(jq -r '.lat' <<<$q)
		lon=$(jq -r '.lon' <<<$q)
		org=$(jq -r '.org' <<<$q)
		org=$(clean_str "$org")
		ipAddr=$(jq -r '.query' <<<$q)
		region=$(jq -r '.region' <<<$q)
		region=$(clean_str "region")
		status=$(jq -r '.status' <<<$q)
		status=$(clean_str "$status")

		echo "  extreme-ip-lookup.com: $status"

		# Because of the large number of entries in
		# each row we have to split the data to two
		# SQL commands to avoid an "argument list too
		# long" error.
		$mysqlcmd -N -B -e "insert ignore into hosts ( \
			ipAddr, \
			ipName, \
			ipType, \
			isp, \
			org, \
			status, \
			lookupTime) values (\
			\"$ip\", \
			\"$ipName\", \
			\"$ipType\", \
			\"$isp\", \
			\"$org\", \
			\"$status\", \
			$now);"
		$mysqlcmd -N -B -e "update hosts set \
			businessName=\"$businessName\", \
			businessWebsite=\"$businessWebsite\", \
			city=\"$city\", \
			country=\"$country\", \
			countryCode=\"$countryCode\", \
			continent=\"$continent\", \
			region=\"$region\", \
			lat=$lat, \
			lon=$lon \
			where ipAddr=\"$ip\";"
		echo "  Saved results to database"

		# Wait 2 seconds, because service 
		# extreme-ip-lookup.com can be polled
		# only 50 times a minute without
		# subscription
		echo -n "  wait "
		t=$(date +%s)
		while (( t-now < 2 ))
	    	do
			t=$(date +%s)
			echo -n "."
			sleep 0.1
		done
		echo ""
	done

	# Count the number of IP addresses left unprocessed in
	# the database for the condition of the while loop
	n_ips=0
	for tbl in $source_tables
	do
		n=$($mysqlcmd -N -B -e "select count($tbl.source_ip) \
	        	 from $tbl left join hosts \
		         on ($tbl.source_ip = hosts.ipAddr) \
		         where hosts.ipAddr is null;")
		n_ips=$((n_ips+n))
	done
done

# Echo script name and time (end)
echo -n "$0, end at "
date
echo ""

# SQL to set-up database for this script
# CREATE TABLE `hosts` (
#  `businessName` text,
#  `businessWebsite` text,
#  `city` text,
#  `continent` text,
#  `country` text,
#  `countryCode` text,
#  `ipName` text,
#  `ipType` text,
#  `isp` text,
#  `lat` double DEFAULT NULL,
#  `lon` double DEFAULT NULL,
#  `org` text,
#  `ipAddr` varchar(15) DEFAULT NULL,
#  `region` text,
#  `status` text,
#  `lookupTime` double DEFAULT NULL,
#  `nmap` text,
#  `nmapCmd` text,
#  `nmapVer` text,
#  `nmapXMLVer` text,
#  `nmapStart` double DEFAULT NULL,
#  `nmapEnd` double DEFAULT NULL,
#  `nmapHostName` text,
#  `nmapUptime` bigint(20) DEFAULT NULL,
#  `nmapProcessed` tinyint(1) NOT NULL DEFAULT '0',
#  `nmapInvalid` tinyint(1) DEFAULT '0',
#  UNIQUE KEY `unique_ipAddr` (`ipAddr`)
#  ) ENGINE=InnoDB DEFAULT CHARSET=latin1

