#!/usr/bin/env sh
PLATFORM="linux/amd64"
TAILSCALE_VERSION=1.80.1
VERSION=0.1.37

set -eu

rm -f tailscale.tar

if [ ! -d ./tailscale/.git ]
then
    git -c advice.detachedHead=false clone https://github.com/tailscale/tailscale.git --branch v$TAILSCALE_VERSION
fi

TS_USE_TOOLCHAIN="Y"
cd tailscale && eval $(./build_dist.sh shellvars) && cd ..

docker buildx build \
  --no-cache \
  --build-arg TAILSCALE_VERSION=$TAILSCALE_VERSION \
  --build-arg VERSION_LONG=$VERSION_LONG \
  --build-arg VERSION_SHORT=$VERSION_SHORT \
  --build-arg VERSION_GIT_HASH=$VERSION_GIT_HASH \
  --platform $PLATFORM \
  --load -t ghcr.io/fluent-networks/tailscale-mikrotik:$VERSION .

docker save -o tailscale.tar ghcr.io/fluent-networks/tailscale-mikrotik:$VERSION
