#!/bin/bash

# Requirments:
#  mysql
#  gnuplot

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

# World map file
map=$2

# Output file
output=$3

# Create temporary file for the plot data
tempfile="/tmp/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13).txt"
touch $tempfile

# Create temporary Gnuplot file
tempgpl="/tmp/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13).gpl"
touch $tempgpl

# Retrieve from database hosts with lat/lon
echo "# Logitude,Latitude" > $tempfile
$mysqlcmd -e  "select lon,lat from hosts;" >> $tempfile
sed -i -e "s/|/ /g" $tempfile

# Prepare Gnuplot file
echo "set terminal pngcairo  transparent enhanced font \"arial,10\" fontscale 1.0 size 1200, 800" >> $tempgpl
echo "set output \"$output\"" >> $tempgpl
echo "set format x \"%D %E\" geographic" >> $tempgpl
echo "set format y \"%D %N\" geographic" >> $tempgpl
echo "unset key" >> $tempgpl
echo "set style increment default" >> $tempgpl
echo "set style data lines" >> $tempgpl
echo "set yzeroaxis" >> $tempgpl
echo "set title \"Host locations\"" >> $tempgpl 
echo "set xrange [ -180.000 : 180.000 ] noreverse nowriteback" >> $tempgpl
echo "set x2range [ * : * ] noreverse writeback" >> $tempgpl
echo "set yrange [ -90.0000 : 90.0000 ] noreverse nowriteback" >> $tempgpl
echo "set y2range [ * : * ] noreverse writeback" >> $tempgpl
echo "set zrange [ * : * ] noreverse writeback" >> $tempgpl
echo "set cbrange [ * : * ] noreverse writeback" >> $tempgpl
echo "set rrange [ * : * ] noreverse writeback" >> $tempgpl
echo "plot \"$map\" with lines lc rgb \"blue\" , \"$tempfile\" with points lt 1 pt 2" >> $tempgpl

# Execute Gnuplot
gnuplot $tempgpl

# Delete temporary files
rm $tempfile
rm $tempgpl

