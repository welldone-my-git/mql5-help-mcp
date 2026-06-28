import pandas as pd
import numpy as np
import MetaTrader5 as mt5
from statsmodels.tsa.api import VAR

class VARForecaster:
    def __init__(self, symbol: str, timeframe: int):
        self.symbol = symbol
        self.timeframe = timeframe
        self.model = None
        
    def train(self, start_bar: int=1, total_bars: int=10000, max_lags: int=30):
        
        """Trains the VAR model using the collected OHLC from given bars from MetaTrader5
        
            start_bar:
                int: The recent bar according to copyrates_from_pos 
            total_bars:
                int: Total number of bars to use for training
            max_lags:
                int: The maximum number of lags to use 
        """
        
        self.max_lags = max_lags
        
        if not mt5.symbol_select(self.symbol, True):
            print("Failed to select and add a symbol to the MarketWatch, Error = ",mt5.last_error())
            quit()
            
        rates = mt5.copy_rates_from_pos(self.symbol, self.timeframe, start_bar, total_bars)
        
        if rates is None:
            print("Failed to get copy rates Error =", mt5.last_error())
            return
        
        if total_bars < max_lags:
            print(f"Failed to train, max_lags: {max_lags} must be > total_bars: {total_bars}")
            return
        
        train_df  = pd.DataFrame(rates) # convert rates into a pandas dataframe

        train_df = train_df[["open", "high", "low", "close"]]
        
        stationary_df = pd.DataFrame()
        stationary_df["high_open"] = train_df["high"] - train_df["open"]
        stationary_df["open_low"] = train_df["open"] - train_df["low"]
        
        self.model = VAR(stationary_df)
    
        # Select optimal lag using AIC
        
        lag_order = self.model.select_order(maxlags=self.max_lags)
        print(lag_order.summary())
        
        # Fit the model with selected lag
        
        self.model_results = self.model.fit(lag_order.aic)
        print(self.model_results.summary())
        
    def forecast_next(self):
        
        """Gets recent OHLC from MetaTrader5 and predicts the next differentiated prices

        Returns:
            np.array: predicted values
        """
        
        forecast = None
            
        # Get required lags for prediction
        rates = mt5.copy_rates_from_pos(self.symbol, self.timeframe, 0, self.model_results.k_ar) # Get rates starting at the current bar to bars=lags used during training
        
        if rates is None or len(rates) < self.model_results.k_ar:
            print("Failed to get copy rates Error =", mt5.last_error())
            return forecast
            
        # Prepare input data and make forecast
        input_data = pd.DataFrame(rates)[["open", "high", "low", "close"]]
        
        stationary_input = pd.DataFrame({
                "high_open": input_data["high"] - input_data["open"],
                "open_low": input_data["open"] - input_data["low"]
            })
            
        stationary_input = stationary_input.values[-self.model_results.k_ar:]
        
        try:
            forecast = self.model_results.forecast(stationary_input, steps=1) # predict the next price
        except Exception as e:
            print("Failed to forecast: ", str(e))
            return forecast
            
        try:
            updated_data = np.vstack([self.model_results.endog, stationary_input[-1]]) # concatenate new/last datapoint to the data used during previous training
            updated_model = VAR(updated_data).fit(maxlags=self.model_results.k_ar) # Retrain the model with new data
        except Exception as e:
            print("Failed to update the model: ", str(e))
            return forecast
        
        self.model = updated_model
            
        return forecast