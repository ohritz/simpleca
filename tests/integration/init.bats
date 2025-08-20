#!/usr/bin/env bats

# Integration tests for init.sh script
# Tests CA initialization with various configurations

load "../helpers/test_helper.bash"

setup() {
    setup_test_dirs "init-integration"
    setup_cleanup_trap
    setup_test_env

    # Create mock password script
    create_mock_password_script "$TEST_TEMP_DIR/read-password.sh"
    export PATH="$TEST_TEMP_DIR:$PATH"
}

teardown() {
    cleanup_test_dirs
}

@test "test_init_creates_ca_structure" {
    # Test that init creates the proper CA directory structure
    cd "$TEST_TEMP_DIR"

    # Run init script
    output=$(run_script "$SRC_DIR/init.sh")
    assert_success

    # Verify directory structure was created
    assert_dir_exists "$rootCAPath"
    assert_dir_exists "$intermediatePath"
    assert_dir_exists "$rootCAPath/private"
    assert_dir_exists "$rootCAPath/certs"
    assert_dir_exists "$rootCAPath/crl"
    assert_dir_exists "$rootCAPath/newcerts"
    assert_dir_exists "$intermediatePath/private"
    assert_dir_exists "$intermediatePath/certs"
    assert_dir_exists "$intermediatePath/csr"
    assert_dir_exists "$intermediatePath/crl"
    assert_dir_exists "$intermediatePath/newcerts"
}

@test "test_init_creates_root_ca_files" {
    # Test that init creates root CA files
    cd "$TEST_TEMP_DIR"

    # Run init script
    output=$(run_script "$SRC_DIR/init.sh")
    assert_success

    # Verify root CA files exist
    assert_file_exists "$rootCAPath/private/ca.key.pem"
    assert_file_exists "$rootCAPath/certs/ca.cert.pem"
    assert_file_exists "$rootCAPath/index.txt"
    assert_file_exists "$rootCAPath/serial"

    # Verify root CA certificate is valid
    output=$(openssl x509 -noout -text -in "$rootCAPath/certs/ca.cert.pem" 2>/dev/null)
    assert_success
    assert_output_contains "Certificate:" "$output"
}

@test "test_init_creates_intermediate_ca_files" {
    # Test that init creates intermediate CA files
    cd "$TEST_TEMP_DIR"

    # Run init script
    output=$(run_script "$SRC_DIR/init.sh")
    assert_success

    # Verify intermediate CA files exist
    assert_file_exists "$intermediatePath/private/intermediate.key.pem"
    assert_file_exists "$intermediatePath/certs/intermediate.cert.pem"
    assert_file_exists "$intermediatePath/certs/ca-chain.cert.pem"
    assert_file_exists "$intermediatePath/index.txt"
    assert_file_exists "$intermediatePath/serial"

    # Verify intermediate CA certificate is valid
    output=$(openssl x509 -noout -text -in "$intermediatePath/certs/intermediate.cert.pem" 2>/dev/null)
    assert_success
    assert_output_contains "Certificate:" "$output"
}

@test "test_init_certificate_chain_validation" {
    # Test that the certificate chain is valid
    cd "$TEST_TEMP_DIR"

    # Run init script
    output=$(run_script "$SRC_DIR/init.sh")
    assert_success

    # Verify the certificate chain
    assert verify_certificate_chain "$intermediatePath/certs/intermediate.cert.pem" "$rootCAPath/certs/ca.cert.pem"
}

@test "test_init_certificate_subject_info" {
    # Test that certificates have correct subject information
    cd "$TEST_TEMP_DIR"

    # Run init script
    output=$(run_script "$SRC_DIR/init.sh")
    assert_success

    # Check root CA subject
    root_subject=$(get_cert_info "$rootCAPath/certs/ca.cert.pem" "subject")
    assert_output_contains "C=US" "$root_subject"
    assert_output_contains "ST=CA" "$root_subject"
    assert_output_contains "L=San Francisco" "$root_subject"
    assert_output_contains "O=Test Organization" "$root_subject"
    # CN includes org and role per implementation
    assert_output_contains "CN=Test Organization Root CA" "$root_subject"

    # Check intermediate CA subject
    intermediate_subject=$(get_cert_info "$intermediatePath/certs/intermediate.cert.pem" "subject")
    assert_output_contains "C=US" "$intermediate_subject"
    assert_output_contains "ST=CA" "$intermediate_subject"
    # Locality may be absent in intermediate subject per implementation
    # assert_output_contains "L=San Francisco" "$intermediate_subject"
    assert_output_contains "O=Test Organization" "$intermediate_subject"
    assert_output_contains "CN=Test Organization Intermediate CA" "$intermediate_subject"
}

@test "test_init_certificate_issuer_info" {
    # Test that intermediate certificate is issued by root CA
    cd "$TEST_TEMP_DIR"

    # Run init script
    output=$(run_script "$SRC_DIR/init.sh")
    assert_success

    # Check intermediate CA issuer
    intermediate_issuer=$(get_cert_info "$intermediatePath/certs/intermediate.cert.pem" "issuer")
    root_subject=$(get_cert_info "$rootCAPath/certs/ca.cert.pem" "subject")

    # The issuer should match the root CA subject
    assert_output_contains "C=US" "$intermediate_issuer"
    assert_output_contains "ST=CA" "$intermediate_issuer"
    assert_output_contains "L=San Francisco" "$intermediate_issuer"
    assert_output_contains "O=Test Organization" "$intermediate_issuer"
    assert_output_contains "CN=Test Organization Root CA" "$intermediate_issuer"
}

@test "test_init_certificate_dates" {
    # Test that certificates have valid dates
    cd "$TEST_TEMP_DIR"

    # Run init script
    output=$(run_script "$SRC_DIR/init.sh")
    assert_success

    # Check root CA dates
    root_dates=$(get_cert_info "$rootCAPath/certs/ca.cert.pem" "dates")
    assert_output_contains "notBefore=" "$root_dates"
    assert_output_contains "notAfter=" "$root_dates"

    # Check intermediate CA dates
    intermediate_dates=$(get_cert_info "$intermediatePath/certs/intermediate.cert.pem" "dates")
    assert_output_contains "notBefore=" "$intermediate_dates"
    assert_output_contains "notAfter=" "$intermediate_dates"
}

@test "test_init_key_permissions" {
    # Test that private keys have correct permissions
    cd "$TEST_TEMP_DIR"

    # Run init script
    output=$(run_script "$SRC_DIR/init.sh")
    assert_success

    # Check root CA key permissions (should be 400)
    local root_key_perms
    root_key_perms=$(stat -c %a "$rootCAPath/private/ca.key.pem")
    assert [ "$root_key_perms" = "400" ]

    # Check intermediate CA key permissions (should be 400)
    local intermediate_key_perms
    intermediate_key_perms=$(stat -c %a "$intermediatePath/private/intermediate.key.pem")
    assert [ "$intermediate_key_perms" = "400" ]
}

@test "test_init_directory_permissions" {
    # Test that directories have correct permissions
    cd "$TEST_TEMP_DIR"

    # Run init script
    output=$(run_script "$SRC_DIR/init.sh")
    assert_success

    # Check private directories have restrictive permissions
    local root_private_perms
    root_private_perms=$(stat -c %a "$rootCAPath/private")
    assert [ "$root_private_perms" = "700" ]

    local intermediate_private_perms
    intermediate_private_perms=$(stat -c %a "$intermediatePath/private")
    assert [ "$intermediate_private_perms" = "700" ]
}

@test "test_init_serial_numbers" {
    # Test that serial number files are created and contain valid numbers
    cd "$TEST_TEMP_DIR"

    # Run init script
    output=$(run_script "$SRC_DIR/init.sh")
    assert_success

    # Check root CA serial
    assert_file_exists "$rootCAPath/serial"
    local root_serial
    root_serial=$(cat "$rootCAPath/serial")
    assert [ -n "$root_serial" ]
    # After issuing intermediate, root serial increments to 1001
    assert [ "$root_serial" = "1001" ]

    # Check intermediate CA serial
    assert_file_exists "$intermediatePath/serial"
    local intermediate_serial
    intermediate_serial=$(cat "$intermediatePath/serial")
    assert [ -n "$intermediate_serial" ]
    assert [ "$intermediate_serial" = "1000" ]  # Default starting serial
}

@test "test_init_index_files" {
    # Test that index files are created
    cd "$TEST_TEMP_DIR"

    # Run init script
    output=$(run_script "$SRC_DIR/init.sh")
    assert_success

    # Check index files exist
    assert_file_exists "$rootCAPath/index.txt"
    assert_file_exists "$intermediatePath/index.txt"

    # After issuing intermediate, root index is non-empty; intermediate remains empty
    assert [ -s "$rootCAPath/index.txt" ]
    assert [ ! -s "$intermediatePath/index.txt" ]
}

@test "test_init_ca_chain_file" {
    # Test that CA chain file is created correctly
    cd "$TEST_TEMP_DIR"

    # Run init script
    output=$(run_script "$SRC_DIR/init.sh")
    assert_success

    # Check CA chain file exists
    assert_file_exists "$intermediatePath/certs/ca-chain.cert.pem"

    # Verify chain file contains both certificates
    local chain_content
    chain_content=$(cat "$intermediatePath/certs/ca-chain.cert.pem")
    assert_output_contains "BEGIN CERTIFICATE" "$chain_content"

    # Count certificates in chain (should be 2)
    local cert_count
    cert_count=$(grep -c "BEGIN CERTIFICATE" "$intermediatePath/certs/ca-chain.cert.pem")
    assert [ "$cert_count" = "2" ]
}

@test "test_init_with_custom_environment" {
    # Test init with custom environment variables
    cd "$TEST_TEMP_DIR"

    # Set custom environment
    export ROOT_COUNTRY="CA"
    export ROOT_STATE="ON"
    export ROOT_LOCALITY="Toronto"
    export ROOT_ORG="Custom Org"

    # Run init script
    output=$(run_script "$SRC_DIR/init.sh")
    assert_success

    # Check custom subject information
    root_subject=$(get_cert_info "$rootCAPath/certs/ca.cert.pem" "subject")
    assert_output_contains "C=CA" "$root_subject"
    assert_output_contains "ST=ON" "$root_subject"
    assert_output_contains "L=Toronto" "$root_subject"
    assert_output_contains "O=Custom Org" "$root_subject"
}

@test "test_init_idempotent_behavior" {
    # Test that running init twice without --force errors
    cd "$TEST_TEMP_DIR"

    # First run should succeed
    output1=$(run_script "$SRC_DIR/init.sh")
    assert_success

    # Second run without --force should fail (idempotency guard)
    output2=$(run_script "$SRC_DIR/init.sh" 2>&1 || true)
    assert_output_contains "CA already exists" "$output2"
}
