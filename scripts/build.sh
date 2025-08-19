#!/usr/bin/env bash
set -Eeuo pipefail

# Simple build script for simpleca Docker image

print_usage() {
	cat <<'USAGE'
Build script for simpleca Docker image

Usage:
  ./scripts/build.sh [options]

Options:
  -t, --tag <tag>       Tag for the Docker image (default: simpleca:latest)
  -v, --version <ver>   Version to bake into the image (overrides VERSION file and git)
  --git-version         Use git describe output as the baked version
  --file-version        Use VERSION file content as the baked version
  -h, --help            Show this help

Examples:
  ./scripts/build.sh                                    # Build with default tag, use VERSION file
  ./scripts/build.sh -t simpleca:0.3.0                  # Build with specific tag
  ./scripts/build.sh --git-version -t simpleca:dev      # Build with git version baked in
  ./scripts/build.sh -v "0.3.0-release" -t simpleca:release  # Build with custom version
USAGE
}

TAG="simpleca:latest"
VERSION=""
USE_GIT_VERSION=0
USE_FILE_VERSION=0

while [[ $# -gt 0 ]]; do
	case $1 in
		-t|--tag)
			TAG="$2"
			shift 2
			;;
		-v|--version)
			VERSION="$2"
			shift 2
			;;
		--git-version)
			USE_GIT_VERSION=1
			shift
			;;
		--file-version)
			USE_FILE_VERSION=1
			shift
			;;
		-h|--help)
			print_usage
			exit 0
			;;
		*)
			echo "Unknown option: $1" >&2
			print_usage >&2
			exit 1
			;;
	esac
done

# Determine the version to use
if [[ -n "$VERSION" ]]; then
	BUILD_VERSION="$VERSION"
elif [[ $USE_GIT_VERSION -eq 1 ]]; then
	if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
		BUILD_VERSION="$(git describe --tags --always --dirty 2>/dev/null || echo "unknown")"
	else
		echo "Error: Git not available or not in a git repository" >&2
		exit 1
	fi
elif [[ $USE_FILE_VERSION -eq 1 ]]; then
	if [[ -f "VERSION" ]]; then
		BUILD_VERSION="$(cat VERSION | tr -d '\n\r')"
	else
		echo "Error: VERSION file not found" >&2
		exit 1
	fi
else
	BUILD_VERSION=""
fi

echo "Building Docker image..."
echo "  Tag: $TAG"
if [[ -n "$BUILD_VERSION" ]]; then
	echo "  Baked version: $BUILD_VERSION"
	docker build --build-arg BUILD_VERSION="$BUILD_VERSION" -t "$TAG" .
else
	echo "  Version: Will use runtime detection (git -> VERSION file -> unknown)"
	docker build -t "$TAG" .
fi

echo ""
echo "Testing version detection:"
docker run --rm "$TAG" --version
