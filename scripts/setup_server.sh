#!/bin/bash
set -e

# FreqTrade server setup script
# This script prepares a server for FreqTrade deployment
# Run this script once when setting up a new server

# Configuration
FREQTRADE_DIR="$HOME/freqtrade"
BACKUP_DIR="/backup/freqtrade"
LOG_DIR="/var/log/freqtrade"

echo "=== Setting up FreqTrade server ==="

# Update system
echo "Updating system packages"
sudo apt-get update
sudo apt-get upgrade -y

# Install Docker if not already installed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker"
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update
    sudo apt-get install -y docker-ce
    sudo systemctl enable docker
    sudo systemctl start docker
else
    echo "Docker is already installed"
fi

# Install Docker Compose if not already installed
if ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose"
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
else
    echo "Docker Compose is already installed"
fi

# Add current user to docker group to avoid using sudo with docker
sudo usermod -aG docker $USER
echo "Added $USER to docker group"

# Create necessary directories
echo "Creating FreqTrade directories"
mkdir -p $FREQTRADE_DIR
mkdir -p $BACKUP_DIR
sudo mkdir -p $LOG_DIR
sudo chown $USER:$USER $LOG_DIR

# Create directory structure for FreqTrade
mkdir -p $FREQTRADE_DIR/user_data/data
mkdir -p $FREQTRADE_DIR/user_data/logs
mkdir -p $FREQTRADE_DIR/user_data/strategies
mkdir -p $FREQTRADE_DIR/monitoring
mkdir -p $FREQTRADE_DIR/monitoring/grafana/provisioning/dashboards
mkdir -p $FREQTRADE_DIR/monitoring/grafana/provisioning/datasources

# Set up cron job for monitoring script
echo "Setting up monitoring cron job"
(crontab -l 2>/dev/null || echo "") | grep -v "monitor_freqtrade.sh" | { cat; echo "*/15 * * * * $FREQTRADE_DIR/scripts/monitor_freqtrade.sh >> /dev/null 2>&1"; } | crontab -

# Create sample .env file
echo "Creating sample .env file"
cat > $FREQTRADE_DIR/.env << EOL
# FreqTrade Environment Variables
TELEGRAM_TOKEN=
TELEGRAM_CHAT_ID=
EXCHANGE_KEY=
EXCHANGE_SECRET=
FREQTRADE_STRATEGY=SampleStrategy
EOL

echo "=== Server setup completed ==="
echo "Next steps:"
echo "1. Configure your FreqTrade strategy in the user_data/strategies directory"
echo "2. Configure your bot parameters in user_data/config.json"
echo "3. Set your exchange API keys and Telegram bot details in the .env file"
echo "4. Run the deployment script to start the bot"