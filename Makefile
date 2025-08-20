# Simple CA Makefile
# Provides convenient targets for development and testing

.PHONY: help test test-unit test-integration test-e2e test-all lint clean install-deps docker-build docker-test

# Default target
help:
	@echo "Simple CA - Available targets:"
	@echo ""
	@echo "Testing:"
	@echo "  test              - Run unit, integration, and e2e tests"
	@echo "  test-unit         - Run unit tests only"
	@echo "  test-integration  - Run integration tests only"
	@echo "  test-e2e          - Run end-to-end tests only"
	@echo "  test-all          - Run unit, integration, and e2e with verbose output"
	@echo ""
	@echo "Quality:"
	@echo "  lint              - Run linting and syntax checks"
	@echo "  lint-fix          - Auto-fix linting issues where possible"
	@echo ""
	@echo "Docker:"
	@echo "  docker-build      - Build Docker image"
	@echo "  docker-test       - Test Docker image"
	@echo ""
	@echo "Development:"
	@echo "  install-deps      - Install development dependencies"
	@echo "  clean             - Clean up temporary files"
	@echo "  setup-test-env    - Set up test environment"

# Check if BATS is installed
check-bats:
	@if ! command -v bats >/dev/null 2>&1; then \
		echo "BATS not found. Installing..."; \
		if command -v apt-get >/dev/null 2>&1; then \
			sudo apt-get update && sudo apt-get install -y bats; \
		elif command -v brew >/dev/null 2>&1; then \
			brew install bats-core; \
		elif command -v apk >/dev/null 2>&1; then \
			sudo apk add bats; \
		else \
			echo "Please install BATS manually: https://github.com/bats-core/bats-core"; \
			exit 1; \
		fi; \
	fi

# Check if shellcheck is installed
check-shellcheck:
	@if ! command -v shellcheck >/dev/null 2>&1; then \
		echo "shellcheck not found. Installing..."; \
		if command -v apt-get >/dev/null 2>&1; then \
			sudo apt-get update && sudo apt-get install -y shellcheck; \
		elif command -v brew >/dev/null 2>&1; then \
			brew install shellcheck; \
		elif command -v apk >/dev/null 2>&1; then \
			sudo apk add shellcheck; \
		else \
			echo "Please install shellcheck manually: https://github.com/koalaman/shellcheck"; \
			exit 1; \
		fi; \
	fi

# Install development dependencies
install-deps: check-bats check-shellcheck
	@echo "Development dependencies installed"

# Run all tests (excluding legacy by default)
# Previously ran: bats tests/
# Now explicitly run the three maintained suites to avoid legacy tests implicitly
# and to mirror CI behavior
#
# Note: each sub-target runs check-bats
#
# Usage: make test
#
# For legacy tests, use: make test-legacy
#

test: test-unit test-integration test-e2e

# Run unit tests only
test-unit: check-bats
	@echo "Running unit tests..."
	bats tests/unit/

# Run integration tests only
test-integration: check-bats
	@echo "Running integration tests..."
	bats tests/integration/

# Run end-to-end tests only
test-e2e: check-bats
	@echo "Running end-to-end tests..."
	bats tests/e2e/

# Run all tests with verbose output (excluding legacy)
# If you want to include legacy, use `make test-legacy` separately.

test-all: check-bats
	@echo "Running all maintained tests with verbose output..."
	bats --verbose --show-output-of-passing-tests tests/unit/
	bats --verbose --show-output-of-passing-tests tests/integration/
	bats --verbose --show-output-of-passing-tests tests/e2e/

# Run specific test file
test-file:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=tests/unit/main.bats"; \
		exit 1; \
	fi
	@echo "Running test file: $(FILE)"
	bats --verbose "$(FILE)"

# Run specific test
test-specific:
	@if [ -z "$(TEST)" ]; then \
		echo "Usage: make test-specific TEST=test_main_help_command"; \
		exit 1; \
	fi
	@echo "Running specific test: $(TEST)"
	bats --filter "$(TEST)" tests/

# Run linting and syntax checks
lint: check-shellcheck
	@echo "Running linting and syntax checks..."
	@echo "Running shellcheck..."
	shellcheck --severity=error src/*.sh tests/helpers/*.bash
	@echo "Checking bash syntax..."
	@for script in src/*.sh tests/helpers/*.bash; do \
		echo "Checking $$script"; \
		bash -n "$$script"; \
	done
	@echo "Checking script permissions..."
	@for script in src/*.sh; do \
		if [[ ! -x "$$script" ]]; then \
			echo "Warning: $$script is not executable"; \
		fi; \
	done
	@echo "Linting completed successfully"

# Auto-fix linting issues where possible
lint-fix: check-shellcheck
	@echo "Auto-fixing linting issues..."
	@echo "Note: Most shellcheck issues require manual fixes"
	@echo "Running shellcheck with suggestions..."
	shellcheck --format=json src/*.sh tests/helpers/*.bash || true

# Build Docker image
docker-build:
	@echo "Building Docker image..."
	docker build -t simpleca:latest .

# Test Docker image
docker-test: docker-build
	@echo "Testing Docker image..."
	@echo "Testing basic functionality..."
	docker run --rm simpleca:latest version
	@echo "Testing help command..."
	docker run --rm simpleca:latest help
	@echo "Testing with volume mount..."
	docker run --rm -v "$(PWD)/tests/fixtures:/tmp/ca" -e basePath="/tmp/ca" simpleca:latest version
	@echo "Docker tests completed successfully"

# Clean up temporary files
clean:
	@echo "Cleaning up temporary files..."
	rm -rf /tmp/simpleca-test-*
	rm -rf test-results/
	rm -f *.log
	@echo "Cleanup completed"

# Set up test environment
setup-test-env: install-deps
	@echo "Setting up test environment..."
	@echo "Creating test directories..."
	mkdir -p tests/fixtures/sample-ca/{root,intermediate,output}
	@echo "Test environment setup completed"

# Run security checks
security-check:
	@echo "Running security checks..."
	@echo "Checking for hardcoded secrets..."
	@if grep -r "password.*=" src/; then \
		echo "Warning: Potential hardcoded passwords found"; \
		exit 1; \
	fi
	@if grep -r "api_key\|apikey\|secret.*=" src/; then \
		echo "Warning: Potential secrets found"; \
		exit 1; \
	fi
	@echo "Security checks completed"

# Run performance tests
perf-test: check-bats
	@echo "Running performance tests..."
	@echo "Testing CA initialization performance..."
	time bats tests/e2e/complete_workflow.bats
	@echo "Testing certificate generation performance..."
	time bats --filter "test_e2e_performance" tests/e2e/complete_workflow.bats

# Generate test coverage report
coverage: check-bats
	@echo "Generating test coverage report..."
	@echo "Note: BATS doesn't provide built-in coverage reporting"
	@echo "Running maintained tests to check coverage..."
	bats --verbose tests/unit/ > coverage.log 2>&1
	bats --verbose tests/integration/ >> coverage.log 2>&1
	bats --verbose tests/e2e/ >> coverage.log 2>&1
	@echo "Coverage log saved to coverage.log"

# Run tests in parallel (experimental)
# Excludes legacy suite by default
test-parallel: check-bats
	@echo "Running tests in parallel..."
	@echo "Note: This is experimental and may cause issues"
	bats --jobs 4 tests/unit/
	bats --jobs 4 tests/integration/
	bats --jobs 4 tests/e2e/

# Validate certificates (if CA exists)
validate-certs:
	@echo "Validating existing certificates..."
	@if [ -f "ca/intermediate/certs/ca-chain.cert.pem" ]; then \
		echo "Found CA chain, validating..."; \
		openssl verify ca/intermediate/certs/ca-chain.cert.pem; \
	else \
		echo "No CA found. Run 'make setup-test-env' first."; \
	fi

# Show test statistics
test-stats: check-bats
	@echo "Test Statistics:"
	@echo "Unit tests:"
	@bats --count tests/unit/ 2>/dev/null || echo "No unit tests found"
	@echo "Integration tests:"
	@bats --count tests/integration/ 2>/dev/null || echo "No integration tests found"
	@echo "E2E tests:"
	@bats --count tests/e2e/ 2>/dev/null || echo "No E2E tests found"

# Quick smoke test
smoke-test: check-bats
	@echo "Running smoke test..."
	@echo "Testing basic functionality..."
	bats --filter "test_main_version_command" tests/unit/main.bats
	@echo "Smoke test completed"

# Development workflow
dev: install-deps lint test
	@echo "Development workflow completed"

# CI workflow (what runs in GitHub Actions)
ci: lint test-unit test-integration test-e2e docker-test security-check
	@echo "CI workflow completed"

# Release preparation
release-prep: clean test-all lint security-check docker-test
	@echo "Release preparation completed"
	@echo "All checks passed - ready for release"
