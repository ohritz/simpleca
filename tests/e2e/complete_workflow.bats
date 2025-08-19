#!/usr/bin/env bats

# End-to-end tests for complete Simple CA workflow
# Tests: init → issue → validate → eject → re-init

load "helpers/test_helper.bash"

setup() {
    setup_test_dirs "e2e-complete"
    setup_cleanup_trap
    setup_test_env

    # Create mock password script
    create_mock_password_script "$TEST_TEMP_DIR/read-password.sh"
    export PATH="$TEST_TEMP_DIR:$PATH"
}

teardown() {
    cleanup_test_dirs
}

@test "test_e2e_complete_workflow_ec" {
    # Test complete workflow with EC keys
    cd "$TEST_TEMP_DIR"

    print_info "Starting complete E2E workflow with EC keys"

    # Step 1: Initialize CA
    print_info "Step 1: Initializing CA"
    output=$(run_script "$SRC_DIR/init.sh")
    assert_success
    print_success "CA initialization completed"

    # Step 2: Issue server certificate
    print_info "Step 2: Issuing server certificate"
    output=$(run_script "$SRC_DIR/request-server-cert.sh" "test.local")
    assert_success
    print_success "Server certificate issued"

    # Step 3: Verify generated files
    print_info "Step 3: Verifying generated files"
    assert_file_exists "$serverKey"
    assert_file_exists "$serverCert"
    assert_file_exists "$serverPem"
    assert_file_exists "$serverPfx"
    print_success "All certificate files generated"

    # Step 4: Validate certificate chain
    print_info "Step 4: Validating certificate chain"
    assert verify_certificate_chain "$serverCert" "$intermediatePath/certs/ca-chain.cert.pem"
    print_success "Certificate chain validation passed"

    # Step 5: Test modern certificate reading
    print_info "Step 5: Testing modern certificate reading"
    assert test_pkcs8_modern "$serverPem" "$TEST_PASSWORD"
    assert test_pkcs12_modern "$serverPfx" "$TEST_PASSWORD"
    print_success "Modern certificate reading works"

    # Step 6: Validate certificate details
    print_info "Step 6: Validating certificate details"

    # Check signature algorithm
    sig_alg=$(get_cert_info "$serverCert" "signature")
    assert_output_contains "sha256" "$sig_alg"

    # Check key type
    key_type=$(get_cert_info "$serverCert" "key_type")
    assert_output_contains "id-ecPublicKey" "$key_type"

    # Check SANs
    sans=$(get_cert_info "$serverCert" "sans")
    assert_output_contains "DNS:test.local" "$sans"
    assert_output_contains "DNS:test" "$sans"
    assert_output_contains "IP:127.0.0.1" "$sans"

    print_success "Certificate details validated"

    # Step 7: Test validation command
    print_info "Step 7: Testing validation command"
    output=$(run_script "$SRC_DIR/validate.sh" "$serverCert")
    assert_success
    assert_output_contains "Certificate is valid" "$output"
    print_success "Validation command works"

    # Step 8: Test eject command
    print_info "Step 8: Testing eject command"
    output=$(run_script "$SRC_DIR/eject-ca.sh" "$TEST_EXPORT_DIR")
    assert_success
    print_success "CA ejected successfully"

    # Step 9: Verify eject created archive
    print_info "Step 9: Verifying eject archive"
    local archive_file
    archive_file=$(find "$TEST_EXPORT_DIR" -name "*.tar.gz" | head -1)
    assert [ -n "$archive_file" ]
    assert_file_exists "$archive_file"
    print_success "Eject archive created"

    # Step 10: Test re-init command
    print_info "Step 10: Testing re-init command"
    output=$(run_script "$SRC_DIR/re-init.sh" "$archive_file")
    assert_success
    print_success "CA re-initialized successfully"

    # Step 11: Verify re-init restored files
    print_info "Step 11: Verifying re-init restored files"
    assert_file_exists "$rootCAPath/private/ca.key.pem"
    assert_file_exists "$rootCAPath/certs/ca.cert.pem"
    assert_file_exists "$intermediatePath/private/intermediate.key.pem"
    assert_file_exists "$intermediatePath/certs/intermediate.cert.pem"
    assert_file_exists "$serverKey"
    assert_file_exists "$serverCert"
    print_success "All files restored by re-init"

    print_success "Complete E2E workflow with EC keys passed"
}

@test "test_e2e_complete_workflow_rsa" {
    # Test complete workflow with RSA keys
    cd "$TEST_TEMP_DIR"

    # Set RSA configuration
    export KEY_TYPE="rsa"
    export RSA_BITS="3072"

    print_info "Starting complete E2E workflow with RSA keys"

    # Step 1: Initialize CA
    print_info "Step 1: Initializing CA"
    output=$(run_script "$SRC_DIR/init.sh")
    assert_success
    print_success "CA initialization completed"

    # Step 2: Issue server certificate
    print_info "Step 2: Issuing server certificate"
    output=$(run_script "$SRC_DIR/request-server-cert.sh" "test.local")
    assert_success
    print_success "Server certificate issued"

    # Step 3: Verify generated files
    print_info "Step 3: Verifying generated files"
    assert_file_exists "$serverKey"
    assert_file_exists "$serverCert"
    assert_file_exists "$serverPem"
    assert_file_exists "$serverPfx"
    print_success "All certificate files generated"

    # Step 4: Validate certificate chain
    print_info "Step 4: Validating certificate chain"
    assert verify_certificate_chain "$serverCert" "$intermediatePath/certs/ca-chain.cert.pem"
    print_success "Certificate chain validation passed"

    # Step 5: Test modern certificate reading
    print_info "Step 5: Testing modern certificate reading"
    assert test_pkcs8_modern "$serverPem" "$TEST_PASSWORD"
    assert test_pkcs12_modern "$serverPfx" "$TEST_PASSWORD"
    print_success "Modern certificate reading works"

    # Step 6: Validate certificate details
    print_info "Step 6: Validating certificate details"

    # Check signature algorithm
    sig_alg=$(get_cert_info "$serverCert" "signature")
    assert_output_contains "sha256" "$sig_alg"

    # Check key type
    key_type=$(get_cert_info "$serverCert" "key_type")
    assert_output_contains "rsaEncryption" "$key_type"

    # Check SANs
    sans=$(get_cert_info "$serverCert" "sans")
    assert_output_contains "DNS:test.local" "$sans"
    assert_output_contains "DNS:test" "$sans"
    assert_output_contains "IP:127.0.0.1" "$sans"

    print_success "Certificate details validated"

    print_success "Complete E2E workflow with RSA keys passed"
}

@test "test_e2e_multiple_certificates" {
    # Test issuing multiple certificates
    cd "$TEST_TEMP_DIR"

    print_info "Starting multiple certificates test"

    # Step 1: Initialize CA
    print_info "Step 1: Initializing CA"
    output=$(run_script "$SRC_DIR/init.sh")
    assert_success

    # Step 2: Issue first certificate
    print_info "Step 2: Issuing first certificate"
    export SERVER_CN="web.local"
    output=$(run_script "$SRC_DIR/request-server-cert.sh" "web.local")
    assert_success

    # Step 3: Issue second certificate
    print_info "Step 3: Issuing second certificate"
    export SERVER_CN="api.local"
    output=$(run_script "$SRC_DIR/request-server-cert.sh" "api.local")
    assert_success

    # Step 4: Issue third certificate
    print_info "Step 4: Issuing third certificate"
    export SERVER_CN="db.local"
    output=$(run_script "$SRC_DIR/request-server-cert.sh" "db.local")
    assert_success

    # Step 5: Verify all certificates
    print_info "Step 5: Verifying all certificates"

    local certs=("web.local" "api.local" "db.local")
    for cert in "${certs[@]}"; do
        local cert_file="$intermediatePath/certs/${cert}.cert.pem"
        local key_file="$intermediatePath/private/${cert}.key.pem"

        assert_file_exists "$cert_file"
        assert_file_exists "$key_file"
        assert verify_certificate_chain "$cert_file" "$intermediatePath/certs/ca-chain.cert.pem"

        # Check each certificate has correct CN
        local subject
        subject=$(get_cert_info "$cert_file" "subject")
        assert_output_contains "CN=${cert}" "$subject"
    done

    print_success "Multiple certificates test passed"
}

@test "test_e2e_custom_sans" {
    # Test issuing certificate with custom SANs
    cd "$TEST_TEMP_DIR"

    print_info "Starting custom SANs test"

    # Step 1: Initialize CA
    print_info "Step 1: Initializing CA"
    output=$(run_script "$SRC_DIR/init.sh")
    assert_success

    # Step 2: Issue certificate with custom SANs
    print_info "Step 2: Issuing certificate with custom SANs"
    export SERVER_CN="custom.local"
    export SERVER_SANS="DNS:custom.local,DNS:www.custom.local,DNS:api.custom.local,IP:192.168.1.100,IP:10.0.0.1"
    output=$(run_script "$SRC_DIR/request-server-cert.sh" "custom.local")
    assert_success

    # Step 3: Verify certificate SANs
    print_info "Step 3: Verifying certificate SANs"
    local cert_file="$intermediatePath/certs/custom.local.cert.pem"
    local sans
    sans=$(get_cert_info "$cert_file" "sans")

    assert_output_contains "DNS:custom.local" "$sans"
    assert_output_contains "DNS:www.custom.local" "$sans"
    assert_output_contains "DNS:api.custom.local" "$sans"
    assert_output_contains "IP:192.168.1.100" "$sans"
    assert_output_contains "IP:10.0.0.1" "$sans"

    print_success "Custom SANs test passed"
}

@test "test_e2e_cli_interface" {
    # Test the CLI interface through main.sh
    cd "$TEST_TEMP_DIR"

    print_info "Starting CLI interface test"

    # Step 1: Test init through CLI
    print_info "Step 1: Testing init through CLI"
    output=$(run_script "$SRC_DIR/main.sh" init)
    assert_success

    # Step 2: Test issue through CLI
    print_info "Step 2: Testing issue through CLI"
    output=$(run_script "$SRC_DIR/main.sh" issue "cli.local")
    assert_success

    # Step 3: Test validate through CLI
    print_info "Step 3: Testing validate through CLI"
    local cert_file="$intermediatePath/certs/cli.local.cert.pem"
    output=$(run_script "$SRC_DIR/main.sh" validate "$cert_file")
    assert_success

    # Step 4: Test backward compatibility
    print_info "Step 4: Testing backward compatibility"
    output=$(run_script "$SRC_DIR/main.sh" "backward.local")
    assert_success

    print_success "CLI interface test passed"
}

@test "test_e2e_error_handling" {
    # Test error handling in various scenarios
    cd "$TEST_TEMP_DIR"

    print_info "Starting error handling test"

    # Test 1: Issue certificate without CA
    print_info "Test 1: Issue certificate without CA"
    output=$(run_script "$SRC_DIR/request-server-cert.sh" "error.local" 2>&1 || true)
    assert_failure
    assert_output_contains "error" "$output"

    # Test 2: Validate non-existent certificate
    print_info "Test 2: Validate non-existent certificate"
    output=$(run_script "$SRC_DIR/validate.sh" "/nonexistent/cert.pem" 2>&1 || true)
    assert_failure
    assert_output_contains "error" "$output"

    # Test 3: Eject without CA
    print_info "Test 3: Eject without CA"
    output=$(run_script "$SRC_DIR/eject-ca.sh" "$TEST_EXPORT_DIR" 2>&1 || true)
    assert_failure
    assert_output_contains "error" "$output"

    # Test 4: Re-init with non-existent archive
    print_info "Test 4: Re-init with non-existent archive"
    output=$(run_script "$SRC_DIR/re-init.sh" "/nonexistent/archive.tar.gz" 2>&1 || true)
    assert_failure
    assert_output_contains "error" "$output"

    print_success "Error handling test passed"
}

@test "test_e2e_performance" {
    # Test performance with multiple operations
    cd "$TEST_TEMP_DIR"

    print_info "Starting performance test"

    # Step 1: Initialize CA
    print_info "Step 1: Initializing CA"
    local start_time
    start_time=$(date +%s)
    output=$(run_script "$SRC_DIR/init.sh")
    assert_success
    local init_time
    init_time=$(($(date +%s) - start_time))
    print_info "CA initialization took ${init_time}s"

    # Step 2: Issue multiple certificates quickly
    print_info "Step 2: Issuing multiple certificates"
    start_time=$(date +%s)

    for i in {1..5}; do
        export SERVER_CN="perf${i}.local"
        output=$(run_script "$SRC_DIR/request-server-cert.sh" "perf${i}.local")
        assert_success
    done

    local issue_time
    issue_time=$(($(date +%s) - start_time))
    print_info "Issuing 5 certificates took ${issue_time}s"

    # Step 3: Validate all certificates
    print_info "Step 3: Validating all certificates"
    start_time=$(date +%s)

    for i in {1..5}; do
        local cert_file="$intermediatePath/certs/perf${i}.local.cert.pem"
        assert verify_certificate_chain "$cert_file" "$intermediatePath/certs/ca-chain.cert.pem"
    done

    local validate_time
    validate_time=$(($(date +%s) - start_time))
    print_info "Validating 5 certificates took ${validate_time}s"

    # Performance assertions (adjust based on expected performance)
    assert [ "$init_time" -lt 30 ]  # CA init should take less than 30s
    assert [ "$issue_time" -lt 60 ]  # 5 certs should take less than 60s
    assert [ "$validate_time" -lt 10 ]  # Validation should be fast

    print_success "Performance test passed"
}
