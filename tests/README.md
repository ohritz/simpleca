# Simple CA Test Suite

This directory contains the comprehensive test suite for Simple CA, following the bash-ninja rules and Docker best practices.

## Test Structure

```
tests/
├── bats/                    # BATS test framework files
├── fixtures/                # Test data and fixtures
├── unit/                    # Unit tests for individual functions
├── integration/             # Integration tests for workflows
├── e2e/                     # End-to-end tests
└── helpers/                 # Test helper functions
```

## Running Tests

### Prerequisites

Install BATS (Bash Automated Testing System):
```bash
# On Ubuntu/Debian
sudo apt-get install bats

# On macOS
brew install bats-core

# On Alpine
apk add bats

# Or install from source
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

### Run All Tests
```bash
# Run all tests
bats tests/

# Run with verbose output
bats --verbose tests/

# Run specific test suite
bats tests/unit/
bats tests/integration/
bats tests/e2e/
```

### Run Individual Tests
```bash
# Run specific test file
bats tests/unit/init.bats

# Run specific test
bats --filter "test_init_creates_ca_structure" tests/unit/init.bats
```

## Test Categories

### Unit Tests (`tests/unit/`)
- Test individual functions in isolation
- Mock dependencies where appropriate
- Fast execution (< 1 second per test)
- Test edge cases and error conditions

### Integration Tests (`tests/integration/`)
- Test complete workflows
- Use temporary test directories
- Test real file operations
- Validate generated artifacts

### End-to-End Tests (`tests/e2e/`)
- Test complete user workflows
- Use Docker containers when appropriate
- Test CLI interface
- Validate all outputs

## Test Conventions

### Naming
- Test files: `*.bats`
- Test functions: `test_<function>_<scenario>`
- Fixtures: `fixtures/<name>/`

### Structure
```bash
#!/usr/bin/env bats

setup() {
    # Setup before each test
}

teardown() {
    # Cleanup after each test
}

@test "test description" {
    # Test implementation
}
```

### Assertions
Use BATS built-in assertions:
- `assert_success` - command succeeded
- `assert_failure` - command failed
- `assert_output` - check stdout
- `assert_line` - check specific line
- `assert_file_exist` - file exists
- `assert_file_not_exist` - file doesn't exist

### Mocking
Use `stub` and `unstub` for mocking:
```bash
stub openssl "echo 'mocked openssl'"
# ... test code ...
unstub openssl
```

## CI/CD Integration

Tests are automatically run in GitHub Actions:
- On every push and pull request
- In Docker containers for consistency
- With parallel execution where possible
- With proper reporting and artifacts

## Adding New Tests

1. Create test file in appropriate directory
2. Follow naming conventions
3. Add setup/teardown for cleanup
4. Use descriptive test names
5. Add to CI workflow if needed

## Debugging Tests

### Verbose Output
```bash
bats --verbose --show-output-of-passing-tests tests/
```

### Debug Mode
```bash
bats --debug tests/
```

### Run Single Test
```bash
bats --filter "test_name" tests/file.bats
```

## Test Data

Test fixtures are stored in `tests/fixtures/`:
- Sample certificates and keys
- Configuration files
- Expected outputs
- Mock data

## Coverage

The test suite aims for:
- 100% function coverage for core utilities
- 90%+ line coverage overall
- All error paths tested
- All CLI options tested
- All file formats validated
