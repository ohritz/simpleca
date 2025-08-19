# Phase 5: Test Suite Setup

This document describes the comprehensive test suite setup for Simple CA, following the bash-ninja rules and Docker best practices.

## Overview

The test suite has been completely restructured to provide:

- **Unit Tests**: Test individual functions in isolation
- **Integration Tests**: Test complete workflows
- **End-to-End Tests**: Test complete user workflows
- **Legacy Integration**: Maintains compatibility with existing tests
- **CI/CD Integration**: Automated testing in GitHub Actions
- **Quality Gates**: Linting, security checks, and performance tests

## Test Structure

```
tests/
├── README.md                    # Test documentation
├── helpers/
│   └── test_helper.bash        # Common test utilities
├── unit/                        # Unit tests
│   ├── main.bats               # Main script tests
│   └── utils.bats              # Utility function tests
├── integration/                 # Integration tests
│   └── init.bats               # CA initialization tests
├── e2e/                        # End-to-end tests
│   └── complete_workflow.bats  # Complete workflow tests
├── legacy-integration.bats     # Legacy test integration
└── fixtures/                   # Test data and fixtures
    └── sample-ca/              # Sample CA data
```

## Key Features

### 1. BATS Test Framework
- Uses BATS (Bash Automated Testing System) for structured testing
- Provides clear test organization and reporting
- Supports parallel execution and filtering

### 2. Comprehensive Test Coverage
- **Unit Tests**: 15+ tests covering main script functionality
- **Integration Tests**: 12+ tests covering CA initialization
- **E2E Tests**: 8+ tests covering complete workflows
- **Legacy Integration**: 8+ tests ensuring backward compatibility

### 3. Test Helper Functions
- Common setup and teardown utilities
- Assertion functions for file operations, output validation
- Certificate validation utilities
- Mock password functions for non-interactive testing

### 4. CI/CD Integration
- GitHub Actions workflow with 7 parallel jobs
- Automated linting with shellcheck
- Security checks for secrets and permissions
- Performance benchmarking
- Test reporting and artifact collection

### 5. Makefile Integration
- Convenient targets for different test types
- Automatic dependency installation
- Development workflow automation
- Release preparation checks

## Quick Start

### Install Dependencies
```bash
make install-deps
```

### Run All Tests
```bash
make test
```

### Run Specific Test Types
```bash
make test-unit          # Unit tests only
make test-integration   # Integration tests only
make test-e2e          # End-to-end tests only
```

### Run Linting
```bash
make lint
```

### Development Workflow
```bash
make dev               # Install deps, lint, and test
```

## Test Categories

### Unit Tests (`tests/unit/`)
- Test individual functions in isolation
- Mock dependencies where appropriate
- Fast execution (< 1 second per test)
- Test edge cases and error conditions

**Examples:**
- Command parsing and help display
- Version information retrieval
- Subcommand dispatching
- Environment variable handling

### Integration Tests (`tests/integration/`)
- Test complete workflows
- Use temporary test directories
- Test real file operations
- Validate generated artifacts

**Examples:**
- CA initialization workflow
- Certificate chain validation
- File permissions and security
- Directory structure creation

### End-to-End Tests (`tests/e2e/`)
- Test complete user workflows
- Use Docker containers when appropriate
- Test CLI interface
- Validate all outputs

**Examples:**
- Complete workflow: init → issue → validate → eject → re-init
- Multiple certificate generation
- Custom SANs configuration
- Error handling scenarios
- Performance benchmarking

### Legacy Integration Tests
- Maintains compatibility with existing test scripts
- Ensures migration path from old to new tests
- Validates that existing functionality still works

## Test Helper Functions

The `tests/helpers/test_helper.bash` provides:

### Setup Functions
- `setup_test_dirs()` - Create temporary test directories
- `setup_test_env()` - Set up test environment variables
- `create_mock_password_script()` - Create non-interactive password script

### Assertion Functions
- `assert_file_exists()` - Verify file exists
- `assert_dir_exists()` - Verify directory exists
- `assert_success()` - Verify command succeeded
- `assert_output_contains()` - Verify output contains pattern

### Certificate Functions
- `verify_certificate_chain()` - Validate certificate chain
- `get_cert_info()` - Extract certificate information
- `test_pkcs8_modern()` - Test modern PKCS#8 reading
- `test_pkcs12_modern()` - Test modern PKCS#12 reading

### Utility Functions
- `run_script()` - Run script with captured output
- `print_info()` - Colored output for test progress
- `cleanup_test_dirs()` - Clean up test directories

## CI/CD Pipeline

The GitHub Actions workflow (`/.github/workflows/test.yml`) includes:

### Jobs
1. **Lint**: shellcheck and syntax validation
2. **Unit Tests**: Fast unit test execution
3. **Integration Tests**: Workflow testing
4. **E2E Tests**: Complete workflow testing
5. **Docker Tests**: Container functionality testing
6. **Security Tests**: Secret detection and permission checks
7. **Performance Tests**: Performance benchmarking
8. **Test Report**: Aggregated test results

### Features
- Parallel job execution
- Artifact collection and reporting
- PR comment integration
- Comprehensive error reporting

## Quality Gates

### Linting
- **shellcheck**: Static analysis for shell scripts
- **bash -n**: Syntax checking
- **Permission checks**: Verify executable permissions

### Security
- **Secret detection**: Check for hardcoded secrets
- **Permission validation**: Verify secure file permissions
- **Certificate security**: Validate security settings

### Performance
- **CA initialization**: < 30 seconds
- **Certificate generation**: < 60 seconds for 5 certificates
- **Validation**: < 10 seconds for 5 certificates

## Migration from Legacy Tests

The existing test scripts (`test-modern-certs.sh` and `test-end-to-end.sh`) are preserved and integrated:

### Backward Compatibility
- Legacy scripts continue to work unchanged
- New test suite runs alongside legacy tests
- Gradual migration path provided

### Integration Points
- `tests/legacy-integration.bats` runs legacy scripts
- Common test environment shared between old and new
- Same test data and fixtures used

### Migration Benefits
- **Structured testing**: Clear test organization
- **Better reporting**: Detailed test results
- **CI/CD integration**: Automated testing
- **Extensibility**: Easy to add new tests

## Best Practices

### Test Writing
1. Use descriptive test names
2. Follow the `test_<function>_<scenario>` naming convention
3. Include setup and teardown for cleanup
4. Use helper functions for common operations
5. Test both success and failure scenarios

### Test Organization
1. Group related tests in the same file
2. Use appropriate test categories (unit/integration/e2e)
3. Keep tests independent and isolated
4. Use fixtures for test data

### Error Handling
1. Test error conditions explicitly
2. Verify error messages are helpful
3. Test edge cases and boundary conditions
4. Ensure proper cleanup on failure

## Troubleshooting

### Common Issues

**BATS not found:**
```bash
make install-deps
```

**Permission denied:**
```bash
chmod +x src/*.sh
```

**Test failures:**
```bash
make test-all  # Verbose output
bats --debug tests/  # Debug mode
```

**Docker issues:**
```bash
make docker-test
```

### Debug Mode
```bash
bats --debug tests/
bats --verbose --show-output-of-passing-tests tests/
```

### Individual Test Debugging
```bash
make test-specific TEST=test_main_help_command
make test-file FILE=tests/unit/main.bats
```

## Future Enhancements

### Planned Improvements
1. **Test Coverage Reporting**: Integration with coverage tools
2. **Performance Regression Testing**: Automated performance monitoring
3. **Cross-Platform Testing**: Windows and macOS compatibility
4. **Load Testing**: High-volume certificate generation
5. **Security Scanning**: Integration with security tools

### Extensibility
- Easy to add new test categories
- Modular test helper functions
- Configurable test environments
- Plugin architecture for custom tests

## Conclusion

The Phase 5 test suite provides a comprehensive, maintainable, and extensible testing framework for Simple CA. It follows industry best practices, maintains backward compatibility, and provides clear migration paths for future development.

The test suite ensures:
- **Quality**: Comprehensive coverage and validation
- **Reliability**: Automated testing and CI/CD integration
- **Maintainability**: Clear structure and documentation
- **Extensibility**: Easy to add new tests and features
- **Security**: Built-in security checks and validation
