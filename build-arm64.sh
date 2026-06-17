#!/usr/bin/env sh
# Build script for ARM64 Tailscale MikroTik container

TAILSCALE_VERSION=1.98.5
VERSION=0.1.40

set -eu

echo "Building optimized Tailscale container for ARM64 (target: <30MB)"
rm -f tailscale-arm64.tar

if [ -d ./tailscale/.git ]; then
    echo "Updating existing Tailscale repo to v$TAILSCALE_VERSION..."
    (cd tailscale && git fetch --tags --depth=1 origin "v$TAILSCALE_VERSION" && git checkout --force "v$TAILSCALE_VERSION")
else
    echo "Cloning Tailscale repository (version $TAILSCALE_VERSION)..."
    git -c advice.detachedHead=false clone https://github.com/tailscale/tailscale.git --branch v$TAILSCALE_VERSION --depth 1
fi

# Obtain Tailscale version variables for embedding into binaries
echo "Preparing Tailscale build metadata..."
TS_USE_TOOLCHAIN="Y"
VERSION_LONG=""
VERSION_SHORT=""
VERSION_GIT_HASH=""
if (cd tailscale && ./build_dist.sh shellvars >/dev/null 2>&1); then
  eval $(cd tailscale && ./build_dist.sh shellvars)
  echo "Version metadata: long=${VERSION_LONG}, short=${VERSION_SHORT}, git=${VERSION_GIT_HASH}"
else
  echo "Warning: Could not obtain shellvars from build_dist.sh; continuing without embedded version metadata"
fi

echo "Building optimized container image for ARM64..."
if docker buildx version >/dev/null 2>&1; then
  echo "Using docker buildx"
  docker buildx build \
    --platform linux/arm64 \
    --build-arg TARGETARCH=arm64 \
    --build-arg VERSION_LONG="$VERSION_LONG" \
    --build-arg VERSION_SHORT="$VERSION_SHORT" \
    --build-arg VERSION_GIT_HASH="$VERSION_GIT_HASH" \
    --load -t tailscale-mikrotik-arm64:latest .
else
  echo "docker buildx not available; falling back to legacy docker build (native arch)"
  # Build natively without BuildKit since buildx is missing; this requires host arch=arm64
  DOCKER_BUILDKIT=0 docker build \
    --build-arg TARGETARCH=arm64 \
    --build-arg VERSION_LONG="$VERSION_LONG" \
    --build-arg VERSION_SHORT="$VERSION_SHORT" \
    --build-arg VERSION_GIT_HASH="$VERSION_GIT_HASH" \
    -t tailscale-mikrotik-arm64:latest .
fi

echo "Saving container image..."
docker save -o tailscale-arm64.oci.tar tailscale-mikrotik-arm64:latest

# RouterOS cannot import gzip-compressed OCI layers that modern Docker
# (BuildKit / containerd image store) produces. Repack with uncompressed
# layers so `/container/add` does not fail with "failed to load next entry".
echo "Repacking image for RouterOS compatibility..."
python3 pack-for-routeros.py tailscale-arm64.oci.tar tailscale-arm64.tar
rm -f tailscale-arm64.oci.tar

# Get the actual image size
IMAGE_SIZE=$(docker images tailscale-mikrotik-arm64:latest --format "{{.Size}}")
TAR_SIZE=$(du -h tailscale-arm64.tar | cut -f1)

echo "Build complete\!"
echo "Container image size: $IMAGE_SIZE"
echo "Exported tar file size: $TAR_SIZE"
echo "Image is ready for upload to MikroTik router"
