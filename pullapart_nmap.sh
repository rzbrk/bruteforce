#!/bin/bash

# Requirements:
#  mysql
#  xmllint, xpath

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

# Count all IP addresses with nmap scan output and where the field
# nmapProcessed is false/0.
n_ips=$($mysqlcmd -N -B -e  "select count(*) from hosts where \
	nmapProcessed=0 and nmap is not null;")

while (( n_ips > 0  ))
do

	# Search database for nmap xml to processes, but
	# limit the number to 10 for each round in the while 
	# loop:
	sqlret=$($mysqlcmd -N -B -e "select ipAddr,nmap from hosts \
		where nmapProcessed=0 and nmap is not null limit 1;")

	# Separate ip address and nmap xml
	ip=`echo $sqlret | awk '{print $1}'`
	nmapxml=`echo $sqlret | awk '{$1=""; print $0}'`
	# Remove literal occurances of "\n"
	nmapxml=`echo $nmapxml | sed 's/\\\n//g'`
	# Remove leading/trailing whitespace
	#nmapxml=`echo $nmapxml | awk '{$1=$1};1'`
	
	echo "Processing nmap scan from $ip . . ."
	# Check validity of XML. If not valid, skip this ip address
	echo $nmapxml | xmllint --noout - > /dev/null 2>&1
	if (( $? != 0 ));
	then
		echo "  Nmap XML not valid --> skip"
		$mysqlcmd -e "update hosts set \
			nmapInvalid=1, \
			nmapProcessed=1 \
			where ipAddr=\"$ip\";"
		continue
	fi

	# Extract information vom xml structure
	nmapCmd=`echo $nmapxml | xmllint --xpath "string(/nmaprun/@args)" -`
	nmapVer=`echo $nmapxml | xmllint --xpath "string(/nmaprun/@version)" -`
	nmapXMLVer=`echo $nmapxml | xmllint --xpath "string(/nmaprun/@xmloutputversion)" -`
	nmapStart=`echo $nmapxml | xmllint --xpath "string(/nmaprun/@start)" -`
	if [ "$nmapStart" == "" ]; then nmapStart="NULL"; fi
	nmapEnd=`echo $nmapxml | xmllint --xpath "string(/nmaprun/runstats/finished/@time)" -`
	if [ "$nmapEnd" == "" ]; then nmapEnd="NULL"; fi
	nmapHostName=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/hostnames/hostname/@name)" -`
	nmapUptime=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/uptime/@seconds)" -`
	if [ "$nmapUptime" == "" ]; then nmapUptime="NULL"; fi
	
	# Update host information in database
	$mysqlcmd -e "update hosts set \
		nmapCmd=\"$nmapCmd\", \
		nmapVer=\"$nmapVer\", \
		nmapXMLVer=\"$nmapXMLVer\", \
		nmapStart=$nmapStart, \
		nmapEnd=$nmapEnd, \
		nmapHostName=\"$nmapHostName\", \
		nmapUptime=$nmapUptime, \
		nmapProcessed=1 \
		where ipAddr=\"$ip\";"

	# Number of ports found
	n_ports=`echo $nmapxml | xmllint --xpath "count(/nmaprun/host/ports/port)" -`

	# Loop over all individual ports
	for ((n=1; n<=$n_ports; n++))
	do
		# Retrieve information regarding the port
		ptype=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port[$n]/@protocol)" -`
		pnumb=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port[$n]/@portid)" -`
		pstate=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port[$n]/state/@state)" -`
		preason=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port[$n]/state/@reason)" -`
		preasonttl=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port[$n]/state/@reason_ttl)" -`
		if [ "$preasonttl" == "" ]; then preasonttl="NULL"; fi
		pservname=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port[$n]/service/@name)" -`
		pprod=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port[$n]/service/@product)" -`
		pprodver=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port[$n]/service/@version)" -`
		pextrinf=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port[$n]/service/@extrainfo)" -`
		postype=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port[$n]/service/@ostype)" -`
		pmethod=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port[$n]/service/@method)" -`
		pconf=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port[$n]/service/@conf)" -`

		echo "  port $n/$n_ports: $ptype/$pnumb ($pservname)"
		# Create entry for port in database linked to host
		$mysqlcmd -e "insert ignore into ports ( \
			ipAddr, \
			type, \
			portID, \
			state, \
			reason, \
			reasonTTL, \
			serviceName, \
			product, \
			version, \
			extrainfo, \
			osType, \
			method, \
			conf) values ( \
			\"$ip\", \
			\"$ptype\", \
			$pnumb, \
			\"$pstate\", \
			\"$preason\", \
			\"$preasonttl\", \
			\"$pservname\", \
			\"$pprod\", \
			\"$pprodver\", \
			\"$pextrinf\", \
			\"$postype\", \
			\"$pmethod\", \
			\"$pconf\");"
	done

	# Number of osmatches
	n_osmatches=`echo $nmapxml | xmllint --xpath "count(/nmaprun/host/os/osmatch)" -`

	# Loop over all individual os matches
	for ((n=1; n<=$n_osmatches; n++))
	do
		# Retrieve information regarding the os match
		osname=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/os/osmatch[$n]/@name)" -`
		osaccuracy=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/os/osmatch[$n]/@accuracy)" -`
		if [ "$osaccuracy" == "" ]; then osaccuracy="NULL"; fi
		osline=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/os/osmatch[$n]/@line)" -`
		if [ "$osline" == "" ]; then osline="NULL"; fi
		# For type, vendor, family use ../osmatch[*]/osclass[1]
		# although there may be multiple osclass
		ostype=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/os/osmatch[$n]/osclass[1]/@type)" -`
		osvendor=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/os/osmatch[$n]/osclass[1]/@vendor)" -`
		osfamily=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/os/osmatch[$n]/osclass[1]/@osfamily)" -`
		osportused=`echo $nmapxml | xmllint --xpath "count(/nmaprun/host/os/portused)" -`

		echo "  os $n/$n_osmatches: $osname ($osfamily)"
		# Create entry for os match in database linked to host
		$mysqlcmd -e "insert ignore into os_matches ( \
			ipAddr, \
			name, \
			accuracy, \
			line, \
			type, \
			vendor, \
			family, \
			portUsed) values ( \
			\"$ip\", \
			\"$osname\", \
			$osaccuracy, \
			\"$osline\", \
			\"$ostype\", \
			\"$osvendor\", \
			\"$osfamily\", \
			$osportused);"
			
	done
	
	# Number of ssh keys
	n_sshkeys=`echo $nmapxml | xmllint --xpath "count(//script[@id=\"ssh-hostkey\"]//table/elem[@key=\"key\"])" -`

	# Loop over all individual ssh keys
	for ((n=0; n<$n_sshkeys; n++))
	do
		# Retrieve information regarding the ssh key
		kfingerpr=`echo $nmapxml | xmllint --xpath "string((//script[@id=\"ssh-hostkey\"]//table/elem[@key=\"fingerprint\"])[last()-$n])" -`
		ktype=`echo $nmapxml | xmllint --xpath "string((//script[@id=\"ssh-hostkey\"]//table/elem[@key=\"type\"])[last()-$n])" -`
		ksshkey=`echo $nmapxml | xmllint --xpath "string((//script[@id=\"ssh-hostkey\"]/table/elem[@key=\"key\"])[last()-$n])" -`
		kbits=`echo $nmapxml | xmllint --xpath "string((//script[@id=\"ssh-hostkey\"]/table/elem[@key=\"bits\"])[last()-$n])" -`
	
		echo "  ssh hostkey $((n+1))/$n_sshkeys: $ktype ($kbits bits)"
		# Create entry for ssh hostkey in database linked to host
		$mysqlcmd -e "insert ignore into ssh_hostkeys ( \
			ipAddr, \
			fingerprint, \
			type, \
			sshkey, \
			bits) values ( \
			\"$ip\", \
			\"$kfingerpr\", \
			\"$ktype\", \
			\"$ksshkey\", \
			$kbits);"

	done

	# Update number of xml data to process
	n_ips=$($mysqlcmd -N -B -e  "select count(*) from hosts where \
		nmapProcessed=0;")

done

# Echo script name and time (end)
echo -n "$0, end at "
date
echo ""


