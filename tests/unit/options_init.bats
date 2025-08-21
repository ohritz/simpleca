#!/usr/bin/env bats

# Unit tests for init.sh option parsing
# Tests short flags, long flags, error handling, and help functionality

load "../helpers/test_helper.bash"

setup() {
    setup_test_dirs "options-init"
    setup_cleanup_trap
}

teardown() {
    cleanup_test_dirs
}

@test "test_init_help_short_flag" {
    output=$(run_script "$SRC_DIR/init.sh" -h)
    assert_success
    assert_output_contains "simpleca init - Initialize root and intermediate CA" "$output"
    assert_output_contains "Usage:" "$output"
    assert_output_contains "-f, --force" "$output"
    assert_output_contains "-k, --key-type" "$output"
}

@test "test_init_help_long_flag" {
    output=$(run_script "$SRC_DIR/init.sh" --help)
    assert_success
    assert_output_contains "simpleca init - Initialize root and intermediate CA" "$output"
    assert_output_contains "Usage:" "$output"
    assert_output_contains "-f, --force" "$output"
    assert_output_contains "-k, --key-type" "$output"
}

@test "test_init_force_short_flag" {
    # Test -f flag
    output=$(run_script "$SRC_DIR/init.sh" -f 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "init" "$output" || assert_output_contains "ERR" "$output"
    # Should not contain parsing error messages
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_init_force_long_flag" {
    # Test --force flag
    output=$(run_script "$SRC_DIR/init.sh" --force 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "init" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_init_key_type_short_flag" {
    # Test -k flag with space
    output=$(run_script "$SRC_DIR/init.sh" -k rsa 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "init" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for -k" "$output"
}

@test "test_init_key_type_long_flag_space" {
    # Test --key-type flag with space
    output=$(run_script "$SRC_DIR/init.sh" --key-type rsa 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "init" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for --key-type" "$output"
}

@test "test_init_key_type_long_flag_equals" {
    # Test --key-type=value flag
    output=$(run_script "$SRC_DIR/init.sh" --key-type=rsa 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "init" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_init_rsa_bits_short_flag" {
    # Test -r flag with space
    output=$(run_script "$SRC_DIR/init.sh" -r 4096 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "init" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for -r" "$output"
}

@test "test_init_rsa_bits_long_flag_space" {
    # Test --rsa-bits flag with space
    output=$(run_script "$SRC_DIR/init.sh" --rsa-bits 4096 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "init" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for --rsa-bits" "$output"
}

@test "test_init_rsa_bits_long_flag_equals" {
    # Test --rsa-bits=value flag
    output=$(run_script "$SRC_DIR/init.sh" --rsa-bits=4096 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "init" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_init_ec_curve_short_flag" {
    # Test -e flag with space
    output=$(run_script "$SRC_DIR/init.sh" -e secp384r1 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "init" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for -e" "$output"
}

@test "test_init_ec_curve_long_flag_space" {
    # Test --ec-curve flag with space
    output=$(run_script "$SRC_DIR/init.sh" --ec-curve secp384r1 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "init" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for --ec-curve" "$output"
}

@test "test_init_ec_curve_long_flag_equals" {
    # Test --ec-curve=value flag
    output=$(run_script "$SRC_DIR/init.sh" --ec-curve=secp384r1 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "init" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_init_pass_file_short_flag" {
    # Test -p flag with space
    output=$(run_script "$SRC_DIR/init.sh" -p /tmp/pass.txt 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "init" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for -p" "$output"
}

@test "test_init_pass_file_long_flag_space" {
    # Test --pass-file flag with space
    output=$(run_script "$SRC_DIR/init.sh" --pass-file /tmp/pass.txt 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "init" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for --pass-file" "$output"
}

@test "test_init_pass_file_long_flag_equals" {
    # Test --pass-file=value flag
    output=$(run_script "$SRC_DIR/init.sh" --pass-file=/tmp/pass.txt 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "init" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_init_multiple_options" {
    # Test multiple options together
    output=$(run_script "$SRC_DIR/init.sh" --force --key-type=rsa --rsa-bits=4096 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "init" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_init_mixed_short_long_options" {
    # Test mixing short and long options
    output=$(run_script "$SRC_DIR/init.sh" -f --key-type=rsa -r 4096 --ec-curve=secp384r1 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "init" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_init_unknown_option" {
    # Test unknown option
    output=$(run_script "$SRC_DIR/init.sh" --unknown-option 2>&1 || true)
    assert_output_contains "Unknown option: --unknown-option" "$output"
}

@test "test_init_missing_argument_short" {
    # Test missing argument for short option
    output=$(run_script "$SRC_DIR/init.sh" -k 2>&1 || true)
    assert_output_contains "Missing argument for --key-type" "$output"
}

@test "test_init_missing_argument_long" {
    # Test missing argument for long option
    output=$(run_script "$SRC_DIR/init.sh" --key-type 2>&1 || true)
    assert_output_contains "Missing argument for --key-type" "$output"
}

@test "test_init_double_dash_separator" {
    # Test -- separator
    output=$(run_script "$SRC_DIR/init.sh" --force -- --some-argument 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "init" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option: --some-argument" "$output"
}

@test "test_init_help_with_other_options" {
    # Test that help takes precedence
    output=$(run_script "$SRC_DIR/init.sh" --force --key-type=rsa --help)
    assert_success
    assert_output_contains "simpleca init - Initialize root and intermediate CA" "$output"
    assert_output_contains "Usage:" "$output"
}

@test "test_init_help_with_equals" {
    # Test help with equals (should be treated as unknown option)
    output=$(run_script "$SRC_DIR/init.sh" --help=something 2>&1 || true)
    assert_output_contains "Unknown option: --help=something" "$output"
}
