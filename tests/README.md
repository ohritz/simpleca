# Tests for Simple CA

This directory contains unit, integration, e2e, and legacy tests for the Simple CA scripts.

## Structure
- `unit/`: Fast unit tests for individual scripts/functions
- `integration/`: Script-level flows like `init` and `issue`
- `e2e/`: End-to-end workflows across multiple scripts
- `legacy-integration.bats`: Backward compatibility tests
- `helpers/`: Shared test utilities

## Running tests
From the project root:

```bash
# Run all tests
make test

# Run unit tests only
make test-unit

# Run integration tests only
make test-integration

# Run a specific test file (requires bats installed)
bats tests/integration/cert_manager_export.bats
```

## cert-manager export tests
The integration test `tests/integration/cert_manager_export.bats` validates:
- CA initialization and chain creation
- `cert-manager export` generates:
  - Unencrypted intermediate key in PKCS#8
  - Full issuer chain (intermediate + root)
  - Kubernetes `Secret` and `Issuer` manifests with correct content
- Optional `--crl` and `--ocsp` flags render YAML arrays in `issuer.yaml`

These tests run non-interactively using a mock password script and a temporary `--pass-file`. Ensure `openssl` is installed and available in PATH.
