"""
afml/sample_weights/optimized_attribution.py

Sample weight computation by absolute return attribution, with concurrency
correction (Advances in Financial Machine Learning, Chapter 4). Numba-
optimized implementation.

This is a minimal excerpt of the Blueprint Quant afml package, containing
only the functions adx_pipeline.py's Step 6 (sample weights for the
secondary classifier) calls: get_weights_by_return_optimized and its three
internal dependencies. It is not the complete sample_weights module — time-
decay weighting, uniqueness estimation, and the non-optimized original
implementations are omitted as out of scope for this article.

Author: Patrick Murimi Njoroge — Blueprint Quant
"""

import time
from datetime import timedelta

import numpy as np
import pandas as pd
from numba import njit, prange


# ─────────────────────────────────────────────────────────────────────────────
@njit(parallel=True, fastmath=True, cache=True)
def _compute_concurrent_events_numba(start_times, end_times, time_index, start_idx, end_idx):
    """
    Numba-optimized function to compute concurrent events count.

    This function uses parallel computation and fast math to dramatically speed up
    the counting of concurrent events. It processes time intervals in parallel
    and uses efficient indexing to avoid redundant computations.

    Parameters:
    -----------
    start_times : np.ndarray
        Array of event start times (as int64 timestamps)
    end_times : np.ndarray
        Array of event end times (as int64 timestamps)
    time_index : np.ndarray
        Array of time index values (as int64 timestamps)
    start_idx : int
        Starting index in time_index array
    end_idx : int
        Ending index in time_index array

    Returns:
    --------
    np.ndarray
        Array of concurrent event counts for each time point
    """
    n_times = end_idx - start_idx
    counts = np.zeros(n_times, dtype=np.int32)

    for i in prange(n_times):
        current_time = time_index[start_idx + i]
        count = 0

        for j in range(len(start_times)):
            if start_times[j] <= current_time <= end_times[j]:
                count += 1

        counts[i] = count

    return counts


def get_num_conc_events_optimized(
    close_index: pd.DatetimeIndex, label_endtime: pd.Series, verbose: bool = False
):
    """
    Advances in Financial Machine Learning, Snippet 4.1, page 60.

    Estimating the Uniqueness of a Label

    This function uses close series prices and label endtime (when the first barrier is touched) to compute the number
    of concurrent events per bar.

    Parameters:
    -----------
    close_index : pd.DatetimeIndex
        Close prices index
    label_endtime : pd.Series
        Label endtime series (t1 for triple barrier events)
    verbose : bool, default=True
        Report computation time

    Returns:
    --------
    pd.Series
        Number of concurrent labels for each datetime index
    """
    if verbose:
        time0 = time.perf_counter()

    relevant_events = label_endtime.fillna(close_index[-1])

    max_end_time = relevant_events.max()
    relevant_events = relevant_events.loc[:max_end_time]

    start_times = relevant_events.index.to_numpy(np.int64)
    end_times = relevant_events.to_numpy(np.int64)

    time_index = close_index.to_numpy(np.int64)
    start_idx = 0
    end_idx = close_index.searchsorted(max_end_time, side="right")

    counts = _compute_concurrent_events_numba(
        start_times, end_times, time_index, start_idx, end_idx
    )

    result_index = close_index[start_idx:end_idx]
    result = pd.Series(counts, index=result_index)

    num_conc_events = result.loc[:max_end_time]

    if verbose:
        print(
            f"get_num_conc_events_optimized done after {timedelta(seconds=round(time.perf_counter() - time0))}."
        )

    return num_conc_events


# ─────────────────────────────────────────────────────────────────────────────
@njit(parallel=True, fastmath=True, cache=True)
def _compute_return_weights_numba(
    log_returns, start_indices, end_indices, concurrent_counts, n_events
):
    """
    Numba-optimized function to compute return-based weights.

    This function calculates sample weights based on returns and concurrency
    using parallel processing. It normalizes returns by concurrent event counts
    and computes absolute weights efficiently.

    Parameters:
    -----------
    log_returns : np.ndarray
        Array of log returns
    start_indices : np.ndarray
        Array of start indices for each event
    end_indices : np.ndarray
        Array of end indices for each event
    concurrent_counts : np.ndarray
        Array of concurrent event counts
    n_events : int
        Number of events to process

    Returns:
    --------
    np.ndarray
        Array of absolute return weights
    """
    weights = np.zeros(n_events, dtype=np.float64)

    for i in prange(n_events):
        start_idx = start_indices[i]
        end_idx = end_indices[i]

        if start_idx < end_idx and end_idx <= len(log_returns):
            weight_sum = 0.0

            for j in range(start_idx, end_idx):
                if concurrent_counts[j] > 0:
                    weight_sum += log_returns[j] / concurrent_counts[j]

            weights[i] = abs(weight_sum)

    return weights


def _apply_weight_by_return_optimized(label_endtime, num_conc_events, close):
    """
    Optimized version of return weight calculation for parallel processing.

    This function is designed to work with mp_pandas_obj and provides significant
    performance improvements over the original implementation through:

    - Vectorized log return calculations
    - Parallel processing of weight calculations via Numba
    - Efficient indexing and memory access
    - Reduced Python overhead

    Parameters:
    -----------
    label_endtime : pd.Series
        Label endtime series (t1 for triple barrier events)
    num_conc_events : pd.Series
        Number of concurrent events
    close : pd.Series
        Close prices

    Returns:
    --------
    pd.Series
        Sample weights based on return and concurrency
    """
    log_returns = np.log(close).diff().values

    n_events = len(label_endtime)

    if n_events == 0:
        return pd.Series(dtype=np.float64)

    start_indices = close.index.get_indexer(label_endtime.index)
    end_indices = (
        close.index.get_indexer_for(label_endtime) + 1
    )  # Guaranteed return of an indexer even when non-unique.

    concurrent_counts = num_conc_events.values

    weights = _compute_return_weights_numba(
        log_returns, start_indices, end_indices, concurrent_counts, n_events
    )

    return pd.Series(weights, index=label_endtime.index)


def get_weights_by_return_optimized(
    triple_barrier_events,
    close,
    num_conc_events=None,
    verbose=False,
):
    """
    Optimized determination of sample weight by absolute return attribution.

    This function provides significant performance improvements over the original
    implementation through multiple optimization techniques:

    Key Optimizations:
    1. Numba JIT compilation for hot loops and numerical computations
    2. Vectorized operations using NumPy for mathematical operations
    3. Parallel processing optimizations via multiprocessing
    4. Efficient memory usage and reduced Python overhead
    5. Cache-friendly data access patterns

    Parameters:
    -----------
    triple_barrier_events : pd.DataFrame
        Events from labeling.get_events()
    close : pd.Series
        Close prices
    num_conc_events : pd.Series, optional
        Precomputed concurrent events count. If None, will be computed.
    verbose : bool, default=True
        Report progress on parallel jobs

    Returns:
    --------
    pd.Series
        Sample weights based on absolute return attribution

    Examples:
    ---------
    >>> # Basic usage
    >>> weights = get_weights_by_return_optimized(events, close_prices)
    >>>
    >>> # With precomputed concurrent events for better performance
    >>> conc_events = get_num_conc_events_optimized(events, close_prices)
    >>> weights = get_weights_by_return_optimized(events, close_prices, num_conc_events=conc_events)

    Notes:
    ------
    - This function is a drop-in replacement for the original get_weights_by_return
    - Results are identical to the original implementation
    - Requires numba package for optimal performance
    - For best performance, precompute num_conc_events if calling multiple times
    """
    if verbose:
        time0 = time.perf_counter()

    # Input validation
    assert not triple_barrier_events.isnull().values.any(), "NaN values in events"
    assert not triple_barrier_events.index.isnull().any(), "NaN values in index"

    def process_concurrent_events(ce):
        """Process concurrent events to ensure proper format and indexing."""
        ce = ce.loc[~ce.index.duplicated(keep="last")]
        ce = ce.reindex(close.index).fillna(0)
        return ce

    if num_conc_events is None:
        num_conc_events = get_num_conc_events_optimized(
            close.index, triple_barrier_events["t1"], verbose
        )
        processed_ce = process_concurrent_events(num_conc_events)
    else:
        processed_ce = process_concurrent_events(num_conc_events.copy())

        missing_in_close = processed_ce.index.difference(close.index)
        assert missing_in_close.empty, (
            f"num_conc_events contains {len(missing_in_close)} indices not in close"
        )

    weights = _apply_weight_by_return_optimized(
        label_endtime=triple_barrier_events["t1"],
        num_conc_events=processed_ce,
        close=close,
    )

    weights *= weights.shape[0] / weights.sum()

    if verbose:
        print(
            f"get_weights_by_return_optimized done after {timedelta(seconds=round(time.perf_counter() - time0))}."
        )

    return weights
