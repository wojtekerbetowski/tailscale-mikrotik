#!/usr/bin/env sh
# Optimized build script for Tailscale MikroTik container
# This script builds a highly optimized container image under 25MB

PLATFORM="linux/amd64"  # Change to linux/arm64 or linux/arm/v7 for other architectures
TAILSCALE_VERSION=1.80.1
VERSION=0.1.38

set -eu

echo "Building optimized Tailscale container (target: <25MB)"
rm -f tailscale.tar

if [ ! -d ./tailscale/.git ]
then
    echo "Cloning Tailscale repository (version $TAILSCALE_VERSION)..."
    git -c advice.detachedHead=false clone https://github.com/tailscale/tailscale.git --branch v$TAILSCALE_VERSION
fi

# Get Tailscale build variables
echo "Setting up Tailscale build environment..."
TS_USE_TOOLCHAIN="Y"
cd tailscale && eval $(./build_dist.sh shellvars) && cd ..

echo "Building optimized container image..."
docker buildx build \
  --no-cache \
  --build-arg TAILSCALE_VERSION=$TAILSCALE_VERSION \
  --build-arg VERSION_LONG=$VERSION_LONG \
  --build-arg VERSION_SHORT=$VERSION_SHORT \
  --build-arg VERSION_GIT_HASH=$VERSION_GIT_HASH \
  --platform $PLATFORM \
  --load -t ghcr.io/fluent-networks/tailscale-mikrotik:$VERSION .

echo "Saving container image to tailscale.tar..."
docker save -o tailscale.tar ghcr.io/fluent-networks/tailscale-mikrotik:$VERSION

# Get the actual image size
IMAGE_SIZE=$(docker images ghcr.io/fluent-networks/tailscale-mikrotik:$VERSION --format "{{.Size}}")
TAR_SIZE=$(du -h tailscale.tar | cut -f1)

echo "Build complete!"
echo "Container image size: $IMAGE_SIZE"
echo "Exported tar file size: $TAR_SIZE"
echo "Image is ready for upload to MikroTik router"
