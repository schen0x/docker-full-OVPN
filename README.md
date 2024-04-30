# docker-portable-OVPN

An OVPN server that is:

- without leak (*)
- customizable
- portable
- stable

## IMPORTANT: VPN && DNS-LEAK

- Due to a BUG in the NetworkManager/systemd-resolved, many Linux distributions (e.g. Ubuntu) may leak DNS by default, see this link: https://github.com/systemd/systemd/issues/6076

- What is DNS-LEAK: Even when using a VPN, a user may still be using the nameserver of a local ISP, which is pushed when the internet connection is established. This leaks sensible information.

- Why DNS-LEAK is a problem: For multiple reasons. First, the ISP will know such a request. Second, the site owner can also trace the nameserver and found it in some interesting location.

- A possible workaround is as follows:

```sh
# as root
if [ "$EUID" -ne 0 ]
  then echo "Needs to be run as root"
  exit
fi

# [Optional] install dnsmasq before altering internet config.
# apt install dnsmasq
apt install dnss

# Stop NetworkManager from handling our DNS. We can do it by ourself.
systemctl disable systemd-resolved.service
systemctl stop systemd-resolved.service
# 24.04 LTS
apt purge systemd-resolvd

# 22.04 LTS
# cat << 'EOF' > /etc/NetworkManager/conf.d/my-dns.conf
# # ref: man networkmanager.conf
# [main]
# # do not update /etc/resolv.conf
# rc-manager=unmanaged
# dns=none
# systemd-resolved=false
# EOF


# # [Optional] Config "dnsmasq", a local DNS cache server for better performance and DNSSEC etc.
# # apt-file search dnsmasq.conf.example; locate dnsmasq.conf.example;
# # apt install dnsmasq
# # cp /usr/share/doc/dnsmasq-base/examples/dnsmasq.conf.example /etc/dnsmasq.conf
#
# cat << 'EOF' > /etc/dnsmasq.conf
# port=53
# listen-address=127.0.0.1
# bind-interfaces
# dnssec
# # Do not read /etc/resolv.conf
# no-resolv
# # Add name servers
# server=8.8.8.8
# server=1.1.1.1
# EOF
# systemctl enable dnsmasq

# [Optional] Config "dnss", a local DNS over HTTPs resolver
# apt show dnss
# apt install dnss
# systemctl status dnss
## Loaded: loaded (/lib/systemd/system/dnss.service; enabled; vendor preset: enabled)
# systemctl status dnss | grep -i "Loaded: loaded" | cut -d '(' -f2 | cut -d ';' -f1
cat $(systemctl show -P FragmentPath dnss);
TMP_DNSS_ENV_F=$(cat $(systemctl show -P FragmentPath dnss) | grep "EnvironmentFile" | cut -d '-' -f2);
echo && echo "========[Default Flags]========"
cat "${TMP_DNSS_ENV_F}";

# /etc/default/dnss
# sudo vim "${TMP_DNSS_ENV_F}";
cat << 'EOF' > "${TMP_DNSS_ENV_F}"
MODE_FLAGS='--enable_dns_to_https -https_upstream="https://1.1.1.1/dns-query"'
#MONITORING_FLAG="--monitoring_listen_addr=127.0.0.1:9981"
MONITORING_FLAG=""
EOF

systemctl enable dnss
systemctl restart dnss
systemctl -l status dnss

# rewrite /etc/resolv.conf
# Set 127.0.0.1 as nameserver if dnsmasq has been configured.
# Otherwise use some public dns server.
cat << 'EOF' > /etc/resolv.conf
nameserver 127.0.0.1
# nameserver 8.8.8.8
# nameserver 1.1.1.1
EOF

# reboot the system now
# shutdown -r 0

# check service status after reboot
systemctl status dnsmasq
systemctl status NetworkManager

# to test the latency (should be 0ms on local cache hit)
dig archlinux.com @127.0.0.1
# to test leak
dig +trace archlinux.org
https://dnsleaktest.com

# to test DNSSEC
dig sigok.verteiltesysteme.net @127.0.0.1
dig sigfail.verteiltesysteme.net @127.0.0.1
```

# Usage:

- on the server

```sh
# RUN `server_setup.sh` when setting up the server.
# Assume UBUNTU 20.04
bash ./server_setup.sh && bash

# the client cred will be outputted to here
mkdir -p /out

# to start the server
docker-compose build
docker-compose up

# to shut down the server
docker-compose down
```

- on the client

```sh
# get the .gz file, then to unzip it:
tar xvf *.gz

# to start the client
sudo openvpn client.ovpn
```

## CREDIT:

- https://github.com/jpetazzo/dockvpn
- https://github.com/kylemanna/docker-openvpn
