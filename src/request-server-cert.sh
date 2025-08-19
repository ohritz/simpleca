#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities first
. "${SCRIPT_DIR}/utils.sh"
setup_error_handling

export SERVER_CN="${1:?'Hostname to generate a certificate for is not entered.'}"
. "${SCRIPT_DIR}/common.sh"

#------------- Password prompts ------------------
echo "Enter the intermediate CA password: "
rootCaPasswd="$(. /opt/tools/read-password.sh)"

echo "Choose a password for the Server private key: "
passwd="$(. /opt/tools/read-password.sh)"
#------------- --------------- ------------------

# Output files
# ${SERVER_CN}.key.pem: Server private key, password protected (this shouldn't be shared)
# ${SERVER_CN}.csr: Server certificate signing request (this should be shared with the CA owner)
# ${SERVER_CN}.cert.pem: Server certificate signed by the CA (this would be sent back by the CA owner) - keep on server
# ${SERVER_CN}.pkcs8.key.pem: Conversion of server.key into a pkcs8 format gRPC likes (this shouldn't be shared)
# ${SERVER_CN}.pfx: password protected pfx file with the whole certificate chain.

# Step 1: Generate the Server Private Key (server.key)
if [[ "$KEY_TYPE" == "ec" ]]; then
	openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:"${EC_CURVE}" \
		-pkeyopt ec_param_enc:named_curve -aes-256-cbc -pass pass:"${passwd}" \
		-out "$serverKey"
else
	openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:"${RSA_BITS}" \
		-aes-256-cbc -pass pass:"${passwd}" -out "$serverKey"
fi
chmod 400 "$serverKey"

# Step 2: create a certificate signing request (server.csr)
# Set default SANs if not provided
if [[ -z "$SERVER_SANS" ]]; then
	SERVER_SANS="DNS:${SERVER_CN}"
fi

openssl req -config "$intermediateConfig" \
        -key "$serverKey" -passin pass:"$passwd" \
        -new -sha256 -out "$serverCsr" \
        -addext "subjectAltName = ${SERVER_SANS}" \
        -subj "/CN=${SERVER_CN}"

# # Step 3: Sign the certificate with the CA we created (it's called self signing) - server.crt
openssl ca -config "$intermediateConfig" \
        -extensions server_cert -days "${LEAF_DAYS}" -notext -md sha256 -batch \
        -passin pass:"$rootCaPasswd" \
        -in "$serverCsr" -out "$serverCert"
chmod 444 "$serverCert"

mkdir -p "$outputDir"

# # Step 4: Convert the server certificate to .pem format (server.pem) - usable by gRPC
openssl pkcs8 -topk8 -v2 aes-256-cbc -iter "${PKCS8_ITER}" \
	-passin pass:"$passwd" -passout pass:"${passwd}" \
	-in "$serverKey" -out "$serverPem"

echo "Exporting server cert as pkcs12/pfx file..."
openssl pkcs12 -export -inkey "$serverKey" -passin pass:"${passwd}" \
             -in "$serverCert" -certfile "$certificateChain" \
             -out "$serverPfx" \
             -keypbe AES-256-CBC -certpbe AES-256-CBC \
             -macalg sha256 -iter "${PFX_ITER}" -maciter

echo "Warning, the certificates will be copied to and possibly overwrite any files mounted to $exportDir"

cp "$outputDir"/* "$exportDir"/
cp "$serverCert" "$exportDir"/
cp "$certificateChain" "$exportDir"/
chmod 776 "$exportDir"/*
