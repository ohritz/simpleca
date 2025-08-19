#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# End-to-end test script for modern certificate generation
# This script tests the complete workflow: init → issue → verify

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Testing end-to-end modern certificate generation..."

# Set test environment
export KEY_TYPE=ec
export EC_CURVE=prime256v1
export LEAF_DAYS=398
export PKCS8_ITER=204000
export PFX_ITER=204000
export SERVER_SANS="DNS:test.local,DNS:test,IP:127.0.0.1"

# Test directories
TEST_DIR="/tmp/simpleca-e2e-test-$$"
CA_DIR="$TEST_DIR/ca"
EXPORT_DIR="$TEST_DIR/export"

cleanup() {
    echo "Cleaning up test directory..."
    rm -rf "$TEST_DIR"
}

trap cleanup EXIT

# Create test directories
mkdir -p "$CA_DIR" "$EXPORT_DIR"

# Mock password function for non-interactive testing
mock_password() {
    echo "testpass"
}

echo "1. Setting up test environment..."
# Create mock password script
cat > "$TEST_DIR/read-password.sh" <<'EOF'
#!/usr/bin/env bash
echo "testpass"
EOF
chmod +x "$TEST_DIR/read-password.sh"

# Create test .env file
cat > "$TEST_DIR/.env" <<'EOF'
KEY_TYPE=ec
EC_CURVE=prime256v1
LEAF_DAYS=398
PKCS8_ITER=204000
PFX_ITER=204000
SERVER_SANS=DNS:test.local,DNS:test,IP:127.0.0.1
EOF

echo "2. Testing CA initialization..."
# Set up environment for init
export basePath="$CA_DIR"
export rootCAPath="$CA_DIR/root"
export intermediatePath="$CA_DIR/intermediate"
export rootConfig="$SCRIPT_DIR/src/openssl-root.cnf"
export intermediateConfig="$SCRIPT_DIR/src/openssl-intermediate.cnf"
export ROOT_COUNTRY="US"
export ROOT_STATE="CA"
export ROOT_LOCALITY="San Francisco"
export ROOT_ORG="Test Org"

# Mock the password script path
export PATH="$TEST_DIR:$PATH"

# Run init (we'll need to mock the password input)
cd "$TEST_DIR"
if bash "$SCRIPT_DIR/src/init.sh" 2>/dev/null; then
    echo "✓ CA initialization completed"
else
    echo "✗ CA initialization failed"
    exit 1
fi

echo "3. Testing server certificate generation..."
# Set up environment for server cert generation
export SERVER_CN="test.local"
export serverKey="$intermediatePath/private/${SERVER_CN}.key.pem"
export serverCsr="$intermediatePath/csr/${SERVER_CN}.csr"
export serverCert="$intermediatePath/certs/${SERVER_CN}.cert.pem"
export outputDir="$CA_DIR/output/${SERVER_CN}"
export serverPem="$outputDir/${SERVER_CN}.pkcs8.key.pem"
export serverPfx="$outputDir/${SERVER_CN}.pfx"
export exportDir="$EXPORT_DIR"

# Run server cert generation
if bash "$SCRIPT_DIR/src/request-server-cert.sh" "$SERVER_CN" 2>/dev/null; then
    echo "✓ Server certificate generation completed"
else
    echo "✗ Server certificate generation failed"
    exit 1
fi

echo "4. Verifying generated files..."
# Check that all expected files exist
for file in "$rootCAPath/private/ca.key.pem" \
            "$rootCAPath/certs/ca.cert.pem" \
            "$intermediatePath/private/intermediate.key.pem" \
            "$intermediatePath/certs/intermediate.cert.pem" \
            "$intermediatePath/certs/ca-chain.cert.pem" \
            "$serverKey" \
            "$serverCert" \
            "$serverPem" \
            "$serverPfx"; do
    if [[ -f "$file" ]]; then
        echo "✓ Found: $(basename "$file")"
    else
        echo "✗ Missing: $(basename "$file")"
        exit 1
    fi
done

echo "5. Testing certificate chain validation..."
# Verify the certificate chain
if openssl verify -CAfile "$intermediatePath/certs/ca-chain.cert.pem" "$serverCert"; then
    echo "✓ Certificate chain validation passed"
else
    echo "✗ Certificate chain validation failed"
    exit 1
fi

echo "6. Testing PKCS#8 reading without legacy..."
# Test reading PKCS#8 without legacy
if openssl pkcs8 -in "$serverPem" -passin pass:testpass -out /dev/null; then
    echo "✓ PKCS#8 reading works without -legacy"
else
    echo "✗ PKCS#8 reading requires -legacy"
    exit 1
fi

echo "7. Testing PKCS#12 reading without legacy..."
# Test reading PKCS#12 without legacy
if openssl pkcs12 -in "$serverPfx" -nodes -passin pass:testpass -info >/dev/null; then
    echo "✓ PKCS#12 reading works without -legacy"
else
    echo "✗ PKCS#12 reading requires -legacy"
    exit 1
fi

echo "8. Testing certificate signature algorithm..."
# Check signature algorithm
SIG_ALG=$(openssl x509 -noout -text -in "$serverCert" | grep "Signature Algorithm" | head -1)
echo "Signature algorithm: $SIG_ALG"
if echo "$SIG_ALG" | grep -E -q "(sha256|SHA256)"; then
    echo "✓ Certificate uses SHA-256 signature"
else
    echo "✗ Certificate does not use SHA-256 signature"
    exit 1
fi

echo "9. Testing Subject Alternative Names..."
# Check SANs
SANS=$(openssl x509 -noout -text -in "$serverCert" | grep -A1 "Subject Alternative Name" | tail -1)
echo "SANs: $SANS"
if echo "$SANS" | grep -q "DNS:test.local" && echo "$SANS" | grep -q "IP:127.0.0.1"; then
    echo "✓ Certificate includes expected SANs"
else
    echo "✗ Certificate missing expected SANs"
    exit 1
fi

echo "10. Testing key type..."
# Check key type
KEY_TYPE_CHECK=$(openssl x509 -noout -text -in "$serverCert" | grep "Public Key Algorithm" | head -1)
echo "Key type: $KEY_TYPE_CHECK"
if echo "$KEY_TYPE_CHECK" | grep -q "id-ecPublicKey"; then
    echo "✓ Certificate uses EC key (as expected)"
else
    echo "✗ Certificate does not use EC key"
    exit 1
fi

echo ""
echo "🎉 All end-to-end tests passed! Modern certificate generation is working correctly."
echo "✓ CA initialization with modern key generation"
echo "✓ Server certificate generation with modern algorithms"
echo "✓ Certificate chain validation"
echo "✓ PKCS#8 reading without -legacy"
echo "✓ PKCS#12 reading without -legacy"
echo "✓ SHA-256 signatures"
echo "✓ Subject Alternative Names"
echo "✓ EC key type"
