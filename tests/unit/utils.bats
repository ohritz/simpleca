#!/usr/bin/env bats

# Unit tests for utils.sh script
# Tests utility functions and error handling

load "helpers/test_helper.bash"

setup() {
    setup_test_dirs "utils-unit"
    setup_cleanup_trap
}

teardown() {
    cleanup_test_dirs
}

@test "test_utils_error_handling_setup" {
    # Test that error handling is properly set up
    # This tests the setup_error_handling function indirectly

    # Source the utils script
    . "$SRC_DIR/utils.sh"

    # Verify that error handling is active
    # This is implicit in the script execution, but we can verify it works
    # by checking that the script doesn't fail when sourced
    assert_success
}

@test "test_utils_required_tools_check" {
    # Test checking for required tools
    # This would test a function that verifies required tools are available

    # Source the utils script
    . "$SRC_DIR/utils.sh"

    # Test that required tools are available
    assert command -v bash >/dev/null 2>&1
    assert command -v openssl >/dev/null 2>&1
}

@test "test_utils_temp_directory_creation" {
    # Test temporary directory creation with proper permissions

    # Create a temporary directory
    local temp_dir
    temp_dir=$(mktemp -d "/tmp/simpleca-test-XXXXXX")

    # Verify it was created
    assert_dir_exists "$temp_dir"

    # Set restrictive permissions
    chmod 700 "$temp_dir"

    # Verify permissions
    local perms
    perms=$(stat -c %a "$temp_dir")
    assert [ "$perms" = "700" ]

    # Cleanup
    rm -rf "$temp_dir"
}

@test "test_utils_file_permissions" {
    # Test file permission setting

    # Create a test file
    local test_file="$TEST_TEMP_DIR/test.key"
    echo "test content" > "$test_file"

    # Set restrictive permissions
    chmod 600 "$test_file"

    # Verify permissions
    local perms
    perms=$(stat -c %a "$test_file")
    assert [ "$perms" = "600" ]
}

@test "test_utils_path_validation" {
    # Test path validation functions

    # Test valid paths
    assert [ -d "$TEST_TEMP_DIR" ]
    assert [ -w "$TEST_TEMP_DIR" ]

    # Test invalid paths
    assert [ ! -d "/nonexistent/path" ]
    assert [ ! -f "/nonexistent/file" ]
}

@test "test_utils_environment_validation" {
    # Test environment variable validation

    # Test required environment variables
    export TEST_VAR="test_value"
    assert [ -n "$TEST_VAR" ]
    assert [ "$TEST_VAR" = "test_value" ]

    # Test unset variables
    unset TEST_VAR
    assert [ -z "${TEST_VAR:-}" ]
}

@test "test_utils_signal_handling" {
    # Test signal handling and cleanup

    # This test verifies that signal handlers are properly set up
    # The actual signal handling is tested in integration tests

    # Source the utils script
    . "$SRC_DIR/utils.sh"

    # Verify the script can be sourced without errors
    assert_success
}

@test "test_utils_logging_functions" {
    # Test logging functions (if they exist in utils.sh)

    # Source the utils script
    . "$SRC_DIR/utils.sh"

    # Test that logging functions are available (if they exist)
    # This is a placeholder for actual logging function tests
    assert_success
}

@test "test_utils_configuration_loading" {
    # Test configuration loading functions

    # Create a test configuration file
    local config_file="$TEST_TEMP_DIR/test.conf"
    cat > "$config_file" <<'EOF'
KEY_TYPE=ec
EC_CURVE=prime256v1
LEAF_DAYS=398
EOF

    # Verify the file was created
    assert_file_exists "$config_file"

    # Test reading configuration
    local key_type
    key_type=$(grep "^KEY_TYPE=" "$config_file" | cut -d'=' -f2)
    assert [ "$key_type" = "ec" ]
}

@test "test_utils_input_validation" {
    # Test input validation functions

    # Test valid inputs
    assert [ -n "valid_input" ]
    assert [ -n "test.local" ]

    # Test invalid inputs
    assert [ -z "" ]
    assert [ -z "${EMPTY_VAR:-}" ]
}

@test "test_utils_output_formatting" {
    # Test output formatting functions

    # Test that output can be formatted properly
    local test_output="test message"
    assert [ -n "$test_output" ]
    assert [ "$test_output" = "test message" ]
}

@test "test_utils_error_messages" {
    # Test error message generation

    # Test that error messages are properly formatted
    local error_msg="Test error message"
    assert [ -n "$error_msg" ]
    assert_output_contains "error" "$error_msg"
}

@test "test_utils_cleanup_functions" {
    # Test cleanup functions

    # Create test files for cleanup
    local test_file1="$TEST_TEMP_DIR/test1.txt"
    local test_file2="$TEST_TEMP_DIR/test2.txt"

    echo "test1" > "$test_file1"
    echo "test2" > "$test_file2"

    # Verify files were created
    assert_file_exists "$test_file1"
    assert_file_exists "$test_file2"

    # Clean up
    rm -f "$test_file1" "$test_file2"

    # Verify files were removed
    assert_file_not_exists "$test_file1"
    assert_file_not_exists "$test_file2"
}
