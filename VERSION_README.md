# Simpleca Version System

Simpleca uses a flexible version detection system that works in different environments.

## Version Sources (in order of precedence)

1. **BUILD_VERSION environment variable** - Baked into Docker images during build
2. **Git describe** - When running in a git repository with git available
3. **VERSION file** - Fallback when git is not available
4. **"unknown"** - Final fallback

## VERSION File

The `VERSION` file contains the current version number:
```
0.3.0
```

This file is copied into Docker images and used as a fallback when git is not available.

## Docker Build Options

### Basic Build (uses VERSION file at runtime)
```bash
docker build -t simpleca:latest .
# Version: Uses VERSION file -> "0.3.0"
```

### Build with Custom Version
```bash
docker build --build-arg BUILD_VERSION="1.0.0-release" -t simpleca:release .
# Version: Uses baked version -> "1.0.0-release"
```

### Build with Git Version
```bash
# Manual
BUILD_VERSION=$(git describe --tags --always --dirty)
docker build --build-arg BUILD_VERSION="$BUILD_VERSION" -t simpleca:dev .

# Using build script
./scripts/build.sh --git-version -t simpleca:dev
# Version: Uses git describe -> "v0.2.0-7-g4a534cf-dirty"
```

## Build Script

Use the `scripts/build.sh` script for convenient building:

```bash
# Build with VERSION file (default)
./scripts/build.sh

# Build with git version baked in
./scripts/build.sh --git-version -t simpleca:dev

# Build with custom version
./scripts/build.sh -v "1.0.0-rc1" -t simpleca:rc

# Build with VERSION file content baked in
./scripts/build.sh --file-version -t simpleca:stable
```

## Version Detection Examples

### Local Development (with git)
```bash
$ ./src/main.sh --version
simpleca v0.2.0-7-g4a534cf-dirty
```

### Local Development (without git)
```bash
$ mv .git .git-backup
$ ./src/main.sh --version
simpleca 0.3.0
$ mv .git-backup .git
```

### Docker Container (no baked version)
```bash
$ docker run --rm simpleca:latest --version
simpleca 0.3.0
```

### Docker Container (with baked version)
```bash
$ docker run --rm simpleca:release --version
simpleca 1.0.0-release
```

## CI/CD Integration

For CI/CD pipelines, you can bake versions into images:

```bash
# Use git tag
VERSION=$(git describe --tags --exact-match 2>/dev/null || git describe --tags --always)
docker build --build-arg BUILD_VERSION="$VERSION" -t simpleca:$VERSION .

# Use semantic version from CI environment
docker build --build-arg BUILD_VERSION="$CI_COMMIT_TAG" -t simpleca:$CI_COMMIT_TAG .
```

## Updating the Version

1. **For development**: The git version will automatically reflect your commits
2. **For releases**: Update the `VERSION` file and create a git tag:
   ```bash
   echo "0.4.0" > VERSION
   git add VERSION
   git commit -m "Bump version to 0.4.0"
   git tag v0.4.0
   ```
3. **For Docker releases**: Use the build script with a specific version:
   ```bash
   ./scripts/build.sh -v "0.4.0" -t simpleca:0.4.0
   ```
