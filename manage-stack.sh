#!/bin/bash

# Management script for Docker Swarm stack
STACK_NAME="palm-stack"

case "$1" in
    status)
        echo "📊 Stack Services Status:"
        docker stack services $STACK_NAME
        echo ""
        echo "📋 Stack Processes:"
        docker stack ps $STACK_NAME
        ;;
    logs)
        if [ -z "$2" ]; then
            echo "Usage: $0 logs <service-name>"
            echo "Available services:"
            docker stack services $STACK_NAME --format "table {{.Name}}" | tail -n +2
        else
            echo "📜 Logs for ${STACK_NAME}_$2:"
            docker service logs -f ${STACK_NAME}_$2
        fi
        ;;
    scale)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 scale <service-name> <replica-count>"
            echo "Example: $0 scale api 3"
        else
            echo "⚖️ Scaling ${STACK_NAME}_$2 to $3 replicas..."
            docker service scale ${STACK_NAME}_$2=$3
        fi
        ;;
    update)
        echo "🔄 Updating stack deployment..."
        docker stack deploy -c docker-compose.yml $STACK_NAME
        ;;
    restart)
        if [ -z "$2" ]; then
            echo "Usage: $0 restart <service-name>"
            echo "Available services:"
            docker stack services $STACK_NAME --format "table {{.Name}}" | tail -n +2
        else
            echo "🔄 Restarting ${STACK_NAME}_$2..."
            docker service update --force ${STACK_NAME}_$2
        fi
        ;;
    stop)
        echo "⏹️ Removing stack..."
        docker stack rm $STACK_NAME
        echo "✅ Stack removed"
        ;;
    nodes)
        echo "🖥️ Swarm Nodes:"
        docker node ls
        ;;
    watchtower-logs)
        echo "🤖 Watchtower Logs:"
        docker service logs -f ${STACK_NAME}_watchtower
        ;;
    cleanup-logs)
        echo "🧹 Cleanup Service Logs:"
        docker service logs -f ${STACK_NAME}_docker-cleanup
        ;;
    backup-logs)
        echo "💾 Backup Service Logs:"
        docker service logs -f ${STACK_NAME}_db-backup
        ;;
    health)
        echo "🩺 Running Health Check..."
        ./health-check.sh
        ;;
    monitor)
        if [ -z "$2" ]; then
            echo "🔍 Monitoring ALL services logs (real-time)"
            echo "Use: $0 monitor <service-name> for specific service"
            echo "Press Ctrl+C to stop"
            ./monitor-logs.sh
        else
            echo "🔍 Monitoring $2 service logs (real-time)"
            echo "Press Ctrl+C to stop"
            ./monitor-logs.sh $2
        fi
        ;;
    *)
        echo "Docker Swarm Stack Management Script"
        echo ""
        echo "Usage: $0 {status|logs|scale|update|restart|stop|nodes|watchtower-logs|cleanup-logs|backup-logs|health|monitor}"
        echo ""
        echo "Commands:"
        echo "  status              - Show services status and processes"
        echo "  logs <service>      - Show logs for specific service"
        echo "  scale <service> <n> - Scale service to n replicas"
        echo "  update             - Update stack with current docker-compose.yml"
        echo "  restart <service>   - Force restart a service"
        echo "  stop               - Remove entire stack"
        echo "  nodes              - Show swarm nodes"
        echo "  watchtower-logs    - Show Watchtower logs"
        echo "  cleanup-logs       - Show Docker cleanup service logs"
        echo "  backup-logs        - Show database backup service logs"
        echo "  health             - Run comprehensive health check"
        echo "  monitor [service]  - Real-time log monitoring (all services or specific)"
        echo ""
        echo "Examples:"
        echo "  $0 status"
        echo "  $0 logs api"
        echo "  $0 scale api 3"
        echo "  $0 restart watchtower"
        echo "  $0 health"
        echo "  $0 monitor          # Monitor all services"
        echo "  $0 monitor efris    # Monitor only EFRIS service"
        ;;
esac