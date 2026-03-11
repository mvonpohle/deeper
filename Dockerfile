# Dockerfile for DeeperServer
# Builds the Deeper analytics HTTP server and produces a minimal runtime image.
#
# The server exposes Beeper messaging analytics as JSON endpoints so they can be
# accessed from any device on the network — no macOS or Apple Silicon required.
#
# Build:  docker build -t deeper-server .
# Run:    docker run -p 8080:8080 -e BEEPER_TOKEN=<token> deeper-server

# ── Stage 1: Build ────────────────────────────────────────────────────────────
FROM swift:6.0-noble AS builder

WORKDIR /build

# Copy only the dependency manifests first so Docker can cache the resolved
# package graph and skip re-fetching on source-only changes.
COPY Package.swift Package.resolved* ./

# Pre-fetch dependencies (cached layer)
RUN swift package resolve

# Copy application sources
COPY Deeper/ ./Deeper/
COPY Sources/ ./Sources/

# Build in release mode
RUN swift build --configuration release --product DeeperServer


# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
FROM ubuntu:noble AS runner

# Install Swift runtime libraries (no compiler, no SDK)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libstdc++6 \
        libcurl4 \
        libxml2 \
        libtinfo6 \
        tzdata \
        ca-certificates \
        curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the compiled binary from the build stage
COPY --from=builder /build/.build/release/DeeperServer .

# Copy Swift runtime libraries that aren't in standard Ubuntu packages
COPY --from=builder /usr/lib/swift/linux/*.so* /usr/lib/swift/linux/

# Create a cache directory owned by a non-root user
RUN useradd --system --create-home --shell /bin/false deeper && \
    mkdir -p /home/deeper/.cache/deeper_cache && \
    chown -R deeper:deeper /home/deeper
USER deeper

# Configuration via environment variables (see .env.example)
ENV PORT=8080 \
    HOST=0.0.0.0

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -sf http://localhost:8080/health || exit 1

CMD ["./DeeperServer"]
