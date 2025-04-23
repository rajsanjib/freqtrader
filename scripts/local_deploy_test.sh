#!/bin/bash
set -e

# Local deployment test script for FreqTrade
# This script allows testing the deployment process locally before using CI/CD

# Parse command line arguments
STRATEGY=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --strategy)
      STRATEGY="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--strategy STRATEGY_NAME]"
      exit 1
      ;;
  esac
done

echo "=== Starting Local Deployment Test ==="

# Directory configurations
FREQTRADE_DIR="$(pwd)"
BACKUP_DIR="${FREQTRADE_DIR}/backups"
LOG_DIR="${FREQTRADE_DIR}/logs"
LOCAL_ENV_FILE="${FREQTRADE_DIR}/.env.local"

# Create necessary directories
mkdir -p $BACKUP_DIR
mkdir -p $LOG_DIR

# Logging function
log() {
  local message="$(date '+%Y-%m-%d %H:%M:%S') - $1"
  echo "$message" | tee -a "${LOG_DIR}/local_deploy.log"
}

# Check if docker is running
if ! docker info > /dev/null 2>&1; then
  echo "Error: Docker is not running. Please start Docker and try again."
  exit 1
fi

# List available strategies
list_strategies() {
  echo "Available strategies:"
  for file in user_data/strategies/*.py; do
    if [ -f "$file" ] && [[ "$file" != *"__init__.py" ]]; then
      strategy_name=$(basename "$file" .py)
      echo "  - $strategy_name"
    fi
  done
}

# Secure the config (create .env.local file)
log "Creating local environment file..."

# Create a local .env file for testing if it doesn't exist
if [ ! -f "$LOCAL_ENV_FILE" ]; then
  log "Creating new .env.local file for testing"
  
  # If strategy was provided via command line, use it in the .env file
  if [ -n "$STRATEGY" ]; then
    DEFAULT_STRATEGY=$STRATEGY
  else
    DEFAULT_STRATEGY="SampleStrategy"
  fi
  
  cat > $LOCAL_ENV_FILE << EOL
# Local testing environment variables
TELEGRAM_TOKEN=
TELEGRAM_CHAT_ID=
EXCHANGE_KEY=
EXCHANGE_SECRET=
FREQTRADE_STRATEGY=$DEFAULT_STRATEGY
EOL
  echo "Created .env.local file. Please edit it to add your credentials for testing."
  echo "The following strategies are available in your workspace:"
  list_strategies
  echo "After editing, run this script again."
  exit 0
else
  log ".env.local file exists, proceeding with deployment"
  
  # If strategy was provided via command line, update the .env.local file
  if [ -n "$STRATEGY" ]; then
    log "Updating strategy to $STRATEGY in .env.local"
    sed -i.bak "s/^FREQTRADE_STRATEGY=.*/FREQTRADE_STRATEGY=$STRATEGY/" $LOCAL_ENV_FILE
    rm -f "${LOCAL_ENV_FILE}.bak"
  fi
fi

# Prepare secure config
log "Preparing configuration for local testing..."
cp -f user_data/config.json user_data/config.json.backup
jq '.exchange.key = "" | .exchange.secret = "" | .telegram.token = "" | .telegram.chat_id = ""' user_data/config.json > user_data/config.secure.json
mv user_data/config.secure.json user_data/config.json

# Copy docker-compose.prod.yml to a local test version
log "Setting up Docker Compose environment..."
cp -f docker-compose.prod.yml docker-compose.local.yml

# Build and start the containers
log "Deploying FreqTrade locally..."
docker-compose -f docker-compose.local.yml --env-file $LOCAL_ENV_FILE pull
docker-compose -f docker-compose.local.yml --env-file $LOCAL_ENV_FILE up -d

# Verify deployment
log "Verifying deployment..."
docker-compose -f docker-compose.local.yml ps

# Check logs
log "Checking logs for errors..."
docker-compose -f docker-compose.local.yml logs --tail=10 freqtrade

log "Local deployment test completed. The bot should now be running locally."
log "To view the FreqTrade API, open http://localhost:8080 in your browser"
log "To view Grafana dashboards, open http://localhost:3000 in your browser (default credentials: admin/admin)"
log "Use 'docker-compose -f docker-compose.local.yml logs -f freqtrade' to follow the logs"
log "Use 'docker-compose -f docker-compose.local.yml down' to stop the deployment"

echo "=== Local Deployment Test Completed ==="