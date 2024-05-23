#!/bin/bash
# This script runs in the container, as entrypoint

# ===== VOLATILE START =====
# vultr
# export HOST_NET_INTERFACE=enp1s0
# digital ocean
export HOST_NET_INTERFACE=eth0
# gcp
# export HOST_NET_INTERFACE=ens4

# The external IP (the "remote" field in client.ovpn)
PUB_IP_ASSUME=$(dig +short TXT CH whoami.cloudflare @1.0.0.1 2> /dev/null);
# e.g. PUB_IP_ASSUME="1.2.3.4", on error, fallback to another api
sleep 2 && [[ ${#PUB_IP_ASSUME} -lt 7 ]] && {
    PUB_IP_ASSUME=$(dig +short myip.opendns.com @resolver1.opendns.com 2> /dev/null);
}
SERVER_WAN_DNS_NAME=${PUB_IP_ASSUME};

# (depends on the base image or docker version?)
CONTAINER_NET_INTERFACE=eth0
# ===== VOLATILE END =====

# defined in `server.conf`
OVPN_SUBNET=10.8.0.0/24

CADIR=/etc/openvpn-ca
OHOME=/etc/openvpn
MOUNTED_HOST_DIR=/out

TMPFS=$(mktemp -d)
mkdir -p $MOUNTED_HOST_DIR

CONTENT_CA=$(find $CADIR -type f -name "ca.crt" -exec cat {} \;)
CONTENT_TA=$(find $CADIR -type f -name "ta.key" -exec cat {} \;)
sed -i -e "s/<0w0_SERVER_HOST>/${SERVER_WAN_DNS_NAME}/g" $OHOME/client.example

for CLIENT_KEY_FILE in $(find $CADIR -type f -name "client*.key")
do
CLIENT_BASENAME=$(basename -s '.key' $CLIENT_KEY_FILE)
CONTENT_CLIENT_KEY=$(cat $CLIENT_KEY_FILE)
CONTENT_CLIENT_CERT=$(find $CADIR -type f -name "${CLIENT_BASENAME}.crt" -exec cat {} \;)

cp $OHOME/client.example "${TMPFS}/${CLIENT_BASENAME}.ovpn"

cat << EOE >> "${TMPFS}/${CLIENT_BASENAME}.ovpn"

<ca>
$CONTENT_CA
</ca>
<cert>
$CONTENT_CLIENT_CERT
</cert>
<key>
$CONTENT_CLIENT_KEY
</key>
<tls-auth>
$CONTENT_TA
</tls-auth>

EOE
done

# Win11 can unarchive *.tar.gz in GUI
rm -f $MOUNTED_HOST_DIR/conn.tar.gz
tar cvfz $MOUNTED_HOST_DIR/conn.tar.gz -C $TMPFS .

# Check if rule exist. Error if not exist. Add rule on error
iptables -t nat -C POSTROUTING -s $OVPN_SUBNET -o $CONTAINER_NET_INTERFACE -j MASQUERADE 2>/dev/null || {
    iptables -t nat -A POSTROUTING -s $OVPN_SUBNET -o $CONTAINER_NET_INTERFACE -j MASQUERADE
}
openvpn --config $OHOME/server.conf
