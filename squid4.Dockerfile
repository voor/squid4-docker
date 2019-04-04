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
		--datadir=${prefix}/share/squid4 \
		--exec-prefix=/usr \
		--libexecdir=${prefix}/lib/squid \
		--localstatedir=/var \
		--sysconfdir=/etc/squid4 \
		--sharedstatedir=/var/lib \
		--localstatedir=/var \
		--libdir=/usr/lib64 \
		--datadir=/usr/share/squid \
		--with-logdir=/var/log/squid \
		--with-pidfile=/var/run/squid.pid \
		--with-default-user=proxy \
		--disable-dependency-tracking \
		--enable-linux-netfilter \
		--with-openssl \
		--enable-ssl \
		--enable-ssl-crtd \ 
		--disable-arch-native \
		--enable-async-io=8 \
		--with-swapdir=/var/spool/squid4 \
		--with-large-files
		
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