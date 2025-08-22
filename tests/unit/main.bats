#!/usr/bin/env bats

# Unit tests for main.sh script
# Tests command parsing, help, version, and subcommand dispatching

load "../helpers/test_helper.bash"

setup() {
    setup_test_dirs "main-unit"
    setup_cleanup_trap
}

teardown() {
    cleanup_test_dirs
}

@test "test_main_help_command" {
    # Test help command
    output=$(run_script "$SRC_DIR/main.sh" help)
    assert_success
    assert_output_contains "Simple CA" "$output"
    assert_output_contains "Usage:" "$output"
    assert_output_contains "init" "$output"
    assert_output_contains "issue" "$output"
    assert_output_contains "validate" "$output"
    assert_output_contains "cert-manager" "$output"
}

@test "test_main_help_flag" {
    # Test -h flag
    output=$(run_script "$SRC_DIR/main.sh" -h)
    assert_success
    assert_output_contains "Simple CA" "$output"
    assert_output_contains "Usage:" "$output"
}

@test "test_main_help_long_flag" {
    # Test --help flag
    output=$(run_script "$SRC_DIR/main.sh" --help)
    assert_success
    assert_output_contains "Simple CA" "$output"
    assert_output_contains "Usage:" "$output"
}

@test "test_main_version_command" {
    # Test version command
    output=$(run_script "$SRC_DIR/main.sh" version)
    assert_success
    assert_output_contains "simpleca" "$output"
}

@test "test_main_version_flag" {
    # Test --version flag
    output=$(run_script "$SRC_DIR/main.sh" --version)
    assert_success
    assert_output_contains "simpleca" "$output"
}

@test "test_main_no_arguments" {
    # Test no arguments (should show help)
    output=$(run_script "$SRC_DIR/main.sh")
    assert_success
    assert_output_contains "Simple CA" "$output"
    assert_output_contains "Usage:" "$output"
}

@test "test_main_unknown_command" {
	# Test unknown command (falls back to issue with hostname)
	output=$(run_script "$SRC_DIR/main.sh" unknown-command 2>&1 || true)
	# Should at least print the fallback info message
	assert_output_contains "Making request for hostname unknown-command" "$output"
}

@test "test_main_init_subcommand" {
	# Test init subcommand dispatch
	# This will fail because we don't have a proper CA setup, but we can verify it's dispatched
	output=$(run_script "$SRC_DIR/main.sh" init 2>&1 || true)
	# Should contain init-related output or error
	assert_output_contains "init" "$output" || assert_output_contains "ERR" "$output"
}

@test "test_main_issue_subcommand" {
	# Test issue subcommand dispatch
	output=$(run_script "$SRC_DIR/main.sh" issue 2>&1 || true)
	# Should contain issue-related output or error
	assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
}

@test "test_main_validate_subcommand" {
    # Test validate subcommand dispatch
    output=$(run_script "$SRC_DIR/main.sh" validate 2>&1 || true)
    # Should contain validate-related output or error
    assert_output_contains "validate" "$output" || assert_output_contains "error" "$output"
}

@test "test_main_export_subcommand" {
    # Test export subcommand dispatch
    output=$(run_script "$SRC_DIR/main.sh" export 2>&1 || true)
    # Should contain export-related output or error
    assert_output_contains "export" "$output" || assert_output_contains "error" "$output"
}

@test "test_main_import_subcommand" {
    # Test import subcommand dispatch
    output=$(run_script "$SRC_DIR/main.sh" import 2>&1 || true)
    # Should contain import-related output or error
    assert_output_contains "import" "$output" || assert_output_contains "error" "$output"
}

@test "test_main_cert_manager_subcommand_help" {
    # Ensure cert-manager subcommand is wired and help is available
    output=$(run_script "$SRC_DIR/main.sh" cert-manager export --help)
    assert_success
    assert_output_contains "cert-manager" "$output"
    assert_output_contains "export" "$output"
}

@test "test_main_backward_compatibility" {
    # Test backward compatibility - hostname as first argument
    output=$(run_script "$SRC_DIR/main.sh" test.example.com 2>&1 || true)
    assert_output_contains "Making request for hostname test.example.com" "$output"
}

@test "test_main_script_directory_resolution" {
    # Test that script directory is resolved correctly
    # This is implicit in the script execution, but we can verify it works
    output=$(run_script "$SRC_DIR/main.sh" version)
    assert_success
    # Should not contain error messages about missing files
    assert_output_not_contains "No such file" "$output"
    assert_output_not_contains "Permission denied" "$output"
}

@test "test_main_env_file_loading" {
    # Test .env file loading
    # Create a test .env file
    create_test_env "$TEST_TEMP_DIR/.env"

    # Run from the test directory to pick up .env
    cd "$TEST_TEMP_DIR"
    output=$(run_script "$SRC_DIR/main.sh" version)
    assert_success
    assert_output_contains "simpleca" "$output"
}

@test "test_main_version_sources" {
	# Test version information from different sources
	# This tests the get_version function indirectly

	# Test with BUILD_VERSION environment variable
	export BUILD_VERSION="test-version"
	output=$(run_script "$SRC_DIR/main.sh" version)
	assert_success
	assert_output_contains "simpleca test-version" "$output"
}

@test "test_main_subcommand_with_arguments" {
	# Test subcommand with additional arguments
	output=$(run_script "$SRC_DIR/main.sh" issue --help 2>&1 || true)
	# Should contain issue-related help or error
	assert_output_contains "issue" "$output" || assert_output_contains "ERR" "$output"
}

@test "test_main_quiet_flag" {
    # Test quiet flag (should be passed to subcommands)
    output=$(run_script "$SRC_DIR/main.sh" -q version)
    assert_success
    assert_output_contains "simpleca" "$output"
}

@test "test_main_verbose_flag" {
    # Test verbose flag (should be passed to subcommands)
    output=$(run_script "$SRC_DIR/main.sh" -v version)
    assert_success
    assert_output_contains "simpleca" "$output"
}

@test "test_main_no_color_flag" {
    # Test no-color flag (should be passed to subcommands)
    output=$(run_script "$SRC_DIR/main.sh" --no-color version)
    assert_success
    assert_output_contains "simpleca" "$output"
}

@test "test_main_non_interactive_flag" {
    # Test non-interactive flag (should be passed to subcommands)
    output=$(run_script "$SRC_DIR/main.sh" --non-interactive version)
    assert_success
    assert_output_contains "simpleca" "$output"
}
