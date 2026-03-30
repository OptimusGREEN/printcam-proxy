# printcam-proxy

RTSP to MJPEG proxy for OctoPrint.

Converts an RTSP camera stream into an MJPEG HTTP stream that OctoPrint can use.

## Endpoints

| Path | Description |
|------|-------------|
| `/?action=stream` | MJPEG stream (multipart/x-mixed-replace) |
| `/?action=snapshot` | Single JPEG snapshot |
| `/` | Alias for `/?action=stream` |

## Configuration

Set via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `RTSP_URL` | `rtsp://10.0.0.238:554/unicast` | Source RTSP stream URL |
| `PORT` | `8889` | HTTP port to listen on |
| `FPS` | `15` | Output frame rate |
| `QUALITY` | `5` | JPEG quality (2–31, lower = better) |

## Usage

### Docker (recommended)

```yaml
services:
  printcam-proxy:
    image: ghcr.io/optimusgreen/printcam-proxy:latest
    container_name: printcam-proxy
    restart: unless-stopped
    network_mode: host
    environment:
      - RTSP_URL=rtsp://<camera-ip>:554/unicast
      - PORT=8889
      - FPS=15
      - QUALITY=5
```

### Native Linux (systemd)

A one-shot installer sets up `printcam-proxy` as a systemd service.  
It detects the distro, installs `ffmpeg` and `python3` if needed, and
starts the proxy automatically on boot.

**Requirements:** Linux with systemd, root / sudo access.  
Supported package managers: `apt-get`, `dnf`, `yum`, `pacman`, `zypper`, `apk`.

```bash
# Clone / download the repo, then:
sudo bash install.sh
```

The script prompts for each setting interactively.  
You can also pass values as environment variables for unattended installs:

```bash
sudo RTSP_URL=rtsp://<camera-ip>:554/unicast PORT=8889 FPS=15 QUALITY=5 bash install.sh
```

Configuration is stored in `/etc/printcam-proxy.env`.  
After editing it, apply with:

```bash
sudo systemctl restart printcam-proxy
```

Useful service commands:

```bash
sudo systemctl status  printcam-proxy
sudo journalctl -fu    printcam-proxy
sudo systemctl restart printcam-proxy
sudo systemctl disable printcam-proxy   # stop autostart
```

In OctoPrint, set:
- **Stream URL**: `http://<host>:8889/?action=stream`
- **Snapshot URL**: `http://<host>:8889/?action=snapshot`
