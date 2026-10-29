# Build stalwart-cli first to bundle it with the server
FROM rust:1.99.0@sha256:81015672d6939b0265f09adf96d5de125482bb1330106076956b0518e74edc90 AS builder
WORKDIR /app
RUN git clone https://github.com/stalwartlabs/cli.git
WORKDIR /app/cli
RUN git checkout v1.0.13 && \
    cargo build --release

# Build mail server docker container
# From https://github.com/stalwartlabs/mail-server/blob/main/Dockerfile
FROM ghcr.io/stalwartlabs/stalwart:v1.0.1@sha256:b9da4df8b4efc06bc926dd6e990bdeb0ad7b9261a7c3893d74b0461a00bb389b

# Copy local binaries and stalwart-cli
COPY --chmod=775 bin/* /usr/local/bin/
COPY --chmod=775 --from=builder /app/cli/target/release/stalwart-cli /usr/local/bin/

# Switch user to root; needed for AIO to work due to additional package and reading certificates from caddy
USER root

# Install curl for heathcheck
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl=8.14.1-2+deb13u7 bind9-dnsutils=1:9.20.30-1~deb13u1 \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 10003

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD ["bash", "/usr/local/bin/healthcheck"]

ENTRYPOINT [ "/usr/local/bin/entrypoint" ]
CMD ["/usr/local/bin/stalwart", "--config", "/opt/stalwart-mail/etc/config.json"]

# Needed for Nextcloud AIO so that image cleanup can work. 
# Unfortunately, this needs to be set in the Dockerfile in order to work.
LABEL org.label-schema.vendor="Nextcloud"
