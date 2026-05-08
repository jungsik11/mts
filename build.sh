#!/bin/bash

# MTS Project Build & Deployment Script

echo "🚀 Starting MTS System Build & Deployment..."

# 1. Stop existing containers
echo "Stopping existing containers..."
docker compose down

# 2. Clean up build artifacts (Optional but recommended)
echo "Cleaning up local build artifacts..."
rm -rf admin_web/dist
rm -rf account_server_kt/build
rm -rf trading_server_kt/build

# 3. Build containers without cache to ensure freshness
echo "Building Docker images (this may take a few minutes)..."
docker compose build --no-cache

# 4. Start all services
echo "Starting all services..."
docker compose up -d

# 5. Check status
echo "Checking service status..."
docker compose ps

echo "✅ Deployment completed successfully!"
echo "Admin Dashboard: http://localhost:3000"
echo "Trading Server: http://localhost:9001"
echo "Account Server: http://localhost:9000"
