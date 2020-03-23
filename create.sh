#!/bin/bash -e

DEV1=enp1s0
DEV2=enp7s0
MAC1=52:54:00:aa:bb:cc
MAC2=52:54:00:dd:ee:ff
FACTER2=/usr/local/share/gems/gems/facter-2.5.7/bin/facter
FACTER3=/opt/puppetlabs/puppet/bin/facter
FACTER4=/opt/puppetlabs/puppet/bin/facter-ng

cat >/etc/NetworkManager/conf.d/00-no-auto.conf <<EOF
[main]
no-auto-default=*
EOF

systemctl restart NetworkManager
sleep 2

clean_connections() {
  rm -f /etc/sysconfig/network-scripts/ifcfg-* /etc/NetworkManager/system-connections/*
  nmcli c reload
  sleep 2
}

reset_connection() {
  nmcli c add type ethernet ifname $DEV1
}

create_facts() {
  sleep 5
  nmcli c
  nmcli c > ${1}-${2}-nmcli.txt
  ip a
  ping -c1 8.8.8.8 || true
  $FACTER2 --json > ${1}2-${2}-facter2.json
  $FACTER3 --json > ${1}3-${2}-facter3.json
  $FACTER4 --json > ${1}4-${2}-facter4.json
}

trap "clean_connections; reset_connection" EXIT
rm -f *json

clean_connections
nmcli c add type ethernet ifname $DEV1
create_facts 010 one_regular

clean_connections
nmcli c add type ethernet ifname $DEV1
nmcli c add type ethernet ifname $DEV2
create_facts 020 two_regulars

clean_connections
nmcli c add type ethernet ifname $DEV1
sleep 2
nmcli dev mod $DEV1 +ipv4.addresses "192.168.122.254/24"
create_facts 030 first_and_two_addresses

clean_connections
nmcli c add type ethernet ifname $DEV1
nmcli c add type ethernet ifname $DEV2
sleep 2
nmcli dev mod $DEV2 +ipv4.addresses "192.168.122.254/24"
nmcli dev mod $DEV2 +ipv6.addresses "2001:db8:cafe:babe::1f/64"
nmcli dev mod $DEV2 +ipv6.addresses "2001:db8:cafe:babe::2f/64"
nmcli dev mod $DEV2 +ipv6.addresses "2001:db8:cafe:babe::3f/64"
create_facts 035 second_and_ipv6_addresses

clean_connections
nmcli c add type bond ifname bond0 mode active-backup
nmcli con add type ethernet ifname $DEV1 master bond0
nmcli con add type ethernet ifname $DEV2 master bond0
create_facts 040 bond_active_backup

clean_connections
nmcli c add type team ifname team0
sleep 2
nmcli c add type ethernet ifname $DEV1 master team0
nmcli c add type ethernet ifname $DEV2 master team0
create_facts 050 team

clean_connections
nmcli c add type bridge ifname br0 bridge.stp no
nmcli c add type ethernet ifname $DEV1 master br0
nmcli c add type ethernet ifname $DEV2 master br0
create_facts 060 bridge_primary

clean_connections
nmcli c add type ethernet ifname $DEV1
nmcli c add type bridge ifname br0 bridge.stp no
nmcli c add type ethernet ifname $DEV2 master br0
create_facts 065 bridge_secondary

clean_connections
nmcli c add type vlan ifname ${DEV1}.10 dev $DEV1 id 10 ip4 192.168.122.254/24 gw4 192.168.122.1
nmcli c add type ethernet ifname $DEV2
create_facts 070 vlan_primary

clean_connections
nmcli c add type ethernet ifname $DEV1
nmcli c add type vlan ifname ${DEV2}.10 dev $DEV2 id 10 ip4 192.168.122.254/24 gw4 192.168.122.1
create_facts 075 vlan_secondary

clean_connections
nmcli c add type bond ifname bond0 mode active-backup ipv4.method disabled ipv6.method ignore
nmcli con add type ethernet ifname $DEV1 master bond0
nmcli con add type ethernet ifname $DEV2 master bond0
nmcli c add type vlan ifname bond0.10 dev bond0 id 10 ip4 192.168.122.254/24 gw4 192.168.122.1
create_facts 080 bond_with_vlan_primary

exit 0
