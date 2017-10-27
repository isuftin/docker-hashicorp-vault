#!/bin/bash

files=(consul-provate.pem consul-root.cer consul-server.key consul-server.cer consul-server.csr certindex)
for file in "${files[@]}"; do
	if [ -f $file ]; then rm $file; fi
done

touch certindex
echo 000a > serial
rm -rf certs || true
mkdir certs

# Require this so Github maintains this directory even though it should be empty in source control
touch certs/.keep

SUBJ=${SUBJ:-/C=US/ST=Wisconsin/L=Middleon/O=US Geological Survey/OU=WMA/CN=server.docker_dc.consul}
openssl req -newkey rsa:2048 -days 9999  -x509 -nodes -out consul-root.cer -keyout consul-private.pem -subj "$SUBJ"
openssl req -newkey rsa:1024 -nodes -out consul-server.csr -keyout consul-server.key -subj "$SUBJ"
openssl ca -batch -config openssl.conf -notext -in consul-server.csr -out consul-server.cer

files=(certindex serial certindex.attr certindex.attr.old certindex.old serial.old certs/0A.pem)
for file in "${files[@]}"; do
	if [ -f $file ]; then rm $file; fi
done
