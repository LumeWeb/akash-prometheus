ARG PROMETHEUS_VERSION=3

FROM ghcr.io/lumeweb/promster:develop AS promster
FROM bitnami/prometheus:${PROMETHEUS_VERSION}

COPY --from=promster /bin/promster /usr/bin/promster

USER root

# Define build arguments (after FROM to be available during build)
ARG SUPERCRONIC_VERSION=0.2.33

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    ca-certificates \
    && rm -rf /var/cache/apt/*

# Install MinIO client
RUN wget https://dl.min.io/client/mc/release/linux-amd64/mc \
    && chmod +x mc \
    && mv mc /usr/local/bin/

# Install supercronic
RUN wget https://github.com/aptible/supercronic/releases/download/v${SUPERCRONIC_VERSION}/supercronic-linux-amd64 -O /usr/local/bin/supercronic \
    && chmod +x /usr/local/bin/supercronic

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh

# Make entrypoint script executable
RUN chmod +x /entrypoint.sh

# Copy config-validator, backup-manager, and storage-manager scripts
COPY bin/config-validator /bin/config-validator
COPY bin/backup-manager /bin/backup-manager
COPY bin/storage-manager /bin/storage-manager

# Make scripts executable
RUN chmod +x /bin/config-validator
RUN chmod +x /bin/backup-manager
RUN chmod +x /bin/storage-manager

ENTRYPOINT [ "/entrypoint.sh" ]
