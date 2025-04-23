#!/bin/bash
# FreqTrade local test deployment stop script
# This script stops a local test deployment of FreqTrade

# Configuration
FREQTRADE_DIR="$(pwd)"
TEST_COMPOSE_FILE="$FREQTRADE_DIR/docker-compose.local-test.yml"

if [ -f "$TEST_COMPOSE_FILE" ]; then
    echo "Stopping local test deployment..."
    docker-compose -f "$TEST_COMPOSE_FILE" down
    
    echo "Checking if any test containers are still running..."
    if docker ps | grep -q "freqtrade_test"; then
        echo "Forcefully stopping freqtrade_test container..."
        docker stop freqtrade_test
        docker rm -f freqtrade_test
    else
        echo "No FreqTrade test containers are running."
    fi
    
    echo "Local test deployment stopped successfully."
else
    echo "Error: Test docker-compose file not found at $TEST_COMPOSE_FILE"
    echo "Make sure you are in the FreqTrade directory where you ran the local_test_deploy.sh script."
    
    # Try to stop by container name as a fallback
    if docker ps | grep -q "freqtrade_test"; then
        echo "Found running freqtrade_test container. Stopping it..."
        docker stop freqtrade_test
        docker rm -f freqtrade_test
        echo "Container stopped."
    fi
fi