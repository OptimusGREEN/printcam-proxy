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

In OctoPrint, set:
- **Stream URL**: `http://<host>:8889/?action=stream`
- **Snapshot URL**: `http://<host>:8889/?action=snapshot`
