#!/bin/sh
exec ffmpeg \
  -rtsp_transport tcp \
  -i rtsp://10.79.80.238:554/unicast \
  -c:v mjpeg \
  -q:v 5 \
  -r 15 \
  -f mpjpeg \
  -boundary_tag frame \
  -listen 1 \
  http://0.0.0.0:8889