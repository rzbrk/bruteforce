#!/bin/bash

# Helper routines
# Include with:
#    source helper.sh

#################################################

# Remove special characters or substrings
# Call:
#    clean=$(sanitize_str "$dirty")
#
sanitize_str () {
	local text=$1

	text=$(sed 's/\\//g' <<< $text)
	text=$(sed 's/\"//g' <<< $text)

	echo "$text"
}

# Exit, if current user is NOT root
# Call:
#    exit_ifnot_root()
#
exit_ifnot_root () {
	if [ "$EUID" -ne 0 ]
		then echo "Please run as root. Exit."
		exit 1
	fi
}

# Checks if ip address is valid
# Returns "invalid" if ip address is invalid
# Returns "ipv4" if ip address is valid ipv4
# Returns "ipv6" if ip address is valid ipv6
# Call:
#    result=$(verify_ip "$ipaddr")
#
verify_ip () {
	local ip=$1
	local ret="invalid"
	local check=$(sipcalc $ip)
	if [ $(echo $check | grep -e "ERR" | wc -l) -eq 0 ]
	then
		if [ $(echo $check | grep -e "ipv6" | wc -l) -gt 0 ]
		then
			ret="ipv6"
		elif [ $(echo $check | grep -e "ipv4" | wc -l) -gt 0 ];
		then
			ret="ipv4"
		fi
	fi

	echo $ret
}

# Exits, if command not found
# Call:
#    exit_ifnot_cmd "cmd_name"
#
exit_ifnot_cmd () {
	local cmd_name=$1
	if ! command -v $cmd_name 2>&1 > /dev/null;
	then
		echo "Command \"$cmd_name\" not found. Exit."
		exit 1
	fi
}

