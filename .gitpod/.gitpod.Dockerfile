# Gitpod Classic Dockerfile
# Use the official Gitpod full workspace image
FROM gitpod/workspace-full

# Switch to root to install Docker Compose
USER root

# Install Docker Compose
RUN apt-get update \
    && apt-get install -y docker-compose \
    && usermod -aG docker gitpod \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Revert to gitpod user
USER gitpod
