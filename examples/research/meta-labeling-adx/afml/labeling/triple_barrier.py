"""
afml/labeling/triple_barrier.py

Triple-barrier labeling (Advances in Financial Machine Learning, Chapter 3).
Numba-optimized implementation: get_events, add_vertical_barrier, get_bins,
and their internal helpers.

This is a minimal excerpt of the Blueprint Quant afml package, containing
only the functions this article's code (adx_hpo.py, adx_pipeline.py) calls.
It is included so the article's code is runnable without installing the
complete afml package. It is not the full labeling module — drop_labels,
triple_barrier_labels, and the non-optimized original implementations are
omitted as out of scope for this article.

Author: Patrick Murimi Njoroge — Blueprint Quant
"""

import numpy as np
import pandas as pd
from numba import njit, prange


@njit(parallel=True, cache=True)
def _find_barrier_hits(close_val, event_locs, t1_locs, trgt, side, pt_sl_arr):
    """
    Core Numba-jitted logic to find the first time barriers are touched.
    Operates entirely on NumPy arrays for maximum performance.
    """
    pt_level = pt_sl_arr[0]
    sl_level = pt_sl_arr[1]
    N = event_locs.shape[0]

    pt_hit_locs, sl_hit_locs = np.full((2, N), -1, dtype=np.int64)

    for i in prange(N):
        start_loc = event_locs[i]
        end_loc = t1_locs[i]

        if start_loc == -1:
            continue

        start_price = close_val[start_loc]
        event_side = side[i]

        pt = pt_level * trgt[i] if pt_level > 0 else np.inf
        sl = -sl_level * trgt[i] if sl_level > 0 else -np.inf

        for j in range(start_loc + 1, end_loc + 1):
            ret = (close_val[j] / start_price - 1) * event_side

            if sl_hit_locs[i] == -1 and ret <= sl:
                sl_hit_locs[i] = j

            if pt_hit_locs[i] == -1 and ret >= pt:
                pt_hit_locs[i] = j

            if sl_hit_locs[i] != -1 and pt_hit_locs[i] != -1:
                break

    return sl_hit_locs, pt_hit_locs


def apply_pt_sl_on_t1_optimized(close: pd.Series, events: pd.DataFrame, pt_sl: list):
    """
    Advances in Financial Machine Learning, Snippet 3.2, page 45.
    Triple Barrier Labeling Method (Numba Optimized)
    """
    event_locs = close.index.get_indexer(events.index)
    t1_locs = close.index.get_indexer_for(events["t1"].values)

    close_val = close.to_numpy()
    t1_locs[t1_locs == -1] = len(close_val) - 1  # Handle NaT in t1
    trgt_val = events["trgt"].to_numpy()
    side_val = events["side"].to_numpy()
    pt_sl_arr = np.array(pt_sl)

    sl_hit_locs, pt_hit_locs = _find_barrier_hits(
        close_val, event_locs, t1_locs, trgt_val, side_val, pt_sl_arr
    )

    out = events[["t1"]].copy()
    out["sl"] = pd.NaT
    out["pt"] = pd.NaT

    sl_hit_mask = sl_hit_locs != -1
    pt_hit_mask = pt_hit_locs != -1

    sl_idx_labels = events.index[sl_hit_mask]
    pt_idx_labels = events.index[pt_hit_mask]
    sl_timestamps = close.index[sl_hit_locs[sl_hit_mask]]
    pt_timestamps = close.index[pt_hit_locs[pt_hit_mask]]

    out.loc[sl_idx_labels, "sl"] = sl_timestamps
    out.loc[pt_idx_labels, "pt"] = pt_timestamps

    return out


def get_events(
    close: pd.Series,
    t_events: pd.DatetimeIndex,
    pt_sl: list,
    target: pd.Series,
    min_ret: float = 0.0,
    vertical_barrier_times: pd.Series = None,
    side_prediction: pd.Series = None,
):
    """
    Advances in Financial Machine Learning, Snippet 3.6 page 50.
    """
    target = target.reindex(t_events)
    target = target[target > min_ret]

    if vertical_barrier_times is None:
        vertical_barrier_times = pd.Series(pd.NaT, index=t_events, dtype=t_events.dtype)

    if side_prediction is None:
        side = pd.Series(1.0, index=target.index)
        pt_sl = [pt_sl[0], pt_sl[0]]
    else:
        side = side_prediction.reindex(target.index)
        pt_sl = pt_sl[:2]

    events = pd.concat({"t1": vertical_barrier_times, "trgt": target, "side": side}, axis=1)
    events = events.dropna(subset=["trgt"])
    events[["pt", "sl"]] = np.full((events.shape[0], 2), pt_sl, dtype="float32")

    first_touch_dates = apply_pt_sl_on_t1_optimized(close, events, pt_sl)
    events["t1"] = first_touch_dates.dropna(how="all").min(axis=1)

    if side_prediction is None:
        events = events.drop("side", axis=1)

    return events


def add_vertical_barrier(
    t_events: pd.DatetimeIndex, close: pd.Series, num_bars: int = 0, **time_delta_kwargs
):
    """
    Advances in Financial Machine Learning, Enhanced Implementation.
    Adding a Vertical Barrier
    """
    if num_bars and time_delta_kwargs:
        raise ValueError("Use either num_bars OR time deltas, not both")

    if num_bars > 0:
        indices = close.index.get_indexer(t_events, method="nearest")
        t1 = []
        for i in indices:
            if i == -1:
                t1.append(pd.NaT)
            else:
                end_loc = i + num_bars
                t1.append(close.index[end_loc] if end_loc < len(close) else pd.NaT)
        return pd.Series(t1, index=t_events, name="t1")

    td = pd.Timedelta(**time_delta_kwargs) if time_delta_kwargs else pd.Timedelta(0)
    barrier_times = t_events + td

    t1_indices = np.searchsorted(close.index, barrier_times, side="left")
    t1 = []
    for idx in t1_indices:
        if idx < len(close):
            t1.append(close.index[idx])
        else:
            t1.append(pd.NaT)

    return pd.Series(t1, index=t_events, name="t1")


@njit(parallel=True, cache=True)
def barrier_touched(ret, target, pt_sl):
    """
    Advances in Financial Machine Learning, Snippet 3.9, page 55, Question 3.3.
    """
    N = len(ret)
    store = np.empty(N, dtype=np.int8)

    profit_taking_multiple = pt_sl[0]
    stop_loss_multiple = pt_sl[1]

    for i in prange(N):
        pt_level_reached = ret[i] > profit_taking_multiple * target[i]
        sl_level_reached = ret[i] < -stop_loss_multiple * target[i]

        if ret[i] > 0.0 and pt_level_reached:
            store[i] = 1
        elif ret[i] < 0.0 and sl_level_reached:
            store[i] = -1
        else:
            store[i] = 0

    return store


def optimize_dtypes(df: pd.DataFrame, verbose: bool = True) -> pd.DataFrame:
    optimized_df = df.copy()
    start_mem = optimized_df.memory_usage(deep=True).sum() / 1024**2

    for col in optimized_df.columns:
        col_dtype = optimized_df[col].dtype

        if pd.api.types.is_numeric_dtype(col_dtype):
            if pd.api.types.is_integer_dtype(col_dtype):
                optimized_df[col] = pd.to_numeric(optimized_df[col], downcast="integer")
            elif pd.api.types.is_float_dtype(col_dtype):
                if (
                    not optimized_df[col].isna().any()
                    and (optimized_df[col] == optimized_df[col].round()).all()
                ):
                    optimized_df[col] = optimized_df[col].astype("int64")
                    optimized_df[col] = pd.to_numeric(optimized_df[col], downcast="integer")
                else:
                    optimized_df[col] = pd.to_numeric(optimized_df[col], downcast="float")
        elif pd.api.types.is_object_dtype(col_dtype):
            num_unique_values = optimized_df[col].nunique()
            num_total_values = len(optimized_df[col])
            if num_unique_values / num_total_values < 0.5:
                optimized_df[col] = optimized_df[col].astype("category")

    end_mem = optimized_df.memory_usage(deep=True).sum() / 1024**2

    if verbose:
        reduction_pct = 100 * (start_mem - end_mem) / max(start_mem, 1e-9)
        print(
            f"Memory usage reduced from {start_mem:.2f} MB to {end_mem:.2f} MB ({reduction_pct:.1f}% reduction)"
        )

    return optimized_df


def get_bins(triple_barrier_events, close, vertical_barrier_zero=False):
    """
    Advances in Financial Machine Learning, Snippet 3.7, page 51.
    """
    events = triple_barrier_events.dropna(subset=["t1"])
    all_dates = events.index.union(other=events["t1"].array).drop_duplicates()
    prices = close.reindex(all_dates, method="bfill")

    out_df = events[["t1", "trgt"]].copy()
    out_df["ret"] = prices.loc[events["t1"].array].array / prices.loc[events.index] - 1

    if "side" in events:
        out_df["ret"] *= events["side"]

    if vertical_barrier_zero:
        pt_sl = events[["pt", "sl"]].iloc[0].to_numpy()
        out_df["bin"] = barrier_touched(out_df["ret"].to_numpy(), out_df["trgt"].to_numpy(), pt_sl)
    else:
        out_df["bin"] = np.sign(out_df["ret"]).astype("int8")

    if "side" in events:
        out_df.loc[out_df["ret"].values <= 0, "bin"] = 0
        out_df["side"] = events["side"].astype("int8")

    out_df = optimize_dtypes(out_df, verbose=False)

    return out_df
