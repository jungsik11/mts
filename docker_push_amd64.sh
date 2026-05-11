#!/bin/bash

# Docker Hub Username
DOCKER_USER="oliver173"
PLATFORM="linux/amd64"

echo "🚀 Starting Cross-Platform Build and Push to Docker Hub ($DOCKER_USER) for $PLATFORM..."

# Create buildx builder if not exists
docker buildx create --use --name mybuilder 2>/dev/null || docker buildx use mybuilder

# 1. account-server
echo "Building and Pushing account-server (mts-account)..."
docker buildx build --platform $PLATFORM -t $DOCKER_USER/mts-account:latest ./account_server_kt --push

# 2. trading-server
echo "Building and Pushing trading-server (mts-trading)..."
docker buildx build --platform $PLATFORM -t $DOCKER_USER/mts-trading:latest ./trading_server_kt --push

# 3. admin-web
echo "Building and Pushing admin-web (mts-admin)..."
docker buildx build --platform $PLATFORM -t $DOCKER_USER/mts-admin:latest ./admin_web --push

# 4. price-generator
echo "Building and Pushing price-generator (mts-price-generator)..."
docker buildx build --platform $PLATFORM -f ./simulation/Dockerfile.gen -t $DOCKER_USER/mts-price-generator:latest ./simulation --push

# 5. trading-bot
echo "Building and Pushing trading-bot (mts-trading-bot)..."
docker buildx build --platform $PLATFORM -f ./simulation/Dockerfile.bot -t $DOCKER_USER/mts-trading-bot:latest ./simulation --push

echo "✅ All 5 images built for AMD64 and pushed to Docker Hub successfully!"
