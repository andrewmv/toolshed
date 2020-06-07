#!/bin/sh
# 2017 Andrew Villeneuve
# Setup port forwarding and firewall rules on boot

action=$1
shift;

install_rules() {
        modprobe xt_nat
        modprobe xt_conntrack
        iptables -t nat -D POSTROUTING -s 192.168.2.0/24 -j MASQUERADE
        iptables -t nat -A POSTROUTING -s 192.168.2.0/24 -j MASQUERADE
        iptables -A INPUT -i eth1 -m state --state NEW,INVALID -j DROP
        iptables -A FORWARD -i eth1 -m state --state NEW,INVALID -j DROP
        echo "1" > /proc/sys/net/ipv4/ip_forward
}

flush_rules() {
        iptables -F
        iptables -t nat -F
}

case "$action" in
        start)
                        install_rules
            ;;
        stop)
                        echo "0" > /proc/sys/net/ipv4/ip_forward
            ;;
        restart)
                                flush_rules
                                install_rules
            ;;
                check)
                        iptables -n -L | grep 'INVALID,NEW' > /dev/null
                        if [ $? -ne 0 ]
                        then
                                echo "Filtering rules missing - reinstalling"
                                install_rules
                        fi
                        ;;
        *)
            echo "Usage: $0 [start|stop|restart]"
            ;;
esac

exit 0
