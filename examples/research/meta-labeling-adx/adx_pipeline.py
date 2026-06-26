"""
adx_pipeline.py
===============
Full pipeline for Meta-Labeling the Classics (Part 2): ADX/DI meta-labeling.

Steps
-----
1. Load EURUSD H1 OHLC data from a Parquet file exported from MetaTrader 5.
2. Run Bayesian HPO (Layer 1) to find the optimal ADXR regime gate parameters.
3. Construct the gated signal stream using the best HPO parameters.
4. Compute triple-barrier labels on the in-sample gated signals.
5. Compute eleven ADX-derived features at each in-sample signal bar.
6. Train the Random Forest secondary classifier (Layer 2) on in-sample data.
7. Evaluate three tracks on the out-of-sample period:
      Track 1 — Plain DI crossover (Wilder's ADXR ≥ 25, no classifier).
      Track 2 — HPO gate only (no classifier, bet sizing at full position).
      Track 3 — HPO gate + secondary classifier + afml.bet_sizing.
8. Print the per-track summary table.

Prerequisites
-------------
- A minimal excerpt of the afml package is included in this article's
  attached files (afml/labeling/triple_barrier.py,
  afml/sample_weights/optimized_attribution.py,
  afml/bet_sizing/bet_sizing.py) — only the functions this pipeline calls,
  not the complete Blueprint Quant afml package. Place the afml/ folder
  alongside this script, or install the full package separately if you
  already have it. Requires numba and scipy in addition to the standard
  numpy/pandas/scikit-learn stack.
- MetaTrader 5 EURUSD H1 Parquet file at the path configured in DATA_PATH.
  The file must have columns: time (index, tz-naive), open, high, low, close,
  tick_volume.  Export via the Blueprint Part 1 data pipeline.

Configuration
-------------
Edit the constants at the top of this file before running.

Series: Meta-Labeling the Classics (Part 2)
Author: Patrick Murimi Njoroge — Blueprint Quant
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd
from adx_features import compute_adx_features
from adx_hpo import run_adx_hpo
from adx_system import ADXSignalGenerator, ADXSystem
from sklearn.ensemble import RandomForestClassifier

from afml.bet_sizing.bet_sizing import get_signal
from afml.labeling.triple_barrier import add_vertical_barrier, get_bins, get_events
from afml.sample_weights.optimized_attribution import get_weights_by_return_optimized

# ─────────────────────────────────────────────────────────────────────────────
# Configuration — edit before running
# ─────────────────────────────────────────────────────────────────────────────

DATA_PATH = Path.cwd() / "data/EURUSD_H1_time_2018-01-01-2024-12-31.parq"
OUTPUT_DIR = Path("output/adx_meta_label")

# Train / test split (tz-naive, matching MT5 Parquet index convention)
SPLIT_DATE = pd.Timestamp("2022-01-01")

# Triple-barrier parameters
PT_SL = [1.5, 1.5]  # [profit-take multiplier, stop-loss multiplier]
MIN_RET = 0.0005  # minimum expected return for a label to be nonzero

# Vertical barrier (max holding period).  DESIGN CHOICE — flagged explicitly:
# afml's get_events does not gracefully disable the time barrier when given
# vertical_barrier_times=None; it leaves t1 as NaT, which the underlying numba
# kernel resolves by searching forward to the LAST BAR OF THE ENTIRE SERIES for
# every event. That makes trade duration unbounded, contradicting the bounded-
# horizon assumption the rest of this project's purging/embargo machinery
# relies on. 240 bars (10 trading days on H1) is a starting point for a
# multi-day ADX trend system — confirm this matches your actual holding-period
# expectations before trusting the reported drawdown and win-rate numbers.
MAX_HOLDING_BARS = 240

# HPO parameters
HPO_TRIALS = 200
HPO_STORAGE = f"sqlite:///{OUTPUT_DIR}/adx_hpo.db"

# Secondary classifier
N_ESTIMATORS = 500
MIN_SAMPLES_LEAF = 5
CONFIDENCE_THR = 0.55  # minimum classifier probability to size a position


# ─────────────────────────────────────────────────────────────────────────────
def load_data(path: Path) -> pd.DataFrame:
    """Load MT5 EURUSD H1 Parquet and validate required columns."""
    df = pd.read_parquet(path)
    required = {"high", "low", "close"}
    missing = required - set(df.columns)
    if missing:
        raise ValueError(f"Parquet file missing columns: {missing}")
    if df.index.tz is not None:
        raise ValueError(
            "MT5 Parquet index must be tz-naive.  "
            "Do not localize — use pd.Timestamp without tz='UTC'."
        )
    return df


def split_data(df: pd.DataFrame, split: pd.Timestamp) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Split the DataFrame at split_date into in-sample and out-of-sample."""
    return df[df.index < split], df[df.index >= split]


# ─────────────────────────────────────────────────────────────────────────────
def run_pipeline() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # ── 1. Load data ──────────────────────────────────────────────────────
    print("Loading data …")
    df = load_data(DATA_PATH)
    df_is, df_oos = split_data(df, SPLIT_DATE)
    close_is = df_is["close"]
    close_oos = df_oos["close"]
    print(
        f"  In-sample:  {df_is.index[0].date()} → {df_is.index[-1].date()}  ({len(df_is):,} bars)"
    )
    print(
        f"  OOS:        {df_oos.index[0].date()} → {df_oos.index[-1].date()}  "
        f"({len(df_oos):,} bars)"
    )

    # ── 2. Layer 1: Bayesian HPO on the regime gate (in-sample only) ──────
    print("\nLayer 1: Bayesian HPO …")
    study = run_adx_hpo(
        ohlc=df_is,
        close=close_is,
        n_trials=HPO_TRIALS,
        val_fraction=0.30,
        pt_sl=PT_SL,
        min_ret=MIN_RET,
        max_holding_bars=MAX_HOLDING_BARS,
        study_name="adx_gate_hpo",
        storage=HPO_STORAGE,
    )
    best = study.best_params
    print(f"  Best gate params: {best}")
    print(f"  Best precision  : {study.best_value:.4f}")

    hpo_adxr_thr = best["adxr_threshold"]
    hpo_period = best["di_period"]
    hpo_min_sep = best["min_di_separation"]

    # ── 3. Build in-sample gated signal stream ────────────────────────────
    print("\nBuilding in-sample gated signals …")
    adx_sys_is = ADXSystem(period=hpo_period)
    adx_df_is = adx_sys_is.compute(df_is["high"], df_is["low"], close_is)

    sig_gen_hpo = ADXSignalGenerator(
        adxr_threshold=hpo_adxr_thr,
        min_di_separation=hpo_min_sep,
    )
    signals_is = sig_gen_hpo.get_signals(adx_df_is, df_is["high"], df_is["low"])
    print(f"  In-sample signals (HPO gate): {len(signals_is)}")

    # ── 4. Triple-barrier labeling ────────────────────────────────────────
    print("Labeling in-sample signals …")
    target_is = close_is.pct_change().rolling(hpo_period).std().ffill()
    vb_is = add_vertical_barrier(
        t_events=signals_is.index, close=close_is, num_bars=MAX_HOLDING_BARS
    )

    events_is = get_events(
        close=close_is,
        t_events=signals_is.index,
        pt_sl=PT_SL,
        target=target_is,
        min_ret=MIN_RET,
        vertical_barrier_times=vb_is,
        side_prediction=signals_is["side"],
    )
    labels_is = get_bins(events_is, close_is).dropna()
    print(
        f"  Labeled signals: {len(labels_is)} "
        f"(bin=1: {(labels_is['bin'] == 1).sum()}, "
        f"bin=0: {(labels_is['bin'] == 0).sum()})"
    )

    # ── 5. Feature engineering ────────────────────────────────────────────
    print("Computing features …")
    # Align signals to the labeled subset only.
    signals_labeled = signals_is.loc[labels_is.index]
    X_is = compute_adx_features(
        adx_df_is,
        df_is["high"],
        df_is["low"],
        close_is,
        signals_labeled,
    )
    y_is = labels_is["bin"].loc[X_is.index].astype(int)

    # ── 6. Sample weights ─────────────────────────────────────────────────
    print("Computing sample weights …")
    w_is = get_weights_by_return_optimized(
        triple_barrier_events=events_is.loc[X_is.index],
        close=close_is,
    )
    # Normalise so weights sum to N (preserves effective sample size)
    w_is = w_is * len(w_is) / w_is.sum()

    # ── 7. Train secondary classifier ─────────────────────────────────────
    print("Training secondary classifier …")
    clf = RandomForestClassifier(
        n_estimators=N_ESTIMATORS,
        max_features="sqrt",
        min_samples_leaf=MIN_SAMPLES_LEAF,
        class_weight="balanced_subsample",
        oob_score=True,
        random_state=42,
        n_jobs=-1,
    )
    clf.fit(X_is.values, y_is.values, sample_weight=w_is.values)
    print(f"  OOB score: {clf.oob_score_:.4f}")

    # ── 8. Out-of-sample evaluation: three tracks ─────────────────────────
    print("\nOut-of-sample evaluation …")

    adx_sys_oos = ADXSystem(period=hpo_period)
    adx_df_oos = adx_sys_oos.compute(df_oos["high"], df_oos["low"], close_oos)

    # Wilder reference (ADXR >= 25, DI period = Wilder's 14)
    sig_gen_wilder = ADXSignalGenerator(adxr_threshold=25.0, min_di_separation=0.0)
    adx_df_wilder = ADXSystem(14).compute(df_oos["high"], df_oos["low"], close_oos)
    signals_t1 = sig_gen_wilder.get_signals(adx_df_wilder, df_oos["high"], df_oos["low"])

    # HPO gate (no classifier)
    signals_t2 = sig_gen_hpo.get_signals(adx_df_oos, df_oos["high"], df_oos["low"])

    # HPO gate + classifier + sizing (Track 3)
    if len(signals_t2) > 0:
        X_oos = compute_adx_features(
            adx_df_oos,
            df_oos["high"],
            df_oos["low"],
            close_oos,
            signals_t2,
        )
        proba = clf.predict_proba(X_oos.values)[:, 1]
        proba_s = pd.Series(proba, index=signals_t2.index)

        # Bet sizing: confidence → position size in (-1, 1).
        # get_signal returns a signed size matching signals_t2["side"]; we use
        # its magnitude to scale P&L, since direction is already encoded in
        # the triple-barrier labeling below via side_prediction.
        size_t2 = get_signal(
            prob=proba_s,
            num_classes=2,
            pred=signals_t2["side"],
        )

        # Suppress signals below confidence threshold (gate), then carry the
        # corresponding sizes through for the surviving signals (size).
        approved_idx = proba_s[proba_s >= CONFIDENCE_THR].index
        signals_t3 = signals_t2.loc[approved_idx]
        sizes_t3 = size_t2.loc[approved_idx].abs()
    else:
        signals_t3 = pd.DataFrame(columns=["side", "extreme"])
        sizes_t3 = pd.Series(dtype=float)

    # ── 9. Label all three tracks and report ─────────────────────────────
    def label_track(signals, tag, sizes=None):
        if len(signals) == 0:
            print(f"  {tag}: 0 signals — skipping")
            return None

        adx_period_for_target = hpo_period if tag != "Track 1" else 14
        tgt = close_oos.pct_change().rolling(adx_period_for_target).std().ffill()
        vb = add_vertical_barrier(
            t_events=signals.index, close=close_oos, num_bars=MAX_HOLDING_BARS
        )

        events = get_events(
            close=close_oos,
            t_events=signals.index,
            pt_sl=PT_SL,
            target=tgt,
            min_ret=MIN_RET,
            vertical_barrier_times=vb,
            side_prediction=signals["side"],
        )
        labels = get_bins(events, close_oos).dropna()

        if sizes is not None and len(labels) > 0:
            # Scale P&L magnitude by classifier confidence.  Win/loss
            # classification (bin) is unaffected — sizing changes the
            # magnitude of a barrier-touch outcome, not which barrier
            # was touched.
            aligned = sizes.reindex(labels.index).fillna(1.0)
            labels = labels.copy()
            labels["ret"] = labels["ret"] * aligned

        return labels

    labels_t1 = label_track(signals_t1, "Track 1")
    labels_t2 = label_track(signals_t2, "Track 2")
    labels_t3 = label_track(signals_t3, "Track 3", sizes=sizes_t3)

    # ── Summary table ─────────────────────────────────────────────────────
    print("\n" + "─" * 72)
    print(f"{'Track':<40} {'N':>6} {'Win%':>7} {'Avg P&L':>9} {'MaxDD':>9}")
    print("─" * 72)

    for tag, lbl in [
        ("Track 1 — Plain DI (ADXR≥25)", labels_t1),
        ("Track 2 — HPO gate only", labels_t2),
        ("Track 3 — HPO + classifier + sizing", labels_t3),
    ]:
        if lbl is None or len(lbl) == 0:
            print(f"{tag:<40} {'—':>6}")
            continue
        n_sig = len(lbl)
        win_rt = (lbl["bin"] == 1).mean() * 100
        avg_pl = lbl["ret"].mean() * 10_000  # pips proxy (10k × return)
        cum_pl = (lbl["ret"] + 1).cumprod()
        roll_max = cum_pl.cummax()
        max_dd = ((cum_pl - roll_max) / roll_max).min() * 100
        print(f"{tag:<40} {n_sig:>6} {win_rt:>6.1f}% {avg_pl:>9.1f} {max_dd:>8.1f}%")

    print("─" * 72)
    print("\nPipeline complete.  Results above are OOS only.")
    print(f"Artifacts saved to: {OUTPUT_DIR.resolve()}")


# ─────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    run_pipeline()
