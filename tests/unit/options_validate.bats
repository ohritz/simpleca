#!/usr/bin/env bats

# Unit tests for validate.sh option parsing
# Tests short flags, long flags, error handling, and help functionality

load "../helpers/test_helper.bash"

setup() {
    setup_test_dirs "options-validate"
    setup_cleanup_trap
}

teardown() {
    cleanup_test_dirs
}

@test "test_validate_help_short_flag" {
    output=$(run_script "$SRC_DIR/validate.sh" -h)
    assert_success
    assert_output_contains "simpleca validate - Validate certificates and chains" "$output"
    assert_output_contains "Usage:" "$output"
    assert_output_contains "-c, --cert" "$output"
    assert_output_contains "-k, --key" "$output"
}

@test "test_validate_help_long_flag" {
    output=$(run_script "$SRC_DIR/validate.sh" --help)
    assert_success
    assert_output_contains "simpleca validate - Validate certificates and chains" "$output"
    assert_output_contains "Usage:" "$output"
    assert_output_contains "-c, --cert" "$output"
    assert_output_contains "-k, --key" "$output"
}

@test "test_validate_cert_short_flag" {
    # Test -c flag with space
    output=$(run_script "$SRC_DIR/validate.sh" -c /tmp/cert.pem 2>&1 || true)
    # Should fail because cert file doesn't exist, but should not be a parsing error
    assert_output_contains "validate" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for -c" "$output"
}

@test "test_validate_cert_long_flag_space" {
    # Test --cert flag with space
    output=$(run_script "$SRC_DIR/validate.sh" --cert /tmp/cert.pem 2>&1 || true)
    # Should fail because cert file doesn't exist, but should not be a parsing error
    assert_output_contains "validate" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for --cert" "$output"
}

@test "test_validate_cert_long_flag_equals" {
    # Test --cert=value flag
    output=$(run_script "$SRC_DIR/validate.sh" --cert=/tmp/cert.pem 2>&1 || true)
    # Should fail because cert file doesn't exist, but should not be a parsing error
    assert_output_contains "validate" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_validate_key_short_flag" {
    # Test -k flag with space
    output=$(run_script "$SRC_DIR/validate.sh" -c /tmp/cert.pem -k /tmp/key.pem 2>&1 || true)
    # Should fail because files don't exist, but should not be a parsing error
    assert_output_contains "validate" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for -k" "$output"
}

@test "test_validate_key_long_flag_space" {
    # Test --key flag with space
    output=$(run_script "$SRC_DIR/validate.sh" -c /tmp/cert.pem --key /tmp/key.pem 2>&1 || true)
    # Should fail because files don't exist, but should not be a parsing error
    assert_output_contains "validate" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for --key" "$output"
}

@test "test_validate_key_long_flag_equals" {
    # Test --key=value flag
    output=$(run_script "$SRC_DIR/validate.sh" -c /tmp/cert.pem --key=/tmp/key.pem 2>&1 || true)
    # Should fail because files don't exist, but should not be a parsing error
    assert_output_contains "validate" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_validate_pass_file_short_flag" {
    # Test -p flag with space
    output=$(run_script "$SRC_DIR/validate.sh" -c /tmp/cert.pem -k /tmp/key.pem -p /tmp/pass.txt 2>&1 || true)
    # Should fail because files don't exist, but should not be a parsing error
    assert_output_contains "validate" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for -p" "$output"
}

@test "test_validate_pass_file_long_flag_space" {
    # Test --pass-file flag with space
    output=$(run_script "$SRC_DIR/validate.sh" -c /tmp/cert.pem -k /tmp/key.pem --pass-file /tmp/pass.txt 2>&1 || true)
    # Should fail because files don't exist, but should not be a parsing error
    assert_output_contains "validate" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for --pass-file" "$output"
}

@test "test_validate_pass_file_long_flag_equals" {
    # Test --pass-file=value flag
    output=$(run_script "$SRC_DIR/validate.sh" -c /tmp/cert.pem -k /tmp/key.pem --pass-file=/tmp/pass.txt 2>&1 || true)
    # Should fail because files don't exist, but should not be a parsing error
    assert_output_contains "validate" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_validate_multiple_options" {
    # Test multiple options together
    output=$(run_script "$SRC_DIR/validate.sh" --cert=/tmp/cert.pem --key=/tmp/key.pem --pass-file=/tmp/pass.txt 2>&1 || true)
    # Should fail because files don't exist, but should not be a parsing error
    assert_output_contains "validate" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_validate_mixed_short_long_options" {
    # Test mixing short and long options
    output=$(run_script "$SRC_DIR/validate.sh" -c /tmp/cert.pem --key=/tmp/key.pem -p /tmp/pass.txt 2>&1 || true)
    # Should fail because files don't exist, but should not be a parsing error
    assert_output_contains "validate" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_validate_unknown_option" {
    # Test unknown option
    output=$(run_script "$SRC_DIR/validate.sh" --unknown-option 2>&1 || true)
    assert_output_contains "Unknown option: --unknown-option" "$output"
}

@test "test_validate_missing_argument_short" {
    # Test missing argument for short option
    output=$(run_script "$SRC_DIR/validate.sh" -c 2>&1 || true)
    assert_output_contains "Missing argument for --cert" "$output"
}

@test "test_validate_missing_argument_long" {
    # Test missing argument for long option
    output=$(run_script "$SRC_DIR/validate.sh" --cert 2>&1 || true)
    assert_output_contains "Missing argument for --cert" "$output"
}

@test "test_validate_double_dash_separator" {
    # Test -- separator
    output=$(run_script "$SRC_DIR/validate.sh" -c /tmp/cert.pem -- --some-argument 2>&1 || true)
    # Should fail because cert file doesn't exist, but should not be a parsing error
    assert_output_contains "validate" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option: --some-argument" "$output"
}

@test "test_validate_help_with_other_options" {
    # Test that help takes precedence
    output=$(run_script "$SRC_DIR/validate.sh" -c /tmp/cert.pem --key=/tmp/key.pem --help)
    assert_success
    assert_output_contains "simpleca validate - Validate certificates and chains" "$output"
    assert_output_contains "Usage:" "$output"
}

@test "test_validate_help_with_equals" {
    # Test help with equals (should be treated as unknown option)
    output=$(run_script "$SRC_DIR/validate.sh" --help=something 2>&1 || true)
    assert_output_contains "Unknown option: --help=something" "$output"
}

@test "test_validate_no_options_default_chain" {
    # Test no options (should use default certificate chain)
    output=$(run_script "$SRC_DIR/validate.sh" 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "validate" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}
