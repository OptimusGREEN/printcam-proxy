FROM alpine:3.19
RUN apk add --no-cache ffmpeg python3
COPY server.py /server.py
ENTRYPOINT ["python3", "/server.py"]