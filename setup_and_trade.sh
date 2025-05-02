#!/usr/bin/env bash
#encoding=utf8

# Script to setup Freqtrade and start trading
# Created: May 2, 2025

function echo_block() {
    echo "----------------------------"
    echo $1
    echo "----------------------------"
}

# Function to check if Freqtrade is installed
function check_freqtrade_installed() {
    if [ -d ".venv" ]; then
        source .venv/bin/activate
        freqtrade --version > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "Freqtrade is already installed."
            return 0
        fi
    fi
    return 1
}

# Function to setup Freqtrade
function setup_freqtrade() {
    echo_block "Setting up Freqtrade"
    
    if check_freqtrade_installed; then
        read -p "Would you like to update the existing installation? [y/N] " update
        if [[ $update =~ ^[Yy]$ ]]; then
            echo "Updating Freqtrade..."
            ./setup.sh --update
        fi
    else
        echo "Installing Freqtrade..."
        ./setup.sh --install
    fi
    
    source .venv/bin/activate
}

# Function to check if config exists
function check_config() {
    if [ -f "user_data/config.json" ]; then
        echo "Config file found at user_data/config.json"
        return 0
    fi
    return 1
}

# Function to create a config file
function create_config() {
    echo_block "Setting up configuration"
    
    if check_config; then
        read -p "Would you like to use the existing config? [Y/n] " use_existing
        if [[ $use_existing =~ ^[Nn]$ ]]; then
            create_new_config
        fi
    else
        create_new_config
    fi
}

# Function to create a new config
function create_new_config() {
    echo "Creating a new config file..."
    
    read -p "Which exchange would you like to use? [binance/kraken/other] " exchange
    
    if [ "$exchange" == "binance" ]; then
        cp config_examples/config_binance.example.json user_data/config.json
    elif [ "$exchange" == "kraken" ]; then
        cp config_examples/config_kraken.example.json user_data/config.json
    else
        cp config_examples/config_full.example.json user_data/config.json
    fi
    
    echo "Config file created at user_data/config.json"
    echo "Please edit this file to add your API credentials and customize settings."
    
    # Open the file for editing
    if command -v nano > /dev/null; then
        read -p "Would you like to edit the config file now? [Y/n] " edit_now
        if [[ ! $edit_now =~ ^[Nn]$ ]]; then
            nano user_data/config.json
        fi
    else
        echo "Please edit user_data/config.json with your preferred editor before trading."
    fi
}

# Function to setup strategy
function setup_strategy() {
    echo_block "Setting up trading strategy"
    
    # Check if HarmonicDivergence strategy is available
    if [ -f "user_data/strategies/HarmonicDivergence.py" ]; then
        echo "HarmonicDivergence strategy found."
        read -p "Would you like to use the HarmonicDivergence strategy for trading? [Y/n] " use_harmonic
        if [[ ! $use_harmonic =~ ^[Nn]$ ]]; then
            # Update the config to use HarmonicDivergence
            sed -i '' 's/"strategy": ".*"/"strategy": "HarmonicDivergence"/g' user_data/config.json
            echo "Config updated to use HarmonicDivergence strategy."
            return
        fi
    fi
    
    # List available strategies
    echo "Available strategies:"
    ls -1 user_data/strategies/ | grep -v "__" | sed 's/\.py$//'
    
    read -p "Enter the name of the strategy you'd like to use: " strategy_name
    if [ -f "user_data/strategies/${strategy_name}.py" ]; then
        # Update the config to use the selected strategy
        sed -i '' 's/"strategy": ".*"/"strategy": "'$strategy_name'"/g' user_data/config.json
        echo "Config updated to use ${strategy_name} strategy."
    else
        echo "Strategy not found. Please configure your strategy manually in the config file."
    fi
}

# Function to start trading
function start_trading() {
    echo_block "Starting Freqtrade in trading mode"
    
    # Check if we need to download data first
    read -p "Would you like to download historical data before trading? [y/N] " download_data
    if [[ $download_data =~ ^[Yy]$ ]]; then
        echo "Downloading data..."
        freqtrade download-data --config user_data/config.json
    fi
    
    # Choose trading mode
    echo "Trading modes:"
    echo "1. Live trading with real money"
    echo "2. Dry-run (paper trading)"
    echo "3. Backtesting"
    
    read -p "Select trading mode [2]: " trading_mode
    trading_mode=${trading_mode:-2}
    
    case $trading_mode in
        1)
            echo "Starting live trading. CAUTION: This will trade with real money!"
            read -p "Are you sure you want to trade with real money? [y/N] " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                freqtrade trade --config user_data/config.json
            else
                echo "Switching to dry-run mode for safety."
                freqtrade trade --config user_data/config.json --dry-run
            fi
            ;;
        2)
            echo "Starting dry-run trading (paper trading)."
            freqtrade trade --config user_data/config.json --dry-run
            ;;
        3)
            echo "Starting backtesting."
            freqtrade backtesting --config user_data/config.json --timerange 20230101-
            ;;
        *)
            echo "Invalid choice. Starting dry-run trading (paper trading)."
            freqtrade trade --config user_data/config.json --dry-run
            ;;
    esac
}

# Main execution
echo_block "Freqtrade Setup and Trading Script"
echo "This script will setup Freqtrade and start trading."

# Setup Freqtrade
setup_freqtrade

# Setup config
create_config

# Setup strategy
setup_strategy

# Start trading
start_trading

echo_block "Script completed"