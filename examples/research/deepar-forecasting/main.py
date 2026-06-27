import pandas as pd
import numpy as np
from pytorch_forecasting import DeepAR, TimeSeriesDataSet, GroupNormalizer
from pytorch_forecasting.metrics import MultivariateNormalDistributionLoss, QuantileLoss
from pytorch_forecasting import DeepAR
import train
import config
import MetaTrader5 as mt5
from Trade.PositionInfo import CPositionInfo
from Trade.SymbolInfo import CSymbolInfo
from Trade.Trade import CTrade
import warnings
import schedule
import time
import os

# -------------- global variables --------------------

warnings.filterwarnings("ignore")

symbols = [
    "EURUSD",
    "GBPUSD",
    "USDJPY",
    "USDCHF",
    "AUDUSD",
    "USDCAD",
    "NZDUSD"
]

timeframe = mt5.TIMEFRAME_D1

# config.best_model_name += f"_{symbol}_{timeframe}" # append symbol and timeframe to model name
config.best_model_name += f"_{timeframe}" # append symbol and timeframe to model name

# --------------- configure metatrader5 modules -------------------

if not mt5.initialize(): # initialize MetaTrader 5
    print(f"failed to initialize MetaTrader5, Error = {mt5.last_error()}")
    exit()    

m_position = CPositionInfo(mt5_instance=mt5)
m_trades = [CTrade(mt5_instance=mt5, magic_number=123456, filling_type_symbol=symbol, deviation_points=100) for symbol in symbols]

m_symbols = []
for symbol in symbols:
    s = CSymbolInfo(mt5_instance=mt5)
    s.name(symbol)
    m_symbols.append(s)

# --------------- get historical data from MetaTrader 5 -------------------

def feature_engineering(df: pd.DataFrame, symbol: str) -> pd.DataFrame:
    
    # convert time in seconds to datetime
    df['time'] = pd.to_datetime(df['time'], unit='s')
    df = df.sort_values("time").reset_index(drop=True)

    # print(df.head())

    df["time_idx"] = np.arange(len(df))
    df["symbol"] = symbol

    # print(df.head())

    # instead of using close price which is very hard to predict let's use close price returns

    df["returns"] = (df["close"].shift(-1) - df["close"]) / df["close"]
    df = df.dropna().reset_index(drop=True)

    df["hour"] = df["time"].dt.hour.astype(str)
    df["day_of_week"] = df["time"].dt.dayofweek.astype(str)
    df["month"] = df["time"].dt.month.astype(str)

    return df[["time_idx", "returns", "symbol", "hour", "day_of_week", "month"]]

def pos_exists(magic_number: int, symbol: str, pos_type: int, m_symbol: CSymbolInfo) -> bool:
    
    """
    Check if a position of a given type and magic number exists.

    Args:
        pos_type (int): Position type (1 for buy, -1 for sell).
        magic_number (int): Magic number of the position.

    Returns:
        bool: True if such a position exists, False otherwise.
    """
    
    positions = mt5.positions_get()
    if positions is None:
        return False

    for pos in positions:
        if m_position.select_position(pos):
            if m_position.magic() == magic_number and m_position.symbol() == symbol and m_position.position_type() == pos_type:
                return True

    return False

def is_valid_sl_tp(sl: float, tp: float, price: float, m_symbol: CSymbolInfo) -> bool:

    point = m_symbol.point()
    digits = m_symbol.digits()
    stops_level = m_symbol.stops_level() * point
    freeze_level = m_symbol.freeze_level() * point

    # normalize everything
    price = round(price, digits)
    sl = round(sl, digits) if sl is not None else None
    tp = round(tp, digits) if tp is not None else None

    # distance-based validation (NOT price comparison)
    if sl is not None:
        if abs(sl - price) < stops_level:
            print("SL too close after rounding.")
            return False
        if abs(sl - price) < freeze_level:
            print("SL inside freeze level.")
            return False

    if tp is not None:
        if abs(price - tp) < stops_level:
            print("TP too close after rounding.")
            return False
        if abs(price - tp) < freeze_level:
            print("TP inside freeze level.")
            return False

    return True


model = None # global model variable   


def training_job():
    global model    
        
    # -------- feature engineering ---------
    
    ts_df = pd.DataFrame()
    for symbol in symbols:
        try:
            
            df = pd.DataFrame(mt5.copy_rates_from_pos(symbol, timeframe, config.train_start_bar, config.train_total_bars))
            temp_df = feature_engineering(df, symbol)
            
            ts_df = pd.concat([ts_df, temp_df], axis=0, ignore_index=True)
            
        except Exception as e:
            print(f"Failed to get historical data from MetaTrader 5: {e} for symbol {symbol}")
            continue
    
    print(ts_df.head())
    print(ts_df.tail())

    # ----- create timeseries datasets and dataloaders -----
    
    training_cutoff = ts_df["time_idx"].max() - config.max_prediction_length

    training = TimeSeriesDataSet(
        data=ts_df[ts_df.time_idx <= training_cutoff],
        time_idx="time_idx",
        target="returns",
        group_ids=["symbol"],
        
        max_encoder_length=config.max_encoder_length,
        max_prediction_length=config.max_prediction_length,
        
        min_encoder_length=config.min_encoder_length,
        # min_prediction_length=1,
        
        allow_missing_timesteps=True,
        
        time_varying_known_categoricals=["hour", "day_of_week", "month"],
        
        time_varying_known_reals=["time_idx"],
        time_varying_unknown_reals=["returns"],
        
        target_normalizer=GroupNormalizer(groups=["symbol"], transformation="log1p")
    )

    validation = TimeSeriesDataSet.from_dataset(training, ts_df, min_prediction_idx=training_cutoff + 1)

    train_dataloader = training.to_dataloader(train=True, batch_size=config.batch_size, num_workers=config.num_workers, batch_sampler="synchronized")
    val_dataloader = validation.to_dataloader(train=False, batch_size=config.batch_size, num_workers=config.num_workers, batch_sampler="synchronized")    
    
    model = train.run(training=training,
              train_dataloader=train_dataloader,
              val_dataloader=val_dataloader,
              loss=MultivariateNormalDistributionLoss(rank=30),
              best_model_name=config.best_model_name)


def load_model():
    global model
    
    try:
        model = DeepAR.load_from_checkpoint(
            checkpoint_path=os.path.join(config.models_path, config.best_model_name+".ckpt"),
            weights_only=False,
        )
    except Exception as e:
        print(f"Failed to load model from checkpoint: {e}")
        model = None
        return False
    
    return True


def trading_loop():
    
    global model
    if model is None:
        if not load_model():
            print("Model not loaded, skipping trading loop.")
            return False
    
    # ----------- get realtime data from MetaTrader 5 -----------
    
    ts_df = pd.DataFrame()
    for symbol in symbols:
        try:
            
            df = pd.DataFrame(mt5.copy_rates_from_pos(symbol, timeframe, 1, config.max_encoder_length + config.max_prediction_length))
            temp_df = feature_engineering(df, symbol)
            
            ts_df = pd.concat([ts_df, temp_df], axis=0, ignore_index=True)
            
        except Exception as e:
            
            print(f"Failed to get realtime data from MetaTrader 5: {e} for symbol {symbol}")
            continue
    
    # ---------- use the model to make predictions ----------
    
    predictions = model.predict(data=ts_df, mode="prediction")
    predictions = np.array(predictions)
    # print("Predictions: ", predictions)
    
    forecast_index = -1  # last-step forecast
        
    for idx, (symbol, m_trade, m_symbol) in enumerate(zip(symbols, m_trades, m_symbols)):
        
        # get latest symbol info
        
        if not m_symbol.refresh_rates():
            print(f"failed to refresh rates for symbol {symbol}, Error = {mt5.last_error()}")
            return
        
        min_lotsize = m_symbol.lots_min()
        
        ask = m_symbol.ask()
        bid = m_symbol.bid()
        
        # ------------ Get a corresponding prediction -----------
        
        predicted_return = predictions[idx][forecast_index] 
        price_delta = predicted_return * df["close"].iloc[-1]
        
        digits = m_symbol.digits()
        
        # ------------ sl and tp according to model predictions ------------
        
        if predicted_return > 0:
            
            tp = round(ask + price_delta, digits)
            sl = round(ask - abs(price_delta), digits)

            if not is_valid_sl_tp(sl=sl, tp=tp, price=ask, m_symbol=m_symbol):
                return
            
            if not pos_exists(magic_number=m_trade.magic_number, symbol=symbol, pos_type=mt5.POSITION_TYPE_BUY, m_symbol=m_symbol):
                if not m_trade.buy(symbol=symbol, volume=min_lotsize, price=ask, sl=sl, tp=tp):
                    print(f"Buy order failed, Error = {mt5.last_error()} | price= {ask}, sl= {sl}, tp= {tp}")
            
        else:
            
            tp = round(bid - abs(price_delta), digits)
            sl = round(bid + abs(price_delta), digits)

            if not is_valid_sl_tp(sl=sl, tp=tp, price=bid, m_symbol=m_symbol):
                return
        
            if not pos_exists(magic_number=m_trade.magic_number, symbol=symbol, pos_type=mt5.POSITION_TYPE_SELL, m_symbol=m_symbol):
                if not m_trade.sell(symbol=symbol, volume=min_lotsize, price=bid, sl=sl, tp=tp):
                    print(f"Sell order failed, Error = {mt5.last_error()} | price= {bid}, sl= {sl}, tp= {tp}")

    return True


# check if the model doesn't exist, if so train it for the first time
if not os.path.exists(os.path.join(config.models_path, config.best_model_name+".ckpt")):
    training_job()
    
schedule.every(config.train_interval_minutes).minutes.do(training_job)
schedule.every(1).seconds.do(trading_loop)

while True:
    schedule.run_pending()
    time.sleep(1)

mt5.shutdown()

