import MetaTrader5 as mt5
import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns
import schedule
from sklearn.metrics import mean_absolute_percentage_error
from neuralforecast import NeuralForecast 
from neuralforecast.models import NBEATS # Neural Basis Expansion Analysis for Time Series
import datetime as dt
import time
import warnings

sns.set_style("darkgrid")
warnings.filterwarnings("ignore")

# Initialize MetaTrader 5

if not mt5.initialize():
    print("Metratrader5 initialization failed, Error code = ", mt5.last_error())
    mt5.shutdown()

def train_nbeats_model(forecast_horizon: int=30,
                       start_bar: int=1,
                       number_of_bars: int=1000, 
                       input_size: int=90, 
                       max_steps: int=100, 
                       mt5_timeframe: int=mt5.TIMEFRAME_D1,
                       symbol_01: str="NAS100",
                       symbol_02: str="US500",
                       test_size_percentage: float=0.2,
                       scaler_type: str='robust'):
    
    """    
        Train NBEATS model on NAS100 and US500 data from MetaTrader 5.
        
        Args:
            start_bar: starting bar to be used to in CopyRates from MT5
            number_of_bars: The number of bars to extract from MT5 for training the model
            forecast_horizon: the number of days to predict in the future
            input_size: number of previous days to consider for prediction
            max_steps: maximum number of training steps (epochs)
            mt5_timeframe: timeframe to be used for the data extraction from MT5
            symbol_01: unique identifier for the first symbol (default is NAS100)
            symbol_02: unique identifier for the second symbol (default is US500)
            test_size_percentage: percentage of the data to be used for testing (default is 0.2)
            scaler_type: type of scaler to be used for the time series data (default is 'robust')
        
        Returns:
            NBEATS: the n-beats model object
    """
        
    # Getting data from MetaTrader 5

    rates_nq = mt5.copy_rates_from_pos(symbol_01, mt5_timeframe, start_bar, number_of_bars)
    rates_df_nq = pd.DataFrame(rates_nq)

    rates_snp = mt5.copy_rates_from_pos(symbol_02, mt5_timeframe, start_bar, number_of_bars)
    rates_df_snp = pd.DataFrame(rates_snp)

    if rates_df_nq.empty or rates_df_snp.empty:
        print(f"Failed to retrieve data for {symbol_01} or {symbol_02}.")
        return None
    
    # Getting NAS100 data
    rates_df_nq["ds"] = pd.to_datetime(rates_df_nq["time"], unit="s")
    rates_df_nq["y"] = rates_df_nq["close"]
    rates_df_nq["unique_id"] = symbol_01
    df_nq = rates_df_nq[["unique_id", "ds", "y"]]

    # Getting US500 data
    rates_df_snp["ds"] = pd.to_datetime(rates_df_snp["time"], unit="s")
    rates_df_snp["y"] = rates_df_snp["close"]
    rates_df_snp["unique_id"] = symbol_02
    df_snp = rates_df_snp[["unique_id", "ds", "y"]]

    multivariate_df = pd.concat([df_nq, df_snp], ignore_index=True) # combine both dataframes
    multivariate_df = multivariate_df.sort_values(['unique_id', 'ds']).reset_index(drop=True) # sort by unique_id and date

    # Group by unique_id and split per group
    train_df_list = []
    test_df_list = []

    for _, group in multivariate_df.groupby('unique_id'):
        group = group.sort_values('ds')
        split_idx = int(len(group) * (1 - test_size_percentage))

        train_df_list.append(group.iloc[:split_idx])
        test_df_list.append(group.iloc[split_idx:])

    # Concatenate all series
    train_df = pd.concat(train_df_list).reset_index(drop=True)
    test_df = pd.concat(test_df_list).reset_index(drop=True)

    # Define model and horizon

    model = NeuralForecast(
        models=[NBEATS(h=forecast_horizon, # predictive horizon of the model
                    input_size=input_size, # considered autorregresive inputs (lags), y=[1,2,3,4] input_size=2 -> lags=[1,2].
                    max_steps=max_steps, # maximum number of training steps (epochs)
                    scaler_type=scaler_type, # scaler type for the time series data
                    )], 
        freq='D' # frequency of the time series data
    )

    # fit the model on the training data
    
    model.fit(df=train_df)

    test_forecast = model.predict() # predict future 30 days based on the training data

    df_test = pd.merge(test_df, test_forecast, on=['ds', 'unique_id'], how='outer') # merge the test data with the forecast
    df_test.dropna(inplace=True) # drop rows with NaN values


    unique_ids = df_test['unique_id'].unique()
    for unique_id in unique_ids:
        
        df_unique = df_test[df_test['unique_id'] == unique_id].copy()
        
        mape = mean_absolute_percentage_error(df_unique['y'], df_unique['NBEATS'])   
        print(f"Unique ID: {unique_id} - MAPE: {mape:.2f}")
    
    return model


def predict_next(model, 
                  symbol_unique_id: str, 
                  input_size: int=90,
                  timeframe= mt5.TIMEFRAME_D1):
    
    """
        Predict the next values for a given unique_id using the trained model.
        
        Args:
            model (NBEATS): the trained NBEATS model
            symbol_unique_id (str): unique identifier for the symbol to predict
            input_size (int): number of previous days to consider for prediction
        
        Returns:
            DataFrame: containing the predicted values for the next days
    """
    
    # Getting data from MetaTrader 5

    rates = mt5.copy_rates_from_pos(symbol_unique_id, timeframe, 1, input_size * 2)  # Get enough data for prediction
    if rates is None or len(rates) == 0:
        print(f"Failed to retrieve data for {symbol_unique_id}.")
        return pd.DataFrame()
    
    rates_df = pd.DataFrame(rates)
    
    rates_df["ds"] = pd.to_datetime(rates_df["time"], unit="s")
    rates_df = rates_df[["ds", "close"]].rename(columns={"close": "y"})
    rates_df["unique_id"] = symbol_unique_id
    rates_df = rates_df.sort_values(by="ds").reset_index(drop=True)
    
    # Prepare the dataframe for reference & prediction    
    univariate_df = rates_df[["unique_id", "ds", "y"]]
    forecast = model.predict(df=univariate_df)
    
    return forecast
    
# Trading modules 

from Trade.Trade import CTrade
from Trade.PositionInfo import CPositionInfo
from Trade.SymbolInfo import CSymbolInfo

SLIPPAGE = 100 # points
MAGIC_NUMBER = 15072025 # unique identifier for the trades
TIMEFRAME = mt5.TIMEFRAME_D1 # timeframe for the trades

# Create trade objects for NAS100 and US500
m_trade_nq = CTrade(magic_number=MAGIC_NUMBER,
                 filling_type_symbol = "NAS100",
                 deviation_points=SLIPPAGE)

m_trade_snp = CTrade(magic_number=MAGIC_NUMBER,
                 filling_type_symbol = "US500",
                 deviation_points=SLIPPAGE)

# Training the NBEATS model INITIALLY
trained_model = train_nbeats_model(max_steps=100,
                                    input_size=90,
                                    forecast_horizon=30,
                                    start_bar=1,
                                    number_of_bars=1000,
                                    mt5_timeframe=TIMEFRAME,
                                    symbol_01="NAS100",
                                    symbol_02="US500"
                                   )

m_symbol_nq = CSymbolInfo("NAS100") # Create symbol info object for NAS100
m_symbol_snp = CSymbolInfo("US500") # Create symbol info object for US500

m_position = CPositionInfo() # Create position info object


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


def RunStrategyandML(trained_model: NBEATS):

    today = dt.datetime.now().date() # today's date

    forecast_df = predict_next(trained_model, "NAS100") # Get the predicted values for NAS100, 30 days into the future
    today_pred_close_nq = forecast_df[forecast_df['ds'].dt.date == today]['NBEATS'].values # extract today's predicted close value for NAS100

    forecast_df = predict_next(trained_model, "US500") # Get the predicted values for US500, 30 days into the future
    today_pred_close_snp = forecast_df[forecast_df['ds'].dt.date == today]['NBEATS'].values # extract today's predicted close value for US500

    # convert numpy arrays to float values
    
    today_pred_close_nq = float(today_pred_close_nq[0]) if len(today_pred_close_nq) > 0 else None
    today_pred_close_snp = float(today_pred_close_snp[0]) if len(today_pred_close_snp) > 0 else None

    print(f"Today's predicted NAS100 values:", today_pred_close_nq)
    print(f"Today's predicted US500 values:", today_pred_close_snp)
    
    # Refreshing the rates for NAS100 and US500 symbols
    
    m_symbol_nq.refresh_rates()
    m_symbol_snp.refresh_rates()
    
    ask_price_nq = m_symbol_nq.ask() # get today's close price for NAS100
    ask_price_snp = m_symbol_snp.ask() # get today's close price for US500

    # Trading operations for the NAS100 symol
        
    if not pos_exists(pos_type=mt5.ORDER_TYPE_BUY, magic=MAGIC_NUMBER, symbol="NAS100"):
        if today_pred_close_nq > ask_price_nq: # if predicted close price for NAS100 is greater than the current ask price
            # Open a buy trade 
            m_trade_nq.buy(volume=m_symbol_nq.lots_min(), 
                            symbol="NAS100",
                            price=m_symbol_nq.ask(),
                            sl=0.0,
                            tp=today_pred_close_nq) # set take profit to the predicted close price
    
    print("ask: ", m_symbol_nq.ask(), "bid: ", m_symbol_nq.bid(), "last: ", ask_price_nq)
    print("tp: ", today_pred_close_nq, "lots: ", m_symbol_nq.lots_min())
    print("istp within range: ", (m_symbol_nq.ask() - today_pred_close_nq) > m_symbol_nq.stops_level())
    
    if not pos_exists(pos_type=mt5.ORDER_TYPE_SELL, magic=MAGIC_NUMBER, symbol="NAS100"):
        if today_pred_close_nq < ask_price_nq: # if predicted close price for NAS100 is less than the current bid price
            m_trade_nq.sell(volume=m_symbol_nq.lots_min(), 
                             symbol="NAS100",
                             price=m_symbol_nq.bid(),
                             sl=0.0,
                             tp=today_pred_close_nq) # set take profit to the predicted close price
    
    
    # Buy and sell oeprations for the US500 symbol
    
        
    if not pos_exists(pos_type=mt5.ORDER_TYPE_BUY, magic=MAGIC_NUMBER, symbol="US500"):
        if today_pred_close_snp > ask_price_snp: # if the predicted price for US500 is greater than the current ask price
            m_trade_snp.buy(volume=m_symbol_snp.lots_min(), 
                            symbol="US500",
                            price=m_symbol_snp.ask(),
                            sl=0.0,
                            tp=today_pred_close_snp)

    if not pos_exists(pos_type=mt5.ORDER_TYPE_SELL, magic=MAGIC_NUMBER, symbol="US500"):
        if today_pred_close_snp < ask_price_snp: # if the predicted price for US500 is less than the current bid price
            m_trade_snp.sell(volume=m_symbol_snp.lots_min(), 
                             symbol="US500",
                             price=m_symbol_snp.bid(),
                             sl=0.0,
                             tp=today_pred_close_snp)


# Schedule the strategy to run every day at 00:00
schedule.every().day.at("00:00").do(RunStrategyandML, trained_model=trained_model)

while True:
    
    schedule.run_pending()
    time.sleep(10)