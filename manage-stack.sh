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
            echo "🔄 Force updating ALL services (complete rebuild)..."
            echo "⚠️  WARNING: This will kill services, delete images, and prune Docker system"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            
            # Get list of services
            services=$(docker stack services $STACK_NAME --format "{{.Name}}")
            total=$(echo "$services" | wc -l)
            current=0
            
            for service in $services; do
                current=$((current + 1))
                service_name=$(echo $service | sed "s/${STACK_NAME}_//")
                
                echo "[$current/$total] 🔄 Processing: $service_name"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                
                # Get current image
                current_image=$(docker service inspect $service --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}' 2>/dev/null)
                echo "📦 Current image: $current_image"
                
                # Extract image name without digest
                image_name=$(echo $current_image | cut -d'@' -f1)
                
                # Step 1: Stop service containers
                echo "⏹️  Step 1: Stopping service containers..."
                docker service scale $service=0
                sleep 3
                
                # Step 2: Force remove the image
                echo "🗑️  Step 2: Force removing image..."
                docker rmi -f $image_name 2>/dev/null || echo "   (Image already removed)"
                
                # Step 3: Docker system prune
                echo "🧹 Step 3: Running docker system prune..."
                docker system prune -af
                
                # Step 4: Pull fresh image
                echo "⬇️  Step 4: Pulling fresh image: $image_name"
                docker pull $image_name
                
                # Step 5: Scale back up and update
                echo "🔄 Step 5: Scaling service back up and updating..."
                docker service update --force --with-registry-auth $service --detach=false
                
                # Show new state
                new_image=$(docker service inspect $service --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}' 2>/dev/null)
                echo "✅ Updated to: $new_image"
                
                # Show service status
                replicas=$(docker service ls --filter name=$service --format "{{.Replicas}}")
                echo "📊 Status: $replicas"
                echo ""
            done
            
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "✅ All services force updated successfully"
            echo ""
            echo "💡 View status: ./manage-stack.sh status"
            echo "💡 View logs: ./manage-stack.sh logs <service-name>"
        else
            service_name=$2
            full_service_name="${STACK_NAME}_${service_name}"
            
            echo "🔄 Force updating service: $service_name (complete rebuild)"
            echo "⚠️  WARNING: This will kill the service, delete its image, and prune Docker system"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            
            # Get current image
            current_image=$(docker service inspect $full_service_name --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}' 2>/dev/null)
            if [ -z "$current_image" ]; then
                echo "❌ Error: Service $service_name not found"
                exit 1
            fi
            
            echo "📦 Current image: $current_image"
            
            # Extract image name without digest
            image_name=$(echo $current_image | cut -d'@' -f1)
            
            # Step 1: Stop service containers
            echo ""
            echo "⏹️  Step 1: Stopping service containers..."
            docker service scale $full_service_name=0
            echo "   Waiting for service to stop..."
            sleep 5
            
            # Step 2: Force remove the image
            echo ""
            echo "🗑️  Step 2: Force removing image: $image_name"
            docker rmi -f $image_name 2>/dev/null || echo "   (Image already removed)"
            
            # Step 3: Docker system prune
            echo ""
            echo "🧹 Step 3: Running docker system prune -af..."
            docker system prune -af
            
            # Step 4: Pull fresh image
            echo ""
            echo "⬇️  Step 4: Pulling fresh image: $image_name"
            docker pull $image_name
            
            # Step 5: Scale back up and update
            echo ""
            echo "🔄 Step 5: Scaling service back up and updating..."
            docker service update --force --with-registry-auth $full_service_name --detach=false
            
            # Show new state
            echo ""
            new_image=$(docker service inspect $full_service_name --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}' 2>/dev/null)
            echo "✅ Updated to: $new_image"
            
            # Show service status
            replicas=$(docker service ls --filter name=$full_service_name --format "{{.Replicas}}")
            echo "📊 Status: $replicas"
            
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "✅ Service $service_name force updated successfully"
            echo ""
            echo "💡 View logs: ./manage-stack.sh logs $service_name"
            echo "💡 Monitor: ./manage-stack.sh monitor $service_name"
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