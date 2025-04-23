#!/bin/bash
set -e

# Prepare server environment for FreqTrade deployment
# This script ensures proper permissions and directory structure

FREQTRADE_DIR="$HOME/freqtrade"
LOG_DIR="$FREQTRADE_DIR/user_data/logs"

echo "=== Preparing server for FreqTrade deployment ==="

# Ensure directories exist with proper permissions
echo "Creating directories with proper permissions..."
mkdir -p "$LOG_DIR"

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

echo "=== Server preparation completed ==="