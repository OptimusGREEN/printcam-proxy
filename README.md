# printcam-proxy

A lightweight Docker container that converts an RTSP camera stream into an MJPEG-over-HTTP stream, making IP cameras compatible with [OctoPrint](https://octoprint.org/) and other tools that consume MJPEG webcam feeds.

Built on [Alpine Linux](https://alpinelinux.org/) with [FFmpeg](https://ffmpeg.org/).

## How it works

The container uses FFmpeg to pull an RTSP stream from your camera over TCP and re-streams it as a multipart JPEG (MJPEG) stream over HTTP. OctoPrint (and many other tools) can consume this HTTP URL directly as a webcam feed.

```
Camera (RTSP) ──► printcam-proxy (FFmpeg) ──► OctoPrint (HTTP MJPEG)
```

## Prerequisites

- Docker (or Docker Compose)
- An IP camera that exposes an RTSP stream

## Quick start

### Docker Compose (recommended)

1. Download [`docker-compose.yml`](docker-compose.yml):

   ```yaml
   services:
     printcam-proxy:
       image: ghcr.io/optimusgreen/printcam-proxy:latest
       container_name: printcam-proxy
       restart: unless-stopped
       network_mode: host
       environment:
         - RTSP_URL=rtsp://your-camera-ip:554/unicast
   ```

2. Set `RTSP_URL` to your camera's RTSP stream address.

3. Start the container:

   ```bash
   docker compose up -d
   ```

### Docker run

```bash
docker run -d \
  --name printcam-proxy \
  --restart unless-stopped \
  --network host \
  -e RTSP_URL=rtsp://your-camera-ip:554/unicast \
  ghcr.io/optimusgreen/printcam-proxy:latest
```

## Configuration

All settings are controlled via environment variables:

| Variable        | Default                          | Description                                      |
|-----------------|----------------------------------|--------------------------------------------------|
| `RTSP_URL`      | `rtsp://10.0.0.1:554/unicast`    | Full RTSP URL of the camera stream               |
| `HTTP_PORT`     | `8889`                           | Port on which the MJPEG stream is served         |
| `VIDEO_QUALITY` | `5`                              | MJPEG quality (2 = best, 31 = worst)             |
| `FRAMERATE`     | `15`                             | Output framerate (frames per second)             |

> **Note:** `network_mode: host` is used so the container can reach cameras on your local network and bind directly to the host's port without additional port-mapping configuration.

## Accessing the stream

Once running, the MJPEG stream is available at:

```
http://<host-ip>:<HTTP_PORT>
```

For example, with default settings on the same machine:

```
http://localhost:8889
```

## OctoPrint setup

1. In OctoPrint, open **Settings → Webcam & Timelapse**.
2. Set **Stream URL** to:
   ```
   http://<host-ip>:8889
   ```
   Replace `<host-ip>` with the IP address of the machine running printcam-proxy (or `localhost` / `127.0.0.1` if OctoPrint runs on the same host).
3. Leave **Snapshot URL** blank, or point it at a single-frame grab tool if needed.
4. Save and reload the OctoPrint tab — the webcam feed should appear.

## Building locally

```bash
git clone https://github.com/OptimusGREEN/printcam-proxy.git
cd printcam-proxy
docker build -t printcam-proxy .
```

Run your local build:

```bash
docker run -d \
  --name printcam-proxy \
  --restart unless-stopped \
  --network host \
  -e RTSP_URL=rtsp://your-camera-ip:554/unicast \
  printcam-proxy
```

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Container exits immediately | Invalid or unreachable RTSP URL | Check `RTSP_URL` and camera connectivity |
| Black screen / no stream | Wrong RTSP path | Consult your camera's manual for the correct RTSP URL path |
| High latency | Network congestion or high quality setting | Lower `FRAMERATE` or increase `VIDEO_QUALITY` value |
| Port conflict | Another service using port 8889 | Change `HTTP_PORT` to a free port |

View container logs for more detail:

```bash
docker logs printcam-proxy
```

