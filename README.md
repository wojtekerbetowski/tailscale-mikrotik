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
# Create a RAM disk (tmpfs). This is ONLY a staging area for the image .tar.
# It is wiped on reboot, which is fine: the .tar is only read during import.
/disk add type=tmpfs tmpfs-max-size=200M

# Create the container root dir and the persistent state dir.
# Both live on the router's internal flash, so they SURVIVE reboots.
/file/mkdir containers/tailscale
/file/mkdir containers/tailscale-state
```

> **Persistence note:** the hAP ax² has no NVMe/USB by default — its only
> persistent storage is the internal flash. Earlier versions of this guide
> referenced `/nvme1/...`; on a stock hAP ax² that is just a folder on flash and
> is not needed. Keep the container `root-dir` and the state mount on flash (as
> above) and the node stays authenticated across reboots. Do **not** point
> `root-dir` or the state mount at the tmpfs disk — it is cleared on reboot.

Define the persistent state mount (the `/container/add` below references it):

```routeros
# Persist Tailscale's state (node key, etc.) on flash so the node stays
# authenticated across reboots and container re-creation.
/container/mounts/add name=tailscale_state src=containers/tailscale-state dst=/var/lib/tailscale
```

> **Why one mount, not two?** A common broken pattern defines two mounts that
> both target `/var/lib/tailscale` (e.g. `src=containers/tailscale` **and**
> `src=containers/tailscale/state`). They conflict, and the first one mounts the
> container's `root-dir` into itself. Use the single mount above instead.

### 3. Environment Variables

Configure the required environment variables:

```routeros
/container/envs/add list=tailscale key=AUTH_KEY value=your-auth-key-here
/container/envs/add list=tailscale key=ADVERTISE_ROUTES value=192.168.88.0/24
/container/envs/add list=tailscale key=CONTAINER_GATEWAY value=192.168.98.1
/container/envs/add list=tailscale key=TAILSCALE_ARGS value="--accept-routes --advertise-exit-node"
```

> **`list=` vs `name=`:** current RouterOS (verified on 7.20) expects `list=` for
> the env-list name; older releases used `name=`. If one returns
> `expected end of command`, use the other.
>
> **Use `AUTH_KEY`, not `TS_AUTH_KEY`:** the entrypoint (`tailscale.sh`) reads
> `AUTH_KEY`. Setting only `TS_AUTH_KEY` leaves the key empty, and the container
> falls back to printing an interactive `https://login.tailscale.com/a/...` URL
> in the logs instead of authenticating. Use a **reusable** key so restarts work.

### 4. Container Setup

1. Build the ARM64 container image:
```bash
./build-arm64.sh
```

2. Transfer the container image to the router:
```bash
scp tailscale-arm64.tar admin@192.168.88.1:tmp1/
```

3. Add the container to RouterOS (enter as a single line — RouterOS does not
   accept the multi-line form):
```routeros
/container/add file=tmp1/tailscale-arm64.tar interface=veth-tailscale envlist=tailscale root-dir=containers/tailscale mounts=tailscale_state start-on-boot=yes hostname=mikrotik-tailscale dns=8.8.4.4,8.8.8.8 logging=yes
```

The container extracts asynchronously. Watch `/container/print` until it shows
`stopped` (not `extracting`), then start it and follow the logs:
```routeros
/container/start 0
/log/print where topics~"container"
```

### 5. Authorize the node in Tailscale

Because this node advertises subnet routes and an exit node, you must approve
them once in the Tailscale admin console:

1. Open **https://login.tailscale.com/admin/machines**.
2. Find `mikrotik-tailscale`, and under its route settings **approve the subnet
   route** (`192.168.88.0/24`) and **enable it as an exit node**.
3. (Recommended) **Disable key expiry** for the node so it stays connected
   across reboots without re-authentication.

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

# Add environment variable (use list= on current RouterOS; older used name=)
/container/envs/add list=tailscale key=AUTH_KEY value=your-auth-key-here

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
   - Symptom: `*** error getting layer file` / `import error: failed to load next entry`
   - Cause: modern Docker (BuildKit / containerd image store) writes `docker save`
     archives as OCI layout with **gzip-compressed** layers, which RouterOS cannot
     import. (The tar transferred fine — the format is the problem.)
   - Solution: build with the provided `./build-arm64.sh`, which now repacks the
     image with uncompressed layers via `pack-for-routeros.py`. To fix a tar you
     already have: `python3 pack-for-routeros.py old.tar tailscale-arm64.tar`.

3. **Container starts but never authenticates (prints a login URL)**
   - Symptom: logs show `To authenticate, visit: https://login.tailscale.com/a/...`
   - Cause: the auth key was not passed. The entrypoint reads `AUTH_KEY`; setting
     only `TS_AUTH_KEY` leaves it empty.
   - Solution: `/container/envs/add list=tailscale key=AUTH_KEY value=<reusable-key>`,
     then restart the container.

4. **`health(warnable=router): ... iptables (nf_tables): Could not fetch rule set generation id`**
   - This warning is expected on RouterOS — the container cannot program the host's
     netfilter. Routing/NAT is handled by RouterOS itself, so connectivity still
     works. No action needed.

5. **Container Not Starting**
   - Check container logs: `/log/print where topics~"container"`
   - Verify environment variables: `/container/envs/print`
   - Ensure mount points exist and are accessible

### Reboot persistence

The container `root-dir` (`containers/tailscale`) and the state mount
(`containers/tailscale-state`) live on internal flash, and the container has
`start-on-boot=yes`, so after a reboot it auto-starts and reconnects using the
persisted node key — no re-upload of the `.tar` and no re-auth required. Only the
import `.tar` on the tmpfs disk is lost on reboot, which does not affect runtime.

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
