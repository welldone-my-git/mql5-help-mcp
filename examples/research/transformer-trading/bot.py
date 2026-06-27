import MetaTrader5 as mt5
import features
import os
import model
import pandas as pd
import numpy as np
import pickle
from pytorch_forecasting import TimeSeriesDataSet
from pytorch_forecasting.data import GroupNormalizer
from Trade.Trade import CTrade
import schedule
import time
    

outputs_dir = "Outputs"
os.makedirs(outputs_dir, exist_ok=True)

optuna_timeout = 60  # seconds
max_training_epochs = 50

trained_model = None

def prepare_data(rates_df: pd.DataFrame) -> pd.DataFrame:
    
    rates_df["time"] = pd.to_datetime(rates_df["time"], unit="s") # convert time in seconds to datetime
    
    features_df = features.FeatureEngineer.get_all(rates_df)
    data = pd.concat([rates_df, features_df], axis=1) # concatenate dataframes
    
    # making the target variable
    
    data["returns"] = data["close"].pct_change()
    data["symbol"] = "EURUSD" # assigning symbol name as a group
    
    # drop NANs if any
    
    data.dropna(inplace=True)
    
    # assigning a time index
    
    data = data.reset_index(drop=True)
    data["time_idx"] = data.index
    
    # let's keep track of unused features
    
    unused_features = ["time", "spread", "real_volume"] 
    return data.drop(columns=unused_features)
    
    

def train_model(start_bar: int=100,
                num_bars: int=1000,
                symbol: int = "EURUSD",
                timeframe: int=mt5.TIMEFRAME_M15,
                max_prediction_length: int = 6,
                max_encoder_length: int = 24,
                load_best_parameters = False):
    
    # we extract training data from MetaTrader 5
    
    try:
        rates = mt5.copy_rates_from_pos(symbol, timeframe, start_bar, num_bars)
    except Exception as e:
        print("Error retrieving data from MetaTrader 5: ", e)
        return
    
    data = prepare_data(rates_df=pd.DataFrame(rates))
    
    # ------------ preparing training data and data loaders ------------
    
    training_cutoff = data["time_idx"].max() - max_prediction_length

    training = TimeSeriesDataSet(
        data[lambda x: x.time_idx <= training_cutoff],
        time_idx="time_idx",
        target="returns",
        group_ids=["symbol"],
        min_encoder_length=max_encoder_length // 2,  # keep encoder length long (as it is in the validation set)
        max_encoder_length=max_encoder_length,
        min_prediction_length=1,
        max_prediction_length=max_prediction_length,
        static_categoricals=["symbol"],
        # time_varying_known_categoricals=[],
        
        time_varying_known_reals=[
                                "hour",
                                "dayofweek",
                                "dayofmonth",
                                "month",
                                "time_idx", 
                                "stochrsi_k",
                                "stochrsi_d",
                                "rsi",
                                "macd_diff",
                                ],
        
        time_varying_unknown_categoricals=[],
        time_varying_unknown_reals=[
            "open",
            "high",
            "low",
            "close",
            "tick_volume",
            "ema_20",
            "sma_20",
            "bollinger_hband",
            "bollinger_lband"
        ],
        
        target_normalizer=GroupNormalizer(
            groups=["symbol"], transformation="softplus"
        ),  # use softplus and normalize by group
        
        add_relative_time_idx=True,
        add_target_scales=True,
        add_encoder_length=True,
    )

    # create validation set (predict=True) which means to predict the last max_prediction_length points in time
    # for each series
    validation = TimeSeriesDataSet.from_dataset(
        training, data, predict=True, stop_randomization=True
    )

    # create dataloaders for model
    batch_size = 128  # set this between 32 to 128
    train_dataloader = training.to_dataloader(
        train=True, batch_size=batch_size, num_workers=4, persistent_workers=True
    )
    val_dataloader = validation.to_dataloader(
        train=False, batch_size=batch_size * 10, num_workers=4, persistent_workers=True
    )

    best_params_path = os.path.join(outputs_dir, "best_params.pkl")
    
    if load_best_parameters:
        try:
            with open(best_params_path, "rb") as fin:
                best_params = pickle.load(fin)
        except Exception as e:
            print("Error loading best parameters: ", e)
            print("Finding optimal parameters instead...")
            
            best_params = model.TFTModel.find_optimal_parameters(train_dataloader=train_dataloader,
                                                    val_dataloader=val_dataloader,
                                                    timeout=optuna_timeout,
                                                    best_params_path=best_params_path,
                                                    )
    else:
        best_params = model.TFTModel.find_optimal_parameters(train_dataloader=train_dataloader,
                                                    val_dataloader=val_dataloader,
                                                    timeout=optuna_timeout,
                                                    best_params_path=best_params_path
                                                    )
        
    print("Best hyperparameters found: ", best_params)
    
    global trained_model
    trained_model = model.TFTModel(
        training=training,
        train_dataloader=train_dataloader,
        val_dataloader=val_dataloader,
        parameters=best_params,
        trainer_max_epochs=max_training_epochs
    )
    
    trained_model.load_best_model()
    trained_model.fit()


def pos_exists(symbol: str, magic: int, type: int) -> bool:
    
    for pos in mt5.positions_get():
        if pos.symbol == symbol and pos.magic == magic and pos.type == type:
            return True
        
    return False

def close_by_type(symbol: str, magic: int, type: int):
    
    for pos in mt5.positions_get():
        if pos.symbol == symbol and pos.magic == magic and pos.type == type:
            m_trade.position_close(pos.ticket, slippage)
        

timeframe = mt5.TIMEFRAME_M15
symbol = "EURUSD"
magic_number = 20012026
slippage = 100

lookback_window = 24
lookahead_window = 6

if __name__ == "__main__":

    mt5_exe_path = r"C:\Program Files\MetaTrader 5 IC Markets Global\terminal64.exe"
    
    if not mt5.initialize(mt5_exe_path):
        print("initialize() failed, error code =", mt5.last_error())
        quit()

    m_trade = CTrade(magic_number=magic_number, filling_type_symbol=symbol, deviation_points=slippage, mt5_instance=mt5)


    def trading_function():
        
        global trained_model
        if trained_model is None:
            
            train_model(symbol=symbol, timeframe=timeframe, max_encoder_length=lookback_window, max_prediction_length=lookahead_window, load_best_parameters=True) # get a trained model instance
            return
        
        # ---------- get data for model's inference -------
        
        rates = mt5.copy_rates_from_pos(symbol, timeframe, 0, 100)
        rates_df = pd.DataFrame(rates)
        
        if rates_df.empty:
            return
        
        data = prepare_data(rates_df=rates_df)
        
        predicted_returns = trained_model.predict(x=data, return_x=False, return_y=False)
        print(f"predicted returns: {np.array(predicted_returns)}")
        
        
        next_return = np.array(predicted_returns).ravel()[-1]
        print(f"next_return: {next_return:.2f}")
        
        # ------------- some trading strategy ----------------
        
        tick_info = mt5.symbol_info_tick(symbol)
        if tick_info is None:
            print("Failed to get tick information. Error = ",mt5.last_error())
            return
        
        symbol_info = mt5.symbol_info(symbol)
        if symbol_info is None:
            print(f"Failed to get information for {symbol}")
            return 
        
        lotsize = symbol_info.volume_min
        
        if next_return > 0:
            if not pos_exists(symbol=symbol, magic=magic_number, type=mt5.POSITION_TYPE_BUY):
                m_trade.buy(volume=lotsize, symbol=symbol, price=tick_info.ask)
                close_by_type(symbol=symbol, magic=magic_number, type=mt5.POSITION_TYPE_SELL) # close a different type 
        else:
            if not pos_exists(symbol=symbol, magic=magic_number, type=mt5.POSITION_TYPE_SELL):
                m_trade.sell(volume=lotsize, symbol=symbol, price=tick_info.bid)
                close_by_type(symbol=symbol, magic=magic_number, type=mt5.POSITION_TYPE_BUY) # close a different type
                

    schedule.every(15).minutes.do(trading_function) # check for signals after 15 minutes (according to the timeframe)
    schedule.every(lookback_window*15).minutes.do(train_model, 
                                                max_encoder_length=lookback_window, 
                                                max_prediction_length=lookahead_window)
    
    while True:
        schedule.run_pending()
        time.sleep(1)

