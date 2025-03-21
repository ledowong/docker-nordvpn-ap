#!/bin/bash -e

# Check if running in privileged mode
if [ ! -w "/sys" ] ; then
    echo "[Error] Not running in privileged mode."
    exit 1
fi

# Default values
true ${INTERFACE:=wlan0}
true ${SUBNET:=192.168.254.0}
true ${AP_ADDR:=192.168.254.1}
true ${SSID:=docker-ap}
true ${CHANNEL:=36}
true ${WPA_PASSPHRASE:=passw0rd}
true ${HW_MODE:=a}
true ${DRIVER:=nl80211}
true ${DNS_ADDRESSES=1.1.1.1,1.0.0.1}
true ${COUNTRY_CODE=US}

# Attach interface to container
echo "Attaching interface to container"
CONTAINER_ID=$(cat /proc/self/cgroup | grep -o  -e "/docker/.*" | head -n 1| sed "s/\/docker\/\(.*\)/\\1/")
if [ -z "${CONTAINER_ID}" ]; then
  echo "Cannot find CONTAINER_ID with default cgroup. Find it with systemd cgroup instead"
  CONTAINER_ID=$(ls -it /sys/fs/cgroup/systemd/system.slice | grep -o  -e "docker-.*.scope" | head -n 1  | sed -e "s/^docker-//" -e "s/.scope$//")
fi
if [ -z "${CONTAINER_ID}" ]; then
  OVERLAY_ID=`cat /proc/self/mountinfo | grep -i overlay | sed -n "s/.\+upperdir\\=\\(.\+\\)\\/diff.\+/\1/p"`
  CONTAINER_ID=`docker inspect -f $'{{.ID}}\t{{.Name}}\t{{.GraphDriver.Data.MergedDir}}' $(docker ps -aq) | grep $OVERLAY_ID | sed -n "s/\t\+.\+//p"`
fi
if [ -z "${CONTAINER_ID}" ]; then
  echo "[Error] Not find this Docker container"
  exit 1
fi
CONTAINER_PID=$(docker inspect -f '{{.State.Pid}}' ${CONTAINER_ID})
CONTAINER_IMAGE=$(docker inspect -f '{{.Config.Image}}' ${CONTAINER_ID})

if $(ip a | grep -q "${INTERFACE}"); then
  echo "Interface exists~ No need to retrieve again~~"
else
  echo "Attaching ${INTERFACE}"
  docker run -t --privileged --net=host --pid=host --rm --entrypoint /bin/sh ${CONTAINER_IMAGE} -c "
    PHY=\$(echo phy\$(iw dev ${INTERFACE} info | grep wiphy | tr ' ' '\n' | tail -n 1))
    iw phy \$PHY set netns ${CONTAINER_PID}
    "
  echo "${INTERFACE} Attached"
fi

ip link set ${INTERFACE} name ${INTERFACE}

if [ ! -f "/etc/hostapd.conf" ] ; then
    cat > "/etc/hostapd.conf" <<EOF
interface=${INTERFACE}
country_code=${COUNTRY_CODE}
driver=${DRIVER}
ssid=${SSID}
hw_mode=${HW_MODE}
channel=${CHANNEL}
wpa=2
wpa_passphrase=${WPA_PASSPHRASE}
wpa_key_mgmt=WPA-PSK
# TKIP is no secure anymore
wpa_pairwise=TKIP CCMP
wpa_pairwise=CCMP
rsn_pairwise=CCMP
wpa_ptk_rekey=600
wmm_enabled=1

macaddr_acl=0
ignore_broadcast_ssid=0
wmm_enabled=1

# AC
ieee80211ac=1
require_vht=1
ieee80211d=1
ieee80211h=0
EOF

fi

# unblock wlan
rfkill unblock wlan

# down interface if it is up
ip a | grep -Eq ": ${INTERFACE}:.*state UP" && ip link set ${INTERFACE} down && echo "Down ${INTERFACE} ..."

echo "Setting interface ${INTERFACE}"

# Setup interface and restart DHCP service
ip link set ${INTERFACE} up
ip addr flush dev ${INTERFACE}
ip addr add ${AP_ADDR}/24 dev ${INTERFACE}

# NAT settings
echo "NAT settings ip_dynaddr, ip_forward"

for i in ip_dynaddr ip_forward ; do
  if [ $(cat /proc/sys/net/ipv4/$i) ]; then
    echo $i already 1
  else
    echo "1" > /proc/sys/net/ipv4/$i
  fi
done

cat /proc/sys/net/ipv4/ip_dynaddr
cat /proc/sys/net/ipv4/ip_forward

if [ "${OUTGOINGS}" ] ; then
   ints="$(sed 's/,\+/ /g' <<<"${OUTGOINGS}")"
   for int in ${ints}
   do
      echo "Setting iptables for outgoing traffics on ${int}..."
      iptables -t nat -D POSTROUTING -s ${SUBNET}/24 -o ${int} -j MASQUERADE > /dev/null 2>&1 || true
      iptables -t nat -A POSTROUTING -s ${SUBNET}/24 -o ${int} -j MASQUERADE

      iptables -D FORWARD -i ${int} -o ${INTERFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
      iptables -A FORWARD -i ${int} -o ${INTERFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT

      iptables -D FORWARD -i ${INTERFACE} -o ${int} -j ACCEPT > /dev/null 2>&1 || true
      iptables -A FORWARD -i ${INTERFACE} -o ${int} -j ACCEPT
   done
else
   echo "Setting iptables for outgoing traffics on all interfaces..."
   iptables -t nat -D POSTROUTING -s ${SUBNET}/24 -j MASQUERADE > /dev/null 2>&1 || true
   iptables -t nat -A POSTROUTING -s ${SUBNET}/24 -j MASQUERADE

   iptables -D FORWARD -o ${INTERFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1 || true
   iptables -A FORWARD -o ${INTERFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT

   iptables -D FORWARD -i ${INTERFACE} -j ACCEPT > /dev/null 2>&1 || true
   iptables -A FORWARD -i ${INTERFACE} -j ACCEPT
fi
echo "Configuring DHCP server .."

cat > "/etc/dhcp/dhcpd.conf" <<EOF
option domain-name-servers ${DNS_ADDRESSES};
option subnet-mask 255.255.255.0;
option routers ${AP_ADDR};
subnet ${SUBNET} netmask 255.255.255.0 {
  range ${SUBNET::-1}100 ${SUBNET::-1}200;
}
EOF

echo "Starting DHCP server .."
dhcpd ${INTERFACE}

echo "Starting HostAP daemon ..."
/usr/sbin/hostapd /etc/hostapd.conf
