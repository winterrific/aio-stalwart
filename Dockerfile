# Build stalwart-cli first to bundle it with the server
FROM rust:1.99.1@sha256:8a4e90c7946b74626488b1446f712c0fe0ed1a596cbd3d871684bc9c5433ae07 AS builder
WORKDIR /app
RUN git clone https://github.com/stalwartlabs/cli.git
WORKDIR /app/cli
RUN git checkout v2.0.0 && \
    cargo build --release --locked

# Build mail server docker container
# From https://github.com/stalwartlabs/mail-server/blob/main/Dockerfile
FROM ghcr.io/stalwartlabs/stalwart:v1.2.1@sha256:ed3153af935f0125ed0424b2a6d7d5891915a9249189dda76860a27f906b64ea

# Copy local binaries and stalwart-cli
COPY --chmod=775 bin/* /usr/local/bin/
COPY --chmod=775 --from=builder /app/cli/target/release/stalwart-cli /usr/local/bin/

# Switch user to root; needed for AIO to work due to additional package and reading certificates from caddy
USER root

# Install curl for heathcheck
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl=8.14.1-2+deb13u7 bind9-dnsutils=1:9.20.30-1~deb13u1 xz-utils=5.8.1-1+deb13u2\
    && rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -LsSf https://github.com/stalwartlabs/stalwart-migrate/releases/download/v1.0.8/stalwart-migrate-installer.sh \
    -o ./stalwart-migrate-installer.sh \
    && sh ./stalwart-migrate-installer.sh --version 1.0.8 \
    && rm ./stalwart-migrate-installer.sh

EXPOSE 10003

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD ["bash", "/usr/local/bin/healthcheck"]

ENTRYPOINT [ "/usr/local/bin/entrypoint" ]
CMD ["/usr/local/bin/stalwart", "--config", "/opt/stalwart-mail/etc/config.json"]

# Needed for Nextcloud AIO so that image cleanup can work. 
# Unfortunately, this needs to be set in the Dockerfile in order to work.
LABEL org.label-schema.vendor="Nextcloud"
