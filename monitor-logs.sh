#!/bin/bash

# Multi-service log monitor for Palm Stack
echo "🔍 Palm Stack Multi-Service Log Monitor"
echo "======================================"
echo "Press Ctrl+C to stop monitoring"
echo ""

STACK_NAME="palm-stack"

# Check if a specific service was requested
if [ "$1" != "" ]; then
    echo "Monitoring logs for service: $1"
    docker service logs -f --timestamps ${STACK_NAME}_$1
else
    echo "Monitoring ALL services logs (interleaved)"
    echo "Use: $0 <service-name> to monitor specific service"
    echo ""
    
    # Get list of all services
    SERVICES=$(docker service ls --filter "name=${STACK_NAME}" --format "{{.Name}}" | sed "s/${STACK_NAME}_//g")
    
    echo "Available services: $SERVICES"
    echo ""
    echo "=== Combined Logs (all services) ==="
    
    # Monitor all services simultaneously
    for service in $SERVICES; do
        echo "Starting monitor for: $service"
        docker service logs -f --timestamps ${STACK_NAME}_${service} 2>/dev/null &
    done
    
    # Wait for all background processes
    wait
fi