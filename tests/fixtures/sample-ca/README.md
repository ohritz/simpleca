# Test Fixtures

This directory contains sample CA data and test fixtures for the Simple CA test suite.

## Structure

```
fixtures/
├── sample-ca/           # Sample CA directory structure
│   ├── root/           # Root CA files
│   ├── intermediate/   # Intermediate CA files
│   └── output/         # Sample output files
├── certificates/       # Sample certificates for testing
├── keys/              # Sample private keys for testing
└── configs/           # Sample configuration files
```

## Usage

These fixtures are used by the test suite to:

1. **Unit Tests**: Mock data for testing individual functions
2. **Integration Tests**: Sample data for testing workflows
3. **E2E Tests**: Pre-existing CA state for testing restore operations

## Security Note

The certificates and keys in this directory are **test-only** and should never be used in production. They are generated with weak passwords and short validity periods for testing purposes only.

## Sample Data

- **Root CA**: Self-signed certificate with 10-year validity
- **Intermediate CA**: Certificate signed by root CA with 5-year validity
- **Server Certificates**: Various test certificates with different configurations
- **Keys**: Both RSA and EC keys for testing different algorithms

## Adding New Fixtures

When adding new test fixtures:

1. Use descriptive names that indicate the purpose
2. Include documentation about the fixture
3. Ensure they follow the same format as existing fixtures
4. Add corresponding tests that use the new fixtures
