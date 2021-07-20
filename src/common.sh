#!/bin/sh

basePath="/opt/ca"
export rootCAPath="${basePath}/root"
export intermediatePath="${basePath}/intermediate"

export rootConfig="/opt/tools/openssl-root.cnf"
export intermediateConfig="/opt/tools/openssl-intermediate.cnf"

# Root CA Private key.
export rootCAKey="$rootCAPath/private/ca.key.pem"
# Root CA certificate
export rootCaCert="$rootCAPath/certs/ca.cert.pem"

export intermediateKey="$intermediatePath/private/intermediate.key.pem"
export intermediateCsr="$intermediatePath/csr/intermediate.csr.pem"
export intermediateCert="$intermediatePath/certs/intermediate.cert.pem"
export certificateChain="$intermediatePath/certs/ca-chain.cert.pem"

export exportDir="${basePath}/export"

export serverKey="$intermediatePath/private/${SERVER_CN}.key.pem"
export serverCsr="${intermediatePath}/csr/${SERVER_CN}.csr"
export serverCert="${intermediatePath}/certs/${SERVER_CN}.cert.pem"

export outputDir="$basePath/output/${SERVER_CN}"
export serverPem="${outputDir}/${SERVER_CN}.pkcs8.key.pem"
export serverPfx="${outputDir}/${SERVER_CN}.pfx"
export rootCACertFriendly="${outputDir}/rootCA.crt.pem"