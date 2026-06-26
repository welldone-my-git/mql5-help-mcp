from __future__ import annotations
from pathlib import Path
import warnings
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report
from sklearn.preprocessing import StandardScaler

warnings.filterwarnings("ignore")

PARQUET_PATH = Path("./EURUSD_H1_time_2018-01-01-2024-12-31.parq")
SPLIT_DATE   = pd.Timestamp("2025-01-01", tz="UTC")


# ─────────────────────────────────────────────────────────────────────────────
# 1. DATA
# ─────────────────────────────────────────────────────────────────────────────

def load_data(parquet_path: Path | None = PARQUET_PATH) -> pd.DataFrame:
    """
    Load EURUSD H1 bars.  Priority:
      1. parquet_path if the file exists on disk.
      2. yfinance 730-day fallback.
    Returns columns [open, high, low, close, volume], UTC DatetimeIndex.
    Zero-range weekend/holiday bars are removed.
    """
    if parquet_path is not None and parquet_path.exists():
        df = pd.read_parquet(parquet_path)
        df.columns = [c.lower() for c in df.columns]
        if df.index.tz is None:
            df.index = df.index.tz_localize("UTC")
        else:
            df.index = df.index.tz_convert("UTC")
        source = f"parquet ({parquet_path.name})"
    else:
        import yfinance as yf
        raw = yf.download("EURUSD=X", period="730d", interval="1h",
                          auto_adjust=True, progress=False)
        raw.columns = [c[0].lower() for c in raw.columns]
        raw.index   = raw.index.tz_convert("UTC")
        df     = raw
        source = "yfinance (730-day fallback)"

    df = df[df["high"] != df["low"]].copy()
    df.index.name = "datetime"
    print(f"Loaded {len(df):,} bars  "
          f"[{df.index[0].date()} → {df.index[-1].date()}]  source={source}")
    return df


# ─────────────────────────────────────────────────────────────────────────────
# 2. TIME FEATURES  (from Feature Engineering series, article 22516)
# ─────────────────────────────────────────────────────────────────────────────

def encode_cyclical_features(
    datetime_index: pd.DatetimeIndex,
    n_terms: int = 3,
    extra_fourier_features: list[str] | None = None,
) -> pd.DataFrame:
    """
    Fourier (sin/cos) encoding for hour, day-of-week, and day-of-year.
    For H1 bars extra_fourier_features=[] → single sin/cos pair per variable.
    """
    out = pd.DataFrame(index=datetime_index)
    features = {
        "hour"      : (datetime_index.hour,      24),
        "dayofweek" : (datetime_index.dayofweek,  7),
        "dayofyear" : (datetime_index.dayofyear, 366),
    }
    for name, (series, period) in features.items():
        radians = 2.0 * np.pi * series / period
        out[f"{name}_sin"] = np.sin(radians)
        out[f"{name}_cos"] = np.cos(radians)

        if n_terms >= 1 and (
            extra_fourier_features is None or name in extra_fourier_features
        ):
            out.rename(columns={
                f"{name}_sin": f"{name}_sin_h1",
                f"{name}_cos": f"{name}_cos_h1",
            }, inplace=True)
            for k in range(2, n_terms + 1):
                rk = 2.0 * np.pi * k * series / period
                out[f"{name}_sin_h{k}"] = np.sin(rk)
                out[f"{name}_cos_h{k}"] = np.cos(rk)
    return out


def trading_session_encoded_features(
    df: pd.DataFrame,
) -> pd.DataFrame:
    """
    Binary session flags + session-conditional rolling volatility (lagged 1 bar).
    Sessions are fixed UTC hours (DST-agnostic).
    Calendar effects (month_end, quarter_end, friday_ny_close, sunday_open)
    are dropped by the H1 frequency gate inside get_time_features().
    """
    dt_utc = (df.index.tz_convert("UTC") if df.index.tz is not None
              else df.index.tz_localize("UTC"))
    hours = dt_utc.hour.values
    out   = pd.DataFrame(index=df.index)

    sessions = {
        "sydney_session"  : dict(start=21, end= 6, cross_midnight=True),
        "tokyo_session"   : dict(start= 0, end= 9, cross_midnight=False),
        "london_session"  : dict(start= 7, end=16, cross_midnight=False),
        "ny_session"      : dict(start=13, end=22, cross_midnight=False),
    }
    for col, p in sessions.items():
        s, e, xm = p["start"], p["end"], p["cross_midnight"]
        mask = (hours >= s) | (hours < e) if xm else (hours >= s) & (hours < e)
        out[col] = mask.astype("int8")

    out["session_overlap"] = np.where(out.sum(axis=1) > 1, 1, 0).astype("int8")

    # Session-conditional volatility — lagged by 1 bar, no lookahead
    log_ret = np.log(df["close"]).diff()
    session_cols = list(sessions.keys()) + ["session_overlap"]
    for col in session_cols:
        mask = out[col] == 1
        if mask.sum() > 0:
            vol = (log_ret[mask]
                   .rolling(20, min_periods=1).std()
                   .reindex(df.index, method="ffill")
                   .shift(1))
            out[f"{col}_vol"] = vol

    # Calendar effects  (generated but dropped for H1 by get_time_features)
    dow = df.index.dayofweek.values
    dom = df.index.day.values
    mon = df.index.month.values
    out["friday_ny_close"] = ((dow == 4) & (hours >= 21)).astype(int)
    out["sunday_open"]     = ((dow == 6) & (hours <=  2)).astype(int)
    out["month_end"]       = (dom >= 28).astype(int)
    out["quarter_end"]     = ((mon % 3 == 0) & (dom >= 28)).astype(int)
    return out


def get_time_features(df: pd.DataFrame, timeframe: str = "H1") -> pd.DataFrame:
    """
    Orchestrator matching article 22516 — H1 frequency gate:
      - Single sin/cos pair per Fourier variable (no multi-harmonic expansion).
      - Calendar effect columns dropped (not meaningful at H1).
    """
    tf = timeframe.upper()
    extra = [] if tf.startswith(("H", "D", "W", "MN")) else (
        ["hour"] if tf.startswith("M") else []
    )
    cyc  = encode_cyclical_features(df.index, n_terms=3,
                                    extra_fourier_features=extra)
    sess = trading_session_encoded_features(df)

    # H1 frequency gate: drop calendar effects
    if not tf.startswith(("D", "W", "MN")):
        sess.drop(
            columns=["friday_ny_close", "sunday_open", "month_end", "quarter_end"],
            inplace=True, errors="ignore",
        )
    return pd.concat([cyc, sess], axis=1, join="inner")


# ─────────────────────────────────────────────────────────────────────────────
# 3. PRICE / VOLATILITY INDICATORS
# ─────────────────────────────────────────────────────────────────────────────

def _compute_rsi(close: pd.Series, period: int = 14) -> pd.Series:
    d  = close.diff()
    g  = d.clip(lower=0).ewm(com=period - 1, min_periods=period).mean()
    l  = (-d).clip(lower=0).ewm(com=period - 1, min_periods=period).mean()
    return (100 - 100 / (1 + g / l.replace(0, np.nan))).rename("rsi")


def _compute_atr(high: pd.Series, low: pd.Series,
                 close: pd.Series, period: int = 14) -> pd.Series:
    tr = pd.concat([
        high - low,
        (high - close.shift()).abs(),
        (low  - close.shift()).abs(),
    ], axis=1).max(axis=1)
    return tr.ewm(com=period - 1, min_periods=period).mean().rename("atr")


def _compute_adx(high: pd.Series, low: pd.Series,
                 close: pd.Series, period: int = 14) -> pd.Series:
    pdm = high.diff().clip(lower=0)
    mdm = (-low.diff()).clip(lower=0)
    pdm[pdm < mdm] = 0
    mdm[mdm < pdm] = 0
    atr     = _compute_atr(high, low, close, period)
    plus_di = 100 * pdm.ewm(com=period-1, min_periods=period).mean() / atr
    min_di  = 100 * mdm.ewm(com=period-1, min_periods=period).mean() / atr
    dx      = 100 * (plus_di - min_di).abs() / (plus_di + min_di).replace(0, np.nan)
    return dx.ewm(com=period-1, min_periods=period).mean().rename("adx")


def compute_features(df: pd.DataFrame) -> pd.DataFrame:
    """
    Build the full feature matrix.

    Price / volatility features (11 columns):
      rsi_depth, rsi_mom, adx, atr, vol_ratio, mom5,
      trend_vel, trend_stretch, dist_high, dist_low, above_ema50

    Time features — get_time_features(H1) — (16 columns):
      Fourier : hour_sin, hour_cos, dayofweek_sin, dayofweek_cos,
                dayofyear_sin, dayofyear_cos
      Session flags : sydney_session, tokyo_session, london_session,
                      ny_session, session_overlap
      Session vol   : sydney_session_vol, tokyo_session_vol,
                      london_session_vol, ny_session_vol,
                      session_overlap_vol

    Total: 27 columns.
    """
    rsi   = _compute_rsi(df["close"])
    atr   = _compute_atr(df["high"], df["low"], df["close"])
    ema50 = df["close"].ewm(span=50, min_periods=50).mean()

    price = pd.DataFrame(index=df.index)
    price["rsi_depth"]     = rsi
    price["rsi_mom"]       = rsi.diff(3)
    price["adx"]           = _compute_adx(df["high"], df["low"], df["close"])
    price["atr"]           = atr
    price["vol_ratio"]     = atr / atr.rolling(50).mean()
    price["mom5"]          = df["close"].pct_change(5)
    price["trend_vel"]     = ema50.diff(5)
    price["trend_stretch"] = (df["close"] - ema50) / atr
    price["dist_high"]     = (df["high"].rolling(20).max() - df["close"]) / atr
    price["dist_low"]      = (df["close"] - df["low"].rolling(20).min()) / atr
    price["above_ema50"]   = (df["close"] > ema50).astype(int)

    time  = get_time_features(df, timeframe="H1")
    return pd.concat([price, time], axis=1, join="inner")


# Build FEATURE_COLS dynamically so it always matches compute_features output
_PRICE_COLS = [
    "rsi_depth", "rsi_mom", "adx", "atr", "vol_ratio", "mom5",
    "trend_vel", "trend_stretch", "dist_high", "dist_low", "above_ema50",
]
_FOURIER_COLS = [
    "hour_sin", "hour_cos",
    "dayofweek_sin", "dayofweek_cos",
    "dayofyear_sin", "dayofyear_cos",
]
_SESSION_COLS = [
    "sydney_session", "tokyo_session", "london_session",
    "ny_session", "session_overlap",
]
_SESSION_VOL_COLS = [
    "sydney_session_vol", "tokyo_session_vol", "london_session_vol",
    "ny_session_vol", "session_overlap_vol",
]
FEATURE_COLS = _PRICE_COLS + _FOURIER_COLS + _SESSION_COLS + _SESSION_VOL_COLS


# ─────────────────────────────────────────────────────────────────────────────
# 4. RSI SIGNALS
# ─────────────────────────────────────────────────────────────────────────────

def generate_rsi_signals(rsi: pd.Series,
                         ob: float = 70.0, os_: float = 30.0) -> pd.Series:
    prev = rsi.shift(1)
    sig  = pd.Series(0, index=rsi.index, dtype=int)
    sig[(prev < os_) & (rsi >= os_)]  = 1
    sig[(prev > ob)  & (rsi <= ob)]   = -1
    return sig.rename("signal")


# ─────────────────────────────────────────────────────────────────────────────
# 5. TRIPLE-BARRIER LABELING
# ─────────────────────────────────────────────────────────────────────────────

def triple_barrier_label(
    close: pd.Series,
    signal_idx: pd.DatetimeIndex,
    signal_side: pd.Series,
    atr: pd.Series,
    pt_mult: float = 1.5,
    sl_mult: float = 1.5,
    max_hold: int = 24,
) -> pd.DataFrame:
    records = []
    for idx in signal_idx:
        side    = signal_side.loc[idx]
        entry   = close.loc[idx]
        av      = atr.loc[idx]
        pt      = entry + side * pt_mult * av
        sl      = entry - side * sl_mult * av
        future  = close.loc[idx:].iloc[1 : max_hold + 1]
        label, ret, exit_bar, reason = 0, 0.0, idx, "time"
        for fbar, fp in future.items():
            if side == 1:
                if fp >= pt:  label, ret, exit_bar, reason =  1, fp-entry, fbar, "pt";  break
                if fp <= sl:  label, ret, exit_bar, reason = -1, fp-entry, fbar, "sl";  break
            else:
                if fp <= pt:  label, ret, exit_bar, reason =  1, entry-fp, fbar, "pt";  break
                if fp >= sl:  label, ret, exit_bar, reason = -1, entry-fp, fbar, "sl";  break
        if reason == "time":
            last  = future.iloc[-1] if len(future) else entry
            ret   = side * (last - entry)
            label = 1 if ret > 0 else -1
        records.append(dict(
            signal_bar=idx, side=side, entry=entry, label=label, ret=ret,
            hold_bars=len(close.loc[idx:exit_bar]) - 1, exit_reason=reason,
        ))
    return pd.DataFrame(records).set_index("signal_bar")


# ─────────────────────────────────────────────────────────────────────────────
# 6. MODEL
# ─────────────────────────────────────────────────────────────────────────────

def train_meta_model(X_train, y_train):
    scaler = StandardScaler()
    clf    = RandomForestClassifier(
        n_estimators=300, max_depth=5, min_samples_leaf=5,
        class_weight="balanced", random_state=42, n_jobs=-1,
    )
    clf.fit(scaler.fit_transform(X_train), y_train)
    return clf, scaler


# ─────────────────────────────────────────────────────────────────────────────
# 7. BACKTEST
# ─────────────────────────────────────────────────────────────────────────────

SPREAD_PIPS = 1.2
PIP         = 0.0001


def backtest_three_tracks(labels, proba, threshold=0.55):
    rows = []
    for i, (idx, row) in enumerate(labels.iterrows()):
        p        = proba[i]
        raw_pips = row["ret"] / PIP - SPREAD_PIPS
        taken    = p >= threshold
        bet_size = float(np.clip((p - 0.5) / 0.5, 0, 1)) if taken else 0.0
        rows.append(dict(
            bar=idx, label=row["label"], side=row["side"],
            hold_bars=row["hold_bars"], exit_reason=row["exit_reason"],
            prob=p, plain_pnl=raw_pips,
            meta_taken=taken, meta_pnl=raw_pips if taken else 0.0,
            bet_size=bet_size, sized_pnl=raw_pips * bet_size,
        ))
    return pd.DataFrame(rows).set_index("bar")


def performance_metrics(pnl, label):
    t = pnl[pnl != 0];  n = len(t)
    if n == 0: return dict(label=label, n_trades=0)
    pf = (-t[t>0].sum() / t[t<0].sum() if (t<0).any() else float("inf"))
    cum = pnl.cumsum();  dd = cum - cum.cummax()
    return dict(label=label, n_trades=n,
                win_rate=round((t>0).mean()*100, 1),
                avg_win=round(t[t>0].mean(), 1) if (t>0).any() else 0,
                avg_loss=round(t[t<0].mean(), 1) if (t<0).any() else 0,
                prof_factor=round(pf, 2), total_pips=round(pnl.sum(), 1),
                max_dd_pips=round(dd.min(), 1))


# ─────────────────────────────────────────────────────────────────────────────
# 8. MAIN RUNNER
# ─────────────────────────────────────────────────────────────────────────────

def run_pipeline(parquet_path: Path | None = PARQUET_PATH) -> dict:
    df   = load_data(parquet_path)
    feat = compute_features(df)

    print(f"\nFeature matrix: {feat.shape[1]} columns × {len(feat):,} rows")
    print(f"  Price/vol : {len(_PRICE_COLS)}")
    print(f"  Fourier   : {len(_FOURIER_COLS)}")
    print(f"  Sessions  : {len(_SESSION_COLS)}")
    print(f"  Sess-vol  : {len(_SESSION_VOL_COLS)}")

    rsi  = feat["rsi_depth"].rename("rsi")
    atr  = feat["atr"]
    sigs = generate_rsi_signals(rsi)
    sig_idx = sigs[sigs != 0].index
    print(f"\nRSI signals: {len(sig_idx):,}  "
          f"(long={int((sigs==1).sum())}  short={int((sigs==-1).sum())})")

    labels = triple_barrier_label(
        df["close"], sig_idx, sigs[sigs != 0], atr,
        pt_mult=1.5, sl_mult=1.5, max_hold=24,
    )
    vc = labels["label"].value_counts()
    print(f"Labels  +1={vc.get(1,0)}  -1={vc.get(-1,0)}  "
          f"win_rate={vc.get(1,0)/len(labels)*100:.1f}%")

    train_labels = labels[labels.index <  SPLIT_DATE]
    test_labels  = labels[labels.index >= SPLIT_DATE]
    print(f"\nTrain: {len(train_labels):,}  "
          f"[{train_labels.index[0].date()} → {train_labels.index[-1].date()}]")
    print(f"Test : {len(test_labels):,}   "
          f"[{test_labels.index[0].date()} → {test_labels.index[-1].date()}]")

    feat_clean = feat[FEATURE_COLS].dropna()
    X_train = feat_clean.loc[train_labels.index.intersection(feat_clean.index)]
    y_train = train_labels.loc[X_train.index, "label"]
    X_test  = feat_clean.loc[test_labels.index.intersection(feat_clean.index)]
    y_test  = test_labels.loc[X_test.index,  "label"]
    print(f"X_train: {X_train.shape}  pos%={(y_train==1).mean()*100:.1f}")
    print(f"X_test : {X_test.shape}   pos%={(y_test==1).mean()*100:.1f}")

    clf, scaler = train_meta_model(X_train, y_train)
    proba_test  = clf.predict_proba(scaler.transform(X_test))[:, 1]
    y_pred = (proba_test >= 0.55).astype(int) * 2 - 1
    print("\n── Test classification report ──")
    print(classification_report(y_test, y_pred, target_names=["loss", "win"]))

    fi = pd.Series(clf.feature_importances_, index=FEATURE_COLS).sort_values(ascending=False)
    print("Feature importance (top 10):")
    print(fi.head(10).round(4).to_string())

    results = backtest_three_tracks(test_labels.loc[X_test.index], proba_test)
    m1 = performance_metrics(results["plain_pnl"],  "Plain RSI")
    m2 = performance_metrics(results["meta_pnl"],   "Meta-labeled")
    m3 = performance_metrics(results["sized_pnl"],  "Meta + Bet-sized")
    summary = pd.DataFrame([m1, m2, m3]).set_index("label")
    print("\n── Performance summary ──")
    print(summary.to_string())

    return dict(df=df, feat=feat, rsi=rsi, atr=atr, sigs=sigs,
                labels=labels, train_labels=train_labels,
                test_labels=test_labels, X_train=X_train, y_train=y_train,
                X_test=X_test, y_test=y_test, clf=clf, scaler=scaler,
                proba_test=proba_test, results=results, fi=fi,
                summary=summary, metrics=dict(plain=m1, meta=m2, sized=m3))
