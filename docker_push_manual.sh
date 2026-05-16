#!/bin/bash
DOCKER_USER="oliver173"
PLATFORM="linux/amd64"

echo "🚀 Building and Pushing remaining images..."

# 1. trading-server
echo "Building and Pushing trading-server..."
docker buildx build --platform $PLATFORM -t $DOCKER_USER/mts-trading:latest ./trading_server_kt --push

# 2. admin-web
echo "Building and Pushing admin-web..."
docker buildx build --platform $PLATFORM -t $DOCKER_USER/mts-admin:latest ./admin_web --push

# 3. price-generator
echo "Building and Pushing price-generator..."
docker buildx build --platform $PLATFORM -f ./simulation/Dockerfile.gen -t $DOCKER_USER/mts-price-generator:latest ./simulation --push

# 4. trading-bot
echo "Building and Pushing trading-bot..."
docker buildx build --platform $PLATFORM -f ./simulation/Dockerfile.bot -t $DOCKER_USER/mts-trading-bot:latest ./simulation --push

echo "✅ All remaining images pushed!"
