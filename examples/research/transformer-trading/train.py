import warnings

warnings.filterwarnings("ignore")


import copy
from pathlib import Path
import warnings

import lightning.pytorch as pl
from lightning.pytorch.callbacks import EarlyStopping, LearningRateMonitor
from lightning.pytorch.loggers import TensorBoardLogger
import numpy as np
import pandas as pd
import torch

from pytorch_forecasting import Baseline, TemporalFusionTransformer, TimeSeriesDataSet
from pytorch_forecasting.data import GroupNormalizer
import pytorch_forecasting.metrics as metrics 
from pytorch_forecasting.tuning import Tuner

import MetaTrader5 as mt5
import features
import os
import matplotlib.pyplot as plt

outputs_dir = "Outputs"
os.makedirs(outputs_dir, exist_ok=True)
    

# get rates from the MetaTrader5 app

if not mt5.initialize():
    print("initialize() failed, error code =", mt5.last_error())
    quit()

symbol = "EURUSD"
rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M15, 0, 10000)
rates_df = pd.DataFrame(rates)

rates_df.drop(columns=[
            "spread",
            "real_volume"
        ], inplace=True)

rates_df["time"] = pd.to_datetime(rates_df["time"], unit="s") # convert time in seconds to datetimeq
new_features = features.FeatureEngineer.get_all(rates_df)

data = pd.concat([rates_df, new_features], axis=1) # concatenate dataframes
print(data.head(-10))

if data.empty:
    print("No data retrieved from MetaTrader 5")
    exit()

# The target variable

data["returns"] = data["close"].pct_change()
data.dropna(inplace=True)

data["symbol"] = "EURUSD"
# data["timeframe"] = "M15"

# the time index to represent the time steps in a time series

data = data.reset_index(drop=True)
data["time_idx"] = data.index
data.drop(columns=["time"], inplace=True) # drop the datatime column as TFT does not use it directly

print(data.head(-10))
print(data.columns)

max_prediction_length = 6
max_encoder_length = 24
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
    
    # add_relative_time_idx=True,
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
    train=True, batch_size=batch_size, num_workers=0
)
val_dataloader = validation.to_dataloader(
    train=False, batch_size=batch_size * 10, num_workers=0
)

pl.seed_everything(42) # random seed for reproducibility

lr_logger = LearningRateMonitor()  # log the learning rate
logger = TensorBoardLogger("lightning_logs")  # logging results to a tensorboard

# configure network and trainer
early_stop_callback = EarlyStopping(
    monitor="val_loss", min_delta=1e-4, patience=5, verbose=False, mode="min"
)

trainer = pl.Trainer(
    max_epochs=5,
    accelerator="cpu",
    enable_model_summary=True,
    gradient_clip_val=0.1,
    limit_train_batches=50,  # comment in for training, running validation every 30 batches
    # fast_dev_run=True,  # comment in to check that networkor dataset has no serious bugs
    callbacks=[lr_logger, early_stop_callback],
    logger=logger,
)

tft = TemporalFusionTransformer.from_dataset(
    training,
    # not meaningful for finding the learning rate but otherwise very important
    learning_rate=0.03,
    hidden_size=8,  # most important hyperparameter apart from learning rate
    # number of attention heads. Set to up to 4 for large datasets
    attention_head_size=2,
    dropout=0.1,  # between 0.1 and 0.3 are good values
    hidden_continuous_size=8,  # set to <= hidden_size
    loss=metrics.QuantileLoss(),
    optimizer="ranger",
    # reduce learning rate if no improvement in validation loss after x epochs
    # reduce_on_plateau_patience=1000,
)

print(f"Number of parameters in network: {tft.size() / 1e3:.1f}k")


# ---------------- finding the optimal LR ------------------

res = Tuner(trainer).lr_find(
    tft,
    train_dataloaders=train_dataloader,
    val_dataloaders=val_dataloader,
    max_lr=10.0,
    min_lr=1e-6,
)

optimal_lr = res.suggestion()

print(f"suggested learning rate: {optimal_lr}")
fig = res.plot(show=False, suggest=True)

plots_path = os.path.join(outputs_dir, "Plots")
os.makedirs(plots_path, exist_ok=True)

fig.savefig(os.path.join(plots_path, "lr_finder.png"))
plt.close(fig=fig)

# create Temporal Fusion Transformer model

tft = TemporalFusionTransformer.from_dataset(
    training,
    learning_rate=optimal_lr,
    hidden_size=16,
    attention_head_size=2,
    dropout=0.1,
    hidden_continuous_size=8,
    loss=metrics.QuantileLoss(),
    log_interval=10,  # uncomment for learning rate finder and otherwise, e.g. to 10 for logging every 10 batches
    optimizer="ranger",
    reduce_on_plateau_patience=4,
)

print(f"Number of parameters in network: {tft.size() / 1e3:.1f}k")


trainer.fit(
    tft,
    train_dataloaders=train_dataloader,
    val_dataloaders=val_dataloader,
)


best_model_path = trainer.checkpoint_callback.best_model_path
best_tft = TemporalFusionTransformer.load_from_checkpoint(best_model_path)

tft_predictions = tft.predict(val_dataloader, return_y=True)
print("TFT MAE: ", metrics.MAE()(tft_predictions.output, tft_predictions.y))

# raw predictions are a dictionary from which all kind of information including quantiles can be extracted
raw_predictions = best_tft.predict(
    val_dataloader, mode="raw", return_x=True, trainer_kwargs=dict(accelerator="cpu")
)

n = raw_predictions.output.prediction.shape[0]
print(f"Plotting {n} predictions...")

for idx in range(n):
    fig = best_tft.plot_prediction(
        raw_predictions.x,
        raw_predictions.output,
        idx=idx,
        add_loss_to_title=True
    )
    
    fig.savefig(os.path.join(plots_path, f"tft_prediction_{idx}.png"))
    plt.close(fig=fig)

# ------------------ baseline model ------------------

# calculate baseline mean absolute error, i.e. predict next value as the last available value from the history

baseline_predictions = Baseline().predict(val_dataloader, return_y=True)
print("Baseline model MAE: ",metrics.MAE()(baseline_predictions.output, baseline_predictions.y))
exit()

# optimize the hyperparameters using Optuna

best_params = optimize.optuna_optimization(train_dataloader=train_dataloader,
                                        val_dataloader=val_dataloader,
                                        max_epochs=50,
                                        n_trials=100,
                                        use_learning_rate_finder=True,
                                        model_path=os.path.join(outputs_dir, "optuna_test"),
                                        best_params_path=os.path.join(outputs_dir, "best_params.pkl"),
                                        timeout=600) 

# load the best model according to the validation loss
# (given that we use early stopping, this is not necessarily the last epoch)

best_tft = TemporalFusionTransformer.from_dataset(
    training,
    learning_rate=best_params["learning_rate"],
    hidden_size=best_params["hidden_size"],
    dropout=best_params["dropout"],
    hidden_continuous_size=best_params["hidden_continuous_size"],
    attention_head_size=best_params["attention_head_size"],
    loss=metrics.QuantileLoss(),
    optimizer="ranger",
    reduce_on_plateau_patience=4,
)

trainer.fit(
    best_tft,
    train_dataloaders=train_dataloader,
    val_dataloaders=val_dataloader,
)

    
best_model_path = trainer.checkpoint_callback.best_model_path
best_tft = TemporalFusionTransformer.load_from_checkpoint(best_model_path)

preds = best_tft.predict(val_dataloader, return_y=True)
print("TFT MAE after Optuna:", metrics.MAE()(preds.output, preds.y))

