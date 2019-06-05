#!/bin/bash

# Requirements:
#  sqlite3
#  jq

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

n1=$($mysqlcmd -N -B -e "select count(ssh_logs.source_ip) \
	from ssh_logs left join hosts \
	on (ssh_logs.source_ip = hosts.ipAddr) \
	where hosts.ipAddr is null;")
n2=$($mysqlcmd -N -B -e "select count(apache_logs.source_ip) from \
	apache_logs left join hosts on \
	(apache_logs.source_ip = hosts.ipAddr) where \
	hosts.ipAddr is null;")
n_ips=$((n1+n2))

while (( n_ips > 0  ))
do

	# Search database for IP addresses to processes, but
	# limit the number to 10 for each round in the while 
	# loop:
	echo ""
	echo -n "Search database for IP addresses to process ... "
	ips=$($mysqlcmd -N -B -e "select ssh_logs.source_ip from \
		ssh_logs left join hosts on \
		(ssh_logs.source_ip = hosts.ipAddr) \
		where hosts.ipAddr is null union select \
		apache_logs.source_ip from apache_logs \
		left join hosts on (apache_logs.source_ip = \
		hosts.ipAddr) where hosts.ipAddr is null \
		limit 10;")
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
		businessWebsite=$(jq -r '.businessWebsite' <<<$q)
		city=$(jq -r '.city' <<<$q)
		continent=$(jq -r '.continent' <<<$q)
		country=$(jq -r '.country' <<<$q)
		countryCode=$(jq -r '.countryCode' <<<$q)
		ipName=$(jq -r '.ipName' <<<$q)
		ipType=$(jq -r '.ipType' <<<$q)
		isp=$(jq -r '.isp' <<<$q)
		lat=$(jq -r '.lat' <<<$q)
		lon=$(jq -r '.lon' <<<$q)
		org=$(jq -r '.org' <<<$q)
		ipAddr=$(jq -r '.query' <<<$q)
		region=$(jq -r '.region' <<<$q)
		status=$(jq -r '.status' <<<$q)

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

	# Count the number of IP addresse left unprocessed in
	# the database for the condition of the while loop
	n1=$($mysqlcmd -N -B -e "select count(ssh_logs.source_ip) \
		from ssh_logs left join hosts \
		on (ssh_logs.source_ip = hosts.ipAddr) \
		where hosts.ipAddr is null;")
	n2=$($mysqlcmd -N -B -e "select count(apache_logs.source_ip) from \
		apache_logs left join hosts on \
		(apache_logs.source_ip = hosts.ipAddr) where \
		hosts.ipAddr is null;")
	n_ips=$((n1+n2))

done

# SQL to set-up database for this script
# CREATE TABLE hosts (businessName text, businessWebsite text, city text, continent text, country test, countryCode text, ipName text, ipType text, isp text, lat real, lon real, org text,ipAddr text, region text, status text, lookupTime real);
# CREATE UNIQUE INDEX unique_ipAddr on hosts(ipAddr);

