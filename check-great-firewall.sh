#!/bin/bash
###############################################################################
# check-great-firewall v0.1
# Author: James Thomas Danielson
# Description: Quick dirty script to check if we are behind the great firewall
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

BASE_WEBSITE="baidu.com"
FIREWALL_TEST_WEBSITE="google.com"

# Test the base first to make sure we have a connection
ping -c 1 $BASE_WEBSITE
if [[ $? == 0 ]]; then
	ping -c 1 $FIREWALL_TEST_WEBSITE

    # The second website is blocked behind the firewall
    # If it fails to connect, then we are behind the firewall
	if [[ $? == 0 ]]; then
		echo "No Great Firewall detected"
		exit 0
	else
		echo "Great Firewall detected"
		exit 1
	fi
# If we couldn't connect to the first website, we must not have a connection
else
	echo "No internet connection, or bad website?"
	exit 2
fi
