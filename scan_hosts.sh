#!/bin/bash

# Requirements:
#  sqlite3
#  nmap

# Database file
db=$1

# Limit time to scan host (default 10 inutes)
timeout=${2-10m}

# See if table hosts already has column nmap for nmap output.
# If not, create column
hosts_row_nmap=`sqlite3 $db ".schema hosts" | grep "nmap text"`
if [ "$hosts_row_nmap" == "" ]
then
	sqlite3 $db "alter table hosts add nmap text;"
fi

# Select all IP addresses where the nmap field is empty.
ips=$(sqlite3 $db "select ipAddr from hosts where nmap is null;")

# For all IP addresses with empty field nmap perform a
# nmap scan
for ip in $ips
do
	# Perform a fast (-T4) nmap scan for discovery of
	# operating system and services (-A). Output is
	# formatted to XML to make it easier to use parse
	# through the results for a detailed analysis.
	# The time spent to scan a host can be limited. If
	# no value is provided by command line argument a
	# default value of 10 minutes per host is assumed.
	echo "Scanning $ip"
	nmap_out=`nmap --host-timeout $timeout -A -T4 $ip -oX -`

	# Save results to database
	sqlite3 $db "update hosts \
		set nmap='${nmap_out}' where \
		ipAddr = \"$ip\";"
done

