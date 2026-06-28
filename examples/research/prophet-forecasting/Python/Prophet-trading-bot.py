import MetaTrader5 as mt5
import pandas as pd

import MetaTrader5 as mt5
from Trade.TerminalInfo import CTerminalInfo
from Trade.SymbolInfo import CSymbolInfo
from Trade.PositionInfo import CPositionInfo
from Trade.Trade import CTrade

import matplotlib.pyplot as plt
from prophet import Prophet
from datetime import datetime
import time
import schedule
import os
import warnings


warnings.filterwarnings("ignore")

if not mt5.initialize(): # Initializing MetaTrader5
    print("Failed to initialize MetaTrader5. Error = ",mt5.last_error())
    mt5.shutdown()


# Global varibles 

symbol = "EURUSD"
timeframe = "PERIOD_H1"
terminal = CTerminalInfo()
m_position = CPositionInfo()

def prophet_vol_predict() -> float:

    # Getting the data with news
    
    now_utc = datetime.utcnow()
    current_date = now_utc.strftime("%Y.%m.%d")
    current_hour = now_utc.hour

    filename = f"{symbol}.{timeframe}.OHLC.date={current_date}.hour={current_hour} + News.csv" # the same file naming as in MQL5 script
    common_path = os.path.join(terminal.common_data_path(), "Files")
    csv_path = os.path.join(common_path, filename)
    
    # Keep trying to read a csv file until it is found as there could be a temporary difference in values for the file due to the change in time
    while True:
        if os.path.exists(csv_path):
            try:
                rates_df = pd.read_csv(csv_path)
                rates_df["Time"] = pd.to_datetime(rates_df["Time"], unit="s", errors="ignore")  # Convert time from seconds to datetime
                
                print("File loaded successfully.")
                break  # Exit the loop once file is read
            except Exception as e:
                print(f"Error reading the file: {e}")
                time.sleep(30)
        else:
            print(f"File not found '{csv_path}'. Retrying in 30 seconds...")
            time.sleep(30)

    # Getting continous variables for the prophet model
    
    prophet_df = pd.DataFrame({
        "time": rates_df["Time"],
        "volatility": rates_df["High"] - rates_df["Low"]
    }).set_index("time")

    prophet_df = prophet_df.reset_index().rename(columns={"time": "ds", "volatility": "y"}).copy()
    
    print("Prophet df\n",prophet_df.head())
    
    # Getting the news data for the model as well
    
    news_df = rates_df[
        (rates_df['Name'] != "(null)") & # Filter rows without news at all
        ((rates_df['Importance'] == "CALENDAR_IMPORTANCE_HIGH") | (rates_df['Importance'] == "CALENDAR_IMPORTANCE_MODERATE")) # Filter other news except high importance news
    ].copy()

    holidays = news_df[['Time', 'Name']].rename(columns={
        'Time': 'ds',
        'Name': 'holiday'
    })

    holidays['ds'] = pd.to_datetime(holidays['ds'])  # Ensure datetime format

    holidays['lower_window'] = 0
    holidays['upper_window'] = 1 

    print("Holidays df\n", holidays)
    
    # re-training the prophet model
    
    prophet_model = Prophet(holidays=holidays)
    prophet_model.fit(prophet_df)
    
    # Making future predictions
    
    future = prophet_model.make_future_dataframe(periods=1) # prepare the dataframe for a single value prediction
    forecast = prophet_model.predict(future) # Predict the next one value
    
    return forecast.yhat[0] # return a single predicted value
    

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


def main():
    
    m_symbol = CSymbolInfo(symbol=symbol)
    
    magic_number = 25062025
    slippage = 100
    
    m_trade = CTrade(magic_number=magic_number,
                     filling_type_symbol=symbol,
                     deviation_points=slippage)
    
    m_symbol.refresh_rates() # Get recent information from the market
    
    # we want to open random buy and sell trades if they don't exist and use the predicted volatility to set our stoploss and takeprofit targets
    
    predicted_volatility = prophet_vol_predict()
    print("predicted volatility: ",prophet_vol_predict())
    
    if pos_exists(mt5.POSITION_TYPE_BUY, magic_number, symbol) is False:
        m_trade.buy(volume=m_symbol.lots_min(), 
                    symbol=symbol,
                    price=m_symbol.ask(),
                    sl=m_symbol.ask()-predicted_volatility,
                    tp=m_symbol.ask()+predicted_volatility)
        
    if pos_exists(mt5.POSITION_TYPE_SELL, magic_number, symbol) is False:
        m_trade.sell(volume=m_symbol.lots_min(), 
                     symbol=symbol,
                     price=m_symbol.bid(),
                     sl=m_symbol.bid()+predicted_volatility,
                     tp=m_symbol.bid()-predicted_volatility)
    

schedule.every(1).minute.do(main) # train and run trading operations after every one minute

while True:
    
    schedule.run_pending()
    time.sleep(1)
    