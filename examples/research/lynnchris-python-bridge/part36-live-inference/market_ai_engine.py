#!/usr/bin/env python3
import sys
import time
import json
import argparse
import datetime as dt
from datetime import timezone
from pathlib import Path

import numpy as np
import pandas as pd
import ta
import joblib
from flask import Flask, request, jsonify
import MetaTrader5 as mt5
from loguru import logger
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.model_selection import TimeSeriesSplit, RandomizedSearchCV
from prophet import Prophet

# Logger configuration
logger.remove()
logger.add(sys.stderr, level="INFO",
           format="{time:YYYY-MM-DD HH:mm:ss} | {level} | {message}")
logger.add("app_{time:YYYYMMDD}.log", rotation="10 MB", level="DEBUG",
           format="{time:YYYY-MM-DD HH:mm:ss} | {level} | {message}")

# Configuration constants
MAIN_SYMBOL      = "Boom 300 Index"
LOGIN_ID         = 403******
PASSWORD         = "******"
SERVER           = "******"

LOOKAHEAD_MIN    = 10
LABEL_THRESHOLD  = 0.0015
DAYS_TO_PULL     = 60
PARQUET_FILE     = "hist.parquet.zst"
MODEL_FILE       = "model.pkl"
COLLECT_SECONDS  = 60

ATR_PERIOD       = 14
SL_MULT, TP_MULT = 1.0, 2.0

UTC = timezone.utc
pd.set_option("mode.chained_assignment", None)

FEATS = ['z_spike', 'macd', 'rsi', 'atr', 'env_low', 'env_up', 'delta']

app = Flask(__name__)

# MT5 initialization
def mt5_initialize() -> bool:
    if mt5.initialize():
        return True
    return mt5.initialize(login=LOGIN_ID, password=PASSWORD, server=SERVER)

# Data fetching
def fetch_data(start: dt.datetime, end: dt.datetime) -> pd.DataFrame:
    if not mt5_initialize():
        logger.error("MT5 initialization failed")
        return pd.DataFrame()
    mt5.symbol_select(MAIN_SYMBOL, True)
    bars = mt5.copy_rates_range(
        MAIN_SYMBOL, mt5.TIMEFRAME_M1,
        int(start.timestamp()), int(end.timestamp())
    )
    if bars is None or len(bars) == 0:
        return pd.DataFrame()
    df = pd.DataFrame(bars)
    df['Date'] = pd.to_datetime(df['time'], unit='s', utc=True)
    return df.set_index('Date')

# Bootstrapping historical data
def bootstrap():
    p = Path(PARQUET_FILE)
    if p.exists():
        return
    now = dt.datetime.now(UTC)
    df = fetch_data(now - dt.timedelta(days=DAYS_TO_PULL), now)
    if df.empty:
        logger.error("No data fetched in bootstrap; exiting")
        sys.exit(1)
    df.to_parquet(p, compression='zstd')
    logger.info(f"Bootstrapped historical data: {len(df)} rows")

# Append new bars
def append_new_bars() -> int:
    bootstrap()
    df = pd.read_parquet(PARQUET_FILE)
    last_ts = df.index[-1]
    new = fetch_data(last_ts + dt.timedelta(minutes=1),
                     dt.datetime.now(UTC))
    if new.empty:
        return 0
    merged = pd.concat([df, new])
    merged = merged[~merged.index.duplicated(keep='last')]
    merged.to_parquet(PARQUET_FILE, compression='zstd')
    logger.info(f"Appended {len(new)} new bars")
    return len(new)

# Feature engineering
def engineer(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df['close'] = df['close'].astype(float)
    df['r']       = df['close'].diff()
    df['z_spike'] = df['r'] / (df['r'].rolling(20).std().fillna(1e-9))
    df['macd']    = ta.trend.macd_diff(df['close'])
    df['rsi']     = ta.momentum.rsi(df['close'], 14)
    df['atr']     = ta.volatility.average_true_range(
                        df['high'], df['low'], df['close'], ATR_PERIOD)
    ema = df['close'].ewm(span=20).mean()
    df['env_low'] = ema * 0.997
    df['env_up']  = ema * 1.003
    df['delta']   = 0.0
    if len(df) > 200:
        pr = Prophet(daily_seasonality=False, weekly_seasonality=False)
        ds_index = df.index.tz_localize(None) if hasattr(df.index, 'tz') else df.index
        tmp = pd.DataFrame({'ds': ds_index, 'y': df['close']})
        pr.fit(tmp)
        future = pr.make_future_dataframe(periods=0, freq='min')
        df['delta'] = pr.predict(future)['yhat'].values - df['close']
    chg = (df['close'].shift(-LOOKAHEAD_MIN) - df['close']) / df['close']
    df['label'] = np.where(chg > LABEL_THRESHOLD, 1,
                   np.where(chg < -LABEL_THRESHOLD, 2, 0))
    return df.dropna()

# Model training
def train():
    df = engineer(pd.read_parquet(PARQUET_FILE))
    X, y = df[FEATS], df['label']
    pipe = Pipeline([
        ('sc', StandardScaler()),
        ('gb', GradientBoostingClassifier(random_state=42))
    ])
    param = {
        'gb__learning_rate': [0.01, 0.05, 0.1],
        'gb__n_estimators': [300, 500, 700],
        'gb__max_depth': [2, 3, 4]
    }
    rs = RandomizedSearchCV(
        pipe, param, n_iter=12,
        cv=TimeSeriesSplit(5),
        scoring='roc_auc_ovr',
        n_jobs=-1, random_state=42
    )
    rs.fit(X, y)
    joblib.dump(rs.best_estimator_, MODEL_FILE)
    logger.info("Model training complete")

# SL/TP calculation
def sl_tp(price: float, side: str, atr: float):
    if side == 'BUY':
        return price - SL_MULT * atr, price + TP_MULT * atr
    else:
        return price + SL_MULT * atr, price - TP_MULT * atr

# Signal decision
def decide_open(pb: float, ps: float) -> str:
    if pb > 0.55:
        return 'BUY'
    if ps > 0.55:
        return 'SELL'
    return 'WAIT'

# Backtesting
def backtest(days: int = 30, slippage: float = 0.0, commission: float = 0.0):
    mdl = joblib.load(MODEL_FILE)
    end = dt.datetime.now(UTC)
    hist = fetch_data(end - dt.timedelta(days=days), end)
    if hist.empty:
        logger.warning("No history for backtest")
        return
    df = engineer(hist)
    proba = mdl.predict_proba(df[FEATS])
    df['p_buy'], df['p_sell'] = proba[:,1], proba[:,2]

    trades, open_t = [], None
    for ts, row in df.iterrows():
        price, atr = row['close'], row['atr']
        if open_t:
            side, sl, tp = open_t['side'], open_t['sl'], open_t['tp']
            if (side=='BUY' and price<=sl) or (side=='SELL' and price>=sl):
                exit_p, reason = sl, 'SL'
            elif (side=='BUY' and price>=tp) or (side=='SELL' and price<=tp):
                exit_p, reason = tp, 'TP'
            else:
                continue
            pnl = (exit_p - open_t['entry']) * (1 if side=='BUY' else -1)
            pnl -= commission + slippage * abs(exit_p - open_t['entry'])
            trades.append({**open_t,
                           'exit': exit_p,
                           'exit_time': ts,
                           'pnl': pnl,
                           'reason': reason})
            open_t = None
        else:
            side = decide_open(row['p_buy'], row['p_sell'])
            if side != 'WAIT':
                sl, tp = sl_tp(price, side, atr)
                open_t = {'open_time': ts,
                          'side': side,
                          'entry': price,
                          'sl': sl,
                          'tp': tp}

    df_tr = pd.DataFrame(trades)
    if df_tr.empty:
        logger.info("No trades in backtest")
        return
    df_tr['cum_eq'] = df_tr['pnl'].cumsum()
    fname = f"backtest_results_{days}d.csv"
    df_tr.to_csv(fname, index=False)
    logger.info(f"Backtest results saved to {fname}")

@app.route('/analyze', methods=['POST'])
def analyze():
    # Read raw request body for debugging
    raw = request.get_data(as_text=True)
    logger.debug(f"analyze raw body: {raw}")

    # Robust JSON parsing to handle extra data errors
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as e:
        # Attempt to decode the first JSON object in case of extra data
        try:
            decoder = json.JSONDecoder()
            payload, idx = decoder.raw_decode(raw)
            logger.debug(f"analyze: raw_decode succeeded at index {idx}")
        except Exception as e2:
            logger.warning(f"analyze: JSON parse error: {e2}")
            return jsonify(signal='WAIT', sl=0.0, tp=0.0)
    except Exception as e:
        logger.warning(f"analyze: JSON parse error: {e}")
        return jsonify(signal='WAIT', sl=0.0, tp=0.0)

    # Validate payload structure
    symbol = payload.get("symbol")
    prices = payload.get("prices")
    if symbol != MAIN_SYMBOL or not isinstance(prices, list) or len(prices) < LOOKAHEAD_MIN:
        logger.warning("analyze: invalid payload content: %s", payload)
        return jsonify(signal='WAIT', sl=0.0, tp=0.0)

    # Proceed with feature engineering and prediction
    df_live = pd.DataFrame({'open': prices, 'high': prices, 'low': prices, 'close': prices})
    df_live['volume'] = 0
    feat = engineer(df_live).iloc[-1]
    model = joblib.load(MODEL_FILE)
    pb, ps = model.predict_proba([feat[FEATS]])[0][1:]
    side = decide_open(pb, ps)
    sl, tp = sl_tp(feat['close'], side, feat['atr'])
    logger.info("analyze: signal=%s, sl=%.5f, tp=%.5f", side, sl, tp)
    return jsonify(signal=side, sl=round(sl,5), tp=round(tp,5), conf=round(max(pb, ps), 2))

# CLI entrypoint
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('cmd', choices=[
        'bootstrap', 'collect', 'train', 'backtest', 'serve'])
    parser.add_argument('--days', type=int, default=30)
    parser.add_argument('--port', type=int, default=5000)
    args = parser.parse_args()

    if args.cmd == 'bootstrap':
        bootstrap()
    elif args.cmd == 'collect':
        while True:
            append_new_bars()
            time.sleep(COLLECT_SECONDS)
    elif args.cmd == 'train':
        train()
    elif args.cmd == 'backtest':
        backtest(days=args.days)
    elif args.cmd == 'serve':
        app.run(host='0.0.0.0', port=args.port, threaded=True)

if __name__ == '__main__':
    main()
