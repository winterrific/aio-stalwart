# Build stalwart-cli first to bundle it with the server
FROM rust:1.98.1@sha256:a8a5f0a1e5fe7dfe1d352591e4a1c7dd2c08fd70475cae872cf3458ba0df0546 AS builder
WORKDIR /app
RUN git clone https://github.com/stalwartlabs/cli.git
WORKDIR /app/cli
RUN git checkout v1.0.13 && \
    cargo build --release

# Build mail server docker container
# From https://github.com/stalwartlabs/mail-server/blob/main/Dockerfile
FROM ghcr.io/stalwartlabs/stalwart:v0.16.27@sha256:c429b311c93db5606598abc1c68225a85a6953183848ae01bee9c6a98885836c

# Copy local binaries and stalwart-cli
COPY --chmod=775 bin/* /usr/local/bin/
COPY --chmod=775 --from=builder /app/cli/target/release/stalwart-cli /usr/local/bin/

# Switch user to root; needed for AIO to work due to additional package and reading certificates from caddy
USER root

# Install curl for heathcheck
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl bind9-dnsutils \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 10003

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD ["bash", "/usr/local/bin/healthcheck"]

ENTRYPOINT [ "/usr/local/bin/entrypoint" ]
CMD ["/usr/local/bin/stalwart", "--config", "/opt/stalwart-mail/etc/config.json"]

# Needed for Nextcloud AIO so that image cleanup can work. 
# Unfortunately, this needs to be set in the Dockerfile in order to work.
LABEL org.label-schema.vendor="Nextcloud"
