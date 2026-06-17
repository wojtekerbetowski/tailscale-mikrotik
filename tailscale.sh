#!/bin/sh
# Copyright (c) 2024 Fluent Networks Pty Ltd & AUTHORS All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# If arguments are passed, execute tailscale with those arguments
if [ $# -gt 0 ]; then
  exec /usr/local/bin/tailscale "$@"
fi

set -e

# Log to persistent state directory if available
LOG_DIR="/var/lib/tailscale"
LOG_FILE="$LOG_DIR/startup.log"
mkdir -p "$LOG_DIR" 2>/dev/null || true
if [ -w "$LOG_DIR" ]; then
  # Prepend timestamp and redirect stdout/stderr to log file (POSIX-safe)
  echo "$(date -Iseconds) tailscale.sh starting" >> "$LOG_FILE" 2>/dev/null || true
  exec >> "$LOG_FILE" 2>&1
fi

# Ensure TUN device exists (best-effort)
if [ ! -e /dev/net/tun ]; then
  echo "Creating TUN device (best-effort)..."
  mkdir -p /dev/net || true
  mknod /dev/net/tun c 10 200 2>/dev/null || echo "Warning: Could not create /dev/net/tun; ensure host provides it"
  chmod 600 /dev/net/tun 2>/dev/null || true
fi

# Verify iptables availability (warn only on MikroTik; netfilter-mode may be off)
if ! command -v iptables >/dev/null 2>&1; then
  echo "Warning: iptables not found in PATH (ok if --netfilter-mode=off)"
  echo "Current PATH: $PATH"
fi

# Enable IP forwarding - requires root privileges
if [ "$(id -u)" = "0" ]; then
  echo 'Enabling IP forwarding...'
  
  # Try to enable IP forwarding directly, but don't fail if it doesn't work
  # This will fail in Docker unless --privileged is used
  if [ -w /proc/sys/net/ipv4/ip_forward ]; then
    echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo "Warning: Could not enable IPv4 forwarding"
  else
    echo "Note: /proc/sys/net/ipv4/ip_forward is read-only, IP forwarding must be enabled on the host"
  fi
  
  if [ -w /proc/sys/net/ipv6/conf/all/forwarding ]; then
    echo 1 > /proc/sys/net/ipv6/conf/all/forwarding 2>/dev/null || echo "Warning: Could not enable IPv6 forwarding"
  else
    echo "Note: /proc/sys/net/ipv6/conf/all/forwarding is read-only, IP forwarding must be enabled on the host"
  fi
  
  # Create sysctl.d directory if it doesn't exist and is writable
  if [ -w /etc ] && [ ! -d /etc/sysctl.d ]; then
    mkdir -p /etc/sysctl.d
  fi
  
  # Write to sysctl.d if it exists and is writable
  if [ -d /etc/sysctl.d ] && [ -w /etc/sysctl.d ]; then
    echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/99-tailscale.conf
    echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.d/99-tailscale.conf
    # Only run sysctl if it exists
    if command -v sysctl >/dev/null 2>&1; then
      sysctl -p /etc/sysctl.d/99-tailscale.conf 2>/dev/null || echo "Note: Could not apply sysctl settings, IP forwarding must be enabled on the host"
    fi
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
      ip route add "$s" via "${CONTAINER_GATEWAY}" 2>/dev/null || echo "Note: Failed to add route $s - this may be normal in Docker"
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

# Create state directory if it doesn't exist
mkdir -p /var/lib/tailscale

# Print environment information for debugging
echo "Environment information:"
echo "PATH: $PATH"
echo "iptables location: $(which iptables 2>/dev/null || echo 'not found')"
echo "ip6tables location: $(which ip6tables 2>/dev/null || echo 'not found')"
echo "TUN device: $(ls -la /dev/net/tun 2>/dev/null || echo 'not found')"
echo "IP forwarding status:"
cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo "Cannot read IPv4 forwarding status"
cat /proc/sys/net/ipv6/conf/all/forwarding 2>/dev/null || echo "Cannot read IPv6 forwarding status"

# Start tailscaled
echo "Starting tailscaled..."
/usr/local/bin/tailscaled --state=/var/lib/tailscale/tailscaled.state ${TAILSCALED_ARGS} >>"$LOG_FILE" 2>&1 &
TAILSCALED_PID=$!

# Wait for tailscaled to start
sleep 2

# If tailscaled exited early, dump a hint to the log
if ! kill -0 "$TAILSCALED_PID" 2>/dev/null; then
  echo "tailscaled exited early; see $LOG_FILE for details" >&2
fi

# Bring tailscale up
echo "Bringing tailscale up..."
if [ -n "${AUTH_KEY}" ]; then
  # Use auth key if provided
  /usr/local/bin/tailscale up \
    --reset \
    --authkey="${AUTH_KEY}" \
    --login-server "${LOGIN_SERVER}" \
    ${ADVERTISE_ROUTES:+--advertise-routes="${ADVERTISE_ROUTES}"} \
    ${TAILSCALE_ARGS} || echo "Warning: tailscale up with AUTH_KEY returned non-zero; continuing"
else
  # Interactive login if no auth key
  # If state already exists, this should be idempotent. Ignore failure to avoid exit.
  /usr/local/bin/tailscale up \
    --reset \
    --login-server "${LOGIN_SERVER}" \
    ${ADVERTISE_ROUTES:+--advertise-routes="${ADVERTISE_ROUTES}"} \
    ${TAILSCALE_ARGS} || echo "Warning: tailscale up returned non-zero (likely awaiting interactive auth); continuing"
fi

echo "Tailscale started successfully!"

# Keep the container running
wait $TAILSCALED_PID
