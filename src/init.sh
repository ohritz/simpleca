#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities first
. "${SCRIPT_DIR}/utils.sh"
setup_error_handling

. "${SCRIPT_DIR}/common.sh"
cwd=${PWD}

# ------------------ Create root CA --------------------------
echo "Creating root CA key cert pair."
echo "Enter Root CA Password: "
rootPasswd="$(. /opt/tools/read-password.sh)"

if [ -d "$rootCAPath" ]; then
  echo "root cert directories found... removing & recreating"
  rm -rf "$rootCAPath"
  mkdir "$rootCAPath"
fi

if [ -d "$intermediatePath" ]; then
  echo "intermediate cert directories found... removing & recreating"
  rm -rf "$intermediatePath"
  mkdir "$intermediatePath"
fi

cd "$rootCAPath"
mkdir certs crl newcerts private
chmod 700 private
touch index.txt
echo 1000 > serial
cd "$cwd"

dd if=/dev/urandom of="${rootCAPath}/private/.rand" bs=256 count=1

# Output files
# # ca.key.pem: Certificate Authority private key file (this shouldn't be shared in real-life)
# # ca.cert.pem: Certificate Authority trust certificate (this should be shared with users in real-life)

# Generate root CA key using modern genpkey
if [[ "$KEY_TYPE" == "ec" ]]; then
	openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:"${EC_CURVE}" \
		-pkeyopt ec_param_enc:named_curve -aes-256-cbc -pass pass:"${rootPasswd}" \
		-out "$rootCAKey"
else
	openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:"${RSA_BITS}" \
		-aes-256-cbc -pass pass:"${rootPasswd}" -out "$rootCAKey"
fi
chmod 400 "$rootCAKey"

openssl req -x509 -new -key "$rootCAKey" \
  -config "$rootConfig" -extensions v3_ca \
  -sha256 -days 7300 -out "$rootCaCert" -passin pass:"${rootPasswd}" \
  -subj "/C=${ROOT_COUNTRY}/ST=${ROOT_STATE}/L=${ROOT_LOCALITY}/O=${ROOT_ORG}/OU=${ROOT_ORG} Certificate Authority/CN=${ROOT_ORG} Root CA"

chmod 444 "$rootCaCert"
echo "Root CA created"

# ------------------ Create intermediate CA --------------------------

cd "$intermediatePath"
mkdir certs crl csr newcerts private
chmod 700 private
touch index.txt
echo 1000 > serial
echo 1000 > "$intermediatePath/crlnumber"
cd "$cwd"

echo "Creating intermediate CA"
echo "Enter Intermediate CA Password: "

intermediatePasswd="$(. /opt/tools/read-password.sh)"

# Generate intermediate CA key using modern genpkey
if [[ "$KEY_TYPE" == "ec" ]]; then
	openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:"${EC_CURVE}" \
		-pkeyopt ec_param_enc:named_curve -aes-256-cbc -pass pass:"${intermediatePasswd}" \
		-out "$intermediateKey"
else
	openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:"${RSA_BITS}" \
		-aes-256-cbc -pass pass:"${intermediatePasswd}" -out "$intermediateKey"
fi

chmod 400 "$intermediateKey"

openssl req -config "$intermediateConfig" -new -sha256 \
      -key "$intermediateKey" \
      -out "$intermediateCsr" \
      -passin pass:"${intermediatePasswd}" \
      -subj "/C=${ROOT_COUNTRY}/ST=${ROOT_STATE}/L=${ROOT_LOCALITY}/O=${ROOT_ORG}/OU=${ROOT_ORG} Certificate Authority/CN=${ROOT_ORG} Intermediate CA"

openssl ca -config "$rootConfig" -extensions v3_intermediate_ca \
      -days 3650 -notext -md sha256 -batch \
      -in "$intermediateCsr" \
      -passin pass:"${rootPasswd}" \
      -out "$intermediateCert"

chmod 444 "$intermediateCert"

echo "Intermediate CA created"

echo "Creating certificate chain"

cat "$intermediateCert" "$rootCaCert" > "$certificateChain"

echo "done..."
