#!/bin/bash

sleep 5s

echo VISUAL=vim | tee -a ~/.bashrc
echo EDITOR=vim | tee -a ~/.bashrc

cat <<'EOF' > /root/.vimrc
colorscheme desert
EOF

chmod 644 /root/.vimrc

SWAP_ON_SCRIPT="/root/server_setup_swap.sh"
cat <<'EOF' > $SWAP_ON_SCRIPT
#!/bin/bash

fallocate -l 5G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo 'swap is on'
free -h

EOF

chmod u+x $SWAP_ON_SCRIPT && bash $SWAP_ON_SCRIPT

# this script set swapon on start
EXEC="/root/server_setup_swap.sh"
# The systemd-escape is used when a parameter is supplied with space or other special chars. (man systemd.unit) related.
# EXEC_ESCAPED=/bin/bash -c "$(systemd-escape 'some fun string')"
SYSTEMD_UNIT_FILE=/etc/systemd/system/$(systemd-escape --suffix=service --path $EXEC)
cat << EOF > $SYSTEMD_UNIT_FILE && chmod 644 $SYSTEMD_UNIT_FILE
[Unit]
Description=Swapon On Start

[Service]
User=root
Type=exec
ExecStart=$EXEC

[Install]
WantedBy=multi-user.target

EOF
systemctl daemon-reload
systemctl enable $(basename $SYSTEMD_UNIT_FILE)
# systemctl status $(basename $SYSTEMD_UNIT_FILE)
# systemctl stop $(basename $SYSTEMD_UNIT_FILE)


# PKGS
PKG_LISTS="docker docker-compose git vim tmux iptables iproute2 p7zip-full dnsutils"
DEBIAN_FRONTEND=noninteractive; apt update -y && apt upgrade -y && apt-get install -y $PKG_LISTS


# Allowing IN 22/tcp
iptables -C INPUT -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT 2>/dev/null || {
	    iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
    iptables -A OUTPUT -p tcp --sport 22 -m conntrack --ctstate ESTABLISHED -j ACCEPT
}


# Allowing IN 80,443/tcp
iptables -C INPUT -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT 2>/dev/null || {
		iptables -A INPUT -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
	}
iptables -C OUTPUT -p tcp -m multiport --dports 80,443 -m conntrack --ctstate ESTABLISHED -j ACCEPT 2>/dev/null || {
	iptables -A OUTPUT -p tcp -m multiport --dports 80,443 -m conntrack --ctstate ESTABLISHED -j ACCEPT
}

# Allowing IN 1194/udp
iptables -C INPUT -i eth0 -m state --state NEW -p udp --dport 1194 -j ACCEPT 2>/dev/null || {
	    iptables -A INPUT -i eth0 -m state --state NEW -p udp --dport 1194 -j ACCEPT
}

# OPENVPN SETUP
mkdir -p /out

# if dir not exist, then init
D0=/srv/docker-portable-OVPN
[[ -d $D0 ]] || git clone https://github.com/schen0x/docker-portable-OVPN $D0

##### VOLATILE START #####
cat << 'EOF' >> ~/.bashrc
# VOLATILE
# vultr
# export HOST_NET_INTERFACE=enp1s0
# gcp
export HOST_NET_INTERFACE=ens4
# VOLATILE
PUB_IP_ASSUME=$(dig +short TXT CH whoami.cloudflare @1.0.0.1 2> /dev/null);
[[ ${#PUB_IP_ASSUME} -lt 8 ]] && {
PUB_IP_ASSUME=$(dig +short myip.opendns.com @resolver1.opendns.com 2> /dev/null);
}
export SERVER_WAN_DNS_NAME=${PUB_IP_ASSUME};
HOST_WAN_NIC_IP=$(ip addr | grep $HOST_NET_INTERFACE | grep inet | awk -F " brd" '{print $1}' | awk -F "inet " '{print $2}' | cut -d '/' -f 1)
export HOST_IP=$HOST_WAN_NIC_IP

cd /srv/docker-portable-OVPN
EOF
##### VOLATILE END #####

# refresh the ENVs, The variables in the .bashrc goes to the docker_compose.yml
cd $D0
source ~/.bashrc

docker-compose build && docker-compose up -d

