FROM gitpod/workspace-full

USER root

# Install Docker Compose
RUN apt-get update \
    && apt-get install -y docker-compose \
    && usermod -aG docker gitpod \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER gitpod
