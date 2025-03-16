#!/bin/sh
# Copyright (c) 2024 Fluent Networks Pty Ltd & AUTHORS All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# If arguments are passed, execute tailscale with those arguments
if [ $# -gt 0 ]; then
  exec /usr/local/bin/tailscale "$@"
fi

set -e

# Enable IP forwarding - requires root privileges
if [ "$(id -u)" = "0" ]; then
  echo 'Enabling IP forwarding...'
  if [ -w /etc/sysctl.d ]; then
    echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/99-tailscale.conf
    echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.d/99-tailscale.conf
    sysctl -p /etc/sysctl.d/99-tailscale.conf || echo "Warning: Could not apply sysctl settings"
  else
    echo "Warning: /etc/sysctl.d is not writable, skipping IP forwarding configuration"
  fi
else
  echo "Warning: Not running as root, skipping IP forwarding configuration"
fi

# Install routes if specified - requires root privileges
if [ -n "${ADVERTISE_ROUTES}" ] && [ "$(id -u)" = "0" ]; then
  echo "Setting up routes: ${ADVERTISE_ROUTES}"
  # Use a more compatible syntax for reading the array
  OLD_IFS="$IFS"
  IFS=","
  for s in ${ADVERTISE_ROUTES}; do
    if [ -n "${CONTAINER_GATEWAY}" ]; then
      echo "Adding route: $s via ${CONTAINER_GATEWAY}"
      ip route add "$s" via "${CONTAINER_GATEWAY}" 2>/dev/null || echo "Failed to add route $s"
    fi
  done
  IFS="$OLD_IFS"
elif [ -n "${ADVERTISE_ROUTES}" ]; then
  echo "Warning: Not running as root, skipping route configuration"
fi

# Set login server for tailscale
if [ -z "$LOGIN_SERVER" ]; then
  LOGIN_SERVER=https://controlplane.tailscale.com
fi

# Run any custom startup script if provided
if [ -n "$STARTUP_SCRIPT" ] && [ -f "$STARTUP_SCRIPT" ]; then
  echo "Running startup script: $STARTUP_SCRIPT"
  sh "$STARTUP_SCRIPT" || exit $?
fi

# Start tailscaled
echo "Starting tailscaled..."
/usr/local/bin/tailscaled --state=/var/lib/tailscale/tailscaled.state ${TAILSCALED_ARGS} &
TAILSCALED_PID=$!

# Wait for tailscaled to start
sleep 1

# Bring tailscale up
echo "Bringing tailscale up..."
if [ -n "${AUTH_KEY}" ]; then
  # Use auth key if provided
  /usr/local/bin/tailscale up \
    --reset \
    --authkey="${AUTH_KEY}" \
    --login-server "${LOGIN_SERVER}" \
    ${ADVERTISE_ROUTES:+--advertise-routes="${ADVERTISE_ROUTES}"} \
    ${TAILSCALE_ARGS}
else
  # Interactive login if no auth key
  /usr/local/bin/tailscale up \
    --reset \
    --login-server "${LOGIN_SERVER}" \
    ${ADVERTISE_ROUTES:+--advertise-routes="${ADVERTISE_ROUTES}"} \
    ${TAILSCALE_ARGS}
fi

echo "Tailscale started successfully!"

# Keep the container running
wait $TAILSCALED_PID
