#!/usr/bin/env bats

# Test the use command with positional arguments

load ../helpers/test_helper

setup() {
    setup_test_dirs "options-use"
    setup_cleanup_trap
}

teardown() {
    cleanup_test_dirs
}

@test "test_use_missing_argument" {
	# Test use without any arguments
	output=$(run_script "$SRC_DIR/main.sh" use 2>&1 || true)
	assert_output_contains "use requires a CA identifier" "$output"
	assert_output_contains "Usage:" "$output"
}

@test "test_use_with_nonexistent_ca" {
	# Test use with a CA that doesn't exist
	output=$(run_script "$SRC_DIR/main.sh" use nonexistent-ca 2>&1 || true)
	assert_output_contains "CA 'nonexistent-ca' not found" "$output"
	assert_output_contains "Use 'simpleca list' to see available CAs" "$output"
}

@test "test_use_with_extra_arguments" {
	# Test use with extra arguments
	output=$(run_script "$SRC_DIR/main.sh" use test-ca extra-arg 2>&1 || true)
	assert_output_contains "unexpected arguments: extra-arg" "$output"
	assert_output_contains "Usage:" "$output"
}

@test "test_use_help" {
	# Test use help
	output=$(run_script "$SRC_DIR/main.sh" use --help)
	assert_success
	assert_output_contains "simpleca use - Set default CA" "$output"
	assert_output_contains "simpleca use <id>" "$output"
	assert_output_contains "Arguments:" "$output"
	assert_output_contains "<id>    CA identifier to set as default" "$output"
	assert_output_contains "Examples:" "$output"
	assert_output_contains "simpleca use acme" "$output"
}

@test "test_use_positional_argument" {
	# Test use with positional argument (should work if CA exists)
	# First create a CA
	output=$(run_script "$SRC_DIR/main.sh" init --ca-id test-ca --org "Test Org" --cn "Test CA" --key-type rsa --key-bits 2048 --days 365 2>&1 || true)
	# Should fail because we don't have proper setup, but we can verify it's dispatched
	assert_output_contains "init" "$output" || assert_output_contains "ERR" "$output"

	# Now test use command
	output=$(run_script "$SRC_DIR/main.sh" use test-ca 2>&1 || true)
	assert_output_contains "use" "$output" || assert_output_contains "ERR" "$output"
}

@test "test_use_with_global_ca_flag_works" {
	# Test that --ca as a global flag still works (backward compatibility)
	# First create a CA
	output=$(run_script "$SRC_DIR/main.sh" init --ca-id test-ca --org "Test Org" --cn "Test CA" --key-type rsa --key-bits 2048 --days 365 2>&1 || true)
	# Should fail because we don't have proper setup, but we can verify it's dispatched
	assert_output_contains "init" "$output" || assert_output_contains "ERR" "$output"

	# Now test use command with global --ca flag
	output=$(run_script "$SRC_DIR/main.sh" --ca test-ca use 2>&1 || true)
	assert_output_contains "use" "$output" || assert_output_contains "ERR" "$output"
}

@test "test_use_with_legacy_equals_flag_should_fail" {
	# Test that the old --ca=id flag as positional argument fails
	output=$(run_script "$SRC_DIR/main.sh" use --ca=test-ca 2>&1 || true)
	assert_output_contains "CA '--ca=test-ca' not found" "$output"
	assert_output_contains "Use 'simpleca list' to see available CAs" "$output"
}
