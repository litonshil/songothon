#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "========================================="
echo "   Songothon: Pull & Deploy VPS Script   "
echo "========================================="

# 1. GHCR Authentication (Optional)
# If GHCR_USER and GHCR_TOKEN are defined in environment, log in automatically
if [ -n "$GHCR_USER" ] && [ -n "$GHCR_TOKEN" ]; then
    echo ">>> Logging in to GitHub Container Registry..."
    echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin
else
    echo ">>> Skipping GHCR login (relying on pre-authenticated session or public packages)."
fi

# 2. Pull latest images
echo ">>> Pulling Docker images defined in docker-compose.prod.yml..."
docker compose -f docker-compose.prod.yml pull

# 3. Deploy/Restart services
echo ">>> Restarting services with docker compose..."
docker compose -f docker-compose.prod.yml up -d --remove-orphans

echo ">>> Cleaning up old unused images..."
docker image prune -f

echo "========================================="
echo "   Deployment completed successfully!    "
echo "========================================="
