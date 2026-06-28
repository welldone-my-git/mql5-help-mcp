import MetaTrader5 as mt5
import schedule
import time

import ta
from VAR import VARForecaster
from Trade.Trade import CTrade
from Trade.SymbolInfo import CSymbolInfo
from Trade.PositionInfo import CPositionInfo
import numpy as np
import pandas as pd

symbol = "EURUSD"
timeframe = mt5.TIMEFRAME_D1
mt5_path = r"c:\Users\Omega Joctan\AppData\Roaming\Pepperstone MetaTrader 5\terminal64.exe" # replace this with a desired MT5 path

if not mt5.initialize(mt5_path): # initialize MetaTrader5
    print("Failed to initialize MetaTrader5, error =", mt5.last_error())
    quit()

var_model = VARForecaster(symbol=symbol, timeframe=timeframe)
var_model.train(start_bar=1, total_bars=10000, max_lags=30) # Train the VAR Model

# Initlalize the trade classes

MAGICNUMBER = 5062025
SLIPPAGE = 100

m_trade = CTrade(magic_number=MAGICNUMBER, 
                 filling_type_symbol=symbol, 
                 deviation_points=SLIPPAGE)

m_symbol = CSymbolInfo(symbol=symbol)
m_position = CPositionInfo()

#####################################################

def pos_exists(pos_type: int, magic: int, symbol: str) -> bool: 
    
    """Checks whether a position exists given a magic number, symbol, and the position type

    Returns:
        bool: True if a position is found otherwise False
    """
    
    if mt5.positions_total() < 1: # no positions whatsoever
        return False
    
    positions = mt5.positions_get()
    
    for position in positions:
        if m_position.select_position(position):
            if m_position.magic() == magic and m_position.symbol() == symbol and m_position.position_type()==pos_type:
                return True
            
    return False

def trading_strategy():
    
    forecasts_arr = var_model.forecast_next().flatten()
    
    high_open = forecasts_arr[0]
    open_low = forecasts_arr[1]
    
    print(f"high_open: ",high_open, " open_low: ",open_low)
    
    # Get the information about the market
    
    rates = mt5.copy_rates_from_pos(symbol, timeframe, 0, 50) # Get the last 50 bars information
    rates_df = pd.DataFrame(rates)
    
    if rates is None:
        print("Failed to get copy rates Error =", mt5.last_error())
        return 
    
    sma_buffer = ta.trend.sma_indicator(close=rates_df["close"], window=20)
    
    m_symbol.refresh_rates()
    
    if rates_df["close"].iloc[-1] > sma_buffer.iloc[-1]: # current closing price is above sma20
        if pos_exists(pos_type=mt5.POSITION_TYPE_BUY, symbol=symbol, magic=MAGICNUMBER) is False: # If a buy position doesn't exist
            m_trade.buy(volume=m_symbol.lots_min(),
                        symbol=symbol,
                        price=m_symbol.ask(),
                        sl=m_symbol.ask()-open_low,
                        tp=m_symbol.ask()+high_open)

    else: # if the closing price is below the moving average
        
        if pos_exists(pos_type=mt5.POSITION_TYPE_SELL, symbol=symbol, magic=MAGICNUMBER) is False: # If a buy position doesn't exist
            m_trade.sell(volume=m_symbol.lots_min(),
                        symbol=symbol,
                        price=m_symbol.bid(),
                        sl=m_symbol.bid()+high_open,
                        tp=m_symbol.bid()-open_low)
            
    
schedule.every(1).minutes.do(trading_strategy)

while True:
    
    schedule.run_pending()
    time.sleep(60)
    
else:
    mt5.shutdown()