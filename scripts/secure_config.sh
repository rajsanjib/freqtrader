#!/bin/bash
set -e

# FreqTrade secure configuration script
# This script prepares a secure config file with sensitive data removed
# and creates an .env file with the sensitive credentials

FREQTRADE_DIR="$HOME/freqtrade"
CONFIG_FILE="$FREQTRADE_DIR/user_data/config.json"
ENV_FILE="$FREQTRADE_DIR/.env"
BACKUP_DIR="$FREQTRADE_DIR/backups"

# Ensure directories exist
mkdir -p $BACKUP_DIR

# Create a timestamp for backup files
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Backup the original config
echo "Creating backup of original config..."
cp "$CONFIG_FILE" "$BACKUP_DIR/config.json.$TIMESTAMP"

# Extract API keys and other sensitive data
if [ -f "$CONFIG_FILE" ]; then
  echo "Extracting sensitive data from config file..."
  TELEGRAM_TOKEN=$(jq -r '.telegram.token' "$CONFIG_FILE")
  TELEGRAM_CHAT_ID=$(jq -r '.telegram.chat_id' "$CONFIG_FILE")
  EXCHANGE_KEY=$(jq -r '.exchange.key' "$CONFIG_FILE")
  EXCHANGE_SECRET=$(jq -r '.exchange.secret' "$CONFIG_FILE")
  STRATEGY=$(jq -r '.strategy' "$CONFIG_FILE")
  
  # Create .env file with extracted data
  echo "Creating .env file with sensitive credentials..."
  cat > "$ENV_FILE" << EOL
TELEGRAM_TOKEN=$TELEGRAM_TOKEN
TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID
EXCHANGE_KEY=$EXCHANGE_KEY
EXCHANGE_SECRET=$EXCHANGE_SECRET
FREQTRADE_STRATEGY=$STRATEGY
EOL
  
  # Create a secure version of the config file
  echo "Creating secure version of config file..."
  jq '.exchange.key = "" | .exchange.secret = "" | .telegram.token = "" | .telegram.chat_id = ""' "$CONFIG_FILE" > "$CONFIG_FILE.secure"
  
  # Replace the original config with the secure version
  mv "$CONFIG_FILE.secure" "$CONFIG_FILE"
  
  echo "Configuration secured successfully."
  echo "Sensitive credentials moved to $ENV_FILE"
  echo "Original config backed up to $BACKUP_DIR/config.json.$TIMESTAMP"
else
  echo "Error: Config file not found at $CONFIG_FILE"
  exit 1
fi

# Set appropriate permissions
chmod 600 "$ENV_FILE"
echo "Environment file permissions set to 600 (user read/write only)"