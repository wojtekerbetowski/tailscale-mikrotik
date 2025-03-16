# Tailscale for MikroTik Container

A lightweight Docker container for running [Tailscale](https://tailscale.com) on [MikroTik RouterOS](https://mikrotik.com/software) devices with constrained storage. This project is specifically optimized for MikroTik routers with limited disk space, targeting an image size under 30MB.

## Features

- **Ultra-lightweight**: Container size is less than 25MB
- **Optimized for MikroTik routers**: Designed for devices with limited storage
- **Tailscale v1.80.1**: Latest version of Tailscale (as of February 2025)
- **Alpine Linux 3.20**: Minimal base image for security and size
- **Configurable**: Easily configurable via environment variables
- **Dual Control Server Support**: Works with both Tailscale and Headscale control servers

## Tags

- `latest`: The most recent build
- `0.1`: First stable release with Tailscale v1.80.1 and Alpine 3.20

## Usage

### Basic Usage on MikroTik RouterOS

```
# Configure registry
/container/config 
set registry-url=https://registry-1.docker.io tmpdir=disk1/pull

# Add container
/container add remote-image=wojtekerbetowski/tailscale-mikrotik:latest \
  interface=veth1 \
  envlist=tailscale \
  root-dir=disk1/containers/tailscale \
  mounts=tailscale \
  start-on-boot=yes \
  hostname=mikrotik \
  dns=8.8.4.4,8.8.8.8
```

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

## Links

- [GitHub Repository](https://github.com/wojtekerbetowski/tailscale-mikrotik)
- [Tailscale Documentation](https://tailscale.com/kb/1019/subnets/)
- [MikroTik Container Documentation](https://help.mikrotik.com/docs/display/ROS/Container)

## License

This project is licensed under the MIT License. 