# Importing required libraries
import pandas as pd
import numpy as np
import MetaTrader5 as mt5

# Use auto_arima to automatically select best ARIMA parameters

from pmdarima.arima import auto_arima
import seaborn as sns
import matplotlib.pyplot as plt
import warnings

# Import PACF plot function for lag identification
from statsmodels.graphics.tsaplots import plot_pacf
import os
import schedule
import time

# Suppress warning messages for cleaner output
warnings.filterwarnings("ignore")

# Set seaborn plot style for better visualization
sns.set_style("darkgrid")

plots_path = "Plots"
if not os.path.exists(plots_path):
    os.mkdir(plots_path)

# Getting (EUR/USD OHLC data) from MetaTrader5

mt5_exe_file = r"c:\Users\Omega Joctan\AppData\Roaming\Pepperstone MetaTrader 5\terminal64.exe" # Change this to your MetaTrader5 path
if not mt5.initialize(mt5_exe_file):
    print("Failed to initialize Metatrader5, error = ",mt5.last_error)
    exit()

# select a symbol into the market watch
symbol = "EURUSD"
timeframe = mt5.TIMEFRAME_D1

if not mt5.symbol_select(symbol, True):
    print(f"Failed to select {symbol}, error = {mt5.last_error}")
    mt5.shutdown()
    exit()

rates = mt5.copy_rates_from_pos(symbol, timeframe, 1, 1000) # Get 1000 bars historically
df = pd.DataFrame(rates)

print(df.head(5))
print(df.shape)

plt.figure(figsize=(7,5))
# Plot line chart of closing prices
sns.lineplot(df, x=df.index, y="close")
plt.savefig(os.path.join(plots_path, "close prices.png"))

# Import Augmented Dickey-Fuller test for stationarity check
from statsmodels.tsa.stattools import adfuller

series = df["close"]
# Perform ADF test to check for stationarity
result = adfuller(series)

print(f'p-value: {result[1]}')

plt.figure(figsize=(6,4))
# Remove rows with missing values
plot_pacf(series.diff().dropna(), lags=5)

plt.title("Partial Autocorrelation Plot")
plt.xlabel('Lag')  # X-axis label
plt.ylabel('PACF')  # Y-axis label

plt.savefig(os.path.join(plots_path,"pacf plot.png"))

# Plot ACF to help identify MA term (q)
from statsmodels.graphics.tsaplots import plot_acf

# Original Series
fig, axes = plt.subplots(3, 2, sharex=True, figsize=(9, 9))

axes[0, 0].plot(series); axes[0, 0].set_title('Original Series')
# Plot ACF to help identify MA term (q)
plot_acf(series, ax=axes[0, 1])

# 1st Differencing
# Remove rows with missing values
axes[1, 0].plot(series.diff().dropna()); axes[1, 0].set_title('1st Order Differencing')
# Remove rows with missing values
plot_acf(series.diff().dropna(), ax=axes[1, 1])

# 2nd Differencing
axes[2, 0].plot(series.diff().diff()); axes[2, 0].set_title('2nd Order Differencing')
# Remove rows with missing values
plot_acf(series.diff().diff().dropna(), ax=axes[2, 1])

plt.savefig(os.path.join(plots_path, "acf plots.png"))

# Remove rows with missing values
result = adfuller(series.diff().dropna())
print(f'p-value d=1: {result[1]}')

# Remove rows with missing values
result = adfuller(series.diff().diff().dropna())
print(f'p-value d=2: {result[1]}')

plt.figure(figsize=(7,5))
# Remove rows with missing values
plot_pacf(series.diff().dropna(), lags=20)

plt.title("Partial Autocorrelation Plot")
plt.xlabel('Lag')  # X-axis label
plt.ylabel('PACF')  # Y-axis label

plt.savefig(os.path.join(plots_path, "pacf plot finding q.png"))

# Use auto_arima to automatically select best ARIMA parameters
from pmdarima.arima import auto_arima

# Use auto_arima to automatically select best ARIMA parameters
model = auto_arima(series, seasonal=False, trace=True)
print(model.summary())

print("Best model order (p, d, q):", model.order)

series = df["close"]

train_size = int(len(series) * 0.8)
train, test = series[:train_size], series[train_size:]

from statsmodels.tsa.arima.model import ARIMA

arima_model = ARIMA(train, order=(0,1,0))
arima_model = arima_model.fit()
print(arima_model.summary())

predicted = arima_model.predict(start=1, end=len(train))

print("actual ",len(train)," predicted ",len(predicted))

print(arima_model.predict(steps=10))

plt.figure(figsize=(7,4))
plt.plot(train.index, train, label='Actual')
plt.plot(train.index, predicted, label='Forecasted mean', linestyle='--')
plt.title('Actual vs Forecast')
plt.legend()
plt.savefig(os.path.join(plots_path, "ARIMA train actual&forecast plot.png"))

# Fit initial model

model = ARIMA(train, order=(0, 1, 0)) 
results = model.fit()

# Initialize forecasts
forecasts = [results.forecast(steps=1).iloc[0]]  # First forecast

# Update with test data iteratively
for i in range(len(test)):
    # Append new observation without refitting
    results = results.append(test.iloc[i:i+1], refit=False)
    
    # Forecast next step
    forecasts.append(results.forecast(steps=1).iloc[0])

forecasts = forecasts[:-1] # remove the last element which is the predicted next value 

# Compare forecasts vs actual test data
plt.figure(figsize=(7,5))
plt.plot(test.index, test, label="Actual")
plt.plot(test.index, forecasts, label="Forecast", linestyle="--")
plt.legend()
plt.savefig(os.path.join(plots_path, "ARIMA test actual&forecast plot.png"))

print(f"forecasts len: {len(forecasts)} actual len: {len(test)}")

import sklearn.metrics as metric
from statsmodels.tsa.stattools import acf
from scipy.stats import pearsonr

def forecast_accuracy(forecast, actual):
    # Convert to numpy arrays if they aren't already
    forecast = np.asarray(forecast)
    actual = np.asarray(actual)
    
    metrics = {
        'mape': metric.mean_absolute_percentage_error(actual, forecast),
        'me': np.mean(forecast - actual),  # Mean Error
        'mae': metric.mean_absolute_error(actual, forecast),
        'mpe': np.mean((forecast - actual) / actual),  # Mean Percentage Error
        'rmse': metric.root_mean_squared_error(actual, forecast),
        'corr': pearsonr(forecast, actual)[0],  # Pearson correlation
        'minmax': 1 - np.mean(np.minimum(forecast, actual) / np.maximum(forecast, actual)),
        'acf1': acf(forecast - actual, nlags=1)[1],  # ACF of residuals at lag 1
        "r2_score": metric.r2_score(forecast, actual)
    }
    return metrics

print(forecast_accuracy(forecasts, test))

results.plot_diagnostics(figsize=(8,8))
plt.savefig(os.path.join(plots_path, "ARIMA residuals plot.png"))

series = df["close"] # lets obtain the close prices once mored

train_size = int(len(series) * 0.8)
train, test = series[:train_size], series[train_size:]

# Use auto_arima to automatically select best ARIMA parameters
from pmdarima.arima import auto_arima

# Auto-fit SARIMA (automatically detects P,D,Q,S)

# Use auto_arima to automatically select best ARIMA parameters
auto_model = auto_arima(
    series,
    seasonal=True,          # Enable seasonality
    m=5,                    # Weeky cycle (5 days) for daily data
    trace=True,             # Show search progress
    stepwise=True,          # Faster optimization
    suppress_warnings=True,
    error_action="ignore"
)

print(auto_model.summary())

from statsmodels.tsa.statespace.sarimax import SARIMAX

model = SARIMAX(
    train,
    order=auto_model.order,                  # Non-seasonal (p,d,q)
    seasonal_order=auto_model.order+(5,),      # Seasonal (P,D,Q,S)
    enforce_stationarity=False
)

results = model.fit()
print(results.summary())

predicted = results.predict(start=1, end=len(train))

clean_train = train[5:]
clean_predicted = predicted[5:]

plt.figure(figsize=(7,4))
plt.plot(clean_train.index[5:], clean_train[5:], label='Actual')
plt.plot(clean_train.index[5:], clean_predicted[5:], label='Forecasted mean', linestyle='--')
plt.title('Actual vs Forecast')
plt.legend()
plt.savefig(os.path.join(plots_path, "SARIMAX train actual&forecast plot.png"))

# Initialize forecasts
forecasts = [results.forecast(steps=1).iloc[0]]  # First forecast

# Update with test data iteratively
for i in range(len(test)):
    # Append new observation without refitting
    results = results.append(test.iloc[i:i+1], refit=False)
    
    # Forecast next step
    forecasts.append(results.forecast(steps=1).iloc[0])

clean_test = test[5:]
forecasts = forecasts[5:-1] # remove the last element which is the predicted next value and the first 5 items

print(forecast_accuracy(forecasts, clean_test))

# Make realtime predictions based on the recent data from MetaTrader5

def predict_close():
    
    rates = mt5.copy_rates_from_pos(symbol, timeframe, 0, 1) 
    if not rates:
        print(f"Failed to get recent OHLC values, error = {mt5.last_error}")
        time.sleep(60)
    
    rates_df = pd.DataFrame(rates)    
    
    global results # Get the variable globally, outside the function
    global forecasts
    
    # Append new observation to the model without refitting
    
    new_obs_value = rates_df["close"].iloc[-1]
    new_obs_index = results.data.endog.shape[0]  # continue integer index
    
    new_obs = pd.Series([new_obs_value], index=[new_obs_index]) # Its very important to continue making predictions where we ended on the training data
    results = results.append(new_obs, refit=False)
    
    # Forecast next step
    forecasts.append(results.forecast(steps=1).iloc[0])
    print(f"Current Close Price: {new_obs_value} Forecasted next day Close Price: {forecasts[-1]}")
    

schedule.every(1).days.do(predict_close) # call the predict function after a given time

while True: 
    
    schedule.run_pending()    
    time.sleep(60)

mt5.shutdown()