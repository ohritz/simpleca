#!/usr/bin/env bats

# Integration tests for cert-manager export functionality
# Tests exporting certificates in cert-manager format

load "../helpers/test_helper.bash"

setup() {
    setup_test_dirs "cert-manager-export"
    setup_cleanup_trap
    setup_test_env

    # Create mock password script and pass file
    create_mock_password_script "$TEST_TEMP_DIR/read-password.sh"
    export PATH="$TEST_TEMP_DIR:$PATH"
    echo "$TEST_PASSWORD" > "$TEST_TEMP_DIR/pass.txt"
}

teardown() {
    cleanup_test_dirs
}

@test "cert-manager export produces unencrypted key, full chain, and manifests" {
    cd "$TEST_TEMP_DIR"

    # Initialize CA non-interactively
    output_init=$(run_script "$SRC_DIR/init.sh" --pass-file "$TEST_TEMP_DIR/pass.txt")
    assert_success

    # Run export
    out_base="$TEST_EXPORT_DIR/manifests"
    output_export=$(run_script "$SRC_DIR/cert-manager.sh" export --ns sandbox --issuer-name ca-issuer --secret-name ca-key-pair \
        --out "$out_base" --pass-file "$TEST_TEMP_DIR/pass.txt")
    assert_success

    dest_dir="$out_base/sandbox/ca-issuer"

    # Files exist
    assert_file_exists "$dest_dir/intermediate.key.unencrypted.pem"
    assert_file_exists "$dest_dir/issuer.fullchain.crt.pem"
    assert_file_exists "$dest_dir/secret.yaml"
    assert_file_exists "$dest_dir/issuer.yaml"

    # Permissions
    key_perms=$(stat -c %a "$dest_dir/intermediate.key.unencrypted.pem")
    [ "$key_perms" = "600" ]
    chain_perms=$(stat -c %a "$dest_dir/issuer.fullchain.crt.pem")
    [ "$chain_perms" = "644" ]

    # Key parses
    openssl pkey -in "$dest_dir/intermediate.key.unencrypted.pem" -noout
    assert_success

    # Chain contains 2 certs
    cert_count=$(grep -c "BEGIN CERTIFICATE" "$dest_dir/issuer.fullchain.crt.pem")
    [ "$cert_count" = "2" ]

    # Secret has base64 fields (no wraps)
    grep -q "^  tls.crt: [A-Za-z0-9+/=]\+" "$dest_dir/secret.yaml"
    assert_success
    grep -q "^  tls.key: [A-Za-z0-9+/=]\+" "$dest_dir/secret.yaml"
    assert_success

    # Issuer references the secret and namespace
    grep -q "^kind: Issuer$" "$dest_dir/issuer.yaml"
    assert_success
    grep -q "^  name: ca-issuer$" "$dest_dir/issuer.yaml"
    assert_success
    grep -q "^  namespace: sandbox$" "$dest_dir/issuer.yaml"
    assert_success
    grep -q "^    secretName: ca-key-pair$" "$dest_dir/issuer.yaml"
    assert_success
}
