#!/bin/bash
set -e

# Prepare server environment for FreqTrade deployment
# This script ensures proper permissions and directory structure

FREQTRADE_DIR="$HOME/freqtrade"
LOG_DIR="$FREQTRADE_DIR/user_data/logs"
MONITORING_DIR="$FREQTRADE_DIR/monitoring"
PROMETHEUS_CONFIG="$MONITORING_DIR/prometheus.yml"

echo "=== Preparing server for FreqTrade deployment ==="

# Ensure directories exist with proper permissions
echo "Creating directories with proper permissions..."
mkdir -p "$LOG_DIR"
mkdir -p "$MONITORING_DIR/grafana/provisioning/dashboards"
mkdir -p "$MONITORING_DIR/grafana/provisioning/datasources"

# Handle log file permissions
echo "Setting up log file permissions..."
# Remove existing log file if it exists (it will be recreated by FreqTrade)
if [ -f "$LOG_DIR/freqtrade.log" ]; then
    rm -f "$LOG_DIR/freqtrade.log"
    echo "Removed existing log file"
fi
# Set directory permissions so the container can create its own log files
chmod -R 777 "$LOG_DIR"
echo "Set log directory permissions to 777"

# Ensure prometheus config exists
if [ ! -f "$PROMETHEUS_CONFIG" ]; then
    echo "Creating default Prometheus configuration..."
    cat > "$PROMETHEUS_CONFIG" << EOL
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: "freqtrade"
    static_configs:
      - targets: ["freqtrade:8080"]
    metrics_path: "/metrics"
EOL
fi

# Create Grafana datasource configuration if it doesn't exist
GRAFANA_DS_DIR="$MONITORING_DIR/grafana/provisioning/datasources"
if [ ! -f "$GRAFANA_DS_DIR/prometheus.yml" ]; then
    echo "Creating Grafana datasource configuration..."
    cat > "$GRAFANA_DS_DIR/prometheus.yml" << EOL
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
EOL
fi

# Create Grafana dashboard configuration if it doesn't exist
GRAFANA_DASH_DIR="$MONITORING_DIR/grafana/provisioning/dashboards"
if [ ! -f "$GRAFANA_DASH_DIR/dashboards.yml" ]; then
    echo "Creating Grafana dashboard configuration..."
    cat > "$GRAFANA_DASH_DIR/dashboards.yml" << EOL
apiVersion: 1

providers:
  - name: 'FreqTrade'
    orgId: 1
    folder: 'FreqTrade'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    options:
      path: /etc/grafana/provisioning/dashboards
      foldersFromFilesStructure: true
EOL
fi

echo "=== Server preparation completed ==="