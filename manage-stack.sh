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
        docker service logs -f ${STACK_NAME}_midnight-backup
        ;;
    backup-logs)
        echo "� Backup service has been removed"
        echo "Use manual backup methods if needed"
        ;;
    backup)
        echo "💾 Backup service has been removed from stack"
        echo "For manual backups, you can use:"
        echo "docker exec -it \$(docker ps -q -f name=palm-stack_postgres) pg_dump -U postgres postgres > backup.sql"
        ;;
    backup-restore)
        echo "� Backup/restore service has been removed"
        echo "Use manual PostgreSQL restore methods if needed"
        ;;
    utils)
        echo "🛠️ Utilities - Select action:"
        echo "1. permissions  - Check Docker permissions"
        echo "2. health      - Run health check" 
        echo "3. monitor     - Monitor logs"
        echo ""
        case "$2" in
            permissions)
                echo "🔧 Checking Docker permissions..."
                docker info > /dev/null 2>&1 && echo "✅ Docker access OK" || echo "❌ Docker permission issues"
                ;;
            health)
                echo "🩺 Running health check..."
                ./health-check.sh
                ;;
            monitor)
                echo "🔍 Starting log monitoring..."
                ./monitor-logs.sh
                ;;
            *)
                echo "Usage: $0 utils {permissions|health|monitor}"
                ;;
        esac
        ;;
    health)
        echo "🩺 Running Comprehensive Health Check..."
        ./health-check.sh
        ;;
    monitor)
        if [ -z "$2" ]; then
            echo "🔍 Monitoring ALL services logs (real-time)"
            echo "Press Ctrl+C to stop"
            ./monitor-logs.sh
        else
            echo "🔍 Monitoring $2 service logs (real-time)"
            echo "Press Ctrl+C to stop"
            docker service logs -f ${STACK_NAME}_$2
        fi
        ;;
    permissions)
        echo "🔧 Checking Docker Permissions..."
        docker info > /dev/null 2>&1 && echo "✅ Docker access OK" || echo "❌ Docker permission issues - try: sudo usermod -aG docker $USER"
        ;;
    force-update)
        if [ -z "$2" ]; then
            echo "🔄 Force updating ALL services (pulls latest images)..."
            echo ""
            for service in $(docker stack services $STACK_NAME --format "{{.Name}}"); do
                echo "⬇️  Pulling and updating: $service"
                docker service update --force --with-registry-auth $service
            done
            echo ""
            echo "✅ All services force updated"
        else
            echo "🔄 Force updating ${STACK_NAME}_$2 (pulls latest image)..."
            docker service update --force --with-registry-auth ${STACK_NAME}_$2
            echo "✅ Service ${STACK_NAME}_$2 force updated"
        fi
        ;;
    *)
        echo "Docker Swarm Stack Management Script"
        echo ""
        echo "Usage: $0 {status|logs|scale|update|restart|stop|nodes|watchtower-logs|cleanup-logs|utils|health|monitor|permissions|force-update}"
        echo ""
        echo "Commands:"
        echo "  status              - Show services status and processes"
        echo "  logs <service>      - Show logs for specific service"
        echo "  scale <service> <n> - Scale service to n replicas"
        echo "  update             - Update stack with current docker-compose.yml"
        echo "  restart <service>   - Force restart a service"
        echo "  force-update [svc]  - Force pull latest images and update (all or specific service)"
        echo "  stop               - Remove entire stack"
        echo "  nodes              - Show swarm nodes"
        echo "  watchtower-logs    - Show Watchtower logs"
        echo "  cleanup-logs       - Show Docker cleanup service logs"
        echo "  utils <cmd>        - Utilities (permissions|health|monitor)"
        echo "  health             - Run comprehensive health check"
        echo "  monitor [service]  - Real-time log monitoring (all or specific)"
        echo "  permissions        - Check Docker permission issues"
        echo ""
        echo "Examples:"
        echo "  $0 status          # Check all services"
        echo "  $0 logs api        # View API service logs"
        echo "  $0 scale api 3     # Scale API to 3 replicas"
        echo "  $0 restart watchtower  # Restart watchtower service"
        echo "  $0 force-update api    # Force pull latest API image and update"
        echo "  $0 force-update        # Force update ALL services"
        echo "  $0 health          # Run health diagnostics"
        echo "  $0 monitor efris   # Monitor EFRIS service logs"
        echo ""
        echo "🤖 Automated Services:"
        echo "  • Cleanup runs every 6 hours"
        echo "  • Updates check every 4 hours"
        echo "  • Manual backups: docker exec postgres pg_dump..."
        ;;
esac