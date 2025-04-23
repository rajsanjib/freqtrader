# --- Do not remove these libs ---
import numpy as np
import pandas as pd
from pandas import DataFrame
from datetime import datetime
import talib.abstract as ta
from freqtrade.strategy import IStrategy, informative
from freqtrade.persistence import Trade

# --------------------------------
# Add your lib to import here
import freqtrade.vendor.qtpylib.indicators as qtpylib


class ShortTermMomentumStrategy(IStrategy):
    """
    Short-Term Momentum Strategy
    
    This strategy is designed for short-term trading with quick entry and exit based on:
    - RSI for entry/exit signals
    - EMA crossovers for trend direction
    - MACD for momentum confirmation
    - Bollinger Bands for volatility-based exits
    - Volume filters to avoid low liquidity situations
    
    Timeframe: 5m (recommended)
    """
    
    # Strategy interface version - required
    INTERFACE_VERSION = 3

    # Minimal ROI designed for short-term trades
    # Aim to take profit quickly on volatile movements
    minimal_roi = {
        "0": 0.025,   # 2.5% profit immediately
        "10": 0.02,   # 2% after 10 minutes
        "20": 0.015,  # 1.5% after 20 minutes
        "30": 0.01,   # 1% after 30 minutes
        "60": 0.005   # 0.5% after 60 minutes
    }

    # Stoploss is relatively tight for short-term trading
    stoploss = -0.025  # 2.5%
    
    # Trailing stoploss to lock in profits
    trailing_stop = True
    trailing_stop_positive = 0.01  # 1%
    trailing_stop_positive_offset = 0.02  # 2%
    trailing_only_offset_is_reached = True

    # Optimal timeframe for the strategy
    timeframe = '5m'

    # Run "populate_indicators()" only for new candle.
    process_only_new_candles = True

    # Number of candles the strategy requires
    startup_candle_count = 50
    
    # For short-term trading, we need fast execution
    order_types = {
        'entry': 'market',
        'exit': 'market',
        'stoploss': 'market',
        'stoploss_on_exchange': False
    }
    
    # Trading timeframe is short - act quickly
    order_time_in_force = {
        'entry': 'gtc',
        'exit': 'gtc'
    }
    
    plot_config = {
        'main_plot': {
            'ema9': {'color': 'red'},
            'ema21': {'color': 'green'},
            'bb_upperband': {'color': 'blue'},
            'bb_lowerband': {'color': 'blue'},
        },
        'subplots': {
            "RSI": {
                'rsi': {'color': 'orange'},
            },
            "MACD": {
                'macd': {'color': 'blue'},
                'macdsignal': {'color': 'orange'},
            },
            "VOLUME": {
                'volume': {'color': 'blue'},
            }
        }
    }

    def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        """
        Compute technical indicators we need for our short-term strategy
        """
        
        # Volume indicators
        dataframe['volume_mean'] = dataframe['volume'].rolling(window=10).mean()
        
        # EMA - Exponential Moving Average for trends
        dataframe['ema9'] = ta.EMA(dataframe, timeperiod=9)
        dataframe['ema21'] = ta.EMA(dataframe, timeperiod=21)
        dataframe['ema50'] = ta.EMA(dataframe, timeperiod=50)
        
        # MACD for momentum detection
        macd = ta.MACD(dataframe)
        dataframe['macd'] = macd['macd']
        dataframe['macdsignal'] = macd['macdsignal']
        dataframe['macdhist'] = macd['macdhist']
        
        # Bollinger Bands for volatility measurement
        bollinger = qtpylib.bollinger_bands(qtpylib.typical_price(dataframe), window=20, stds=2)
        dataframe['bb_upperband'] = bollinger['upper']
        dataframe['bb_middleband'] = bollinger['mid']
        dataframe['bb_lowerband'] = bollinger['lower']
        dataframe['bb_width'] = (dataframe['bb_upperband'] - dataframe['bb_lowerband']) / dataframe['bb_middleband']
        dataframe['bb_pct'] = (dataframe['close'] - dataframe['bb_lowerband']) / (dataframe['bb_upperband'] - dataframe['bb_lowerband'])
        
        # RSI for overbought/oversold conditions
        dataframe['rsi'] = ta.RSI(dataframe, timeperiod=14)
        
        # ADX for trend strength
        dataframe['adx'] = ta.ADX(dataframe)
        
        # Short-term price change metrics for trend strength
        dataframe['price_change_1h'] = dataframe['close'].pct_change(12).fillna(0) * 100  # 12 x 5m = 1h
        
        # Volume based metrics
        dataframe['volume_change'] = dataframe['volume'] / dataframe['volume'].shift(1)
        
        return dataframe

    def populate_entry_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        """
        Entry signals for short-term trading
        """
        dataframe.loc[
            (
                # Uptrend condition
                (dataframe['ema9'] > dataframe['ema21']) &
                
                # Momentum rising
                (dataframe['macd'] > dataframe['macdsignal']) &
                
                # RSI rising but not overbought
                (dataframe['rsi'] > 50) & (dataframe['rsi'] < 70) &
                
                # Price below upper Bollinger - still room to grow
                (dataframe['close'] < dataframe['bb_upperband']) &
                
                # Significant volume
                (dataframe['volume'] > 0.8 * dataframe['volume_mean']) &
                
                # ADX showing that we're in a trend
                (dataframe['adx'] > 25)
            ),
            'enter_long'] = 1

        dataframe.loc[
            (
                # Downtrend condition
                (dataframe['ema9'] < dataframe['ema21']) &
                
                # Momentum falling
                (dataframe['macd'] < dataframe['macdsignal']) &
                
                # RSI falling but not oversold
                (dataframe['rsi'] < 50) & (dataframe['rsi'] > 30) &
                
                # Price above lower Bollinger - still room to fall
                (dataframe['close'] > dataframe['bb_lowerband']) &
                
                # Significant volume
                (dataframe['volume'] > 0.8 * dataframe['volume_mean']) &
                
                # ADX showing that we're in a trend
                (dataframe['adx'] > 25)
            ),
            'enter_short'] = 1

        return dataframe

    def populate_exit_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        """
        Exit signals for short-term trading
        """
        dataframe.loc[
            (
                (
                    # Trend reversal - EMA crossover
                    (dataframe['ema9'] < dataframe['ema21']) |
                    
                    # RSI overbought
                    (dataframe['rsi'] > 75) |
                    
                    # Price hitting upper Bollinger Band
                    (dataframe['close'] > dataframe['bb_upperband']) |
                    
                    # MACD crossing below signal line
                    (qtpylib.crossed_below(dataframe['macd'], dataframe['macdsignal']))
                )
            ),
            'exit_long'] = 1

        dataframe.loc[
            (
                (
                    # Trend reversal - EMA crossover
                    (dataframe['ema9'] > dataframe['ema21']) |
                    
                    # RSI oversold
                    (dataframe['rsi'] < 25) |
                    
                    # Price hitting lower Bollinger Band
                    (dataframe['close'] < dataframe['bb_lowerband']) |
                    
                    # MACD crossing above signal line
                    (qtpylib.crossed_above(dataframe['macd'], dataframe['macdsignal']))
                )
            ),
            'exit_short'] = 1

        return dataframe
    
    def custom_stoploss(self, pair: str, trade: Trade, current_time: datetime,
                        current_rate: float, current_profit: float, **kwargs) -> float:
        """
        Custom stoploss for short-term trading
        """
        # For short-term trading, we want to exit losing trades quickly
        # and give winning trades room to grow
        
        # If we're in profit, use a tighter stoploss to protect gains
        if current_profit > 0.01:  # 1%
            return 0.005  # 0.5% from current price
        
        # Default to stoploss defined in strategy
        return self.stoploss