"""
adx_system.py
=============
Welles Wilder's Directional Movement System, implemented exactly as specified
in 'New Concepts in Technical Trading Systems' (1978), Section IV.

Classes
-------
ADXSystem
    Computes +DI14, -DI14, DX, ADX, and ADXR using Wilder's smoothing
    recurrence rather than a standard exponential moving average.

ADXSignalGenerator
    Extracts DI crossover events from a precomputed ADX DataFrame and applies
    a parametric three-condition gate. Records Wilder's Extreme Point for
    stop-placement use in the companion MQL5 execution article.

Wilder's smoothing recurrence
-----------------------------
For period p and a sequence of raw values r:

    S_p = r_1 + r_2 + ... + r_p          (first smoothed value)
    S_t = S_{t-1} - S_{t-1} / p + r_t    (all subsequent values)

This is applied independently to +DM, -DM, and TR.
ADX validity begins at bar 2*p - 1 (27 for the default period of 14).
ADXR validity begins at bar 3*p - 2 (40 for the default period of 14).

Series: Meta-Labeling the Classics (Part 2)
Author: Patrick Murimi Njoroge — Blueprint Quant
"""

from __future__ import annotations

import numpy as np
import pandas as pd


# ─────────────────────────────────────────────────────────────────────────────
class ADXSystem:
    """
    Implements Wilder's Directional Movement System.

    Parameters
    ----------
    period : int
        Lookback period for DM, TR, and ADX smoothing. Wilder's default is 14.
    """

    def __init__(self, period: int = 14) -> None:
        if period < 2:
            raise ValueError(f"period must be >= 2, got {period}")
        self.period = period

    # ------------------------------------------------------------------ #
    def compute(
        self,
        high: pd.Series,
        low: pd.Series,
        close: pd.Series,
    ) -> pd.DataFrame:
        """
        Compute the full ADX system from OHLC price series.

        Parameters
        ----------
        high, low, close : pd.Series
            Price series sharing a common DatetimeIndex.  All three must have
            the same length and index.

        Returns
        -------
        pd.DataFrame
            Columns: plus_di14, minus_di14, dx, adx, adxr.
            Rows before the first valid bar contain NaN.

        Notes
        -----
        Bar 0 is the reference bar (diff produces NaN).
        DI and DX are first valid at bar p (default 14).
        ADX is first valid at bar 2*p - 1 (default 27).
        ADXR is first valid at bar 3*p - 2 (default 40).
        """
        n = len(high)
        p = self.period

        # ── 1. Raw directional movement ───────────────────────────────────
        up_move = high.diff().values  # today_high - yesterday_high
        down_move = (-low.diff()).values  # yesterday_low - today_low

        # +DM: up_move when it exceeds down_move AND is positive; else 0.
        # -DM: down_move when it exceeds up_move AND is positive; else 0.
        # On inside days (up_move <= 0 and down_move <= 0) both are 0.
        # On outside days the larger of the two is retained; the other is 0.
        plus_dm = np.where((up_move > down_move) & (up_move > 0), up_move, 0.0)
        minus_dm = np.where((down_move > up_move) & (down_move > 0), down_move, 0.0)

        # ── 2. True range ─────────────────────────────────────────────────
        hl = (high - low).values
        hc = (high - close.shift(1)).abs().values
        lc = (low - close.shift(1)).abs().values
        tr = np.maximum(hl, np.maximum(hc, lc))

        # ── 3. Wilder smoothing ───────────────────────────────────────────
        # Index 0 is unusable (diff is NaN).  First smoothed value is the
        # raw sum of bars 1 through p (inclusive).
        tr14 = np.full(n, np.nan)
        pdm14 = np.full(n, np.nan)
        mdm14 = np.full(n, np.nan)

        tr14[p] = tr[1 : p + 1].sum()
        pdm14[p] = plus_dm[1 : p + 1].sum()
        mdm14[p] = minus_dm[1 : p + 1].sum()

        for i in range(p + 1, n):
            tr14[i] = tr14[i - 1] - tr14[i - 1] / p + tr[i]
            pdm14[i] = pdm14[i - 1] - pdm14[i - 1] / p + plus_dm[i]
            mdm14[i] = mdm14[i - 1] - mdm14[i - 1] / p + minus_dm[i]

        # ── 4. Directional Indicators ─────────────────────────────────────
        with np.errstate(divide="ignore", invalid="ignore"):
            plus_di14 = np.where(tr14 > 0, 100.0 * pdm14 / tr14, np.nan)
            minus_di14 = np.where(tr14 > 0, 100.0 * mdm14 / tr14, np.nan)

        # ── 5. DX — bounded [0, 100] ──────────────────────────────────────
        di_sum = plus_di14 + minus_di14
        di_diff = np.abs(plus_di14 - minus_di14)
        with np.errstate(divide="ignore", invalid="ignore"):
            dx = np.where(di_sum > 0, 100.0 * di_diff / di_sum, np.nan)

        # ── 6. ADX ────────────────────────────────────────────────────────
        # First value = mean of the first p valid DX readings (bars p to 2p-1).
        # Subsequent values follow the same Wilder recurrence:
        #   ADX_t = (ADX_{t-1} * (p-1) + DX_t) / p
        adx = np.full(n, np.nan)
        first_adx = 2 * p - 1
        adx[first_adx] = np.nanmean(dx[p : first_adx + 1])

        for i in range(first_adx + 1, n):
            adx[i] = (adx[i - 1] * (p - 1) + dx[i]) / p

        # ── 7. ADXR ───────────────────────────────────────────────────────
        # ADXR = (ADX_today + ADX_{p bars ago}) / 2
        adxr = np.full(n, np.nan)
        for i in range(first_adx + p, n):
            adxr[i] = (adx[i] + adx[i - p]) / 2.0

        return pd.DataFrame(
            {
                "plus_di14": plus_di14,
                "minus_di14": minus_di14,
                "dx": dx,
                "adx": adx,
                "adxr": adxr,
            },
            index=high.index,
        )


# ─────────────────────────────────────────────────────────────────────────────
class ADXSignalGenerator:
    """
    Extracts DI crossover events from a precomputed ADX DataFrame and applies
    a three-condition parametric gate.

    Long signal:  +DI14 crosses above -DI14 while all gate conditions hold.
    Short signal: -DI14 crosses above +DI14 while all gate conditions hold.

    Wilder's Extreme Point Rule is recorded alongside each signal.  For a Long
    entry, the extreme is the low of the crossover bar (protective stop level).
    For a Short entry, the extreme is the high of the crossover bar.

    Parameters
    ----------
    adxr_threshold : float
        Minimum ADXR required to admit a signal.  Wilder's original is 25.0.
        Set by Bayesian HPO in the Layer 1 gate search.
    min_di_separation : float
        Minimum |+DI14 - -DI14| at the crossover bar.  Filters crosses where
        the two lines are nearly equal (ambiguous regime state).
    """

    def __init__(
        self,
        adxr_threshold: float = 25.0,
        min_di_separation: float = 0.0,
    ) -> None:
        self.adxr_threshold = adxr_threshold
        self.min_di_separation = min_di_separation

    # ------------------------------------------------------------------ #
    def get_signals(
        self,
        adx_df: pd.DataFrame,
        high: pd.Series,
        low: pd.Series,
    ) -> pd.DataFrame:
        """
        Extract gated DI crossover events.

        Parameters
        ----------
        adx_df : pd.DataFrame
            Output of ADXSystem.compute().
        high, low : pd.Series
            Raw bar highs and lows used to record the Extreme Point.

        Returns
        -------
        pd.DataFrame
            Index  : DatetimeIndex of signal bars.
            Columns:
                side    (int8)  — +1 for Long, -1 for Short.
                extreme (float) — Wilder Extreme Point for stop placement.

            Empty DataFrame (with correct columns) when no signals pass the gate.
        """
        pdi = adx_df["plus_di14"]
        mdi = adx_df["minus_di14"]
        adxr = adx_df["adxr"]

        # Crossover: strict crossing (not equality) on consecutive bars.
        long_cross = (pdi > mdi) & (pdi.shift(1) <= mdi.shift(1))
        short_cross = (mdi > pdi) & (mdi.shift(1) <= pdi.shift(1))

        # Gate conditions.
        adxr_gate = adxr >= self.adxr_threshold
        sep_gate = (pdi - mdi).abs() >= self.min_di_separation

        long_ok = long_cross & adxr_gate & sep_gate
        short_ok = short_cross & adxr_gate & sep_gate

        rows: list[dict] = []
        for ts in adx_df.index[long_ok]:
            rows.append(
                {
                    "t": ts,
                    "side": np.int8(1),
                    "extreme": float(low.loc[ts]),  # Long stop = crossover-bar low
                }
            )
        for ts in adx_df.index[short_ok]:
            rows.append(
                {
                    "t": ts,
                    "side": np.int8(-1),
                    "extreme": float(high.loc[ts]),  # Short stop = crossover-bar high
                }
            )

        if not rows:
            return pd.DataFrame(columns=["side", "extreme"])

        return (
            pd.DataFrame(rows)
            .set_index("t")
            .sort_index()
            .astype({"side": np.int8, "extreme": float})
        )


# ─────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    # Minimal smoke test on synthetic data.
    rng = np.random.default_rng(0)
    n = 500
    close = np.cumprod(1 + rng.normal(0, 0.001, n))
    high = close * (1 + np.abs(rng.normal(0, 0.0005, n)))
    low = close * (1 - np.abs(rng.normal(0, 0.0005, n)))
    idx = pd.date_range("2022-01-03", periods=n, freq="h")

    h = pd.Series(high, index=idx)
    low_s = pd.Series(low, index=idx)
    c = pd.Series(close, index=idx)

    sys_ = ADXSystem(period=14)
    adx_df = sys_.compute(h, low_s, c)

    print("ADX system output (last 5 rows):")
    print(adx_df.tail())
    print(f"\nFirst valid ADX bar: {adx_df['adx'].first_valid_index()}")
    print(f"First valid ADXR bar: {adx_df['adxr'].first_valid_index()}")

    gen = ADXSignalGenerator(adxr_threshold=20.0, min_di_separation=2.0)
    signals = gen.get_signals(adx_df, h, low_s)
    print(f"\nSignals generated: {len(signals)}")
    if len(signals):
        print(signals.head())
