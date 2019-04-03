# squid4-docker
Squid4 with SSL intercept for Docker

## Prerequisite CA2 intermediary

To follow best security practices, **you do not put your CA on the squid proxy** instead, we'll sign an intermediary certificate that we'll call **CA2**.  This is so if for any reason your infrastructure is compromised, you're able to revoke **CA2** with your **CA**

**Do this on an incredibly secure machine, every single request flowing into your network will be signed by this authority.**

```
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=US/ST=MD/L=EC/O=Acme Dev/CN=Acme CA" -extensions v3_ca -keyout ca1.key -out ca1.pem
openssl req -newkey rsa:4096 -nodes -keyout ca.key -extensions v3_ca -subj "/C=US/ST=MD/L=EC/O=Acme Dev/CN=Acme CA2" -out ca2.csr
openssl x509 -req -days 365 -in ca2.csr -CA ca1.pem -CAkey ca1.key -out ca.pem -CAcreateserial
cat ca.pem ca1.pem > chain.pem
```

Check it locally:

```
docker build -t squid4 -f squid4.Dockerfile .
mkdir -p cache
mkdir -p certificates
cp ca.key certificates/ca.key
docker run --net=host --rm \
    -v $PWD/cache:/var/cache/squid4 \
    -v $PWD:/etc/ssl/certs:ro \
    -v $PWD/certificates:/etc/squid4/certificates \
    -v $PWD/squid.conf:/etc/squid4/squid.conf:ro \
    --name squid4 voor/squid4
```