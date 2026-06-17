#\!/usr/bin/env sh
# Build script for ARM64 Tailscale MikroTik container

TAILSCALE_VERSION=1.80.1
VERSION=0.1.38

set -eu

echo "Building optimized Tailscale container for ARM64 (target: <30MB)"
rm -f tailscale-arm64.tar

if [ \! -d ./tailscale/.git ]
then
    echo "Cloning Tailscale repository (version $TAILSCALE_VERSION)..."
    git -c advice.detachedHead=false clone https://github.com/tailscale/tailscale.git --branch v$TAILSCALE_VERSION
fi

# Build the Docker image with standard Docker
echo "Building optimized container image for ARM64..."
docker build \
  --build-arg TAILSCALE_VERSION=$TAILSCALE_VERSION \
  --build-arg TARGETARCH=arm64 \
  -t tailscale-mikrotik-arm64:latest .

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
