#!/bin/sh
set -e

# Initialize the certificates database
if [ ! -f '/var/spool/squid4/ssl_db' ]; then
    /lib/squid/security_file_certgen -c -s /var/spool/squid4/ssl_db -M ${SSL_CERTIFICATE_DISK_STORAGE}
fi
chown -R proxy: /var/spool/squid4/ssl_db

if [ ! -f '/etc/squid4/squid.conf' ]; then
    echo "ERROR: /etc/squid4/squid.conf does not exist. Squid will not work."
    exit 1
fi


mkdir -p /var/cache/squid4
chown -R proxy: /var/cache/squid4 /etc/squid4/certificates
chmod -R 750 /var/cache/squid4

chown proxy: /dev/stdout
chown proxy: /dev/stderr

# Build the configuration directories if needed
/usr/sbin/squid -z -N

/usr/sbin/squid -N 2>&1 &
PID=$!

# This construct allows signals to kill the container successfully.
trap "kill -TERM $(jobs -p)" INT TERM
wait $PID
wait $PID
exit $?