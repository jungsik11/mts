#!/bin/bash

# Docker Hub Username
DOCKER_USER="oliver173"
PROJECT="mts"

echo "🚀 Starting Image Build and Push to Docker Hub ($DOCKER_USER)..."

# 1. Build images using docker-compose
echo "Building latest images..."
docker compose build

# 2. Tag and Push each image (Fixed for macOS bash 3.2 compatibility)
IMAGES=(
    "account-server:mts-account"
    "trading-server:mts-trading"
    "admin-web:mts-admin"
    "price-generator:mts-price-generator"
    "trading-bot:mts-trading-bot"
)

for item in "${IMAGES[@]}"; do
    LOCAL_NAME="${item%%:*}"
    REMOTE_NAME="${item##*:}"
    
    LOCAL_IMG="${PROJECT}-${LOCAL_NAME}"
    REMOTE_IMG="${DOCKER_USER}/${REMOTE_NAME}:latest"
    
    echo "Tagging ${LOCAL_IMG} -> ${REMOTE_IMG}"
    docker tag "${LOCAL_IMG}:latest" "${REMOTE_IMG}"
    
    echo "Pushing ${REMOTE_IMG}..."
    docker push "${REMOTE_IMG}"
done

echo "✅ All images pushed to Docker Hub ($DOCKER_USER) successfully!"
