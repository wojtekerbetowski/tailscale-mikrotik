# Copyright (c) 2020 Fluent Networks Inc & AUTHORS All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

############################################################################
#
# WARNING: Tailscale is not yet officially supported in Docker,
# Kubernetes, etc.
#
# It might work, but we don't regularly test it, and it's not as polished as
# our currently supported platforms. This is provided for people who know
# how Tailscale works and what they're doing.
#
# Our tracking bug for officially support container use cases is:
#    https://github.com/tailscale/tailscale/issues/504
#
# Also, see the various bugs tagged "containers":
#    https://github.com/tailscale/tailscale/labels/containers
#
############################################################################

FROM golang:1.23-alpine AS build-env

WORKDIR /go/src/tailscale

# Copy only what's needed for dependency resolution first
COPY tailscale/go.mod tailscale/go.sum ./
RUN go mod download

# Install UPX for binary compression
RUN apk add --no-cache upx

# Skip pre-building dependencies to reduce build time and layer size
# Copy the source code
COPY tailscale/. .

# Build arguments for versioning
ARG VERSION_LONG=""
ENV VERSION_LONG=$VERSION_LONG
ARG VERSION_SHORT=""
ENV VERSION_SHORT=$VERSION_SHORT
ARG VERSION_GIT_HASH=""
ENV VERSION_GIT_HASH=$VERSION_GIT_HASH
ARG TARGETARCH

# Build tailscale binaries with optimized flags and strip all symbols
RUN GOARCH=$TARGETARCH CGO_ENABLED=0 go install -ldflags="-w -s \
      -X tailscale.com/version.Long=$VERSION_LONG \
      -X tailscale.com/version.Short=$VERSION_SHORT \
      -X tailscale.com/version.GitCommit=$VERSION_GIT_HASH" \
      -v ./cmd/tailscale ./cmd/tailscaled

# Apply maximum compression with UPX
RUN upx --best --lzma /go/bin/tailscale && upx --best --lzma /go/bin/tailscaled

# Use a minimal Alpine base image for the final stage
FROM alpine:3.20 AS runtime

# Install only the essential packages in a single layer with minimal dependencies
RUN apk add --no-cache --virtual .tailscale-deps \
    ca-certificates \
    iptables \
    ip6tables \
    iproute2 \
    && ln -sf /sbin/iptables-legacy /sbin/iptables \
    && ln -sf /sbin/ip6tables-legacy /sbin/ip6tables \
    # Clean up package cache and remove unnecessary files
    && rm -rf /var/cache/apk/* \
    # Remove unnecessary files to reduce image size
    && rm -rf /usr/share/man /usr/share/doc /tmp/* /var/tmp/* \
    # Strip binaries to reduce size
    && find /sbin /usr/sbin -type f -exec strip --strip-all {} \; 2>/dev/null || true

# Copy only the necessary binaries from the build stage
COPY --from=build-env /go/bin/tailscale /go/bin/tailscaled /usr/local/bin/
COPY tailscale.sh /usr/local/bin/

# Set proper permissions
RUN chmod +x /usr/local/bin/tailscale.sh

# Create necessary directories with minimal permissions
RUN mkdir -p /var/run/tailscale /var/cache/tailscale /var/lib/tailscale

# Set up the runtime environment
ENV PATH="/usr/local/bin:${PATH}"

# Expose the tailscale port
EXPOSE 41641/udp

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/tailscale.sh"]
