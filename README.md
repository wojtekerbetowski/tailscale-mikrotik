# Tailscale for MikroTik Container

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
![Docker Image Size](https://img.shields.io/badge/image%20size-<30MB-brightgreen)
![Tailscale Version](https://img.shields.io/badge/Tailscale-v1.80.1-blue)
![Alpine Version](https://img.shields.io/badge/Alpine-3.20-blue)

A lightweight Docker container for running [Tailscale](https://tailscale.com) on [MikroTik RouterOS](https://mikrotik.com/software) devices with constrained storage. This project is specifically optimized for MikroTik routers with limited disk space, targeting an image size under 30MB.

## Overview

This project enables you to run Tailscale in MikroTik's Container environment, allowing your MikroTik router to join your Tailscale network and act as a subnet router. This provides secure access to devices on your local network through Tailscale's encrypted mesh network.

**Key Features:**
- Ultra-lightweight container (<25MB)
- Optimized for MikroTik routers with limited storage
- Supports both Tailscale and Headscale control servers
- Configurable via environment variables
- Automated upgrade script for RouterOS

## Current Version

- **Tailscale**: v1.80.1 (February 2025)
- **Base Image**: Alpine Linux 3.20
- **Image Size**: ~24.5MB

## Requirements

- MikroTik router running RouterOS v7.6 or later
- Container package enabled on RouterOS
- Sufficient storage space (recommended: external USB drive for routers with limited internal storage)
- Compatible with ARM, ARM64, and x86 architectures

> **Note**: This container can impact router performance. In testing, an IPerf test of 50 Mbps via the container on a MikroTik hAP ax3 consumed approximately 30% of the router's CPU.

## Quick Start

1. Enable container mode on your MikroTik router
2. Set up networking for the container
3. Configure environment variables
4. Deploy the container
5. Authorize the router in your Tailscale account

Detailed instructions for each step are provided below.

## Detailed Setup Instructions

### 1. Enable Container Mode

Enable container mode on your MikroTik router and reboot:

```
/system/device-mode/update container=yes
```

### 2. Set Up Container Networking

Create a virtual ethernet interface, bridge, and routing:

```
# Create veth interface
/interface/veth add name=veth1 address=172.17.0.2/16 gateway=172.17.0.1

# Create bridge and add veth1
/interface/bridge add name=dockers
/ip/address add address=172.17.0.1/16 interface=dockers
/interface/bridge/port add bridge=dockers interface=veth1

# Add route to Tailscale network
/ip/route/add dst-address=100.64.0.0/10 gateway=172.17.0.2
```

### 3. Configure Environment Variables

Set up the required environment variables:

```
/container/envs
add name="tailscale" key="PASSWORD" value="your-secure-password"
add name="tailscale" key="AUTH_KEY" value="tskey-your-tailscale-auth-key"
add name="tailscale" key="ADVERTISE_ROUTES" value="192.168.88.0/24"
add name="tailscale" key="CONTAINER_GATEWAY" value="172.17.0.1"
add name="tailscale" key="TAILSCALE_ARGS" value="--accept-routes --advertise-exit-node"
```

Create a mount point for persistent Tailscale state:

```
/container mounts
add name="tailscale" src="/tailscale" dst="/var/lib/tailscale" 
```

### 4. Deploy the Container

You can deploy the container using one of the following methods:

#### Option A: From Container Registry (Recommended)

```
# Configure registry
/container/config 
set registry-url=https://ghcr.io tmpdir=disk1/pull

# Add container
/container add remote-image=fluent-networks/tailscale-mikrotik:latest \
  interface=veth1 \
  envlist=tailscale \
  root-dir=disk1/containers/tailscale \
  mounts=tailscale \
  start-on-boot=yes \
  hostname=mikrotik \
  dns=8.8.4.4,8.8.8.8
```

#### Option B: Using Local Image File

If you've built the image locally:

1. Upload the `tailscale.tar` file to your router (e.g., to `disk1/`)
2. Add the container:

```
/container add file=disk1/tailscale.tar \
  interface=veth1 \
  envlist=tailscale \
  root-dir=disk1/containers/tailscale \
  mounts=tailscale \
  start-on-boot=yes \
  hostname=mikrotik \
  dns=8.8.4.4,8.8.8.8
```

#### Option C: For Routers Without External Storage

For routers with limited internal storage:

```
# Create a temporary RAM disk
/disk add type=tmpfs tmpfs-max-size=200M

# Upload tailscale.tar to tmp1/
# Then add container
/container add file=tmp1/tailscale.tar \
  interface=veth1 \
  envlist=tailscale \
  root-dir=containers/tailscale \
  mounts=tailscale \
  start-on-boot=yes \
  hostname=mikrotik \
  dns=8.8.4.4,8.8.8.8
```

### 5. Start the Container

```
/container/start 0
```

### 6. Verify and Authorize

1. Check the container status: `/container/print`
2. In the Tailscale console, authorize the router and enable subnet routes
3. Your Tailscale hosts should now be able to reach devices on your router's LAN subnet

## Configuration Options

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `PASSWORD` | Root user password for the container | Yes |
| `AUTH_KEY` | Tailscale auth key or Headscale pre-auth key | Yes |
| `ADVERTISE_ROUTES` | Comma-separated list of routes to advertise | Yes |
| `CONTAINER_GATEWAY` | The container bridge IP address (e.g., 172.17.0.1) | Yes |
| `LOGIN_SERVER` | Headscale login server URL (only for Headscale) | No |
| `UPDATE_TAILSCALE` | Update Tailscale on container startup (no value needed) | No |
| `TAILSCALE_ARGS` | Additional arguments for `tailscale up` | No |
| `TAILSCALED_ARGS` | Additional arguments for `tailscaled` | No |
| `STARTUP_SCRIPT` | Path to script to execute before starting Tailscale | No |

### Headscale Configuration

For Headscale users, configure the environment variables as follows:

```
/container/envs
add name="tailscale" key="PASSWORD" value="your-secure-password"
add name="tailscale" key="AUTH_KEY" value="your-headscale-pre-auth-key"
add name="tailscale" key="ADVERTISE_ROUTES" value="192.168.88.0/24"
add name="tailscale" key="CONTAINER_GATEWAY" value="172.17.0.1"
add name="tailscale" key="LOGIN_SERVER" value="http://headscale.example.com:8080"
add name="tailscale" key="TAILSCALE_ARGS" value="--accept-routes"
```

### Custom Startup Script

You can execute a custom script during container startup:

1. Place your script in the mounted volume (e.g., `/var/lib/tailscale/startup.sh`)
2. Add the environment variable:

```
/container/envs
add name="tailscale" key="STARTUP_SCRIPT" value="/var/lib/tailscale/startup.sh"
```

## Upgrading

### Manual Upgrade

1. Stop and remove the current container:
   ```
   /container/stop 0
   /container/remove 0
   ```
2. Deploy the new container as described in the "Deploy the Container" section

### Automated Upgrade

Use the included `upgrade.rsc` script to automate the upgrade process:

1. Edit the `hostname` variable in `upgrade.rsc` to match your container
2. Import the script:
   ```
   /system script add name=upgrade source=[ /file get upgrade.rsc contents];
   ```
3. Run the script:
   ```
   /system script run [find name="upgrade"];
   ```

> **Note**: If you're connected over Tailscale, the script will continue running even after your connection is temporarily lost. When completed, check that the router is authenticated and enable subnet routes in the Tailscale console.

## Building the Image

To build the Docker image locally:

1. Clone this repository
2. Adjust the `PLATFORM` variable in `build.sh` to match your target architecture
3. Run the build script:
   ```
   ./build.sh
   ```

The script will generate a `tailscale.tar` file that you can upload to your MikroTik router.

## Accessing the Container

You can access the container in several ways:

1. Via the router's CLI:
   ```
   /container/shell 0
   ```

2. Via SSH using the router's Tailscale IP address (using the root password set in the environment variables)

## Troubleshooting

- **Container fails to start**: Check the logs with `/container/logs 0`
- **No connectivity to Tailscale network**: Verify the AUTH_KEY is valid and the router is authorized in the Tailscale console
- **Can't reach LAN devices**: Ensure subnet routes are enabled in the Tailscale console
- **High CPU usage**: Consider adjusting the `--netfilter-mode` option in TAILSCALE_ARGS

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request or create an Issue if you encounter any problems or have suggestions for improvements.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Tailscale](https://tailscale.com) for their excellent VPN solution
- [MikroTik](https://mikrotik.com) for RouterOS and Container support
- All contributors to this project
