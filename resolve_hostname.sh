#!/bin/bash

# Requirements:
#  sqlite3
#  jq

# Database file
#db="/root/bad_logs.db"
db=$1

# select ssh_logs.source_ip from ssh_logs left join hosts on (ssh_logs.source_ip = hosts.ipAddr) where hosts.ipAddr is null union select apache_logs.source_ip from apache_logs left join hosts on (apache_logs.source_ip = hosts.ipAddr) where hosts.ipAddr not null;

ips_ssh=$(sqlite3 $db "select source_ip from ssh_logs;")
ips_apache=$(sqlite3 $db "select source_ip from apache_logs;")
ips=("${ips_ssh[@]}" "${ips_apache[@]}")

# Loop over all IPs in the above list, determine if we
# already looked up the information. If not query
# extreme-ip-lookup.com and save information to database.
for ip in $ips
do

	# Count the rows in table hosts with the given IP
	# to determine, if we already looked it up (if > 0).
	lookedup=$(sqlite3 $db "select count(ipAddr) \
		from hosts where ipAddr=\"$ip\";")

	if [ $lookedup -eq 0 ]
	then
		echo "Look up $ip"
		q=$(curl -s extreme-ip-lookup.com/json/$ip)
		
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

		now=$(date +%s)

		sqlite3 $db "insert or ignore into hosts ( \
			businessName, \
			businessWebsite, \
			city, \
			continent, \
			country, \
			countryCode, \
			ipName, \
			ipType, \
			isp, \
			lat, \
			lon, \
			org, \
			ipAddr, \
			region, \
			status, \
			lookupTime) values ( \
			\"$businessName\", \
			\"$businessWebsite\", \
			\"$city\", \
			\"$continent\", \
			\"$country\", \
			\"$countryCode\", \
			\"$ipName\", \
			\"$ipType\", \
			\"$ips\", \
			$lat, \
			$lon, \
			\"$org\", \
			\"$ip\", \
			\"$region\", \
			\"$status\", \
			$now);"

		# Wait 2 seconds, because service 
		# extreme-ip-lookup.com can be polled
		# only 50 times a minute without
		# subscription
		sleep 2
	fi
done

# SQL to set-up database for this script
# CREATE TABLE hosts (businessName text, businessWebsite text, city text, continent text, country test, countryCode text, ipName text, ipType text, isp text, lat real, lon real, org text,ipAddr text, region text, status text, lookupTime real);
# CREATE UNIQUE INDEX unique_ipAddr on hosts(ipAddr);

