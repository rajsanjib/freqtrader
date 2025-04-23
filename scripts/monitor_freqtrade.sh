#!/bin/bash

# FreqTrade monitoring script - Lightweight version
# This script checks if the FreqTrade bot is running and restarts it if needed

LOG_FILE="/var/log/freqtrade_monitor.log"
FREQTRADE_DIR="$HOME/freqtrade"
TELEGRAM_TOKEN=""
TELEGRAM_CHAT_ID=""

# Source environment variables if .env file exists
if [ -f "$FREQTRADE_DIR/.env" ]; then
  source "$FREQTRADE_DIR/.env"
fi

# Ensure log directory exists
mkdir -p $(dirname $LOG_FILE)

# Logging function
log() {
  local message="$(date '+%Y-%m-%d %H:%M:%S') - $1"
  echo "$message" | tee -a $LOG_FILE
}

# Send Telegram notification
send_telegram_notification() {
  if [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
      -d chat_id="$TELEGRAM_CHAT_ID" \
      -d text="FreqTrade Monitor: $message" \
      -d parse_mode="Markdown" > /dev/null
  fi
}

# Check if FreqTrade container is running
check_container() {
  if ! docker ps | grep -q freqtrade; then
    log "FreqTrade container is not running!"
    return 1
  fi
  return 0
}

# Check if API is responding
check_api() {
  if ! curl -s http://localhost:8080/api/v1/ping > /dev/null; then
    log "FreqTrade API is not responding!"
    return 1
  fi
  return 0
}

# Check system resources
check_resources() {
  # Check available memory
  local free_memory=$(free -m | awk '/^Mem:/ {print $4}')
  if [ $free_memory -lt 200 ]; then
    log "WARNING: System memory is running low (${free_memory}MB free)"
    send_telegram_notification "⚠️ Server memory is running low (${free_memory}MB free)"
  fi
  
  # Check disk space
  local free_disk=$(df -m / | awk 'NR==2 {print $4}')
  if [ $free_disk -lt 1000 ]; then
    log "WARNING: Disk space is running low (${free_disk}MB free)"
    send_telegram_notification "⚠️ Server disk space is running low (${free_disk}MB free)"
  fi
}

# Restart FreqTrade
restart_freqtrade() {
  log "Restarting FreqTrade"
  cd "$FREQTRADE_DIR"
  docker-compose -f docker-compose.prod.yml restart freqtrade
  sleep 10  # Wait for container to start up
}

# Main execution
log "=== Starting FreqTrade monitoring check ==="

# Check system resources
check_resources

# Check if container is running
if ! check_container; then
  log "Attempting to restart FreqTrade"
  restart_freqtrade
  
  # Check if restart was successful
  if check_container; then
    log "Container restart successful"
    send_telegram_notification "⚠️ FreqTrade container was down and has been restarted successfully."
  else
    log "Container restart failed"
    send_telegram_notification "🚨 FreqTrade container is down and restart failed! Manual intervention required."
    exit 1
  fi
fi

# Check API health
if ! check_api; then
  log "API is not responding, attempting to restart container"
  restart_freqtrade
  
  # Check if restart fixed the API
  if check_api; then
    log "API is now responding after restart"
    send_telegram_notification "⚠️ FreqTrade API was not responding and has been restored after restart."
  else
    log "API is still not responding after restart"
    send_telegram_notification "🚨 FreqTrade API is not responding even after restart! Manual intervention required."
    exit 1
  fi
fi

# Check if everything is working fine
if check_container && check_api; then
  log "FreqTrade is running properly"
  exit 0
else
  log "FreqTrade is not running properly after checks"
  exit 1
fi