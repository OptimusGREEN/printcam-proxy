#!/usr/bin/env python3
"""MJPEG proxy: converts an RTSP stream to an MJPEG HTTP stream for OctoPrint."""

import os
import queue
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler
from socketserver import ThreadingMixIn, TCPServer

RTSP_URL = os.environ.get("RTSP_URL", "rtsp://10.0.0.238:554/unicast")
PORT = int(os.environ.get("PORT", "8889"))
FPS = int(os.environ.get("FPS", "15"))
QUALITY = int(os.environ.get("QUALITY", "5"))

BOUNDARY = b"frame"

_frame_lock = threading.Lock()
_latest_frame = None

_clients_lock = threading.Lock()
_client_queues: list = []


def _broadcast(frame: bytes) -> None:
    global _latest_frame
    with _frame_lock:
        _latest_frame = frame
    with _clients_lock:
        for q in _client_queues[:]:
            try:
                q.put_nowait(frame)
            except queue.Full:
                pass  # drop stale frame for slow clients


def capture_loop() -> None:
    """Run ffmpeg in a loop, parse JPEG frames and broadcast to all clients."""
    cmd = [
        "ffmpeg",
        "-rtsp_transport", "tcp",
        "-i", RTSP_URL,
        "-c:v", "mjpeg",
        "-q:v", str(QUALITY),
        "-r", str(FPS),
        "-f", "image2pipe",
        "pipe:1",
    ]
    while True:
        proc = None
        try:
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
            )
            buf = bytearray()
            while True:
                chunk = proc.stdout.read(65536)
                if not chunk:
                    break
                buf.extend(chunk)
                # Extract complete JPEG frames delimited by SOI/EOI markers
                while True:
                    start = buf.find(b"\xff\xd8")
                    if start == -1:
                        buf = bytearray()
                        break
                    end = buf.find(b"\xff\xd9", start + 2)
                    if end == -1:
                        # Keep partial frame; discard leading garbage
                        if start > 0:
                            del buf[:start]
                        break
                    frame = bytes(buf[start : end + 2])
                    del buf[: end + 2]
                    _broadcast(frame)
        except Exception as exc:
            print(f"[capture] error: {exc}", flush=True)
        finally:
            if proc is not None:
                try:
                    proc.kill()
                    proc.wait()
                except Exception:
                    pass
        time.sleep(2)  # brief pause before reconnecting


class MJPEGHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):  # silence default request log
        pass

    def do_GET(self):
        if self.path in ("/", "/?action=stream"):
            self._serve_stream()
        elif self.path == "/?action=snapshot":
            self._serve_snapshot()
        else:
            self.send_error(404)

    def _serve_stream(self):
        self.send_response(200)
        self.send_header(
            "Content-Type",
            f"multipart/x-mixed-replace; boundary=--{BOUNDARY.decode()}",
        )
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Pragma", "no-cache")
        self.end_headers()

        q: queue.Queue = queue.Queue(maxsize=2)  # small queue keeps latency low; stale frames are dropped
        with _clients_lock:
            _client_queues.append(q)
        try:
            while True:
                try:
                    frame = q.get(timeout=10)
                except queue.Empty:
                    continue
                try:
                    self.wfile.write(
                        b"--" + BOUNDARY + b"\r\n"
                        b"Content-Type: image/jpeg\r\n\r\n"
                        + frame
                        + b"\r\n"
                    )
                    self.wfile.flush()
                except Exception:
                    break
        finally:
            with _clients_lock:
                try:
                    _client_queues.remove(q)
                except ValueError:
                    pass

    def _serve_snapshot(self):
        with _frame_lock:
            frame = _latest_frame
        if frame is None:
            self.send_error(503, "No frame available yet")
            return
        self.send_response(200)
        self.send_header("Content-Type", "image/jpeg")
        self.send_header("Content-Length", str(len(frame)))
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(frame)


class ThreadedHTTPServer(ThreadingMixIn, TCPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    threading.Thread(target=capture_loop, daemon=True).start()
    print(f"RTSP source:  {RTSP_URL}", flush=True)
    print(f"Stream URL:   http://0.0.0.0:{PORT}/?action=stream", flush=True)
    print(f"Snapshot URL: http://0.0.0.0:{PORT}/?action=snapshot", flush=True)
    server = ThreadedHTTPServer(("0.0.0.0", PORT), MJPEGHandler)
    server.serve_forever()
