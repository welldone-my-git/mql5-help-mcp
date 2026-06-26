"""
afml/bet_sizing/bet_sizing.py

From probabilities to bet size (Advances in Financial Machine Learning,
Chapter 10, Snippet 10.1). Converts a secondary classifier's predicted
probability into a signed position size via the z-score / normal-CDF
transform.

This is a minimal excerpt of the Blueprint Quant afml package, containing
only get_signal, the single function this article's code (adx_pipeline.py)
calls. The complete bet_sizing module also covers averaging active bets,
discrete sizing, and dynamic bet sizing via limit price functions, which
are out of scope for this article.

Author: Patrick Murimi Njoroge — Blueprint Quant
"""

import pandas as pd
from scipy.stats import norm


def get_signal(prob, num_classes, pred=None):
    """
    SNIPPET 10.1 - FROM PROBABILITIES TO BET SIZE
    """
    if prob.shape[0] == 0:
        return pd.Series(dtype="float64")

    prob = prob.clip(lower=1e-6, upper=1 - 1e-6)

    bet_sizes = (prob - 1 / num_classes) / (prob * (1 - prob)) ** 0.5

    if not isinstance(pred, type(None)):
        bet_sizes = pred * (2 * norm.cdf(bet_sizes) - 1)

    return bet_sizes
