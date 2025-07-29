FROM debian:bookworm-slim

RUN apt-get update && \
  apt-get install --no-install-recommends --yes \
    ca-certificates \
    libfuse2 \
    seafile-cli \
    oathtool && \
  apt-get clean && \
  apt-get autoclean && \
  rm -rf \
    /var/log/fsck/*.log \
    /var/log/apt/*.log \
    /var/cache/debconf/*.dat-old \
    /var/lib/apt/lists/*

ENV SFCLI_BASE_DIR=/seafile
ENV SFCLI_CONFIG_DIR=${SFCLI_BASE_DIR}/config
ENV SFCLI_LIB_DIR=/libraries

COPY VERSION .
COPY entrypoint.sh .

RUN chmod +x entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
