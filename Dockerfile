FROM alpine:3.20

# Build argument for version
ARG BUILD_VERSION=""

# Add metadata labels
LABEL maintainer="sohan@graceful.nu"
LABEL org.opencontainers.image.name="simpleca"
LABEL org.opencontainers.image.description="Simple Certificate Authority tool"
LABEL org.opencontainers.image.source="https://github.com/your-org/simpleca"
LABEL org.opencontainers.image.version="${BUILD_VERSION}"

# Install dependencies
RUN apk add --no-cache \
    bash \
    openssl \
    && rm -rf /var/cache/apk/*

# Create non-root user
RUN addgroup -S app && adduser -S app -G app

# Create necessary directories
RUN mkdir -p /opt/ca/root \
    && mkdir -p /opt/ca/intermediate \
    && mkdir -p /opt/ca/output \
    && mkdir -p /opt/ca/export \
    && mkdir -p /opt/tools

# Set working directory
WORKDIR /opt/tools

# Copy version file and source files
COPY VERSION /opt/tools/
COPY src/ /opt/tools/

# Make scripts executable
RUN chmod +x /opt/tools/*.sh

# Set ownership to non-root user
RUN chown -R app:app /opt/ca /opt/tools

# Set build version as environment variable if provided
ENV BUILD_VERSION="${BUILD_VERSION}"

# Switch to non-root user
USER app

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD test -f /opt/ca/intermediate/certs/ca-chain.cert.pem || exit 1

# Set entrypoint
ENTRYPOINT ["./main.sh"]
