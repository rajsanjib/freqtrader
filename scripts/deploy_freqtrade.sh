#!/bin/bash
set -e

# FreqTrade deployment script
# This script is used to deploy the FreqTrade bot on a server

# Configuration
LOG_FILE="/var/log/freqtrade_deploy.log"
BACKUP_DIR="/backup/freqtrade"
FREQTRADE_DIR="$HOME/freqtrade"
ENV_FILE="$FREQTRADE_DIR/.env"

# Ensure directories exist
mkdir -p $(dirname $LOG_FILE)
mkdir -p $BACKUP_DIR
mkdir -p $FREQTRADE_DIR/user_data/logs

# Logging function
log() {
  local message="$(date '+%Y-%m-%d %H:%M:%S') - $1"
  echo "$message" | tee -a $LOG_FILE
}

# Create backup of current state
backup() {
  local timestamp=$(date +"%Y%m%d_%H%M%S")
  log "Creating backup of current state"
  
  if [ -f "$FREQTRADE_DIR/user_data/tradesv3.sqlite" ]; then
    cp "$FREQTRADE_DIR/user_data/tradesv3.sqlite" \
       "$BACKUP_DIR/tradesv3.sqlite.$timestamp"
    log "Database backed up to $BACKUP_DIR/tradesv3.sqlite.$timestamp"
  fi
  
  if [ -d "$FREQTRADE_DIR/user_data" ]; then
    tar -czf "$BACKUP_DIR/user_data.$timestamp.tar.gz" -C "$FREQTRADE_DIR" user_data
    log "User data backed up to $BACKUP_DIR/user_data.$timestamp.tar.gz"
  fi
}

# Deploy FreqTrade
deploy() {
  log "Starting FreqTrade deployment"
  
  # Check if .env file exists, if not create it
  if [ ! -f "$ENV_FILE" ]; then
    log "Creating .env file"
    touch "$ENV_FILE"
  fi
  
  # Pull latest docker images
  log "Pulling latest Docker images"
  cd "$FREQTRADE_DIR"
  docker-compose -f docker-compose.prod.yml pull
  
  # Start or restart the services
  log "Starting/restarting services"
  docker-compose -f docker-compose.prod.yml up -d
  
  # Verify deployment
  log "Verifying deployment"
  docker-compose -f docker-compose.prod.yml ps
  
  # Check logs for errors
  log "Checking logs for errors"
  docker-compose -f docker-compose.prod.yml logs --tail=10 freqtrade
  
  log "Deployment completed successfully"
}

# Monitor health
check_health() {
  log "Checking bot health"
  
  # Check if container is running
  if ! docker ps | grep -q freqtrade; then
    log "ERROR: FreqTrade container is not running!"
    return 1
  fi
  
  # Check if API is responding
  if ! curl -s http://localhost:8080/api/v1/ping > /dev/null; then
    log "ERROR: FreqTrade API is not responding!"
    return 1
  fi
  
  log "FreqTrade is running properly"
  return 0
}

# Main execution
log "=== Starting FreqTrade deployment script ==="

# Create backup before deployment
backup

# Deploy FreqTrade
deploy

# Check health after deployment
if check_health; then
  log "Deployment successful and bot is healthy"
else
  log "Deployment completed but bot health check failed"
  exit 1
fi