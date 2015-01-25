#!/bin/bash
set -e

### Configuration
#
# List of IPs to account
IPS=""
# List of IPs and nets to exclude from accounting
EXCLUDED_NETS=""
# Directory where to store statistics
DIR=/var/lib/traffic-accounting

start() {
        for IP in $IPS
        do
                iptables -N "$IP"_INCOMING
                iptables -N "$IP"_FROM_INT
                iptables -N "$IP"_OUTGOING
                iptables -N "$IP"_TO_INT
                for NET in $EXCLUDED_NETS
                do
                        iptables -I "$IP"_INCOMING -s $NET -j "$IP"_FROM_INT
                        iptables -I "$IP"_OUTGOING -d $NET -j "$IP"_TO_INT
                done
                iptables -I INPUT -d "$IP" -j "$IP"_INCOMING
                iptables -I OUTPUT -s "$IP" -j "$IP"_OUTGOING
        done
}

stop() {
        for IP in $IPS
        do
                RULE_NUM=$(iptables -L INPUT -n --line-numbers | grep "$IP"_INCOMING | awk '{print $1}')
                iptables -D INPUT $RULE_NUM
                RULE_NUM=$(iptables -L OUTPUT -n --line-numbers | grep "$IP"_OUTGOING | awk '{print $1}')
                iptables -D OUTPUT $RULE_NUM

                iptables --flush "$IP"_INCOMING
                iptables --flush "$IP"_FROM_INT
                iptables --flush "$IP"_OUTGOING
                iptables --flush "$IP"_TO_INT

                iptables -X "$IP"_INCOMING
                iptables -X "$IP"_FROM_INT
                iptables -X "$IP"_OUTGOING
                iptables -X "$IP"_TO_INT
        done
}

account_ip() {
        IP=$1

        TMPFILE=`mktemp`
        iptables-save -c > $TMPFILE

        TOTAL_IN=`cat $TMPFILE | grep "\-j $IP"_INCOMING | sed -e 's/^.*://;s/\].*//'`
        IN_FROM_INTERNAL=`cat $TMPFILE | grep "\-j $IP"_FROM_INT | sed -e 's/^.*://;s/\].*//' | awk '{s+=$1} END {print s}'`
        ((IN_FROM_EXTERNAL=$TOTAL_IN-$IN_FROM_INTERNAL))

        TOTAL_OUT=`cat $TMPFILE | grep "\-j $IP"_OUTGOING | sed -e 's/^.*://;s/\].*//'`
        OUT_TO_INTERNAL=`cat $TMPFILE | grep "\-j $IP"_TO_INT | sed -e 's/^.*://;s/\].*//' | awk '{s+=$1} END {print s}'`
        ((OUT_TO_EXTERNAL=$TOTAL_OUT-$OUT_TO_INTERNAL))

        ((TOTAL=$IN_FROM_EXTERNAL+$OUT_TO_EXTERNAL))

        rm $TMPFILE
}

reset_counter() {
                iptables -Z
}

write_out() {
        test -d $DIR || mkdir -p $DIR
        for IP in $IPS
        do
                FILE=$DIR/$(date +%Y-%m)_$IP
                account_ip $IP
                echo "$(date "+%Y-%m-%d %H:%M") $TOTAL $IN_FROM_EXTERNAL $OUT_TO_EXTERNAL" >> $FILE
        done
}

mail_report() {
        TMPFILE=$(mktemp)
        DATE=$(date -d"1 month ago" "+%Y-%m")

        for IP in $IPS
        do
                FILE=$DIR/"$DATE"_$IP
                echo -n "$IP " >> $TMPFILE
                cat $FILE | awk '{ TOTAL += $3; IN += $4; OUT += $5} END { printf "Total: %f GB In: %f GB Out: %f GB\n",TOTAL/1024/1024/1024, IN/1024/1024/1024, OUT/1024/1024/1024 }' >> $TMPFILE
        done

        cat $TMPFILE | mailx -s "Traffic Accounting for $(hostname --fqdn) in $DATE" $MAIL_ADDRESS
        rm $TMPFILE
}

ACTION=$1
MAIL_ADDRESS=$2
case $ACTION in
        start)
                start
        ;;
        stop)
                write_out
                stop
        ;;
        write)
                write_out
                reset_counter
        ;;
        mail)
                mail_report
esac
