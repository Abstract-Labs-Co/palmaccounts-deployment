# Palm Deployment - Docker Swarm with Watchtower

This repository contains a Docker Swarm stack configuration for deploying the Palm application suite with automated updates using Watchtower.

## 🏗️ Architecture

The stack includes the following services:

### Core Services

- **EFRIS** (`axoblade/flawless-on-prem`) - Main EFRIS application
- **EFRIS Router** (`axoblade/efris-router`) - Router service for EFRIS
- **Palm API** (`axoblade/palmaccounts-api`) - Backend API service
- **Palm POS** (`axoblade/palmaccounts-pos`) - Point of Sale frontend
- **Palm Admin** (`axoblade/palmaccounts-admin`) - Administrative interface

### Data Services

- **MongoDB** (`mongo:6.0`) - Database for EFRIS
- **PostgreSQL** (`postgres:16-alpine`) - Database for Palm services
- **PgAdmin** (`dpage/pgadmin4`) - PostgreSQL administration interface

### DevOps Services

- **Watchtower** (`containrrr/watchtower`) - Automated container updates
- **Docker Cleanup** (`alpine:latest`) - Automatic cleanup of unused Docker resources
- **DB Backup** (`alpine:latest`) - Database backup management (creates backup directories)
- **Health Monitor** - Health check script for system monitoring

## 🚀 Quick Start

### Prerequisites

- Docker installed and running
- Docker Swarm mode (will be initialized automatically)

### 1. Deploy the Stack

```bash
./deploy-swarm.sh
```

This script will:

- Initialize Docker Swarm if needed
- Create required directories
- Deploy all services
- Show service status

### 2. Access Services

After deployment, services are available at:

| Service      | URL                   | Description             |
| ------------ | --------------------- | ----------------------- |
| EFRIS        | http://localhost:3005 | Main EFRIS application  |
| EFRIS Router | http://localhost:3122 | EFRIS routing service   |
| Palm API     | http://localhost:3001 | Backend API             |
| Palm POS     | http://localhost:3002 | Point of Sale interface |
| Palm Admin   | http://localhost:3003 | Administrative panel    |
| PgAdmin      | http://localhost:5050 | Database administration |
| PostgreSQL   | localhost:5432        | Direct database access  |

## 📋 Management

### Using the Management Script

```bash
# Check status of all services
./manage-stack.sh status

# View logs for a specific service
./manage-stack.sh logs api
./manage-stack.sh logs watchtower

# Scale a service (increase replicas)
./manage-stack.sh scale api 3

# Update the stack after changing docker-compose.yml
./manage-stack.sh update

# Restart a service
./manage-stack.sh restart api

# View Watchtower logs (to see update activities)
./manage-stack.sh watchtower-logs

# Real-time monitoring of all services
./manage-stack.sh monitor

# Real-time monitoring of specific service
./manage-stack.sh monitor efris

# Stop the entire stack
./manage-stack.sh stop
```

### Manual Docker Commands

If you prefer using Docker commands directly:

```bash
# Check service status
docker stack services palm-stack

# View service logs
docker service logs palm-stack_api

# Scale services
docker service scale palm-stack_api=3

# Update stack
docker stack deploy -c docker-compose.yml palm-stack

# Remove stack
docker stack rm palm-stack
```

## 🔄 Auto-Restart Configuration

All services are configured with robust restart policies to ensure they automatically restart when:

- **PC reboots** - Services will automatically start when Docker starts
- **Docker restarts** - All services will restart automatically
- **Service crashes** - Failed services will restart automatically
- **Container exits** - Any container exit will trigger a restart

**Restart Policy Details:**

- **Condition**: `any` - Restart on any exit condition
- **Delay**: 5-10 seconds between restart attempts
- **Max Attempts**: 5 attempts within 120 seconds
- **Database Placement**: MongoDB and PostgreSQL run on manager nodes for stability

## 🤖 Automated Updates with Watchtower

Watchtower automatically monitors all containers for image updates every 30 minutes. When a new version of any image is available in the registry, Watchtower will:

1. Pull the new image
2. Stop the old container
3. Start a new container with the updated image
4. Clean up the old image

### Watchtower Configuration

- **Poll Interval**: 1800 seconds (30 minutes)
- **Cleanup**: Enabled (removes old images)
- **Scope**: All containers in the stack

To monitor Watchtower activity:

```bash
./manage-stack.sh watchtower-logs
```

## 🧹 Automatic Docker Cleanup

A dedicated cleanup service runs every 6 hours to automatically remove:

- **Unused containers** - Stopped containers not part of the active stack
- **Dangling images** - Images not tagged or used by any container
- **Unused volumes** - Volumes not mounted by any container
- **Build cache** - Docker build cache and temporary files
- **Networks** - Unused Docker networks

### Cleanup Schedule

- **Frequency**: Every 6 hours
- **What's preserved**: Active containers, volumes, and images used by running services
- **What's removed**: All unused Docker resources

To monitor cleanup activity:

```bash
./manage-stack.sh logs docker-cleanup
```

To trigger manual cleanup:

```bash
# View cleanup logs
./manage-stack.sh logs docker-cleanup

# Restart cleanup service to run immediately
./manage-stack.sh restart docker-cleanup
```

## 💾 Database Backup Management

An automated backup service manages database backup directories and cleanup:

- **Backup Directory**: `./backups` (created automatically)
- **Schedule**: Daily backup directory creation
- **Retention**: Automatically removes backup directories older than 7 days
- **Location**: Backup directories are created locally for your backup scripts to use

### Backup Management

```bash
# View backup service logs
./manage-stack.sh backup-logs

# Check backup directories
ls -la ./backups

# Restart backup service
./manage-stack.sh restart db-backup
```

## 🩺 System Health Monitoring

Use the built-in health check script to monitor your entire stack:

```bash
# Run comprehensive health check
./manage-stack.sh health

# Or run directly
./health-check.sh
```

The health monitor provides:

- Service status and replica counts
- Resource usage overview
- Storage usage statistics
- Recent log snippets from all services
- Failed service detection

## 📊 Real-time Log Monitoring

Monitor logs in real-time for debugging and monitoring:

### Monitor All Services

```bash
# Monitor all services simultaneously (interleaved logs)
./manage-stack.sh monitor

# Or use the direct script
./monitor-logs.sh
```

### Monitor Specific Service

```bash
# Monitor single service in real-time
./manage-stack.sh monitor efris
./manage-stack.sh monitor api

# Alternative with more options
docker service logs -f --timestamps palm-stack_efris
docker service logs --tail 100 -f palm-stack_api
```

### Special Service Monitoring

```bash
# Monitor update activities
./manage-stack.sh watchtower-logs

# Monitor cleanup activities
./manage-stack.sh cleanup-logs

# Monitor backup activities
./manage-stack.sh backup-logs
```

**Tip**: Press `Ctrl+C` to stop real-time monitoring## 🔧 Configuration

### Environment Variables

Create a `.env` file in this directory with the following variables for the EFRIS service:

```env
# Add your EFRIS-specific environment variables here
NODE_ENV=production
# Add other environment variables as needed
```

### Database Credentials

**PostgreSQL:**

- Username: `postgres`
- Password: `postgres`
- Database: `postgres`
- Port: `5432`

**PgAdmin:**

- Email: `admin@palmaccounts.com`
- Password: `password`

### Volume Mounts

- `./tmp` → `/tmp_privateKeys` (EFRIS Router private keys)
- `mongo-data` → MongoDB data persistence
- `pgdata_local_all` → PostgreSQL data persistence

## 🔍 Monitoring & Troubleshooting

### Check Service Health

```bash
# Overall stack status
./manage-stack.sh status

# Detailed service processes
docker stack ps palm-stack

# Service logs
./manage-stack.sh logs <service-name>
```

### Common Issues

1. **Service Won't Start**: Check logs for the specific service

   ```bash
   ./manage-stack.sh logs <service-name>
   ```

2. **Port Conflicts**: Ensure no other services are using the required ports

   ```bash
   lsof -i :3001  # Check if port 3001 is in use
   ```

3. **Volume Permissions**: Ensure the `./tmp` directory has proper permissions

   ```bash
   ls -la ./tmp
   ```

4. **Swarm Not Initialized**: Run the deployment script which will initialize it

   ```bash
   ./deploy-swarm.sh
   ```

5. **Docker Permission Issues**: If services can't access Docker daemon
   ```bash
   ./fix-docker-permissions.sh --fix
   ```

### Scaling Services

All services start with 1 replica by default. You can scale them for high availability or increased load:

```bash
# Scale API service to 3 replicas for higher availability
./manage-stack.sh scale api 3

# Scale POS service to 2 replicas
./manage-stack.sh scale pos 2
```

Database services (MongoDB and PostgreSQL) should remain at 1 replica to maintain data consistency.

## 🔄 Updates and Maintenance

### Manual Updates

To update the stack configuration:

1. Edit `docker-compose.yml`
2. Run: `./manage-stack.sh update`

### Image Updates

Watchtower handles automatic image updates, but you can also trigger manual updates:

```bash
# Force update a specific service
./manage-stack.sh restart <service-name>
```

### Backup Considerations

Important data locations to backup:

- PostgreSQL data: `pgdata_local_all` volume
- MongoDB data: `mongo-data` volume
- EFRIS private keys: `./tmp` directory

## 📁 File Structure

```
palm_deployment/
├── docker-compose.yml          # Main stack configuration
├── deploy-swarm.sh            # Initial deployment script
├── manage-stack.sh            # Stack management script
├── monitor-logs.sh            # Real-time log monitoring
├── health-check.sh            # System health checker
├── fix-docker-permissions.sh  # Docker permissions fixer
├── README.md                  # This documentation
├── .env                       # Environment variables (create this)
├── tmp/                       # EFRIS private keys directory (auto-created)
└── backups/                   # Database backup directories (auto-created)
```

## 🆘 Support

For troubleshooting:

1. Check service logs: `./manage-stack.sh logs <service>`
2. Verify service status: `./manage-stack.sh status`
3. Check Watchtower activity: `./manage-stack.sh watchtower-logs`
4. Ensure all required ports are available
5. Verify Docker Swarm is active: `docker info | grep Swarm`

## 🔒 Security Notes

- Change default database passwords in production
- Use secrets management for sensitive environment variables
- Ensure proper firewall configuration for exposed ports
- Regularly update base images through Watchtower or manual updates

---

**Note**: This deployment is configured for development/testing. For production deployments, consider additional security measures, load balancing, and backup strategies.
