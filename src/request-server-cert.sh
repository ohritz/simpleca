#!/bin/sh

export SERVER_CN="${1:?'Hostname to generate a certificate for is not entered.'}"
. ./common.sh

#------------- Password prompts ------------------
echo "Enter the intermediate CA password: "
rootCaPasswd="$(. /opt/tools/read-password.sh)"

echo "Choose a password for the Server private key: "
passwd="$(. /opt/tools/read-password.sh)"

echo "Choose a password for the PFX: "
pfxPwd="$(. /opt/tools/read-password.sh)"
#------------- --------------- ------------------


# Output files
# ${SERVER_CN}.key.pem: Server private key, password protected (this shouldn't be shared)
# server-cert-req.csr: Server certificate signing request (this should be shared with the CA owner)
# server.crt: Server certificate signed by the CA (this would be sent back by the CA owner) - keep on server
# ${SERVER_CN}-cert.pem: Conversion of server.key into a pkcs8 format gRPC likes (this shouldn't be shared)
# ${SERVER_CN}-cert.pfx: password protected pfx file with the whole certificate chain.

# Step 1: Generate the Server Private Key (server.key)
openssl genrsa -aes256 -passout pass:"${passwd}" -out $serverKey 2048
chmod 400 $serverKey

# Step 2: create a certificate signing request (server.csr)
openssl req -config $intermediateConfig \
        -key $serverKey -passin pass:"$passwd" \
        -new -sha256 -out $serverCsr \
        -addext "subjectAltName = DNS:${SERVER_CN}" \
        -subj "/CN=${SERVER_CN}"

# # Step 3: Sign the certificate with the CA we created (it's called self signing) - server.crt
# openssl x509 -req -days 3650 \
#         -passin pass:"${rootCaPasswd}" -in $serverCsr \
#         -CA $rootCaCert -CAkey $rootCAKeyPath -CAcreateserial \
#         -out $serverCert -extensions req_ext -extfile $configPath

openssl ca -config $intermediateConfig \
        -extensions server_cert -days 375 -notext -md sha256 \
        -passin pass:"$rootCaPasswd" \
        -in $serverCsr -out $serverCert
chmod 444 $serverCert

mkdir -p $outputDir

# # Step 4: Convert the server certificate to .pem format (server.pem) - usable by gRPC
openssl pkcs8 -topk8 -passin pass:"$passwd" -passout pass:"${passwd}" -in $serverKey -out $serverPem

openssl pkcs12 -export -inkey $serverKey -passin pass:"$passwd" \
             -passout pass:"$pfxPwd" \
             -in $serverCert -certfile $certificateChain \
             -out $serverPfx

echo "Warning, the certificates will be copied to and possibly overwrite any files mounted to $exportDir"

cp $outputDir/* $exportDir/
cp $serverCert $exportDir/
cp $certificateChain $exportDir/
chmod 776 $exportDir/*
