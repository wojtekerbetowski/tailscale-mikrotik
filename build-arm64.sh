#\!/usr/bin/env sh
# Build script for ARM64 Tailscale MikroTik container

TAILSCALE_VERSION=1.98.5
VERSION=0.1.38

set -eu

echo "Building optimized Tailscale container for ARM64 (target: <30MB)"
rm -f tailscale-arm64.tar

if [ ! -d ./tailscale/.git ]
then
    echo "Cloning Tailscale repository (version $TAILSCALE_VERSION)..."
    git -c advice.detachedHead=false clone https://github.com/tailscale/tailscale.git --branch v$TAILSCALE_VERSION
else
    echo "Updating Tailscale checkout to v$TAILSCALE_VERSION..."
    git -C tailscale fetch --tags origin
    git -C tailscale -c advice.detachedHead=false checkout v$TAILSCALE_VERSION
fi

# Compute proper version stamps from the Tailscale source so the resulting
# binary reports a clean version (e.g. "1.98.5") instead of a "-ERR" build.
echo "Computing version stamps..."
eval "$(cd tailscale && ./build_dist.sh shellvars)"

# Build the Docker image with standard Docker
echo "Building optimized container image for ARM64 (v${VERSION_SHORT})..."
docker build \
  --build-arg VERSION_LONG="$VERSION_LONG" \
  --build-arg VERSION_SHORT="$VERSION_SHORT" \
  --build-arg VERSION_GIT_HASH="$VERSION_GIT_HASH" \
  --build-arg TARGETARCH=arm64 \
  -t tailscale-mikrotik-arm64:latest .

echo "Saving container image to tailscale-arm64.tar..."
docker save -o tailscale-arm64.tar tailscale-mikrotik-arm64:latest

# Get the actual image size
IMAGE_SIZE=$(docker images tailscale-mikrotik-arm64:latest --format "{{.Size}}")
TAR_SIZE=$(du -h tailscale-arm64.tar | cut -f1)

echo "Build complete\!"
echo "Container image size: $IMAGE_SIZE"
echo "Exported tar file size: $TAR_SIZE"
echo "Image is ready for upload to MikroTik router"
