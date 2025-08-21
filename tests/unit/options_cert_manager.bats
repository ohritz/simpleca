#!/usr/bin/env bats

# Unit tests for cert-manager.sh option parsing
# Tests short flags, long flags, error handling, help functionality, and subcommands

load "../helpers/test_helper.bash"

setup() {
    setup_test_dirs "options-cert-manager"
    setup_cleanup_trap
}

teardown() {
    cleanup_test_dirs
}

@test "test_cert_manager_help_short_flag" {
    output=$(run_script "$SRC_DIR/cert-manager.sh" -h)
    assert_success
    assert_output_contains "simpleca cert-manager export - Export Kubernetes cert-manager CA Issuer artifacts" "$output"
    assert_output_contains "Usage:" "$output"
    assert_output_contains "-n, --ns|--namespace" "$output"
    assert_output_contains "--issuer-name" "$output"
}

@test "test_cert_manager_help_long_flag" {
    output=$(run_script "$SRC_DIR/cert-manager.sh" --help)
    assert_success
    assert_output_contains "simpleca cert-manager export - Export Kubernetes cert-manager CA Issuer artifacts" "$output"
    assert_output_contains "Usage:" "$output"
    assert_output_contains "-n, --ns|--namespace" "$output"
    assert_output_contains "--issuer-name" "$output"
}

@test "test_cert_manager_help_command" {
    output=$(run_script "$SRC_DIR/cert-manager.sh" help)
    assert_success
    assert_output_contains "simpleca cert-manager export - Export Kubernetes cert-manager CA Issuer artifacts" "$output"
    assert_output_contains "Usage:" "$output"
}

@test "test_cert_manager_export_subcommand" {
    # Test export subcommand
    output=$(run_script "$SRC_DIR/cert-manager.sh" export 2>&1 || true)
    # Should fail because namespace is required, but should not be a parsing error
    assert_output_contains "cert-manager" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown cert-manager subcommand" "$output"
}

@test "test_cert_manager_unknown_subcommand" {
    # Test unknown subcommand
    output=$(run_script "$SRC_DIR/cert-manager.sh" unknown 2>&1 || true)
    assert_output_contains "Unknown cert-manager subcommand: unknown" "$output"
}

@test "test_cert_manager_no_subcommand" {
    # Test no subcommand
    output=$(run_script "$SRC_DIR/cert-manager.sh" 2>&1 || true)
    assert_output_contains "simpleca cert-manager export - Export Kubernetes cert-manager CA Issuer artifacts" "$output"
}

@test "test_cert_manager_namespace_short_flag" {
    # Test -n flag with space
    output=$(run_script "$SRC_DIR/cert-manager.sh" export -n test-ns 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "cert-manager" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for -n" "$output"
}

@test "test_cert_manager_namespace_long_flag_space" {
    # Test --namespace flag with space
    output=$(run_script "$SRC_DIR/cert-manager.sh" export --namespace test-ns 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "cert-manager" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for --namespace" "$output"
}

@test "test_cert_manager_namespace_short_alias" {
    # Test --ns flag with space
    output=$(run_script "$SRC_DIR/cert-manager.sh" export --ns test-ns 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "cert-manager" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for --ns" "$output"
}

@test "test_cert_manager_namespace_long_flag_equals" {
    # Test --namespace=value flag
    output=$(run_script "$SRC_DIR/cert-manager.sh" export --namespace=test-ns 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "cert-manager" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_cert_manager_namespace_short_alias_equals" {
    # Test --ns=value flag
    output=$(run_script "$SRC_DIR/cert-manager.sh" export --ns=test-ns 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "cert-manager" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_cert_manager_issuer_name_long_flag_space" {
    # Test --issuer-name flag with space
    output=$(run_script "$SRC_DIR/cert-manager.sh" export -n test-ns --issuer-name test-issuer 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "cert-manager" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for --issuer-name" "$output"
}

@test "test_cert_manager_issuer_name_long_flag_equals" {
    # Test --issuer-name=value flag
    output=$(run_script "$SRC_DIR/cert-manager.sh" export -n test-ns --issuer-name=test-issuer 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "cert-manager" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_cert_manager_secret_name_long_flag_space" {
    # Test --secret-name flag with space
    output=$(run_script "$SRC_DIR/cert-manager.sh" export -n test-ns --secret-name test-secret 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "cert-manager" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for --secret-name" "$output"
}

@test "test_cert_manager_secret_name_long_flag_equals" {
    # Test --secret-name=value flag
    output=$(run_script "$SRC_DIR/cert-manager.sh" export -n test-ns --secret-name=test-secret 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "cert-manager" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_cert_manager_out_short_flag" {
    # Test -o flag with space
    output=$(run_script "$SRC_DIR/cert-manager.sh" export -n test-ns -o /tmp/output 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "cert-manager" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for -o" "$output"
}

@test "test_cert_manager_out_long_flag_space" {
    # Test --out flag with space
    output=$(run_script "$SRC_DIR/cert-manager.sh" export -n test-ns --out /tmp/output 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "cert-manager" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for --out" "$output"
}

@test "test_cert_manager_out_long_flag_equals" {
    # Test --out=value flag
    output=$(run_script "$SRC_DIR/cert-manager.sh" export -n test-ns --out=/tmp/output 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "cert-manager" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_cert_manager_pass_file_short_flag" {
    # Test -p flag with space
    output=$(run_script "$SRC_DIR/cert-manager.sh" export -n test-ns -p /tmp/pass.txt 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "cert-manager" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for -p" "$output"
}

@test "test_cert_manager_pass_file_long_flag_space" {
    # Test --pass-file flag with space
    output=$(run_script "$SRC_DIR/cert-manager.sh" export -n test-ns --pass-file /tmp/pass.txt 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "cert-manager" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument for --pass-file" "$output"
}

@test "test_cert_manager_pass_file_long_flag_equals" {
    # Test --pass-file=value flag
    output=$(run_script "$SRC_DIR/cert-manager.sh" export -n test-ns --pass-file=/tmp/pass.txt 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "cert-manager" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_cert_manager_force_short_flag" {
    # Test -f flag
    output=$(run_script "$SRC_DIR/cert-manager.sh" export -n test-ns -f 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "cert-manager" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_cert_manager_force_long_flag" {
    # Test --force flag
    output=$(run_script "$SRC_DIR/cert-manager.sh" export -n test-ns --force 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "cert-manager" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_cert_manager_multiple_options" {
    # Test multiple options together
    output=$(run_script "$SRC_DIR/cert-manager.sh" export --namespace=test-ns --issuer-name=test-issuer --secret-name=test-secret --out=/tmp/output --force 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "cert-manager" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_cert_manager_mixed_short_long_options" {
    # Test mixing short and long options
    output=$(run_script "$SRC_DIR/cert-manager.sh" export -n test-ns --issuer-name=test-issuer -o /tmp/output --force 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "cert-manager" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option" "$output"
    assert_output_not_contains "Missing argument" "$output"
}

@test "test_cert_manager_unknown_option" {
    # Test unknown option
    output=$(run_script "$SRC_DIR/cert-manager.sh" export --unknown-option 2>&1 || true)
    assert_output_contains "Unknown option: --unknown-option" "$output"
}

@test "test_cert_manager_missing_argument_short" {
    # Test missing argument for short option
    output=$(run_script "$SRC_DIR/cert-manager.sh" export -n 2>&1 || true)
    assert_output_contains "Missing argument for --ns|--namespace" "$output"
}

@test "test_cert_manager_missing_argument_long" {
    # Test missing argument for long option
    output=$(run_script "$SRC_DIR/cert-manager.sh" export --namespace 2>&1 || true)
    assert_output_contains "Missing argument for --ns|--namespace" "$output"
}

@test "test_cert_manager_missing_required_namespace" {
    # Test missing required namespace
    output=$(run_script "$SRC_DIR/cert-manager.sh" export --issuer-name=test-issuer 2>&1 || true)
    assert_output_contains "Missing required: --ns|--namespace <name>" "$output"
}

@test "test_cert_manager_double_dash_separator" {
    # Test -- separator
    output=$(run_script "$SRC_DIR/cert-manager.sh" export -n test-ns -- --some-argument 2>&1 || true)
    # Should fail because no CA exists, but should not be a parsing error
    assert_output_contains "cert-manager" "$output" || assert_output_contains "ERR" "$output"
    assert_output_not_contains "Unknown option: --some-argument" "$output"
}

@test "test_cert_manager_help_with_other_options" {
    # Test that help takes precedence
    output=$(run_script "$SRC_DIR/cert-manager.sh" export -n test-ns --issuer-name=test-issuer --help)
    assert_success
    assert_output_contains "simpleca cert-manager export - Export Kubernetes cert-manager CA Issuer artifacts" "$output"
    assert_output_contains "Usage:" "$output"
}

@test "test_cert_manager_help_with_equals" {
    # Test help with equals (should be treated as unknown subcommand)
    output=$(run_script "$SRC_DIR/cert-manager.sh" --help=something 2>&1 || true)
    assert_output_contains "Unknown cert-manager subcommand: --help=something" "$output"
}
