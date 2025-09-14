#\!/usr/bin/env sh
# Build script for ARM64 Tailscale MikroTik container

TAILSCALE_VERSION=1.88.1
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

# Build the Docker image with buildx to ensure arm64 base
echo "Building optimized container image for ARM64 (buildx)..."
docker buildx build \
  --platform linux/arm64 \
  --build-arg TAILSCALE_VERSION=$TAILSCALE_VERSION \
  --build-arg TARGETARCH=arm64 \
  --load -t tailscale-mikrotik-arm64:latest .

echo "Saving container image to tailscale-arm64.tar..."
docker save -o tailscale-arm64.tar tailscale-mikrotik-arm64:latest

# Get the actual image size
IMAGE_SIZE=$(docker images tailscale-mikrotik-arm64:latest --format "{{.Size}}")
TAR_SIZE=$(du -h tailscale-arm64.tar | cut -f1)

echo "Build complete\!"
echo "Container image size: $IMAGE_SIZE"
echo "Exported tar file size: $TAR_SIZE"
echo "Image is ready for upload to MikroTik router"
