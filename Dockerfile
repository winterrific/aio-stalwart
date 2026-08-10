# From https://github.com/stalwartlabs/mail-server/blob/main/Dockerfile
FROM ghcr.io/stalwartlabs/stalwart:v0.16.16@sha256:66ae90f2753ec1dabd70f69cad7da9f0598d2628a04193ce2b08c7263d47aced

COPY --chmod=775 bin/* /usr/local/bin/

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl dnsutils \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 10003

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD bash /usr/local/bin/healthcheck

ENTRYPOINT [ "/usr/local/bin/entrypoint" ]
CMD ["/usr/local/bin/stalwart", "--config", "/opt/stalwart-mail/etc/config.toml"]

# Needed for Nextcloud AIO so that image cleanup can work. 
# Unfortunately, this needs to be set in the Dockerfile in order to work.
LABEL org.label-schema.vendor="Nextcloud"
