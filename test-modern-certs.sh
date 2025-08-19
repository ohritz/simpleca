#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Test script to verify modern certificate generation
# This script tests that certificates can be generated and read without -legacy flags

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Testing modern certificate generation..."

# Set test environment
export KEY_TYPE=ec
export EC_CURVE=prime256v1
export LEAF_DAYS=398
export PKCS8_ITER=204000
export PFX_ITER=204000
export SERVER_SANS="DNS:test.local,DNS:test,IP:127.0.0.1"

# Test directories
TEST_DIR="/tmp/simpleca-test-$$"
CA_DIR="$TEST_DIR/ca"
EXPORT_DIR="$TEST_DIR/export"

cleanup() {
    echo "Cleaning up test directory..."
    rm -rf "$TEST_DIR"
}

trap cleanup EXIT

# Create test directories
mkdir -p "$CA_DIR" "$EXPORT_DIR"

echo "1. Testing EC key generation..."
# Test EC key generation
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:prime256v1 \
    -pkeyopt ec_param_enc:named_curve -aes-256-cbc -pass pass:testpass \
    -out "$TEST_DIR/test-ec.key.pem"

echo "2. Testing RSA key generation..."
# Test RSA key generation
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 \
    -aes-256-cbc -pass pass:testpass \
    -out "$TEST_DIR/test-rsa.key.pem"

echo "3. Testing PKCS#8 conversion..."
# Test PKCS#8 conversion
openssl pkcs8 -topk8 -v2 aes-256-cbc -iter 204000 \
    -passin pass:testpass -passout pass:testpass \
    -in "$TEST_DIR/test-ec.key.pem" -out "$TEST_DIR/test-ec.pkcs8.key.pem"

echo "4. Testing PKCS#8 reading (should work without -legacy)..."
# Test reading PKCS#8 without legacy
if openssl pkcs8 -in "$TEST_DIR/test-ec.pkcs8.key.pem" -passin pass:testpass -out /dev/null; then
    echo "✓ PKCS#8 reading works without -legacy"
else
    echo "✗ PKCS#8 reading requires -legacy (this is what we're trying to avoid)"
    exit 1
fi

echo "5. Testing PKCS#12 generation..."
# Create a test certificate for PKCS#12
openssl req -x509 -new -key "$TEST_DIR/test-ec.key.pem" \
    -sha256 -days 365 -out "$TEST_DIR/test.cert.pem" \
    -passin pass:testpass \
    -subj "/CN=test.local" \
    -addext "subjectAltName = DNS:test.local"

# Test PKCS#12 generation
openssl pkcs12 -export -inkey "$TEST_DIR/test-ec.key.pem" \
    -passin pass:testpass -in "$TEST_DIR/test.cert.pem" \
    -out "$TEST_DIR/test.pfx" \
    -keypbe AES-256-CBC -certpbe AES-256-CBC \
    -macalg sha256 -iter 204000 -maciter \
    -passout pass:testpass

echo "6. Testing PKCS#12 reading (should work without -legacy)..."
# Test reading PKCS#12 without legacy
if openssl pkcs12 -in "$TEST_DIR/test.pfx" -nodes -passin pass:testpass -info >/dev/null; then
    echo "✓ PKCS#12 reading works without -legacy"
else
    echo "✗ PKCS#12 reading requires -legacy (this is what we're trying to avoid)"
    exit 1
fi

echo "7. Testing certificate signature algorithm..."
# Check signature algorithm
SIG_ALG=$(openssl x509 -noout -text -in "$TEST_DIR/test.cert.pem" | grep "Signature Algorithm" | head -1)
echo "Signature algorithm: $SIG_ALG"
if echo "$SIG_ALG" | grep -E -q "(sha256|SHA256)"; then
    echo "✓ Certificate uses SHA-256 signature"
else
    echo "✗ Certificate does not use SHA-256 signature"
    exit 1
fi

echo "8. Testing Subject Alternative Names..."
# Check SANs
SANS=$(openssl x509 -noout -text -in "$TEST_DIR/test.cert.pem" | grep -A1 "Subject Alternative Name" | tail -1)
echo "SANs: $SANS"
if echo "$SANS" | grep -q "DNS:test.local"; then
    echo "✓ Certificate includes expected SANs"
else
    echo "✗ Certificate missing expected SANs"
    exit 1
fi

echo ""
echo "🎉 All tests passed! Modern certificate generation is working correctly."
echo "✓ EC key generation with genpkey"
echo "✓ RSA key generation with genpkey"
echo "✓ PKCS#8 conversion with AES-256-CBC"
echo "✓ PKCS#8 reading without -legacy"
echo "✓ PKCS#12 generation with AES-256-CBC"
echo "✓ PKCS#12 reading without -legacy"
echo "✓ SHA-256 signatures"
echo "✓ Subject Alternative Names"
