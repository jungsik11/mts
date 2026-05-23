#!/bin/bash

# Docker Hub Username (User's real account)
DOCKER_USER="oliver173"
PLATFORM="linux/amd64"

echo "🚀 Starting Cross-Platform Build and Push to Docker Hub ($DOCKER_USER) for $PLATFORM using Host Docker..."

# 1. account-server
echo "Building and Pushing account-server..."
docker build --platform $PLATFORM -t $DOCKER_USER/mts-account:latest ./account_server_kt
docker push $DOCKER_USER/mts-account:latest

# 2. trading-server
echo "Building and Pushing trading-server..."
docker build --platform $PLATFORM -t $DOCKER_USER/mts-trading:latest ./trading_server_kt
docker push $DOCKER_USER/mts-trading:latest

# 3. admin-web
echo "Building and Pushing admin-web..."
docker build --platform $PLATFORM -t $DOCKER_USER/mts-admin:latest ./admin_web
docker push $DOCKER_USER/mts-admin:latest

# 4. price-generator
echo "Building and Pushing price-generator..."
docker build --platform $PLATFORM -f ./simulation/Dockerfile.gen -t $DOCKER_USER/mts-price-generator:latest ./simulation
docker push $DOCKER_USER/mts-price-generator:latest

# 5. trading-bot
echo "Building and Pushing trading-bot..."
docker build --platform $PLATFORM -f ./simulation/Dockerfile.bot -t $DOCKER_USER/mts-trading-bot:latest ./simulation
docker push $DOCKER_USER/mts-trading-bot:latest

echo "✅ All 5 images built for AMD64 and pushed to Docker Hub successfully under $DOCKER_USER!"
