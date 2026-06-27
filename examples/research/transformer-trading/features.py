import pandas as pd
from ta.trend import sma_indicator, ema_indicator, macd_diff, macd_signal
from ta.momentum import stochrsi_k, stochrsi_d, rsi
from ta.volatility import bollinger_hband, bollinger_lband

class FeatureEngineer:
    
    # date/time features
    
    @staticmethod
    def hour(date_series: pd.Series) -> pd.Series:
        return date_series.dt.hour
    
    @staticmethod
    def dayofweek(date_series: pd.Series) -> pd.Series:
        return date_series.dt.dayofweek
    
    @staticmethod
    def dayofmonth(date_series: pd.Series) -> pd.Series:
        return date_series.dt.day
    
    @staticmethod
    def month(date_series: pd.Series) -> pd.Series:
        return date_series.dt.month
    
    # trend following indicators
    
    @staticmethod
    def sma(price: pd.Series, window: int=20) -> pd.Series:
        return sma_indicator(price, window)

    @staticmethod
    def ema(price: pd.Series, window: int=20) -> pd.Series:
        return ema_indicator(price, window)

    @staticmethod
    def macd_diff(price: pd.Series, window_slow: int=26, window_fast: int=12, window_signal: int=9) -> pd.Series:
        return macd_diff(price, window_slow=window_slow, window_fast=window_fast, window_sign=window_signal)

    @staticmethod
    def macd_signal(price: pd.Series, window_slow: int=26, window_fast: int=12, window_signal: int=9) -> pd.Series:
        return macd_signal(price, window_slow=window_slow, window_fast=window_fast, window_sign=window_signal)
    
    # momentum indicators
    
    @staticmethod
    def rsi(price: pd.Series, window: int=14) -> pd.Series:
        return rsi(price, window)
    
    @staticmethod
    def stochrsi_k(price: pd.Series, window: int=14, smooth1: int=3, smooth2: int=3) -> pd.Series:
        return stochrsi_k(price, window=window, smooth1=smooth1, smooth2=smooth2)
    
    @staticmethod
    def stochrsi_d(price: pd.Series, window: int=14, smooth1: int=3, smooth2: int=3) -> pd.Series:
        return stochrsi_d(price, window=window, smooth1=smooth1, smooth2=smooth2)
    
    # volatility indicators
    
    @staticmethod
    def bollinger_hband(price: pd.Series, window: int=20, window_dev: int=2) -> pd.Series:
        return bollinger_hband(price, window=window, window_dev=window_dev)

    @staticmethod
    def bollinger_lband(price: pd.Series, window: int=20, window_dev: int=2) -> pd.Series:
        return bollinger_lband(price, window=window, window_dev=window_dev)
    
    @staticmethod
    def get_all(data: pd.DataFrame) -> pd.DataFrame:
        
        """Compute all features and returns a DataFrame."""
        
        return pd.DataFrame({
            "hour": FeatureEngineer.hour(data["time"]),
            "dayofweek": FeatureEngineer.dayofweek(data["time"]),
            "dayofmonth": FeatureEngineer.dayofmonth(data["time"]),
            "month": FeatureEngineer.month(data["time"]),
            "sma_20": FeatureEngineer.sma(data["close"]),
            "ema_20": FeatureEngineer.ema(data["close"]),
            "macd_diff": FeatureEngineer.macd_diff(data["close"]),
            "macd_signal": FeatureEngineer.macd_signal(data["close"]),
            "rsi": FeatureEngineer.rsi(data["close"]),
            "stochrsi_k": FeatureEngineer.stochrsi_k(data["close"]),
            "stochrsi_d": FeatureEngineer.stochrsi_d(data["close"]),
            "bollinger_hband": FeatureEngineer.bollinger_hband(data["close"]),
            "bollinger_lband": FeatureEngineer.bollinger_lband(data["close"]),
        })