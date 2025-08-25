FROM python:3.13-slim
RUN pip install --no-cache-dir rns
# optional: tini for clean shutdowns
RUN apt-get update && apt-get install -y --no-install-recommends tini && rm -rf /var/lib/apt/lists/*
# run as non-root
RUN useradd -m -u 10001 rns
USER rns
WORKDIR /home/rns
VOLUME ["/home/rns/.reticulum"]
ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["rnsd","-vv"]
