#!/bin/sh
RTSP_URL="${RTSP_URL:-rtsp://10.0.0.1:554/unicast}"
HTTP_PORT="${HTTP_PORT:-8889}"
VIDEO_QUALITY="${VIDEO_QUALITY:-5}"
FRAMERATE="${FRAMERATE:-15}"

exec ffmpeg \
  -rtsp_transport tcp \
  -i "$RTSP_URL" \
  -c:v mjpeg \
  -q:v "$VIDEO_QUALITY" \
  -r "$FRAMERATE" \
  -f mpjpeg \
  -boundary_tag frame \
  -listen 1 \
  "http://0.0.0.0:${HTTP_PORT}"