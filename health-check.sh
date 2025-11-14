#!/bin/bash

# System Health Monitor for Palm Stack
echo "🩺 Palm Stack Health Monitor"
echo "============================="

# Check Docker Swarm status
echo "🔵 Docker Swarm Status:"
docker info | grep "Swarm:"

echo ""
echo "📊 Service Status:"
docker stack services palm-stack --format "table {{.Name}}\t{{.Replicas}}\t{{.Image}}"

echo ""
echo "⚠️  Failed Services:"
FAILED=$(docker service ls --filter 'name=palm-stack' --format "{{.Name}} {{.Replicas}}" | grep "0/")
if [ -z "$FAILED" ]; then
    echo "✅ All services are running"
else
    echo "$FAILED"
fi

echo ""
echo "💾 Resource Usage:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" | head -10

echo ""
echo "🗃️ Storage Usage:"
docker system df

echo ""
echo "📋 Recent Service Logs (last 5 lines per service):"
for service in efris efris-router api pos admin mongo postgres watchtower docker-cleanup; do
    echo "--- $service ---"
    docker service logs palm-stack_$service --tail 5 2>/dev/null || echo "Service not found or no logs"
    echo ""
done

echo ""
echo "🔍 Health Checks:"
docker ps --filter "name=palm-stack" --format "table {{.Names}}\t{{.Status}}"

echo ""
echo "📅 Last Updated: $(date)"
echo "============================="