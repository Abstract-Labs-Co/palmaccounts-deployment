#!/bin/bash

# Deploy script for Docker Swarm with automated permission fixing
echo "🚀 Setting up Docker Swarm deployment with automatic permission fixing"

# Function to check if running as root (should avoid)
check_root() {
    if [ "$EUID" -eq 0 ]; then
        echo "⚠️  Running as root is not recommended for Docker operations"
        echo "   Consider running as a regular user with Docker group membership"
    fi
}

# Function to ensure Docker service is running
ensure_docker_running() {
    if ! systemctl is-active --quiet docker 2>/dev/null; then
        echo "🔧 Starting Docker service..."
        sudo systemctl start docker
        sudo systemctl enable docker
        sleep 3
    fi
}

# Check if running as root
check_root

# Ensure Docker service is running (Linux)
if command -v systemctl >/dev/null 2>&1; then
    ensure_docker_running
fi

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running or requires sudo. Please start Docker first."
    echo "� Attempting to fix Docker permissions..."
    
    # Check if user is in docker group
    if ! groups $USER | grep -q docker; then
        echo "📝 Adding user $USER to docker group..."
        sudo usermod -aG docker $USER
        echo "✅ User added to docker group"
        echo "⚠️  You may need to logout and login again, or run: newgrp docker"
        
        # Try to apply group membership immediately
        if command -v newgrp >/dev/null 2>&1; then
            echo "🔄 Applying group membership..."
            exec newgrp docker "$0" "$@"
        fi
    fi
    
    # Check Docker socket permissions
    if [ -S /var/run/docker.sock ]; then
        echo "🔧 Checking Docker socket permissions..."
        if ! [ -w /var/run/docker.sock ]; then
            echo "📝 Fixing Docker socket permissions..."
            sudo chmod 666 /var/run/docker.sock
        fi
    fi
    
    # Test Docker access again
    if ! docker info >/dev/null 2>&1; then
        echo "❌ Unable to fix Docker permissions automatically."
        echo "💡 Please run: sudo usermod -aG docker $USER && newgrp docker"
        exit 1
    fi
fi

# Check Docker permissions
if ! docker ps >/dev/null 2>&1; then
    echo "🔧 Docker permission issues detected. Attempting automatic fix..."
    
    # Add user to docker group if not already
    if ! groups $USER | grep -q docker; then
        echo "📝 Adding $USER to docker group..."
        sudo usermod -aG docker $USER
        
        # Try to reload group membership
        if command -v newgrp >/dev/null 2>&1; then
            echo "🔄 Reloading group membership..."
            exec newgrp docker "$0" "$@"
        else
            echo "⚠️  Please logout and login again to apply group changes"
            echo "   Or run: newgrp docker && $0"
            exit 1
        fi
    fi
    
    # Check and fix Docker daemon socket permissions
    if [ -S /var/run/docker.sock ]; then
        echo "🔧 Adjusting Docker socket permissions..."
        sudo chmod 666 /var/run/docker.sock
        sudo chown root:docker /var/run/docker.sock
    fi
    
    # Final permission test
    if ! docker ps >/dev/null 2>&1; then
        echo "❌ Unable to resolve Docker permission issues automatically."
        echo "🔧 Manual steps required:"
        echo "   1. sudo usermod -aG docker $USER"
        echo "   2. logout and login again"
        echo "   3. sudo systemctl restart docker"
        exit 1
    else
        echo "✅ Docker permissions fixed successfully!"
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
    echo "🔍 To manage services:"
    echo "  ./manage-stack.sh status       # Check all services"
    echo "  ./manage-stack.sh logs <name>  # View service logs"
    echo "  ./manage-stack.sh health       # Run health check"
    echo ""
    echo "🗂️ Available services:"
    echo "  - EFRIS: http://localhost:3201"
    echo "  - EFRIS Router: http://localhost:3122" 
    echo "  - Palm API: http://localhost:3001"
    echo "  - Palm POS: http://localhost:3002"
    echo "  - Palm Admin: http://localhost:3003"
    echo "  - PgAdmin: http://localhost:5050"
    echo "  - PostgreSQL: localhost:5432"
    echo ""
    echo "🤖 Automated Services:"
    echo "  - Watchtower: Updates check every 4 hours"
    echo "  - Cleanup: Runs every 6 hours"
    echo "  - PostgreSQL: Protected from auto-updates"
    echo ""
    echo "🔧 Docker permissions: Configured automatically"
else
    echo "❌ Failed to deploy stack"
    exit 1