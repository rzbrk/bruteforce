#!/usr/bin/python3
# Requirements:
# mysql-connector
# Beautifulsoup4
# lxml


import os

try:
    from bs4 import BeautifulSoup
except ImportError:
    BeautifulSoup = None
    print('Please install BeautifulSoup4 first')
    exit()
from datetime import datetime

try:
    import mysql.connector
except ImportError:
    mysql = None
    print('Please install mysql-connector first')
    exit()
from time import tzname
from sys import argv

scriptpath = os.path.abspath(__file__)
os.chdir(scriptpath[:scriptpath.rfind('/')])


class Config:
    def __init__(self, configfilename):
        self.configfilename = configfilename
        self.host = None
        self.port = None
        self.database = None
        self.user = None
        self.password = None
        self.configdic = {'host': 'localhost', 'port': 3306, 'database': 'bruteforce', 'user': 'bruteforce',
                          'password': 'secret'}
        self.config_read()
        self.set_configattributs()

    def config_read(self):
        configlist = []
        try:
            with open(self.configfilename, "r") as configfile:
                for line in configfile:
                    if line[0] != '#' and line[0] != '\n':
                        configlist.append(line.strip('\n').split('='))

        except (IndexError, FileNotFoundError):
            print("\nCall: {} <conffile>".format(__file__))
            exit()

        for configitem in configlist:
            if configitem[0] in self.configdic.keys():
                self.configdic[configitem[0]] = configitem[1].strip('"')
            else:
                print('Unknown configitemn: ', configitem[0])

    def show(self):
        print('Current config:')
        for configitem in self.configdic.keys():
            print("{:30} {}".format(configitem, self.configdic[configitem]))

    def set_configattributs(self):
        for key, value in self.configdic.items():
            setattr(self, key, value)
        self.port = int(self.port)


class Dbase:
    def __init__(self, configdata):
        self.config = configdata

    def _connect(self):
        self.connection = mysql.connector.connect(host=config.host, port=config.port, user=config.user,
                                                  password=config.password,
                                                  database=config.database)

        self.cursor = self.connection.cursor()

    def execute_sql(self, sql, arguments=''):
        self._connect()
        self.cursor.execute(sql, arguments)
        data = self.cursor.fetchone()
        self._disconnect()
        return data

    def _disconnect(self):
        self.connection.close()


class StripDownXML:
    def __init__(self, xml, database, attacker_ip):
        self.soup = BeautifulSoup(xml, 'lxml-xml')
        self.database = database
        self.attacker_ip = attacker_ip

    def validate(self):
        """ Check if nmap XML. If not skip this ip address """
        if not self.soup.find('nmaprun'):
            print("Nmap XML not valid --> skip")
            sql = "update hosts set nmapInvalid=1, nmapProcessed=1 where ipAddr= %s"
            sql_arguments = (ip,)
            self.database.execute_sql(sql, sql_arguments)
        else:
            return 'okay'

    def process(self):
        nmapCmd = self.soup.nmaprun.attrs
        nmapVer = self.soup.nmaprun.attrs

        return nmapCmd, nmapVer



if __name__ == '__main__':

    # Echo script name and time (start)
    print("{}, start at {}".format(__file__, datetime.strftime(datetime.now(), "%a %d. %b %H:%M:%S " + tzname[1] + " %Y")))

    # Read config file
    # Check the parameter read from the config file and set
    # default values if necessary
    config = Config(argv[1])

    # Initialise DB Class with config
    db = Dbase(config)

    # # Count all IP addresses with nmap scan output and where the field
    # # nmapProcessed is false/0.
    n_ips = db.execute_sql("select count(*) from hosts where nmapProcessed=0 and nmap is not null")[0]

    # Separate ip address and nmap xml
    # Search database for nmap xml to processes, but
    # limit the number to 1
    ip, nmap_xml = db.execute_sql('select ipAddr,nmap from hosts where nmapProcessed=0 and nmap is not null limit 1;')
    print("Processing nmap scan from {}".format(ip))
    # Extract information from xml structure

    xmldata = StripDownXML(nmap_xml, db, ip)
    validated_xml = xmldata.validate()
    if validated_xml:
        nmapCmd, nmapVer = xmldata.process()

    print(nmapCmd, nmapVer)







    exit()

    nmaprun = soup.nmaprun
    print(nmaprun.attrs)
    runstats = soup.runstats
    print(runstats.contents[0].attrs)
    print(runstats.contents[1].attrs)

    print(soup.prettify())

    # while (( n_ips > 0  ))
    # do
    #
    # 	# Search database for nmap xml to processes, but
    # 	# limit the number to 10 for each round in the while
    # 	# loop:
    # 	# Extract information vom xml structure
    # 	nmapCmd=`echo $nmapxml | xmllint --xpath "string(/nmaprun/@args)" -`
    # 	nmapVer=`echo $nmapxml | xmllint --xpath "string(/nmaprun/@version)" -`
    # 	nmapXMLVer=`echo $nmapxml | xmllint --xpath "string(/nmaprun/@xmloutputversion)" -`
    # 	nmapStart=`echo $nmapxml | xmllint --xpath "string(/nmaprun/@start)" -`
    # 	if [ "$nmapStart" == "" ]; then nmapStart="NULL"; fi
    # 	nmapEnd=`echo $nmapxml | xmllint --xpath "string(/nmaprun/runstats/finished/@time)" -`
    # 	if [ "$nmapEnd" == "" ]; then nmapEnd="NULL"; fi
    # 	nmapHostName=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/hostnames/hostname/@name)" -`
    # 	nmapUptime=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/uptime/@seconds)" -`
    # 	if [ "$nmapUptime" == "" ]; then nmapUptime="NULL"; fi
    #
    # 	# Update host information in database
    # 	$mysqlcmd -e "update hosts set \
    # 		nmapCmd=\"$nmapCmd\", \
    # 		nmapVer=\"$nmapVer\", \
    # 		nmapXMLVer=\"$nmapXMLVer\", \
    # 		nmapStart=$nmapStart, \
    # 		nmapEnd=$nmapEnd, \
    # 		nmapHostName=\"$nmapHostName\", \
    # 		nmapUptime=$nmapUptime, \
    # 		nmapProcessed=1 \
    # 		where ipAddr=\"$ip\";"
    #
    # 	# Number of ports found
    # 	n_ports=`echo $nmapxml | xmllint --xpath "count(/nmaprun/host/ports/port)" -`
    #
    # 	# Loop over all individual ports
    # 	for ((n=1; n<=$n_ports; n++))
    # 	do
    # 		# Retrieve information regarding the port
    # 		ptype=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port[$n]/@protocol)" -`
    # 		pnumb=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port[$n]/@portid)" -`
    # 		pstate=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port[$n]/state/@state)" -`
    # 		preason=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port[$n]/state/@reason)" -`
    # 		preasonttl=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port[$n]/state/@reason_ttl)" -`
    # 		if [ "$preasonttl" == "" ]; then preasonttl="NULL"; fi
    # 		pservname=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port[$n]/service/@name)" -`
    # 		pprod=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port[$n]/service/@product)" -`
    # 		pprodver=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port[$n]/service/@version)" -`
    # 		pextrinf=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port[$n]/service/@extrainfo)" -`
    # 		postype=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port[$n]/service/@ostype)" -`
    # 		pmethod=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port[$n]/service/@method)" -`
    # 		pconf=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port[$n]/service/@conf)" -`
    #
    # 		echo "  port $n/$n_ports: $ptype/$pnumb ($pservname)"
    # 		# Create entry for port in database linked to host
    # 		$mysqlcmd -e "insert ignore into ports ( \
    # 			ipAddr, \
    # 			type, \
    # 			portID, \
    # 			state, \
    # 			reason, \
    # 			reasonTTL, \
    # 			serviceName, \
    # 			product, \
    # 			version, \
    # 			extrainfo, \
    # 			osType, \
    # 			method, \
    # 			conf) values ( \
    # 			\"$ip\", \
    # 			\"$ptype\", \
    # 			$pnumb, \
    # 			\"$pstate\", \
    # 			\"$preason\", \
    # 			\"$preasonttl\", \
    # 			\"$pservname\", \
    # 			\"$pprod\", \
    # 			\"$pprodver\", \
    # 			\"$pextrinf\", \
    # 			\"$postype\", \
    # 			\"$pmethod\", \
    # 			\"$pconf\");"
    # 	done
    #
    # 	# Number of osmatches
    # 	n_osmatches=`echo $nmapxml | xmllint --xpath "count(/nmaprun/host/os/osmatch)" -`
    #
    # 	# Loop over all individual os matches
    # 	for ((n=1; n<=$n_osmatches; n++))
    # 	do
    # 		# Retrieve information regarding the os match
    # 		osname=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/os/osmatch[$n]/@name)" -`
    # 		osaccuracy=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/os/osmatch[$n]/@accuracy)" -`
    # 		if [ "$osaccuracy" == "" ]; then osaccuracy="NULL"; fi
    # 		osline=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/os/osmatch[$n]/@line)" -`
    # 		if [ "$osline" == "" ]; then osline="NULL"; fi
    # 		# For type, vendor, family use ../osmatch[*]/osclass[1]
    # 		# although there may be multiple osclass
    # 		ostype=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/os/osmatch[$n]/osclass[1]/@type)" -`
    # 		osvendor=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/os/osmatch[$n]/osclass[1]/@vendor)" -`
    # 		osfamily=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/os/osmatch[$n]/osclass[1]/@osfamily)" -`
    # 		osportused=`echo $nmapxml | xmllint --xpath "count(/nmaprun/host/os/portused)" -`
    #
    # 		echo "  os $n/$n_osmatches: $osname ($osfamily)"
    # 		# Create entry for os match in database linked to host
    # 		$mysqlcmd -e "insert ignore into os_matches ( \
    # 			ipAddr, \
    # 			name, \
    # 			accuracy, \
    # 			line, \
    # 			type, \
    # 			vendor, \
    # 			family, \
    # 			portUsed) values ( \
    # 			\"$ip\", \
    # 			\"$osname\", \
    # 			$osaccuracy, \
    # 			\"$osline\", \
    # 			\"$ostype\", \
    # 			\"$osvendor\", \
    # 			\"$osfamily\", \
    # 			$osportused);"
    #
    # 	done
    #
    # 	# Number of ssh keys
    # 	n_sshkeys=`echo $nmapxml | xmllint --xpath "count(/nmaprun/host/ports/port/script[@id=\"ssh-hostkey\"]/table)" -`
    #
    # 	# Loop over all individual ssh keys
    # 	for ((n=1; n<=$n_sshkeys; n++))
    # 	do
    # 		# Retrieve information regarding the ssh key
    #
    # 		kfingerpr=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port/script[@id=\"ssh-hostkey\"]/table[$n]/elem[@key=\"fingerprint\"])" -`
    # 		ktype=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port/script[@id=\"ssh-hostkey\"]/table[$n]/elem[@key=\"type\"])" -`
    # 		ksshkey=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port/script[@id=\"ssh-hostkey\"]/table[$n]/elem[@key=\"key\"])" -`
    # 		kbits=`echo $nmapxml | xmllint --xpath "string(/nmaprun/host/ports/port/script[@id=\"ssh-hostkey\"]/table[$n]/elem[@key=\"bits\"])" -`
    #
    # 		echo "  ssh hostkey $n/$n_sshkeys: $ktype ($kbits bits)"
    # 		# Create entry for ssh hostkey in database linked to host
    # 		$mysqlcmd -e "insert ignore into ssh_hostkeys ( \
    # 			ipAddr, \
    # 			fingerprint, \
    # 			type, \
    # 			sshkey, \
    # 			bits) values ( \
    # 			\"$ip\", \
    # 			\"$kfingerpr\", \
    # 			\"$ktype\", \
    # 			\"$ksshkey\", \
    # 			$kbits);"
    #
    # 	done
    #
    # 	# Update number of xml data to process
    # 	n_ips=$($mysqlcmd -N -B -e  "select count(*) from hosts where \
    # 		nmapProcessed=0;")
    #
    # done
    #
    # # Echo script name and time (end)
    # echo -n "$0, end at "
    # date
    # echo ""
    #
    #
