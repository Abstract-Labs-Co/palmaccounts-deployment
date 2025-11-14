#!/bin/bash

# Deploy script for Docker Swarm with Watchtower
echo "🚀 Setting up Docker Swarm deployment with Watchtower for automated updates"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Initialize Docker Swarm if not already initialized
if ! docker info | grep -q "Swarm: active"; then
    echo "🔧 Initializing Docker Swarm..."
    docker swarm init
    if [ $? -eq 0 ]; then
        echo "✅ Docker Swarm initialized successfully"
    else
        echo "❌ Failed to initialize Docker Swarm"
        exit 1
    fi
else
    echo "✅ Docker Swarm is already active"
fi

# Create the tmp directory for efris-router if it doesn't exist
if [ ! -d "./tmp" ]; then
    echo "📁 Creating tmp directory for efris-router..."
    mkdir -p ./tmp
    echo "✅ tmp directory created"
fi

# Deploy the stack
echo "🚀 Deploying the stack..."
docker stack deploy -c docker-compose.yml palm-stack

if [ $? -eq 0 ]; then
    echo "✅ Stack deployed successfully!"
    echo ""
    echo "📊 Stack status:"
    docker stack services palm-stack
    echo ""
    echo "🔍 To monitor services:"
    echo "  docker stack services palm-stack"
    echo "  docker service logs palm-stack_<service-name>"
    echo ""
    echo "🗂️ Available services:"
    echo "  - EFRIS: http://localhost:3005"
    echo "  - EFRIS Router: http://localhost:3122"
    echo "  - Palm API: http://localhost:3001"
    echo "  - Palm POS: http://localhost:3002"
    echo "  - Palm Admin: http://localhost:3003"
    echo "  - PgAdmin: http://localhost:5050"
    echo "  - PostgreSQL: localhost:5432"
    echo ""
    echo "🤖 Watchtower is now monitoring for image updates every 30 minutes"
    echo "    It will automatically update containers when new images are available"
else
    echo "❌ Failed to deploy stack"
    exit 1
fi