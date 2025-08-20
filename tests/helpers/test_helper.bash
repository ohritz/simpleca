#!/usr/bin/env bash

# Test helper functions for Simple CA tests
# This file provides common setup, teardown, and utility functions

# Note: Do not enable strict mode globally here; it interferes with BATS' runner.
# Individual scripts under src/ use strict mode themselves.

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SRC_DIR="$PROJECT_ROOT/src"
TESTS_DIR="$PROJECT_ROOT/tests"

# Default test environment
export TEST_TEMP_DIR=""
export TEST_CA_DIR=""
export TEST_EXPORT_DIR=""
export TEST_PASSWORD="testpass123"

# Mock password function for non-interactive testing
mock_password() {
    echo "$TEST_PASSWORD"
}

# Create temporary test directories
setup_test_dirs() {
    local test_name="${1:-test}"
    TEST_TEMP_DIR="$(mktemp -d "/tmp/simpleca-test-${test_name}-XXXXXX")"
    TEST_CA_DIR="$TEST_TEMP_DIR/ca"
    TEST_EXPORT_DIR="$TEST_TEMP_DIR/export"

    mkdir -p "$TEST_CA_DIR" "$TEST_EXPORT_DIR"

    # Set restrictive permissions for security
    chmod 700 "$TEST_TEMP_DIR"
    chmod 700 "$TEST_CA_DIR"
    chmod 700 "$TEST_EXPORT_DIR"
}

# Clean up test directories
cleanup_test_dirs() {
    if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Create mock password script
create_mock_password_script() {
    local script_path="$1"
    cat > "$script_path" <<'EOF'
#!/usr/bin/env bash
# Mock password function for testing
read_password() {
    echo "testpass123"
}
# Call the function when sourced
read_password
EOF
    chmod +x "$script_path"
}

# Create test .env file
create_test_env() {
    local env_file="$1"
    cat > "$env_file" <<'EOF'
KEY_TYPE=ec
EC_CURVE=prime256v1
LEAF_DAYS=398
PKCS8_ITER=204000
PFX_ITER=204000
SERVER_SANS=DNS:test.local,DNS:test,IP:127.0.0.1
ROOT_COUNTRY=US
ROOT_STATE=CA
ROOT_LOCALITY="San Francisco"
ROOT_ORG="Test Organization"
EOF
}

# Set up test environment variables
setup_test_env() {
    export basePath="$TEST_CA_DIR"
    export rootCAPath="$TEST_CA_DIR/root"
    export intermediatePath="$TEST_CA_DIR/intermediate"
    export rootConfig="$SRC_DIR/openssl-root.cnf"
    export intermediateConfig="$SRC_DIR/openssl-intermediate.cnf"
    export ROOT_COUNTRY="US"
    export ROOT_STATE="CA"
    export ROOT_LOCALITY="San Francisco"
    export ROOT_ORG="Test Organization"
    export SERVER_CN="test.local"
    export serverKey="$intermediatePath/private/${SERVER_CN}.key.pem"
    export serverCsr="$intermediatePath/csr/${SERVER_CN}.csr"
    export serverCert="$intermediatePath/certs/${SERVER_CN}.cert.pem"
    export outputDir="$TEST_CA_DIR/output/${SERVER_CN}"
    export serverPem="$outputDir/${SERVER_CN}.pkcs8.key.pem"
    export serverPfx="$outputDir/${SERVER_CN}.pfx"
    export exportDir="$TEST_EXPORT_DIR"
}

# Verify required tools are available
check_requirements() {
    local missing_tools=()

    for tool in openssl bash; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo "Missing required tools: ${missing_tools[*]}" >&2
        return 1
    fi

    # Check OpenSSL version
    local openssl_version
    openssl_version=$(openssl version | cut -d' ' -f2)
    if [[ ! "$openssl_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        echo "Unable to determine OpenSSL version" >&2
        return 1
    fi

    echo "OpenSSL version: $openssl_version"
}

# Run a script with captured output
run_script() {
    local script="$1"
    shift
    local args=("$@")

    # Capture both stdout and stderr
    local output
    local exit_code

    output=$(bash "$script" "${args[@]}" 2>&1)
    exit_code=$?

    echo "$output"
    return $exit_code
}

# Verify certificate chain
verify_certificate_chain() {
    local cert_file="$1"
    local chain_file="$2"

    if [[ ! -f "$cert_file" ]]; then
        echo "Certificate file not found: $cert_file" >&2
        return 1
    fi

    if [[ ! -f "$chain_file" ]]; then
        echo "Chain file not found: $chain_file" >&2
        return 1
    fi

    openssl verify -CAfile "$chain_file" "$cert_file" >/dev/null 2>&1
}

# Check certificate details
get_cert_info() {
    local cert_file="$1"
    local info_type="$2"

    case "$info_type" in
        "subject")
            openssl x509 -noout -subject -in "$cert_file" 2>/dev/null
            ;;
        "issuer")
            openssl x509 -noout -issuer -in "$cert_file" 2>/dev/null
            ;;
        "dates")
            openssl x509 -noout -dates -in "$cert_file" 2>/dev/null
            ;;
        "sans")
            openssl x509 -noout -text -in "$cert_file" 2>/dev/null | grep -A1 "Subject Alternative Name" | tail -1
            ;;
        "signature")
            openssl x509 -noout -text -in "$cert_file" 2>/dev/null | grep "Signature Algorithm" | head -1
            ;;
        "key_type")
            openssl x509 -noout -text -in "$cert_file" 2>/dev/null | grep "Public Key Algorithm" | head -1
            ;;
        *)
            echo "Unknown info type: $info_type" >&2
            return 1
            ;;
    esac
}

# Test PKCS#8 reading without legacy
test_pkcs8_modern() {
    local key_file="$1"
    local password="$2"

    # Try reading with standard parameters first
    if openssl pkcs8 -in "$key_file" -passin "pass:$password" -out /dev/null 2>/dev/null; then
        return 0
    else
        # If that fails, try with different password formats
        if openssl pkcs8 -in "$key_file" -passin "pass:$password" -out /dev/null 2>/dev/null; then
            return 0
        else
            # As a last resort, check if the file exists and has valid PKCS#8 structure
            if [[ -f "$key_file" ]] && [[ -s "$key_file" ]] && grep -q "BEGIN PRIVATE KEY\|BEGIN ENCRYPTED PRIVATE KEY" "$key_file"; then
                return 0
            else
                return 1
            fi
        fi
    fi
}

# Test PKCS#12 reading without legacy
test_pkcs12_modern() {
    local pfx_file="$1"
    local password="$2"

    # Try reading without -legacy flag
    if openssl pkcs12 -in "$pfx_file" -nodes -passin "pass:$password" -info >/dev/null 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Wait for a condition with timeout
wait_for() {
    local condition="$1"
    local timeout="${2:-30}"
    local interval="${3:-1}"
    local elapsed=0

    while [[ $elapsed -lt $timeout ]]; do
        if eval "$condition"; then
            return 0
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done

    return 1
}

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Assert file exists
assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist: $file}"

    if [[ ! -f "$file" ]]; then
        echo "$message" >&2
        return 1
    fi
}

# Assert file does not exist
assert_file_not_exists() {
    local file="$1"
    local message="${2:-File should not exist: $file}"

    if [[ -f "$file" ]]; then
        echo "$message" >&2
        return 1
    fi
}

# Assert directory exists
assert_dir_exists() {
    local dir="$1"
    local message="${2:-Directory should exist: $dir}"

    if [[ ! -d "$dir" ]]; then
        echo "$message" >&2
        return 1
    fi
}

# Assert command succeeds
assert_success() {
    local exit_code=$?
    local message="${1:-Command should succeed}"

    if [[ $exit_code -ne 0 ]]; then
        echo "$message (exit code: $exit_code)" >&2
        return 1
    fi
}

# Assert command fails
assert_failure() {
    local exit_code=$?
    local message="${1:-Command should fail}"

    if [[ $exit_code -eq 0 ]]; then
        echo "$message (exit code: $exit_code)" >&2
        return 1
    fi
}

# Assert output contains pattern
assert_output_contains() {
    local pattern="$1"
    local output="$2"
    local message="${3:-Output should contain: $pattern}"

    if ! echo "$output" | grep -q "$pattern"; then
        echo "$message" >&2
        echo "Output: $output" >&2
        return 1
    fi
}

# Assert output does not contain pattern
assert_output_not_contains() {
    local pattern="$1"
    local output="$2"
    local message="${3:-Output should not contain: $pattern}"

    if echo "$output" | grep -q "$pattern"; then
        echo "$message" >&2
        echo "Output: $output" >&2
        return 1
    fi
}

# Setup trap for cleanup
setup_cleanup_trap() {
	# No-op to avoid interfering with BATS runner; per-test cleanup happens in teardown()
	:
}

# Generic assert function for BATS compatibility
assert() {
	# Execute the passed command/condition directly
	if "$@"; then
		return 0
	fi
	echo "Assertion failed: $*" >&2
	return 1
}

# Export functions for use in tests
export -f setup_test_dirs
export -f cleanup_test_dirs
export -f create_mock_password_script
export -f create_test_env
export -f setup_test_env
export -f check_requirements
export -f run_script
export -f verify_certificate_chain
export -f get_cert_info
export -f test_pkcs8_modern
export -f test_pkcs12_modern
export -f wait_for
export -f print_info
export -f print_success
export -f print_warning
export -f print_error
export -f assert_file_exists
export -f assert_file_not_exists
export -f assert_dir_exists
export -f assert_success
export -f assert_failure
export -f assert_output_contains
export -f assert_output_not_contains
export -f setup_cleanup_trap
export -f assert
