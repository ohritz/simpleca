#!/usr/bin/env bats

# Unit tests for eject-ca.sh option parsing
# Tests short flags, long flags, error handling, and help functionality

load "../helpers/test_helper.bash"

setup() {
    setup_test_dirs "options-eject"
    setup_test_env
    setup_cleanup_trap
}

teardown() {
    cleanup_test_dirs
}

@test "test_eject_help_short_flag" {
    output=$(run_script "$SRC_DIR/eject-ca.sh" -h)
    assert_success
    assert_output_contains "simpleca eject - Archive current CA state" "$output"
    assert_output_contains "Usage:" "$output"
    assert_output_contains "-o, --output" "$output"
    assert_output_contains "-f, --force" "$output"
}

@test "test_eject_help_long_flag" {
    output=$(run_script "$SRC_DIR/eject-ca.sh" --help)
    assert_success
    assert_output_contains "simpleca eject - Archive current CA state" "$output"
    assert_output_contains "Usage:" "$output"
    assert_output_contains "-o, --output" "$output"
    assert_output_contains "-f, --force" "$output"
}

@test "test_eject_output_short_flag" {
    # Test -o flag with space
    output=$(run_script "$SRC_DIR/eject-ca.sh" -o backup.tar.gz 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "eject" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for -o" "$output"
}

@test "test_eject_output_long_flag_space" {
    # Test --output flag with space
    output=$(run_script "$SRC_DIR/eject-ca.sh" --output backup.tar.gz 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "eject" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for --output" "$output"
}

@test "test_eject_output_long_flag_equals" {
    # Test --output=value flag
    output=$(run_script "$SRC_DIR/eject-ca.sh" --output=backup.tar.gz 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "eject" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_eject_force_short_flag" {
    # Test -f flag
    output=$(run_script "$SRC_DIR/eject-ca.sh" -f 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "eject" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_eject_force_long_flag" {
    # Test --force flag
    output=$(run_script "$SRC_DIR/eject-ca.sh" --force 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "eject" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_eject_multiple_options" {
    # Test multiple options together
    output=$(run_script "$SRC_DIR/eject-ca.sh" --output=backup.tar.gz --force 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "eject" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_eject_mixed_short_long_options" {
    # Test mixing short and long options
    output=$(run_script "$SRC_DIR/eject-ca.sh" -o backup.tar.gz --force 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "eject" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_eject_unknown_option" {
    # Test unknown option
    output=$(run_script "$SRC_DIR/eject-ca.sh" --unknown-option 2>&1 || true)
    assert_output_contains "Unknown option: --unknown-option" "$output"
}

@test "test_eject_missing_argument_short" {
    # Test missing argument for short option
    output=$(run_script "$SRC_DIR/eject-ca.sh" -o 2>&1 || true)
    assert_output_contains "Missing argument for --output" "$output"
}

@test "test_eject_missing_argument_long" {
    # Test missing argument for long option
    output=$(run_script "$SRC_DIR/eject-ca.sh" --output 2>&1 || true)
    assert_output_contains "Missing argument for --output" "$output"
}

@test "test_eject_double_dash_separator" {
    # Test -- separator
    output=$(run_script "$SRC_DIR/eject-ca.sh" --force -- --some-argument 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "eject" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option: --some-argument" "$output"
}

@test "test_eject_help_with_other_options" {
    # Test that help takes precedence
    output=$(run_script "$SRC_DIR/eject-ca.sh" --output=backup.tar.gz --force --help)
    assert_success
    assert_output_contains "simpleca eject - Archive current CA state" "$output"
    assert_output_contains "Usage:" "$output"
}

@test "test_eject_help_with_equals" {
    # Test help with equals (should be treated as unknown option)
    output=$(run_script "$SRC_DIR/eject-ca.sh" --help=something 2>&1 || true)
    assert_output_contains "Unknown option: --help=something" "$output"
}

@test "test_eject_no_options_default_filename" {
    # Test no options (should use default filename)
    output=$(run_script "$SRC_DIR/eject-ca.sh" 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "eject" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}
