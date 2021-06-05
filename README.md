**Proxyswitcher v0.1**
 - A simple bash script for managing and testing lists of proxies
 - Note: Only tested to support ips, no domain names.

     This program may be freely redistributed under
     the terms of the GNU General Public License.

Usage: proxyswitcher.sh CMD

**Commands:**

initdb                - Create the proxy database, must be run first time

add IP PORT HTTPS     - Adds proxy IP:PORT (HTTPS: yes/no) to the DB

checkdb IP PORT HTTPS - Checks if proxy IP:PORT (HTTPS: yes/no) is in the DB

get PFILE PNUM        - Retrieves the proxy from PFILE on line PNUM

set IP PORT HTTPS     - Sets proxy IP:PORT. HTTPS: yes/no

setnext               - Sets the proxy with the oldest lastcheck date

test                  - Tests the currently active proxy

testall PFILE OFILE   - Tests all proxies in PFILE. Outputs good ones to OFILE

print                 - Prints all proxies found in the proxy database
