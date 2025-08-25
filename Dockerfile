# Dockerfile
FROM python:3.13-slim

# packages: tini (clean PID 1), gosu (drop privileges), nc (for healthchecks)
RUN apt-get update && apt-get install -y --no-install-recommends \
  tini gosu netcat-openbsd \
  && rm -rf /var/lib/apt/lists/*

# Reticulum
RUN pip install --no-cache-dir rns

# app user
RUN groupadd -g 10001 rns && useradd -m -u 10001 -g 10001 -s /bin/bash rns

# entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# keep both data dirs mountable; we'll use DATA_DIR env to choose
VOLUME ["/home/rns/.reticulum", "/data"]

ENTRYPOINT ["tini","--","/entrypoint.sh"]
