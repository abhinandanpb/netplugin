#!/bin/sh

### Pre-requisite on the host
# run a cluster store like etcd or consul

touch /tmp/restart_netmaster
touch /tmp/restart_netplugin

mkdir -p /var/run/contiv/log
mkdir -p /var/run/openvswitch
mkdir -p /etc/openvswitch

BOOTUP_LOGFILE="/var/run/contiv/log/plugin_bootup.log"

echo "V2 Plugin logs" > $BOOTUP_LOGFILE

if [ $iflist == "" ]; then
    echo "iflist is empty. Host interface(s) should be specified to use vlan mode" >> $BOOTUP_LOGFILE
fi
if [ $ctrl_ip != "none" ]; then
    ctrl_ip_cfg="-ctrl-ip=$ctrl_ip"
fi
if [ $vtep_ip != "none" ]; then
    vtep_ip_cfg="-vtep-ip=$vtep_ip"
fi
if [ $listen_url != ":9999" ]; then
    listen_url_cfg="-listen-url=$listen_url"
fi

echo "Loading OVS" >> $BOOTUP_LOGFILE
(modprobe openvswitch) || (echo "Load ovs FAILED!!! " >> $BOOTUP_LOGFILE && while true; do sleep 1; done)

echo "Starting OVS" >> $BOOTUP_LOGFILE
/usr/share/openvswitch/scripts/ovs-ctl restart --system-id=random --with-logdir=/var/run/contiv/log || ( while true; do sleep 1; done )

echo "Starting Netplugin " >> $BOOTUP_LOGFILE
while true ; do
  if [ -f /tmp/restart_netplugin ]; then
    echo "/netplugin $dbg_flag -plugin-mode docker -vlan-if $iflist -cluster-store $cluster_store $ctrl_ip_cfg $vtep_ip_cfg" >> $BOOTUP_LOGFILE
    /netplugin $dbg_flag -plugin-mode docker -vlan-if $iflist -cluster-store $cluster_store $ctrl_ip_cfg $vtep_ip_cfg &> /var/run/contiv/log/netplugin.log
    echo "CRITICAL : Net Plugin has exited, Respawn in 5s" >> $BOOTUP_LOGFILE
    sleep 5
    echo "Restarting Netplugin " >> $BOOTUP_LOGFILE
  fi
done &

if [ $plugin_role == "master" ]; then
    if [ -f /tmp/restart_netmaster ]; then
    echo "Starting Netmaster " >> $BOOTUP_LOGFILE
    while  true ; do
        echo "/netmaster $dbg_flag -plugin-name=$plugin_name -cluster-store=$cluster_store $listen_url_cfg " >> $BOOTUP_LOGFILE
        /netmaster $dbg_flag -plugin-name=$plugin_name -cluster-store=$cluster_store $listen_url_cfg &> /var/run/contiv/log/netmaster.log
        echo "CRITICAL : Net Master has exited, Respawn in 5s" >> $BOOTUP_LOGFILE
        echo "Restarting Netmaster " >> $BOOTUP_LOGFILE
        sleep 5
    done &
  fi
else
    echo "Not starting netmaster as plugin role is" $plugin_role >> $BOOTUP_LOGFILE
fi

while true; do sleep 1; done
