"""
adx_hpo.py
==========
Bayesian hyperparameter optimization for the ADX regime gate.

The gate has three parameters that Wilder chose by visual inspection on 1970s
commodity charts.  This module replaces that static choice with a data-driven
search over the parameter space that maximizes signal precision on a held-out
validation window.

Functions
---------
adx_hpo_objective
    Optuna trial function.  Suggests gate parameters, constructs the gated
    signal stream, applies triple-barrier labeling, and returns signal
    precision on the last val_fraction of the in-sample data.

run_adx_hpo
    Creates (or resumes) an Optuna study and runs n_trials NEW evaluations on
    top of whatever the SQLite study already contains. n_trials is not a
    total cap across resumed runs.

Searched parameters
-------------------
adxr_threshold    : float in [15, 50]
    ADXR level below which signals are rejected.  Wilder's original is 25.

di_period         : int   in [7, 28]
    Lookback period for DM, TR, and ADX smoothing.  Wilder's original is 14.

min_di_separation : float in [0, 15]
    Minimum |+DI14 - -DI14| at the crossover bar.

Objective metric
----------------
Precision = fraction of gated signals with bin == 1 (profitable) under
triple-barrier labeling, evaluated on the held-out validation window
(last val_fraction of the in-sample period, default 30%).  Trials that
produce fewer than 20 gated signals are pruned.

Series: Meta-Labeling the Classics (Part 2)
Author: Patrick Murimi Njoroge — Blueprint Quant
"""

from __future__ import annotations

import numpy as np
import optuna
import pandas as pd
from adx_system import ADXSignalGenerator, ADXSystem

# Suppress Optuna's verbose per-trial logging by default.
optuna.logging.set_verbosity(optuna.logging.WARNING)


# ─────────────────────────────────────────────────────────────────────────────
def adx_hpo_objective(
    trial: optuna.Trial,
    ohlc: pd.DataFrame,
    close: pd.Series,
    val_fraction: float = 0.30,
    pt_sl: list[float] | None = None,
    min_ret: float = 0.0005,
    max_holding_bars: int = 240,
) -> float:
    """
    Optuna objective for the ADX three-parameter regime gate.

    Parameters
    ----------
    trial : optuna.Trial
        Optuna trial object (injected by the study).
    ohlc : pd.DataFrame
        In-sample OHLC data with columns 'high', 'low', 'close'.
    close : pd.Series
        Close price series (same index as ohlc, passed separately for
        convenience with the labeling API).
    val_fraction : float
        Fraction of in-sample data reserved for objective evaluation.
        The search never touches out-of-sample data.
    pt_sl : list[float] | None
        [profit-take multiplier, stop-loss multiplier] for triple-barrier
        labeling.  Defaults to [1.5, 1.5].
    min_ret : float
        Minimum expected return to label a signal; passed to get_events.
    max_holding_bars : int
        Vertical barrier width in bars.  DESIGN CHOICE — flagged explicitly:
        passing vertical_barrier_times=None to afml's get_events does not
        disable the time barrier gracefully; it leaves every t1 as NaT,
        which the underlying numba kernel resolves by searching forward to
        the *last bar of the entire series* for every event. That makes
        trade duration unbounded and label concurrency unpredictable, which
        contradicts the bounded-horizon assumption the rest of this project
        relies on for purging and embargo. Default here is 240 bars (10
        trading days on H1) as a starting point for a multi-day ADX trend
        system; this is a methodology decision, not a default to accept
        blindly — tune against your actual holding-period expectations.

    Returns
    -------
    float
        Signal precision on the validation window.  Higher is better.

    Raises
    ------
    optuna.exceptions.TrialPruned
        When fewer than 20 labeled signals exist in the validation window.
    """
    from afml.labeling.triple_barrier import add_vertical_barrier, get_bins, get_events

    if pt_sl is None:
        pt_sl = [1.5, 1.5]

    # ── Suggest gate parameters ───────────────────────────────────────────
    adxr_threshold = trial.suggest_float("adxr_threshold", 15.0, 50.0)
    di_period = trial.suggest_int("di_period", 7, 28)
    min_di_separation = trial.suggest_float("min_di_separation", 0.0, 15.0)

    # ── Compute ADX and generate gated signals ────────────────────────────
    adx_sys = ADXSystem(period=di_period)
    adx_df = adx_sys.compute(ohlc["high"], ohlc["low"], ohlc["close"])

    sig_gen = ADXSignalGenerator(
        adxr_threshold=adxr_threshold,
        min_di_separation=min_di_separation,
    )
    signals = sig_gen.get_signals(adx_df, ohlc["high"], ohlc["low"])

    if len(signals) < 20:
        raise optuna.exceptions.TrialPruned()

    # ── Triple-barrier labeling with primary model's side ─────────────────
    # Volatility target: rolling std of returns scaled by the DI period.
    target = close.pct_change().rolling(di_period).std().dropna()
    target = target.reindex(close.index).ffill()

    vertical_barriers = add_vertical_barrier(
        t_events=signals.index, close=close, num_bars=max_holding_bars
    )

    try:
        events = get_events(
            close=close,
            t_events=signals.index,
            pt_sl=pt_sl,
            target=target,
            min_ret=min_ret,
            vertical_barrier_times=vertical_barriers,
            side_prediction=signals["side"],
        )
        labels = get_bins(events, close).dropna()
    except (ValueError, KeyError):
        # Data-related failures (e.g. no valid events in this parameter
        # region) are expected and should prune the trial. Programming
        # errors such as TypeError from a signature mismatch are NOT
        # caught here — they should propagate and fail loudly, since a
        # bare `except Exception` previously masked exactly that failure
        # mode and silently pruned every trial in the study.
        raise optuna.exceptions.TrialPruned()

    if len(labels) < 20:
        raise optuna.exceptions.TrialPruned()

    # ── Time-ordered hold-out: evaluate on last val_fraction ──────────────
    split = int(len(labels) * (1.0 - val_fraction))
    labels_val = labels.iloc[split:]

    if len(labels_val) < 10:
        raise optuna.exceptions.TrialPruned()

    precision = float((labels_val["bin"] == 1).mean())
    return precision


# ─────────────────────────────────────────────────────────────────────────────
def run_adx_hpo(
    ohlc: pd.DataFrame,
    close: pd.Series,
    n_trials: int = 200,
    val_fraction: float = 0.30,
    pt_sl: list[float] | None = None,
    min_ret: float = 0.0005,
    max_holding_bars: int = 240,
    study_name: str = "adx_gate_hpo",
    storage: str = "sqlite:///adx_hpo.db",
    seed: int = 42,
) -> optuna.Study:
    """
    Run (or resume) the Bayesian gate parameter search.

    The study persists to SQLite so an interrupted run resumes from the last
    completed trial — the same approach used in Blueprint Parts 8 and 9.

    Parameters
    ----------
    ohlc : pd.DataFrame
        In-sample OHLC data with columns 'high', 'low', 'close'.
    close : pd.Series
        Close price series (same index as ohlc).
    n_trials : int
        Number of NEW trials to run in this call. NOT a total cap — if the
        SQLite study already has trials from a prior run (load_if_exists=True
        finds them), this many additional trials are appended on top. A run
        interrupted at, say, 150/200 trials and resumed with n_trials=200
        will execute 200 more trials, reaching 350 total, not 200. To target
        a specific total, track completed-trial count yourself (see
        study.trials) and pass the remainder.
    val_fraction : float
        Fraction of in-sample data used for objective evaluation.
    pt_sl : list[float] | None
        Profit-take / stop-loss multipliers for triple-barrier labeling.
    min_ret : float
        Minimum return threshold for a label to be non-zero.
    max_holding_bars : int
        Vertical barrier width in bars, passed to adx_hpo_objective. Must
        match the value used in the final pipeline evaluation (adx_pipeline.py)
        — using a different horizon at HPO time than at evaluation time means
        the gate is optimized for a different labeling regime than the one
        it is ultimately scored against.
    study_name : str
        Name of the Optuna study (key in the SQLite file).
    storage : str
        SQLite connection string.  Use a project-specific path in production.
    seed : int
        Random seed for the TPE sampler.

    Returns
    -------
    optuna.Study
        Completed study.  Access best parameters via study.best_params.

    Example
    -------
    >>> study = run_adx_hpo(ohlc_train, close_train, n_trials=200)
    >>> print(study.best_params)
    >>> print(f"Best precision: {study.best_value:.4f}")
    """
    sampler = optuna.samplers.TPESampler(seed=seed)
    study = optuna.create_study(
        direction="maximize",
        sampler=sampler,
        study_name=study_name,
        storage=storage,
        load_if_exists=True,
    )

    def objective(trial: optuna.Trial) -> float:
        return adx_hpo_objective(
            trial,
            ohlc=ohlc,
            close=close,
            val_fraction=val_fraction,
            pt_sl=pt_sl,
            min_ret=min_ret,
            max_holding_bars=max_holding_bars,
        )

    study.optimize(
        objective,
        n_trials=n_trials,
        catch=(ValueError, RuntimeError),
        show_progress_bar=True,
    )

    completed = len([t for t in study.trials if t.state == optuna.trial.TrialState.COMPLETE])
    pruned = len([t for t in study.trials if t.state == optuna.trial.TrialState.PRUNED])
    print(f"\nHPO complete: {completed} completed, {pruned} pruned")
    print(f"Best params : {study.best_params}")
    print(f"Best value  : {study.best_value:.4f}")

    return study


# ─────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    # Smoke test: run 5 trials on synthetic data without the afml dependency.
    import numpy as np

    rng = np.random.default_rng(0)
    n = 800
    close = pd.Series(
        np.cumprod(1 + rng.normal(0, 0.001, n)),
        index=pd.date_range("2022-01-03", periods=n, freq="h"),
    )
    ohlc = pd.DataFrame(
        {
            "high": close * (1 + np.abs(rng.normal(0, 0.0004, n))),
            "low": close * (1 - np.abs(rng.normal(0, 0.0004, n))),
            "close": close,
        }
    )

    print("Smoke test: checking ADXSystem + ADXSignalGenerator inside objective …")
    adx_sys = ADXSystem(period=14)
    adx_df = adx_sys.compute(ohlc["high"], ohlc["low"], ohlc["close"])
    sig_gen = ADXSignalGenerator(adxr_threshold=20.0)
    signals = sig_gen.get_signals(adx_df, ohlc["high"], ohlc["low"])
    print(f"  Signals with default gate (ADXR >= 20): {len(signals)}")
    print("Smoke test passed. Run run_adx_hpo() with real data and afml installed.")
