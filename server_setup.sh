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
PKG_LISTS="git vim tmux iptables iproute2 p7zip-full dnsutils"
DEBIAN_FRONTEND=noninteractive; apt update -y && apt upgrade -y && apt-get install -y $PKG_LISTS

# DOCKER
# Add Docker's official GPG key:
DEBIAN_FRONTEND=noninteractive; apt -y install ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt -y update
# install docker
DEBIAN_FRONTEND=noninteractive; apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

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

grep -qi "/srv/docker-portable-OVPN" ~/.bashrc || {
cat << 'EOF' >> ~/.bashrc
cd /srv/docker-portable-OVPN
EOF
}

# refresh the ENVs, The variables in the .bashrc goes to the docker_compose.yml
cd $D0
source ~/.bashrc

docker-compose build && docker-compose up -d

