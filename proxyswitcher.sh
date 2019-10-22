#!/bin/bash
###############################################################################
# Proxyswitcher v0.1
# Author: James Thomas Danielson
# Description: A simple bash script for managing and testing lists of proxies
###############################################################################
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>
###############################################################################

DB_FILE="proxies2.db"

# Inits the DB for the first time run. Must be run before any other db commands
init_db () {
    if test -f "$DB_FILE"; then
        echo "The DB file already exists."
        return 5
    fi
    echo "Creating DB file..."
    sqlite3 $DB_FILE "CREATE TABLE proxies (ip text NOT NULL, \
    port integer NOT NULL, https text NOT NULL, country text, \
    type text, speed text, google text, lastcheck text, City text, tested text, \
    lastused text, numSuccess integer, numFail integer, ownership text, \
    publicIP text);"
}

# Adds an entry to the proxy DB. IP ($1) PORT ($2) HTTPS ($3)
add_to_db () {
    echo "Adding proxy to database: $1:$2 https: $3"
    sqlite3 $DB_FILE "INSERT INTO proxies(ip, port, https) VALUES('$1','$2','$3');"
}

# Returns the number of times this proxy appears in the database
is_proxy_in_db () {
    if [ -z $3 ]; then
        count=$(sqlite3 $DB_FILE "SELECT COUNT(*) FROM proxies WHERE ip='$1' AND port=$2;" | sed "s/|/ /" | sed "s/|/ /")
    else
        count=$(sqlite3 $DB_FILE "SELECT COUNT(*) FROM proxies WHERE ip='$1' AND port=$2 AND https='$3';" | sed "s/|/ /" | sed "s/|/ /")
    fi
    return $count
}

# Sets the environmental variables necessary for bash, and anything 
# launched from it to use the proxy
set_proxy() {
	if [[ $3 == "no" ]] ; then
		echo "Setting proxy http://$1:$2"
	    export http_proxy="http://$1:$2"
        export https_proxy="http://$1:$2"
	    echo "Proxy should be set!"
	elif [[ $3 == "yes" ]] ; then
		echo "Setting proxy https://$1:$2"
	    export http_proxy="http://$1:$2"
        export https_proxy="http://$1:$2"
	    echo "Proxy should be set!"
    else
        echo "Couldn't set proxy. Https not defined."
	fi
}

# Retrieves the proxy with the oldest lastcheck date
set_next_proxy () {
    nextProxy=$(sqlite3 $DB_FILE "SELECT ip, port, https FROM proxies ORDER BY lastcheck ASC LIMIT 1;")
    nextIP=$(echo $nextProxy | sed "s/|.*$//")
    nextPort=$(echo $nextProxy | sed "s/^.*\.[0-9]*|//" | sed "s/|.*$//")
    nextHttps=$(echo $nextProxy | sed "s/^.*|//")
   
    echo "Next proxy: $nextIP:$nextPort HTTPS: $nextHttps"

    set_proxy $nextIP $nextPort $nextHttps
}

# A simple function that prints the proxies found in a file ($1)
# Primarily used as a helper function
print_proxy_list() {
	readarray a < $1

	for i in "${a[@]}"
	do
		address=${i%% *}

		afterAd=${i#* }
		port=${afterAd%% *}

		afterPort=${afterAd#* }
		hasHttps=${afterPort%% *}

		echo "$address $port $hasHttps"
	done
}

# Retrieves a specific entry ($2) from a file of proxies ($1)
get_proxy() {
	i=0
	print_proxy_list $1 | while read line;
	do
		if [ $i -eq $2 ]
		then
			echo $line
			return 0
		fi
		let i++
	done
}

# Tests the current proxy and updates the database on success/failure
test_proxy() {
    ip=$(env | grep https | sed "s/^.*\/[^0-9]//" | sed "s/:/ /" | sed "s/ .*$//")
    port=$(env | grep https | sed "s/^.*\/[^0-9]//" | sed "s/:/ /" | sed "s/.* //")

    # If no proxy is set in the environmental, we should bail
    if [[ $ip == "" ]]; then
        echo "=================="
        echo "No proxy detected."
        echo "=================="
        return 99
    fi

    datetime=$(date "+%Y-%m-%d %H:%M:%S")

    # Some useful statistics on the proxy uptimes
    successFail=$(sqlite3 $DB_FILE "SELECT numSuccess, numFail FROM proxies WHERE ip='$ip' AND port='$port';")
    numSuccess=$(echo $successFail | sed "s/|.*$//")
    numFail=$(echo $successFail | sed "s/^.*|//")

    # if there is no value defined yet, then set it to 0
    if [[ $numFail == "" ]] ; then
        numFail="0"
    fi

    if [[ $numSuccess == "" ]] ; then
        numSuccess="0"
    fi

    let total=$numFail+$numSuccess
    
    # Prevent division by 0 if this is the first run
    if [[ $total == 0 ]] ; then
        failRate=0
    else
        failRate=$numFail/$total
    fi

    # Test starting...
    echo "Test started: $datetime"
    echo "Proxy: $ip:$port"
    echo "Waiting for results..."

    # Attempt to get the public faing ip from online
	wget -q -O test.html --timeout=120 --tries=3 http://cmyip.com

    # On success:
    # 1. Display the publically facing ip
    # 2. Remove the downloaded html file
    # 3. Update the database (if the proxy is in it)
	if [ $? == 0 ]; then
		echo "Test success!"
        publicIP=$(grep "ip-whois-lookup" test.html | sed "s/^.*p=//" | sed "s/\"//")
        echo "Public IP: $publicIP"
		rm test.html
        if [[ $ip != "" ]] ; then
            is_proxy_in_db $ip $port 
            if [[ $? == 1 ]]; then
                echo "Updating database entry..."
                let numSuccess=$numSuccess+1
                sqlite3 $DB_FILE "UPDATE proxies SET tested='pass', lastcheck='$datetime', numFail='$numFail', numSuccess='$numSuccess', publicIP='$publicIP' WHERE ip='$ip' AND port=$port;"
            fi
        fi
		return 0
    # On failure:
    # 1. Let user know the test failed
    # 2. Update the database (if the proxy is in it)
	else
		echo "Test failed"
        if [[ $ip != "" ]] ; then
            is_proxy_in_db $ip $port 
            if [[ $? == 1 ]] && [[ $ip != "" ]]; then
                echo "Updating database entry..."
                let numFail=$numFail+1
                sqlite3 $DB_FILE "UPDATE proxies SET tested='fail', lastcheck='$datetime', numFail='$numFail', numSuccess='$numSuccess' WHERE ip='$ip' AND port=$port;"
            fi
        fi
		return 1
	fi

}

# Tests all proxies found in proxy file ($1), output results to $2
test_all() {
	echo "Testing all proxies in $1"
	print_proxy_list $1 | while read line;
	do
		linear=($line)
		echo ${linear[0]} ${linear[1]} ${linear[2]}
		set_proxy ${linear[0]} ${linear[1]} ${linear[2]}
		test_proxy
		
        # If it is a good proxy, save it
		if [ $? == 0 ] ; then
			echo "${linear[0]} ${linear[1]} ${linear[2]}" >> $2
		fi
	done
}

# Prints the proxies stored in the database file
print_proxies () {
    sqlite3 $DB_FILE "SELECT ip, port, https FROM proxies;" | sed "s/|/ /" | sed "s/|/ /"
}

# Gets the proxy from file ($2) line ($3)
if [ "$1" == "get" ]; then
	get_proxy $2 $3
# Gets the proxy from the db file matching the ip, port, and https
elif [[ "$1" == "checkdb" ]]; then
    is_proxy_in_db $2 $3 $4
    let ret=$?
    if [ $ret == 1 ]; then
        echo "Proxy in DB."
    elif (( $ret > 1 )); then
        echo "Proxy in DB.\n WARNING: PROXY IN DB MORE THAN ONCE"
    else
        echo "Proxy not found in DB."
    fi
# Manually set a proxy
elif [ "$1" == "set" ]; then
	set_proxy $2 $3 $4
	exec $SHELL
# Set the proxy with the oldest lastcheck date
elif [ "$1" == "setnext" ]; then
    set_next_proxy
    exec $SHELL
# Prints the proxies in the database
elif [ "$1" == "print" ]; then
    print_proxies
elif [ "$1" == "test" ]; then
	test_proxy
	exit $?
# Tests every proxy in file ($2) and output the good ones to ($3)
elif [ "$1" == "testall" ]; then
	test_all $2 $3
# Must be run the first time the program is used. Inits the DB
elif [ "$1" == "initdb" ]; then
   init_db 
# Add a new entry to the proxy DB. IP ($2) PORT ($3) HTTPS ($4)
elif [ "$1" == "add" ]; then
   add_to_db $2 $3 $4
else
    echo "Proxyswitcher v0.1"
    echo " - A simple bash script for managing and testing lists of proxies"
    echo " - Note: Only tested to support ips, no domain names."
    echo ""
    echo "     This program may be freely redistributed under"
    echo "     the terms of the GNU General Public License."
    echo ""
    echo "Usage: proxyswitcher.sh CMD" 
    echo ""
    echo "Commands:"
    echo "initdb                - Create the proxy database, must be run first time"
    echo "add IP PORT HTTPS     - Adds proxy IP:PORT (HTTPS: yes/no) to the DB"
    echo "checkdb IP PORT HTTPS - Checks if proxy IP:PORT (HTTPS: yes/no) is in the DB"
    echo "get PFILE PNUM        - Retrieves the proxy from PFILE on line PNUM"
    echo "set IP PORT HTTPS     - Sets proxy IP:PORT. HTTPS: yes/no"
    echo "setnext               - Sets the proxy with the oldest lastcheck date"
    echo "test                  - Tests the currently active proxy"
    echo "testall PFILE OFILE   - Tests all proxies in PFILE. Outputs good ones to OFILE"
    echo "print                 - Prints all proxies found in the proxy database"
fi

