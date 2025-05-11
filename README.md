# Tailscale MikroTik Router Implementation

A lightweight Docker container implementation of Tailscale for MikroTik RouterOS devices, specifically tested on the hAP ax² model.

## Overview

This project provides a lightweight Docker container (targeting under 30MB) for running Tailscale on MikroTik RouterOS devices. It enables secure, private network connectivity through Tailscale's mesh VPN technology.

## Hardware Requirements

- Device: MikroTik hAP ax² (RouterBOARD)
- Architecture: ARM64
- RouterOS Version: 7.14.2 or later (stable)
- Memory: 928.0 MiB total (minimum)
- Storage: 128.0 MiB total (minimum)

## Prerequisites

1. A MikroTik hAP ax² router with RouterOS 7.14.2 or later
2. A Tailscale account and auth key
3. Basic understanding of MikroTik RouterOS configuration
4. SSH access to your MikroTik router

## Installation Steps

### 1. Network Configuration

First, set up the required network components on your MikroTik router:

```routeros
# Create virtual interface
/interface/veth/add name=veth-tailscale address=192.168.98.2/24 gateway=192.168.98.1

# Configure bridge
/interface/bridge/add name=dockers
/ip/address/add address=192.168.98.1/24 interface=dockers
/interface/bridge/port/add bridge=dockers interface=veth-tailscale

# Add route for Tailscale network
/ip/route/add dst-address=100.64.0.0/10 gateway=192.168.98.2
```

### 2. Storage Configuration

Set up the required storage:

```routeros
# Create RAM disk
/disk add type=tmpfs tmpfs-max-size=200M

# Create mount points
/file/mkdir containers/tailscale
/file/mkdir /nvme1/container/tailscale/mount
```

### 3. Environment Variables

Configure the required environment variables:

```routeros
/container/envs/add name=tailscale key=AUTH_KEY value=your-auth-key-here
/container/envs/add name=tailscale key=TS_AUTH_KEY value=your-auth-key-here
/container/envs/add name=tailscale key=ADVERTISE_ROUTES value=192.168.88.0/24
/container/envs/add name=tailscale key=CONTAINER_GATEWAY value=192.168.98.1
/container/envs/add name=tailscale key=TAILSCALE_ARGS value="--accept-routes --advertise-exit-node"
```

### 4. Container Setup

1. Build the ARM64 container image:
```bash
./build-arm64.sh
```

2. Transfer the container image to the router:
```bash
scp tailscale-arm64.tar admin@192.168.88.1:tmp1/
```

3. Add the container to RouterOS:
```routeros
/container/add
    file=tmp1/tailscale-arm64.tar
    interface=veth-tailscale
    envlist=tailscale
    root-dir=containers/tailscale
    mounts=tailscale,tailscale_state
    start-on-boot=yes
    hostname=mikrotik-tailscale
    dns=8.8.4.4,8.8.8.8
    logging=yes
```

## Useful Commands

### Network Configuration
```routeros
# Check virtual interfaces
/interface/veth/print

# Check bridge configuration
/interface/bridge/print

# Check bridge ports
/interface/bridge/port/print

# Check IP addresses
/ip/address/print
```

### Container Management
```routeros
# List containers
/container/print

# Get detailed container information
/container/print detail

# Start container
/container/start [container_index]

# Remove container
/container/remove [container_index]

# Check container logs
/log/print

# Enable logging for a container
/container/set [container_index] logging=yes
```

### Environment Variables
```routeros
# List environment variables
/container/envs/print

# Add environment variable
/container/envs/add name=tailscale key=AUTH_KEY value=your-auth-key-here

# Remove environment variable
/container/envs/remove [find key=AUTH_KEY]

# Update environment variable
/container/envs/set [find key=CONTAINER_GATEWAY] value=192.168.98.1
```

### File and Disk Management
```routeros
# List files
/file/print

# List disks
/disk/print

# Check system resources
/system/resource/print
```

## Troubleshooting

### Common Issues

1. **Architecture Mismatch**
   - Symptom: "Exec format error"
   - Solution: Ensure you're using the ARM64 version of the container

2. **Layer Extraction Issues**
   - Symptom: "error getting layer file" or "failed to load next entry"
   - Solution: Verify the container image was properly transferred and try rebuilding

3. **Container Not Starting**
   - Check container logs: `/log/print`
   - Verify environment variables: `/container/envs/print`
   - Ensure mount points exist and are accessible

## Security Considerations

1. Always use a secure Tailscale auth key
2. Regularly update RouterOS to the latest stable version
3. Monitor container logs for any suspicious activity
4. Use appropriate firewall rules to restrict access

## Maintenance

1. Regularly check for RouterOS updates
2. Monitor container logs for issues
3. Verify Tailscale connectivity after router reboots
4. Keep the container image updated

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is open source and available under the MIT License.

## Support

For issues and feature requests, please use the GitHub issue tracker.
