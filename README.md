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
# Stop NetworkManager from handling our DNS. We can do it by ourself.
systemctl disable systemd-resolved.service
systemctl stop systemd-resolved.service

cat << 'EOF' > /etc/NetworkManager/conf.d/my-dns.conf
# ref: man networkmanager.conf
# do not update /etc/resolv.conf
rc-manager=unmanaged
dns=none
systemd-resolved=false
EOF

# [Optional] Config "dnsmasq", a local DNS cache server for better performance and DNSSEC etc.
# apt-file search dnsmasq.conf.example; locate dnsmasq.conf.example;
apt install dnsmasq
# cp /usr/share/doc/dnsmasq-base/examples/dnsmasq.conf.example /etc/dnsmasq.conf

cat << 'EOF' > /etc/dnsmasq.conf
port=53
listen-address=127.0.0.1
bind-interfaces
dnssec
# Do not read /etc/resolv.conf
no-resolv
# Add name servers
server 8.8.8.8
server 1.1.1.1
EOF
systemctl enable dnsmasq

# rewrite /etc/resolv.conf
# Set 127.0.0.1 as nameserver if dnsmasq has been configured.
# Otherwise use some public dns server.
cat << 'EOF' > /etc/resolv.conf
nameserver 127.0.0.1
EOF

# reboot the system now
shutdown -r 0

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
