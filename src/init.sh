#!/bin/sh

. ./common.sh
cwd=${PWD}

# ------------------ Create root CA --------------------------
echo "Creating root CA key cert pair."
echo "Enter Root CA Password: "
rootPasswd="$(. /opt/tools/read-password.sh)"

if [ "(ls -A $rootCAPath)" ]; then 
  rm -rf $rootCAPath/*  
  mkdir $rootCAPath
fi
if [ "(ls -A $intermediatePath)" ]; then
  rm -rf $intermediatePath/*
  mkdir $intermediatePath
fi

cd $rootCAPath
mkdir certs crl newcerts private
chmod 700 private
touch index.txt
echo 1000 > serial
cd $cwd

dd if=/dev/urandom of=${rootCAPath}/private/.rand bs=256 count=1

# Output files
# # ca.key.pem: Certificate Authority private key file (this shouldn't be shared in real-life)
# # ca.cert.pem: Certificate Authority trust certificate (this should be shared with users in real-life)

openssl genrsa -aes256 -passout pass:"${rootPasswd}" -out $rootCAKey 4096
chmod 400 $rootCAKey

openssl req -x509 -new -key $rootCAKey \
  -config $rootConfig -extensions v3_ca \
  -sha512 -days 7300 -out $rootCaCert -passin pass:"${rootPasswd}" \
  -subj "/C=${ROOT_COUNTRY}/ST=${ROOT_STATE}/L=${ROOT_LOCALITY}/O=${ROOT_ORG}/OU=${ROOT_ORG} Certificate Authority/CN=${ROOT_ORG} Root CA"

chmod 444 $rootCaCert
echo "Root CA created"

# ------------------ Create intermediate CA --------------------------

cd $intermediatePath
mkdir certs crl csr newcerts private
chmod 700 private
touch index.txt
echo 1000 > serial
echo 1000 > $intermediatePath/crlnumber
cd $cwd

echo "Creating intermediate CA"
echo "Enter Intermediate CA Password: "

intermediatePasswd="$(. /opt/tools/read-password.sh)"

openssl genrsa -aes256 \
      -passout pass:"${intermediatePasswd}" \
      -out $intermediateKey 4096

chmod 400 $intermediateKey

openssl req -config $intermediateConfig -new -sha256 \
      -key $intermediateKey \
      -out $intermediateCsr \
      -passin pass:"${intermediatePasswd}" \
      -subj "/C=${ROOT_COUNTRY}/ST=${ROOT_STATE}/L=${ROOT_LOCALITY}/O=${ROOT_ORG}/OU=${ROOT_ORG} Certificate Authority/CN=${ROOT_ORG} Intermediate CA"

openssl ca -config $rootConfig -extensions v3_intermediate_ca \
      -days 3650 -notext -md sha256 \
      -in $intermediateCsr \
      -passin pass:"${rootPasswd}" \
      -out $intermediateCert

chmod 444 $intermediateCert

echo "Intermediate CA created"

echo "Creating certificate chain"

cat $intermediateCert $rootCaCert > $certificateChain

echo "certificate chain can be found at: $certificateChain"
