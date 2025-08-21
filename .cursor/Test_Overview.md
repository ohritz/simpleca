# Simple CA Test Suite Overview

This document provides a comprehensive overview of the test suite for the Simple CA project, describing what each test file and individual test is trying to verify.

## Test Structure

The test suite is organized into three main categories:

1. **Unit Tests** (`tests/unit/`) - Test individual components and functions
2. **Integration Tests** (`tests/integration/`) - Test component interactions and workflows
3. **End-to-End Tests** (`tests/e2e/`) - Test complete workflows from start to finish

## Test Files Overview

### 1. Unit Tests (`tests/unit/`)

#### 1.1 Main Script Tests (`tests/unit/main.bats`)

**Purpose**: Tests the main entry point script, command parsing, help system, and subcommand dispatching.

#### Individual Tests:

- `test_main_help_command`: Tests the help command output
- `test_main_help_flag`: Tests -h flag functionality
- `test_main_help_long_flag`: Tests --help flag functionality
- `test_main_version_command`: Tests version command output
- `test_main_version_flag`: Tests --version flag functionality
- `test_main_no_arguments`: Tests behavior when no arguments provided
- `test_main_unknown_command`: Tests handling of unknown commands
- `test_main_init_subcommand`: Tests init subcommand dispatch
- `test_main_issue_subcommand`: Tests issue subcommand dispatch
- `test_main_validate_subcommand`: Tests validate subcommand dispatch
- `test_main_eject_subcommand`: Tests eject subcommand dispatch
- `test_main_re_init_subcommand`: Tests re-init subcommand dispatch
- `test_main_cert_manager_subcommand_help`: Tests cert-manager subcommand help
- `test_main_backward_compatibility`: Tests backward compatibility with hostname as first argument
- `test_main_script_directory_resolution`: Tests script directory resolution
- `test_main_env_file_loading`: Tests environment file loading
- `test_main_subcommand_with_arguments`: Tests subcommands with arguments
- `test_main_non_interactive_flag`: Tests non-interactive mode flag

#### 1.2 Utils Script Tests (`tests/unit/utils.bats`)

**Purpose**: Tests utility functions, error handling, and common operations.

#### Individual Tests:

- `test_utils_error_handling_setup`: Tests error handling setup
- `test_utils_required_tools_check`: Tests required tools verification
- `test_utils_temp_directory_creation`: Tests temporary directory creation with proper permissions
- `test_utils_file_permissions`: Tests file permission setting
- `test_utils_path_validation`: Tests path validation functions
- `test_utils_environment_validation`: Tests environment variable validation
- `test_utils_signal_handling`: Tests signal handling and cleanup
- `test_utils_logging_functions`: Tests logging functions
- `test_utils_cleanup_functions`: Tests cleanup functions

### 2. Integration Tests (`tests/integration/`)

#### 2.1 CA Initialization Tests (`tests/integration/init.bats`)

**Purpose**: Tests the CA initialization process, directory structure creation, and certificate generation.

#### Individual Tests:

- `test_init_creates_ca_structure`: Tests CA directory structure creation
- `test_init_creates_root_ca_files`: Tests root CA file generation
- `test_init_creates_intermediate_ca_files`: Tests intermediate CA file generation
- `test_init_certificate_chain_validation`: Tests certificate chain validation
- `test_init_certificate_subject_info`: Tests certificate subject information
- `test_init_certificate_issuer_info`: Tests certificate issuer information
- `test_init_certificate_dates`: Tests certificate validity dates
- `test_init_key_permissions`: Tests key file permissions
- `test_init_certificate_permissions`: Tests certificate file permissions
- `test_init_serial_number_management`: Tests serial number management
- `test_init_index_file_management`: Tests index file management
- `test_init_idempotent_behavior`: Tests idempotent behavior
- `test_init_force_flag_behavior`: Tests force flag behavior
- `test_init_environment_variable_overrides`: Tests environment variable overrides

#### 2.2 Cert-Manager Export Tests (`tests/integration/cert_manager_export.bats`)

**Purpose**: Tests the cert-manager export functionality for Kubernetes integration.

#### Individual Tests:

- `cert-manager export produces unencrypted key, full chain, and manifests`:
  - Tests basic cert-manager export functionality
  - Validates unencrypted key generation
  - Tests full certificate chain creation
  - Verifies Kubernetes manifest generation
  - Tests file permissions and format

- `cert-manager export supports CRL and OCSP arrays`:
  - Tests CRL (Certificate Revocation List) support
  - Tests OCSP (Online Certificate Status Protocol) support
  - Validates YAML array generation for multiple endpoints

### 3. End-to-End Tests (`tests/e2e/`)

#### 3.1 Complete Workflow Tests (`tests/e2e/complete_workflow.bats`)

**Purpose**: Tests the complete CA workflow from initialization to certificate generation and validation.

#### Individual Tests:

- `test_e2e_complete_workflow_ec`:
  - Tests complete workflow with EC (Elliptic Curve) keys
  - Step 1: CA initialization
  - Step 2: Server certificate issuance
  - Step 3: File generation verification
  - Step 4: Certificate chain validation
  - Step 5: Modern certificate reading (PKCS#8 and PKCS#12)
  - Step 6: Certificate details validation (signature, SANs, key type)
  - Step 7: Validation command testing
  - Step 8: Eject command testing
  - Step 9: Archive verification
  - Step 10: Re-initialization testing

- `test_e2e_complete_workflow_rsa`:
  - Tests complete workflow with RSA keys
  - Similar steps as EC workflow but with RSA-specific key type assertions

- `test_e2e_certificate_validation_workflow`:
  - Tests certificate validation workflow
  - Validates certificate chain verification
  - Tests certificate expiration checking
  - Tests certificate revocation checking

- `test_e2e_certificate_export_workflow`:
  - Tests certificate export workflow
  - Validates PKCS#8 export
  - Tests PKCS#12 export
  - Tests cert-manager export

- `test_e2e_ca_backup_restore_workflow`:
  - Tests CA backup and restore workflow
  - Validates eject functionality
  - Tests re-initialization from backup
  - Tests data integrity after restore

- `test_e2e_performance_benchmarks`:
  - Tests performance characteristics
  - Validates operation timing
  - Tests resource usage
  - Ensures acceptable performance

## Test Execution

Tests can be run using the following commands:

- `make test` - Run unit, integration, and e2e tests
- `make test-unit` - Run unit tests only
- `make test-integration` - Run integration tests only
- `make test-e2e` - Run end-to-end tests only
- `make test-all` - Run all maintained tests with verbose output

## Test Coverage

The test suite covers:

1. **Command Line Interface**: Help, version, subcommand dispatching
2. **CA Operations**: Initialization, certificate issuance, validation
3. **Certificate Formats**: PKCS#8, PKCS#12, PEM, DER
4. **Key Types**: RSA, EC (Elliptic Curve)
5. **Security**: File permissions, password handling, key protection
6. **Integration**: Cert-manager, Kubernetes manifests
7. **Error Handling**: Invalid inputs, missing files, permission errors
8. **Performance**: Operation timing, resource usage
9. **Workflows**: Complete end-to-end processes

## Test Dependencies

- **BATS**: Bash Automated Testing System
- **OpenSSL**: For certificate operations
- **Bash**: For script execution
- **Standard Unix tools**: grep, sed, awk, stat, etc.

## Test Environment

Tests run in isolated temporary directories with:
- Mock password scripts for non-interactive testing
- Controlled environment variables
- Proper cleanup on completion
- Secure file permissions
- Temporary CA structures
