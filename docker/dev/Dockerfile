# Development image for selves: Go toolchain plus everything the test suite needs.
# Built and used through compose.yaml; run commands with scripts/dev.
ARG GO_VERSION=1.25
FROM golang:${GO_VERSION}-bookworm

RUN apt-get update \
 && apt-get install -y --no-install-recommends bats shellcheck python3 git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Runs as the host user (see compose.yaml), so HOME and the Go caches must be
# writable by any UID. The named volume mounted at /cache copies these permissions.
ENV HOME=/tmp/home \
    GOCACHE=/cache/go-build \
    GOMODCACHE=/cache/mod \
    GOFLAGS=-buildvcs=false \
    CGO_ENABLED=0
RUN mkdir -p /tmp/home /cache/go-build /cache/mod \
 && chmod 1777 /tmp/home /cache /cache/go-build /cache/mod

WORKDIR /work
