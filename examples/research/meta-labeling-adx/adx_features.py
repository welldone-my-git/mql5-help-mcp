"""
adx_features.py
===============
Eleven ADX-derived contextual features computed at each signal bar, for use
as input to the Random Forest secondary classifier.

Feature groups
--------------
Trend strength (3 features):
    adx_level           — ADX at the signal bar (absolute trend strength).
    adxr_level          — ADXR at the signal bar (smoothed regime quality).
    adx_slope_5         — Change in ADX over the 5 bars before the signal,
                          divided by 5.  Positive = accelerating trend.

Crossover quality (4 features):
    di_separation       — |+DI14 − -DI14| at the signal bar.  Large values
                          indicate a decisive crossing.
    di_separation_delta — Change in DI separation over the preceding 3 bars.
                          Positive = lines diverging; negative = converging.
    adx_above_both_di   — Binary: 1 when ADX exceeds both +DI14 and -DI14.
                          Wilder identifies this as a turning-point indicator.
    atr_ratio           — Bar's true range divided by the 14-bar ATR.
                          Captures whether the crossover bar was unusually
                          active or quiet relative to recent volatility.

Regime persistence (4 features):
    bars_since_last_cross   — Bars elapsed since the previous DI crossover,
                              capped at 100.  Frequent crossovers indicate a
                              ranging market.
    dominant_di_duration    — Consecutive bars the reversing DI was dominant
                              before this crossover.  Captures trend age.
    session_sin             — Sine encoding of the hour-of-day (0–23), scaled
                              to [−1, 1].  Follows Feature Engineering Part 3.
    session_cos             — Cosine encoding of the hour-of-day.

Functions
---------
compute_adx_features
    Main entry point.  Returns a DataFrame indexed on signal timestamps.

Series: Meta-Labeling the Classics (Part 2)
Author: Patrick Murimi Njoroge — Blueprint Quant
"""

from __future__ import annotations

import numpy as np
import pandas as pd


# ─────────────────────────────────────────────────────────────────────────────
def compute_adx_features(
    adx_df: pd.DataFrame,
    high: pd.Series,
    low: pd.Series,
    close: pd.Series,
    signals: pd.DataFrame,
    lookback_cap: int = 100,
) -> pd.DataFrame:
    """
    Compute eleven ADX-derived features at each signal bar.

    Parameters
    ----------
    adx_df : pd.DataFrame
        Output of ADXSystem.compute() — must contain columns:
        plus_di14, minus_di14, adx, adxr.
    high, low, close : pd.Series
        Raw OHLC price series aligned on the same DatetimeIndex as adx_df.
    signals : pd.DataFrame
        Output of ADXSignalGenerator.get_signals() — must have column 'side'.
    lookback_cap : int
        Maximum bars to look back when computing bars_since_last_cross and
        dominant_di_duration.  Default 100 (≈ one week of H1 data).

    Returns
    -------
    pd.DataFrame
        Eleven feature columns, indexed on the same timestamps as signals.
        NaN values may appear for signals near the start of the series.

    Notes
    -----
    Feature computation is O(n_signals × lookback_cap); for large signal
    sets consider vectorising the bars_since_last_cross calculation.
    """
    pdi = adx_df["plus_di14"]
    mdi = adx_df["minus_di14"]
    adx = adx_df["adx"]
    adxr = adx_df["adxr"]
    idx = adx_df.index

    # ── Precompute series used repeatedly ────────────────────────────────
    hl = high - low
    hc = (high - close.shift(1)).abs()
    lc = (low - close.shift(1)).abs()
    tr = pd.concat([hl, hc, lc], axis=1).max(axis=1)
    atr = tr.rolling(14, min_periods=1).mean()

    di_sep = (pdi - mdi).abs()

    # ── Session encoding (hour of day → sine/cosine) ─────────────────────
    hour = pd.Series(signals.index.hour, index=signals.index, dtype=float)
    session_sin = np.sin(2.0 * np.pi * hour / 24.0)
    session_cos = np.cos(2.0 * np.pi * hour / 24.0)

    rows: list[dict] = []

    for ts in signals.index:
        pos = idx.get_loc(ts)

        # ── Trend strength ─────────────────────────────────────────────
        adx_lev = float(adx.iloc[pos])
        adxr_lev = float(adxr.iloc[pos])

        slope_start = max(0, pos - 5)
        adx_slp = (float(adx.iloc[pos]) - float(adx.iloc[slope_start])) / 5.0

        # ── Crossover quality ─────────────────────────────────────────
        di_sep_now = float(di_sep.iloc[pos])
        delta_start = max(0, pos - 3)
        di_sep_delta = float(di_sep.iloc[pos]) - float(di_sep.iloc[delta_start])

        adx_above = float(float(adx.iloc[pos]) > max(float(pdi.iloc[pos]), float(mdi.iloc[pos])))

        atr_val = float(atr.iloc[pos])
        atr_r = float(tr.iloc[pos]) / atr_val if atr_val > 0 else np.nan

        # ── Regime persistence ────────────────────────────────────────
        lb = min(pos, lookback_cap)

        pdi_hist = pdi.values[pos - lb : pos]
        mdi_hist = mdi.values[pos - lb : pos]

        # bars_since_last_cross: walk backward to find the most recent
        # sign change in (pdi - mdi)
        if lb > 1:
            diff_sign = np.sign(pdi_hist - mdi_hist)
            sign_chng = np.where(np.diff(diff_sign) != 0)[0]
            bars_since = lb - int(sign_chng[-1]) if len(sign_chng) > 0 else lb
        else:
            bars_since = lb

        # dominant_di_duration: consecutive bars the now-reversing DI led
        side = int(signals.loc[ts, "side"])
        if side == 1:  # Long: -DI was dominant before the cross
            dom_hist = mdi_hist
            sub_hist = pdi_hist
        else:  # Short: +DI was dominant before the cross
            dom_hist = pdi_hist
            sub_hist = mdi_hist

        dominant_run = 0
        for k in range(len(dom_hist) - 1, -1, -1):
            if dom_hist[k] > sub_hist[k]:
                dominant_run += 1
            else:
                break

        rows.append(
            {
                "adx_level": adx_lev,
                "adxr_level": adxr_lev,
                "adx_slope_5": adx_slp,
                "di_separation": di_sep_now,
                "di_separation_delta": di_sep_delta,
                "adx_above_both_di": adx_above,
                "atr_ratio": atr_r,
                "bars_since_last_cross": float(bars_since),
                "dominant_di_duration": float(dominant_run),
                "session_sin": float(session_sin.loc[ts]),
                "session_cos": float(session_cos.loc[ts]),
            }
        )

    feature_cols = [
        "adx_level",
        "adxr_level",
        "adx_slope_5",
        "di_separation",
        "di_separation_delta",
        "adx_above_both_di",
        "atr_ratio",
        "bars_since_last_cross",
        "dominant_di_duration",
        "session_sin",
        "session_cos",
    ]

    return pd.DataFrame(rows, index=signals.index, columns=feature_cols)


# ─────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import numpy as np
    from adx_system import ADXSignalGenerator, ADXSystem

    rng = np.random.default_rng(42)
    n = 1000
    close = pd.Series(
        np.cumprod(1 + rng.normal(0, 0.001, n)),
        index=pd.date_range("2022-01-03", periods=n, freq="h"),
    )
    high = pd.Series(close * (1 + np.abs(rng.normal(0, 0.0005, n))), index=close.index)
    low = pd.Series(close * (1 - np.abs(rng.normal(0, 0.0005, n))), index=close.index)

    adx_df = ADXSystem(14).compute(high, low, close)
    signals = ADXSignalGenerator(adxr_threshold=20.0).get_signals(adx_df, high, low)
    feats = compute_adx_features(adx_df, high, low, close, signals)

    print(f"Signals: {len(signals)}, features shape: {feats.shape}")
    print(feats.describe().round(3))
    assert feats.shape[1] == 11, "Expected exactly 11 feature columns"
    print("\nSmoke test passed.")
