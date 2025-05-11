# Tailscale Container Optimizations

This document outlines the optimizations made to reduce the Tailscale container image size while maintaining full functionality.

## Optimization Summary

The container image has been optimized to be under 30MB, making it ideal for MikroTik routers and other devices with limited storage capacity.

| Metric | Before | After | Reduction |
|--------|--------|-------|-----------|
| Image Size | ~50.5MB | ~29MB | ~42% |

## Key Optimizations

### 1. Build Process Optimizations

- **Removed Pre-building Dependencies**: Eliminated the separate step for pre-building Go dependencies, which was creating an unnecessary layer
- **Optimized Build Flags**: Used aggressive build flags to reduce binary size:
  ```
  -ldflags="-w -s"
  ```
  - `-w`: Disables DWARF debugging information
  - `-s`: Disables symbol table
- **Trimpath Option**: Added `-trimpath` to remove file system paths from the resulting binary, further reducing size

### 2. Binary Compression

- **UPX Compression**: Applied UPX compression with maximum settings to the Tailscale binaries:
  ```
  upx --best --lzma /go/bin/tailscale
  upx --best --lzma /go/bin/tailscaled
  ```
  - `--best`: Uses the best compression algorithm
  - `--lzma`: Uses LZMA compression for maximum size reduction

### 3. Base Image Optimization

- **Alpine Linux**: Used Alpine 3.20 as the base image, which is already lightweight
- **Minimal Dependencies**: Installed only the essential packages required for Tailscale to function:
  - `ca-certificates`: Required for SSL/TLS connections
  - `iptables` and `ip6tables`: Required for network routing
  - `iproute2-minimal`: Minimal version of iproute2 for network configuration

### 4. Layer Optimization

- **Reduced Layer Count**: Minimized the number of layers in the Dockerfile
- **Combined RUN Commands**: Grouped related commands to reduce layer size
- **Cleanup in Same Layer**: Performed cleanup operations in the same layer as installations

### 5. Filesystem Cleanup

- **Removed Unnecessary Files**:
  ```
  rm -rf /usr/share/man /usr/share/doc /tmp/* /var/tmp/* /var/cache/apk/*
  rm -rf /etc/init.d /etc/conf.d /etc/logrotate.d /etc/udhcpd
  rm -rf /lib/firmware /lib/modules /media /mnt /opt /srv
  rm -rf /usr/lib/modules-load.d /usr/lib/systemd /usr/lib/udev
  ```
- **Stripped Binaries**:
  ```
  find /sbin /usr/sbin /bin /usr/bin -type f -exec strip --strip-all {} \; 2>/dev/null || true
  ```
- **Cleared Package Cache**:
  ```
  rm -rf /var/cache/apk/*
  ```

### 6. Runtime Considerations

- **TUN Device Support**: Added proper TUN device creation to ensure Tailscale can establish connections:
  ```
  mkdir -p /dev/net
  mknod /dev/net/tun c 10 200
  chmod 600 /dev/net/tun
  ```
- **PATH Configuration**: Explicitly set the PATH environment variable to ensure all binaries are found:
  ```
  ENV PATH="/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin"
  ```
- **Script Adaptations**: Enhanced the startup script with additional checks and debugging information

## Troubleshooting Fixes

After initial optimization, we encountered and fixed several issues:

1. **Missing iptables**: Fixed by ensuring iptables is properly installed and in the PATH
2. **TUN Device**: Added proper TUN device creation in both Dockerfile and startup script
3. **Permission Issues**: Added verification steps in the startup script to check for required permissions
4. **Debugging Information**: Added diagnostic output to help troubleshoot any remaining issues

## Results

These optimizations resulted in a fully functional Tailscale container that is approximately 42% smaller than the original, making it more suitable for deployment on devices with limited storage capacity.

## Future Optimization Possibilities

1. **Multi-stage Build Refinement**: Further optimize the multi-stage build process
2. **Dependency Analysis**: Analyze and potentially remove unnecessary dependencies
3. **Custom Tailscale Build**: Consider building a custom version of Tailscale with only the required features
4. **Alternative Base Images**: Explore even smaller base images like `scratch` or `busybox` if compatible

## Testing

The optimized image has been tested to ensure it maintains all the functionality of the original image, including:

- Tailscale connectivity
- Subnet routing
- IP forwarding
- Authentication with both Tailscale and Headscale servers 