#!/usr/bin/env bats

# Unit tests for request-server-cert.sh option parsing
# Tests short flags, long flags, error handling, help functionality, and positional arguments

load "../helpers/test_helper.bash"

setup() {
    setup_test_dirs "options-issue"
    setup_cleanup_trap
}

teardown() {
    cleanup_test_dirs
}

@test "test_issue_help_short_flag" {
    output=$(run_script "$SRC_DIR/request-server-cert.sh" -h)
    assert_success
    assert_output_contains "simpleca issue - Issue a server certificate" "$output"
    assert_output_contains "Usage:" "$output"
    assert_output_contains "-c, --cn" "$output"
    assert_output_contains "-s, --sans" "$output"
}

@test "test_issue_help_long_flag" {
    output=$(run_script "$SRC_DIR/request-server-cert.sh" --help)
    assert_success
    assert_output_contains "simpleca issue - Issue a server certificate" "$output"
    assert_output_contains "Usage:" "$output"
    assert_output_contains "-c, --cn" "$output"
    assert_output_contains "-s, --sans" "$output"
}

@test "test_issue_cn_short_flag" {
    # Test -c flag with space
    output=$(run_script "$SRC_DIR/request-server-cert.sh" -c test.local 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for -c" "$output"
}

@test "test_issue_cn_long_flag_space" {
    # Test --cn flag with space
    output=$(run_script "$SRC_DIR/request-server-cert.sh" --cn test.local 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for --cn" "$output"
}

@test "test_issue_cn_long_flag_equals" {
    # Test --cn=value flag
    output=$(run_script "$SRC_DIR/request-server-cert.sh" --cn=test.local 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_issue_sans_short_flag" {
    # Test -s flag with space
    output=$(run_script "$SRC_DIR/request-server-cert.sh" -c test.local -s "DNS:test.local,DNS:www.test.local" 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for -s" "$output"
}

@test "test_issue_sans_long_flag_space" {
    # Test --sans flag with space
    output=$(run_script "$SRC_DIR/request-server-cert.sh" -c test.local --sans "DNS:test.local,DNS:www.test.local" 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for --sans" "$output"
}

@test "test_issue_sans_long_flag_equals" {
    # Test --sans=value flag
    output=$(run_script "$SRC_DIR/request-server-cert.sh" -c test.local --sans="DNS:test.local,DNS:www.test.local" 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_issue_key_type_short_flag" {
    # Test -k flag with space
    output=$(run_script "$SRC_DIR/request-server-cert.sh" -c test.local -k rsa 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for -k" "$output"
}

@test "test_issue_key_type_long_flag_space" {
    # Test --key-type flag with space
    output=$(run_script "$SRC_DIR/request-server-cert.sh" -c test.local --key-type rsa 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for --key-type" "$output"
}

@test "test_issue_key_type_long_flag_equals" {
    # Test --key-type=value flag
    output=$(run_script "$SRC_DIR/request-server-cert.sh" -c test.local --key-type=rsa 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_issue_rsa_bits_short_flag" {
    # Test -r flag with space
    output=$(run_script "$SRC_DIR/request-server-cert.sh" -c test.local -r 4096 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for -r" "$output"
}

@test "test_issue_rsa_bits_long_flag_space" {
    # Test --rsa-bits flag with space
    output=$(run_script "$SRC_DIR/request-server-cert.sh" -c test.local --rsa-bits 4096 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for --rsa-bits" "$output"
}

@test "test_issue_rsa_bits_long_flag_equals" {
    # Test --rsa-bits=value flag
    output=$(run_script "$SRC_DIR/request-server-cert.sh" -c test.local --rsa-bits=4096 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_issue_ec_curve_short_flag" {
    # Test -e flag with space
    output=$(run_script "$SRC_DIR/request-server-cert.sh" -c test.local -e secp384r1 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for -e" "$output"
}

@test "test_issue_ec_curve_long_flag_space" {
    # Test --ec-curve flag with space
    output=$(run_script "$SRC_DIR/request-server-cert.sh" -c test.local --ec-curve secp384r1 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for --ec-curve" "$output"
}

@test "test_issue_ec_curve_long_flag_equals" {
    # Test --ec-curve=value flag
    output=$(run_script "$SRC_DIR/request-server-cert.sh" -c test.local --ec-curve=secp384r1 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_issue_pass_file_short_flag" {
    # Test -p flag with space
    output=$(run_script "$SRC_DIR/request-server-cert.sh" -c test.local -p /tmp/pass.txt 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for -p" "$output"
}

@test "test_issue_pass_file_long_flag_space" {
    # Test --pass-file flag with space
    output=$(run_script "$SRC_DIR/request-server-cert.sh" -c test.local --pass-file /tmp/pass.txt 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for --pass-file" "$output"
}

@test "test_issue_pass_file_long_flag_equals" {
    # Test --pass-file=value flag
    output=$(run_script "$SRC_DIR/request-server-cert.sh" -c test.local --pass-file=/tmp/pass.txt 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_issue_days_short_flag" {
    # Test -d flag with space
    output=$(run_script "$SRC_DIR/request-server-cert.sh" -c test.local -d 365 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for -d" "$output"
}

@test "test_issue_days_long_flag_space" {
    # Test --days flag with space
    output=$(run_script "$SRC_DIR/request-server-cert.sh" -c test.local --days 365 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for --days" "$output"
}

@test "test_issue_days_long_flag_equals" {
    # Test --days=value flag
    output=$(run_script "$SRC_DIR/request-server-cert.sh" -c test.local --days=365 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_issue_force_short_flag" {
    # Test -f flag
    output=$(run_script "$SRC_DIR/request-server-cert.sh" -c test.local -f 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_issue_force_long_flag" {
    # Test --force flag
    output=$(run_script "$SRC_DIR/request-server-cert.sh" -c test.local --force 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_issue_positional_argument" {
    # Test positional argument for SERVER_CN
    output=$(run_script "$SRC_DIR/request-server-cert.sh" test.local 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_issue_positional_with_options" {
    # Test positional argument with options
    output=$(run_script "$SRC_DIR/request-server-cert.sh" test.local --key-type=rsa --rsa-bits=4096 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_issue_multiple_options" {
    # Test multiple options together
    output=$(run_script "$SRC_DIR/request-server-cert.sh" --cn=test.local --sans="DNS:test.local" --key-type=rsa --rsa-bits=4096 --days=365 --force 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_issue_mixed_short_long_options" {
    # Test mixing short and long options
    output=$(run_script "$SRC_DIR/request-server-cert.sh" -c test.local --sans="DNS:test.local" -k rsa --rsa-bits=4096 -d 365 --force 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_issue_unknown_option" {
    # Test unknown option
    output=$(run_script "$SRC_DIR/request-server-cert.sh" --unknown-option 2>&1 || true)
    assert_output_contains "Unknown option: --unknown-option" "$output"
}

@test "test_issue_missing_argument_short" {
    # Test missing argument for short option
    output=$(run_script "$SRC_DIR/request-server-cert.sh" -c 2>&1 || true)
    assert_output_contains "Missing argument for --cn" "$output"
}

@test "test_issue_missing_argument_long" {
    # Test missing argument for long option
    output=$(run_script "$SRC_DIR/request-server-cert.sh" --cn 2>&1 || true)
    assert_output_contains "Missing argument for --cn" "$output"
}

@test "test_issue_missing_required_cn" {
    # Test missing required CN
    output=$(run_script "$SRC_DIR/request-server-cert.sh" --key-type=rsa 2>&1 || true)
    assert_output_contains "Missing required: --cn <hostname>" "$output"
}

@test "test_issue_double_dash_separator" {
    # Test -- separator
    output=$(run_script "$SRC_DIR/request-server-cert.sh" -c test.local -- --some-argument 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option: --some-argument" "$output"
}

@test "test_issue_help_with_other_options" {
    # Test that help takes precedence
    output=$(run_script "$SRC_DIR/request-server-cert.sh" --cn=test.local --key-type=rsa --help)
    assert_success
    assert_output_contains "simpleca issue - Issue a server certificate" "$output"
    assert_output_contains "Usage:" "$output"
}

@test "test_issue_help_with_equals" {
    # Test help with equals (should be treated as unknown option)
    output=$(run_script "$SRC_DIR/request-server-cert.sh" --help=something 2>&1 || true)
    assert_output_contains "Unknown option: --help=something" "$output"
}
