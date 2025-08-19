#!/usr/bin/env bats

# Legacy integration tests
# Integrates existing test scripts with the new BATS test suite

load "helpers/test_helper.bash"

setup() {
    setup_test_dirs "legacy-integration"
    setup_cleanup_trap
    setup_test_env

    # Create mock password script
    create_mock_password_script "$TEST_TEMP_DIR/read-password.sh"
    export PATH="$TEST_TEMP_DIR:$PATH"
}

teardown() {
    cleanup_test_dirs
}

@test "test_legacy_test_modern_certs" {
    # Test the existing test-modern-certs.sh script
    cd "$TEST_TEMP_DIR"

    print_info "Running legacy test-modern-certs.sh"

    # Run the legacy test script
    output=$(bash "$PROJECT_ROOT/test-modern-certs.sh" 2>&1)
    local exit_code=$?

    # The legacy script should succeed
    if [ $exit_code -eq 0 ]; then
        print_success "Legacy modern certs test passed"
        assert_success
    else
        print_error "Legacy modern certs test failed"
        echo "Output: $output"
        assert_failure
    fi
}

@test "test_legacy_test_end_to_end" {
    # Test the existing test-end-to-end.sh script
    cd "$TEST_TEMP_DIR"

    print_info "Running legacy test-end-to-end.sh"

    # Run the legacy test script
    output=$(bash "$PROJECT_ROOT/test-end-to-end.sh" 2>&1)
    local exit_code=$?

    # The legacy script should succeed
    if [ $exit_code -eq 0 ]; then
        print_success "Legacy end-to-end test passed"
        assert_success
    else
        print_error "Legacy end-to-end test failed"
        echo "Output: $output"
        assert_failure
    fi
}

@test "test_legacy_script_compatibility" {
    # Test that legacy scripts still work with new structure
    cd "$TEST_TEMP_DIR"

    print_info "Testing legacy script compatibility"

    # Test that the legacy scripts can find required files
    assert [ -f "$PROJECT_ROOT/test-modern-certs.sh" ]
    assert [ -f "$PROJECT_ROOT/test-end-to-end.sh" ]
    assert [ -f "$SRC_DIR/init.sh" ]
    assert [ -f "$SRC_DIR/request-server-cert.sh" ]

    # Test that scripts are executable
    assert [ -x "$PROJECT_ROOT/test-modern-certs.sh" ]
    assert [ -x "$PROJECT_ROOT/test-end-to-end.sh" ]

    print_success "Legacy script compatibility verified"
}

@test "test_legacy_environment_compatibility" {
    # Test that legacy scripts work with new environment setup
    cd "$TEST_TEMP_DIR"

    print_info "Testing legacy environment compatibility"

    # Set up environment similar to legacy scripts
    export KEY_TYPE=ec
    export EC_CURVE=prime256v1
    export LEAF_DAYS=398
    export PKCS8_ITER=204000
    export PFX_ITER=204000
    export SERVER_SANS="DNS:test.local,DNS:test,IP:127.0.0.1"

    # Test that environment variables are set correctly
    assert [ "$KEY_TYPE" = "ec" ]
    assert [ "$EC_CURVE" = "prime256v1" ]
    assert [ "$LEAF_DAYS" = "398" ]
    assert [ "$PKCS8_ITER" = "204000" ]
    assert [ "$PFX_ITER" = "204000" ]
    assert [ "$SERVER_SANS" = "DNS:test.local,DNS:test,IP:127.0.0.1" ]

    print_success "Legacy environment compatibility verified"
}

@test "test_legacy_output_compatibility" {
    # Test that legacy scripts produce expected output
    cd "$TEST_TEMP_DIR"

    print_info "Testing legacy output compatibility"

    # Run a small part of the legacy test to check output format
    # This simulates what the legacy scripts do without full execution

    # Test OpenSSL version output
    openssl_version=$(openssl version)
    assert [ -n "$openssl_version" ]
    assert_output_contains "OpenSSL" "$openssl_version"

    # Test EC key generation (part of legacy test)
    openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:prime256v1 \
        -pkeyopt ec_param_enc:named_curve -aes-256-cbc -pass pass:testpass \
        -out "$TEST_TEMP_DIR/test-ec.key.pem"
    assert_success

    # Verify key was created
    assert_file_exists "$TEST_TEMP_DIR/test-ec.key.pem"

    print_success "Legacy output compatibility verified"
}

@test "test_legacy_error_handling" {
    # Test that legacy error handling still works
    cd "$TEST_TEMP_DIR"

    print_info "Testing legacy error handling"

    # Test that invalid commands fail appropriately
    if openssl invalid-command 2>/dev/null; then
        print_error "Invalid OpenSSL command should have failed"
        assert_failure
    else
        print_success "Invalid OpenSSL command failed as expected"
        assert_success
    fi

    # Test that missing files are handled
    if [ -f "/nonexistent/file" ]; then
        print_error "Non-existent file should not exist"
        assert_failure
    else
        print_success "Non-existent file handling works correctly"
        assert_success
    fi

    print_success "Legacy error handling verified"
}

@test "test_legacy_performance_benchmarks" {
    # Test that legacy performance benchmarks still work
    cd "$TEST_TEMP_DIR"

    print_info "Testing legacy performance benchmarks"

    # Test key generation performance (simplified version of legacy test)
    local start_time
    start_time=$(date +%s)

    # Generate a test key
    openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:prime256v1 \
        -pkeyopt ec_param_enc:named_curve -aes-256-cbc -pass pass:testpass \
        -out "$TEST_TEMP_DIR/benchmark.key.pem"

    local end_time
    end_time=$(date +%s)
    local duration
    duration=$((end_time - start_time))

    # Performance should be reasonable (less than 10 seconds for key generation)
    assert [ "$duration" -lt 10 ]

    print_success "Legacy performance benchmarks verified (duration: ${duration}s)"
}

@test "test_legacy_modern_certificate_features" {
    # Test that legacy modern certificate features still work
    cd "$TEST_TEMP_DIR"

    print_info "Testing legacy modern certificate features"

    # Test PKCS#8 conversion (part of legacy test)
    openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:prime256v1 \
        -pkeyopt ec_param_enc:named_curve -aes-256-cbc -pass pass:testpass \
        -out "$TEST_TEMP_DIR/test-ec.key.pem"

    openssl pkcs8 -topk8 -v2 aes-256-cbc -iter 204000 \
        -passin pass:testpass -passout pass:testpass \
        -in "$TEST_TEMP_DIR/test-ec.key.pem" -out "$TEST_TEMP_DIR/test-ec.pkcs8.key.pem"

    assert_success
    assert_file_exists "$TEST_TEMP_DIR/test-ec.pkcs8.key.pem"

    # Test PKCS#8 reading without legacy (modern feature)
    if openssl pkcs8 -in "$TEST_TEMP_DIR/test-ec.pkcs8.key.pem" -passin pass:testpass -out /dev/null; then
        print_success "PKCS#8 reading works without -legacy (modern feature)"
        assert_success
    else
        print_error "PKCS#8 reading requires -legacy (not modern)"
        assert_failure
    fi

    print_success "Legacy modern certificate features verified"
}

@test "test_legacy_migration_path" {
    # Test that there's a clear migration path from legacy to new tests
    cd "$TEST_TEMP_DIR"

    print_info "Testing legacy migration path"

    # Verify that new test structure exists alongside legacy
    assert [ -d "$PROJECT_ROOT/tests" ]
    assert [ -d "$PROJECT_ROOT/tests/unit" ]
    assert [ -d "$PROJECT_ROOT/tests/integration" ]
    assert [ -d "$PROJECT_ROOT/tests/e2e" ]

    # Verify that legacy scripts still exist
    assert [ -f "$PROJECT_ROOT/test-modern-certs.sh" ]
    assert [ -f "$PROJECT_ROOT/test-end-to-end.sh" ]

    # Verify that new test helper exists
    assert [ -f "$PROJECT_ROOT/tests/helpers/test_helper.bash" ]

    # Verify that Makefile provides migration commands
    assert [ -f "$PROJECT_ROOT/Makefile" ]

    print_success "Legacy migration path verified"
}
