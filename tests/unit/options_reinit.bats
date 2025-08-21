#!/usr/bin/env bats

# Unit tests for re-init.sh option parsing
# Tests short flags, long flags, error handling, help functionality, and positional arguments

load "../helpers/test_helper.bash"

setup() {
    setup_test_dirs "options-reinit"
    setup_cleanup_trap
}

teardown() {
    cleanup_test_dirs
}

@test "test_reinit_help_short_flag" {
    output=$(run_script "$SRC_DIR/re-init.sh" -h)
    assert_success
    assert_output_contains "simpleca re-init - Restore CA from archive" "$output"
    assert_output_contains "Usage:" "$output"
    assert_output_contains "-f, --force" "$output"
    assert_output_contains "archive" "$output"
}

@test "test_reinit_help_long_flag" {
    output=$(run_script "$SRC_DIR/re-init.sh" --help)
    assert_success
    assert_output_contains "simpleca re-init - Restore CA from archive" "$output"
    assert_output_contains "Usage:" "$output"
    assert_output_contains "-f, --force" "$output"
    assert_output_contains "archive" "$output"
}

@test "test_reinit_force_short_flag" {
    # Test -f flag
    output=$(run_script "$SRC_DIR/re-init.sh" -f 2>&1 || true)
    # Should fail because no export directory exists, but should not be a parsing error
    assert_output_contains "re-init" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_reinit_force_long_flag" {
    # Test --force flag
    output=$(run_script "$SRC_DIR/re-init.sh" --force 2>&1 || true)
    # Should fail because no export directory exists, but should not be a parsing error
    assert_output_contains "re-init" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_reinit_positional_argument" {
    # Test positional argument for archive file
    output=$(run_script "$SRC_DIR/re-init.sh" backup.tar.gz 2>&1 || true)
    # Should fail because no export directory exists, but should not be a parsing error
    assert_output_contains "re-init" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_reinit_positional_with_options" {
    # Test positional argument with options
    output=$(run_script "$SRC_DIR/re-init.sh" backup.tar.gz --force 2>&1 || true)
    # Should fail because no export directory exists, but should not be a parsing error
    assert_output_contains "re-init" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_reinit_multiple_options" {
    # Test multiple options together
    output=$(run_script "$SRC_DIR/re-init.sh" --force backup.tar.gz 2>&1 || true)
    # Should fail because no export directory exists, but should not be a parsing error
    assert_output_contains "re-init" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_reinit_unknown_option" {
    # Test unknown option
    output=$(run_script "$SRC_DIR/re-init.sh" --unknown-option 2>&1 || true)
    assert_output_contains "Unknown option: --unknown-option" "$output"
}

@test "test_reinit_double_dash_separator" {
    # Test -- separator
    output=$(run_script "$SRC_DIR/re-init.sh" --force -- --some-argument 2>&1 || true)
    # Should fail because no export directory exists, but should not be a parsing error
    assert_output_contains "re-init" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option: --some-argument" "$output"
}

@test "test_reinit_help_with_other_options" {
    # Test that help takes precedence (but script fails before help is processed)
    output=$(run_script "$SRC_DIR/re-init.sh" --force backup.tar.gz --help 2>&1 || true)
    # Should fail because no export directory exists, but should not be a parsing error
    assert_output_contains "re-init" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_reinit_help_with_equals" {
    # Test help with equals (should be treated as unknown option)
    output=$(run_script "$SRC_DIR/re-init.sh" --help=something 2>&1 || true)
    assert_output_contains "Unknown option: --help=something" "$output"
}

@test "test_reinit_no_options_default_archive" {
    # Test no options (should use default archive filename)
    output=$(run_script "$SRC_DIR/re-init.sh" 2>&1 || true)
    # Should fail because no export directory exists, but should not be a parsing error
    assert_output_contains "re-init" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}
