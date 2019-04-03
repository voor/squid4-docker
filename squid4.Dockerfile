FROM ubuntu:bionic

# Normalize apt sources
RUN cat /etc/apt/sources.list | grep -v '^#' | sed /^$/d | sort | uniq > sources.tmp.1 && \
    cat /etc/apt/sources.list | sed s/deb\ /deb-src\ /g | grep -v '^#' | sed /^$/d | sort | uniq > sources.tmp.2 && \
    cat sources.tmp.1 sources.tmp.2 > /etc/apt/sources.list && \
    rm -f sources.tmp.1 sources.tmp.2

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get build-dep -y squid && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y curl tar xz-utils libssl-dev

ARG SQUID_VERSION=4.6
ARG SQUID_SHA1=0396fe8077049000407d13aca8efdd9228e69d98

# Download squid and verify against provided sha1 hash.
RUN mkdir /src \
    && cd /src \
    && curl -o squid.tar.xz -SsL http://www.squid-cache.org/Versions/v4/squid-$SQUID_VERSION.tar.xz \
    && bash -c "echo \"${SQUID_SHA1} /src/squid.tar.xz\" >> /src/checksum.txt" \
    && sha1sum -c /src/checksum.txt \
    && mkdir squid \
    && tar -C squid --strip-components=1 -xvf squid.tar.xz

RUN mkdir -p /var/cache/squid4 /var/spool/squid4/ /pid \
	&& chown -R proxy: /var/cache/squid4 /var/spool/squid4 /pid \
	&& chmod -R 750 /var/cache/squid4 /var/spool/squid4 /pid
    
RUN cd /src/squid && \
    ./configure \
        --prefix=/usr \
        --datadir=/usr/share/squid4 \
		--sysconfdir=/etc/squid4 \
		--localstatedir=/var \
		--mandir=/usr/share/man \
		--enable-inline \
		--enable-async-io=8 \
		--enable-storeio="ufs,aufs,diskd,rock" \
		--enable-removal-policies="lru,heap" \
		--enable-delay-pools \
		--enable-cache-digests \
		--enable-underscores \
		--enable-icap-client \
		--enable-follow-x-forwarded-for \
		--enable-auth-basic="DB,fake,getpwnam,LDAP,NCSA,NIS,PAM,POP3,RADIUS,SASL,SMB" \
		--enable-auth-digest="file,LDAP" \
		--enable-auth-negotiate="kerberos,wrapper" \
		--enable-auth-ntlm="fake" \
		--enable-external-acl-helpers="file_userip,kerberos_ldap_group,LDAP_group,session,SQL_session,unix_group,wbinfo_group" \
		--enable-url-rewrite-helpers="fake" \
		--enable-eui \
		--enable-esi \
		--enable-icmp \
		--enable-zph-qos \
		--with-openssl \
		--enable-ssl \
		--enable-ssl-crtd \ 
		--disable-translation \
		--with-swapdir=/var/spool/squid4 \
		--with-logdir=/var/log/squid4 \
		--with-pidfile=/pid/squid4.pid \
		--with-filedescriptors=65536 \
		--with-large-files \
		--with-default-user=proxy \
        	--disable-arch-native
		
ARG CONCURRENCY=1

RUN cd /src/squid && \
    make -j$CONCURRENCY && \
    make install

COPY entrypoint.sh /usr/bin/entrypoint.sh

# Default config
COPY squid.conf /etc/squid4/squid.conf

EXPOSE 3128
EXPOSE 3130

RUN apt-get purge --auto-remove -y \
	&& rm -rf /var/lib/apt/lists/* \
    && rm -rf /src/

ENV SSL_CERTIFICATE_DISK_STORAGE 200MB

ENTRYPOINT [ "/usr/bin/entrypoint.sh" ]