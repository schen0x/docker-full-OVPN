FROM ubuntu:focal
RUN apt update -y -q
RUN apt-get install -qy openvpn iptables curl easy-rsa iproute2

ARG OHOME=/etc/openvpn
ARG CADIR=/etc/openvpn-ca
RUN mkdir -p $OHOME

RUN make-cadir $CADIR
WORKDIR $CADIR
RUN ./easyrsa init-pki
RUN dd if=/dev/urandom of=pki/.rnd bs=256 count=1
# run in batch mode, CLI takes no options
RUN echo set_var EASYRSA_BATCH "1" | tee -a vars
RUN ./easyrsa build-ca nopass
RUN ./easyrsa build-server-full server nopass
RUN for i in $(seq 0 4); do ./easyrsa build-client-full "client${i}" nopass; done
RUN ./easyrsa gen-dh
RUN openvpn --genkey --secret $CADIR/ta.key

# SERVER keys are copied at build time
RUN cp $(find $CADIR -type f -name "ca.crt") $OHOME
RUN cp $(find $CADIR -type f -name "dh.pem") $OHOME
RUN cp $(find $CADIR -type f -name "server.key") $OHOME
RUN cp $(find $CADIR -type f -name "server.crt") $OHOME
RUN cp $(find $CADIR -type f -name "ta.key") $OHOME

# server.conf && client.example
ADD ./conf $OHOME
ADD ./bin /usr/local/bin
RUN chmod a+x /usr/local/bin/*
