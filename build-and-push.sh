#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Default tag to "latest" if not provided as first argument
TAG=${1:-"latest"}
IMAGE="ghcr.io/litonshil/songothon-be"

echo "========================================="
echo "   Songothon Backend: Build & Push       "
echo "========================================="
echo "Target Tag:           $TAG"
echo "========================================="

# Verify docker is running
if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker daemon is not running."
    exit 1
fi

# 1. Build and tag Backend
echo ">>> Building Go Backend..."
docker build -t $IMAGE:latest -f backend/Dockerfile backend

if [ "$TAG" != "latest" ]; then
    echo ">>> Tagging backend with $TAG..."
    docker tag $IMAGE:latest $IMAGE:$TAG
fi

# 2. Push to GHCR
echo ">>> Pushing images to GHCR..."
docker push $IMAGE:latest

if [ "$TAG" != "latest" ]; then
    docker push $IMAGE:$TAG
fi

echo ">>> Build and push completed successfully!"
