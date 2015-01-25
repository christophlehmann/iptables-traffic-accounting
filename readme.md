# Traffic accounting with iptables
- IP-based traffic accounting
- Exclusion of IPs or subnets
- Monthly mail report

## Prerequisites / Installation in Ubuntu/Debian
```
apt-get install iptables bsd-mailx
```
## Configuration
Example: account traffic from/to 192.168.1.1 but not from/to 192.168.1.0/24 or 192.168.2.0/24
```
IPS="192.168.1.1"
EXCLUDED_NETS="192.168.1.0/24 192.168.2.0/24"
DIR=/var/lib/traffic-accounting
```
## Start
Setup iptables rules
```
./bin/traffic-accounting.sh start
```
## Write traffic counters to statistic files
Example cron job
```
*/5 * * * * PATH-TO-HERE/bin/traffic-accounting.sh write
```
## Monthly mail report
Example cron job
```
0 0 1 * * PATH-TO-HERE/bin/traffic-accounting.sh mail your@mail.address
```
## Stop
Remove iptables rules
```
./bin/traffic-accounting.sh stop
```
