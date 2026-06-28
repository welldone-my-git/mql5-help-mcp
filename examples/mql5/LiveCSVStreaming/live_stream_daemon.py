"""
live_stream_daemon.py
Real-time CSV tail daemon for MetaTrader 5 LiveCSVStreamer output files.

Requires: Python 3.8+, standard library only.

Usage:
    python live_stream_daemon.py

Configure SYMBOL, TIMEFRAME, POLL_INTERVAL, and ROLLING_WINDOW
in the Configuration block below before starting.
"""

import os
import time
import csv
import io
import logging
from datetime import datetime, timezone
from collections import deque

# ── Configuration ─────────────────────────────────────────────────────────────
MT5_APPDATA    = os.path.join(os.environ.get("APPDATA", ""),
                               "MetaQuotes", "Terminal")
SYMBOL         = "ETHUSD"
TIMEFRAME      = "M1"
POLL_INTERVAL  = 5          # Seconds between tail reads
ROLLING_WINDOW = 50         # Bars retained in rolling metric windows
ALERT_LOG      = "stream_alerts.log"

# Anomaly thresholds
WHIPSAW_DENSITY_THRESHOLD = 4     # False flips in last 5 bars
EQUITY_DRAWDOWN_THRESHOLD = 5.0   # Percent decline over last 10 bars
# ─────────────────────────────────────────────────────────────────────────────

logging.basicConfig(
    filename = ALERT_LOG,
    level    = logging.WARNING,
    format   = "%(asctime)s  %(levelname)s  %(message)s",
    datefmt  = "%Y-%m-%d %H:%M:%S"
)


def resolve_active_file(symbol: str, timeframe: str) -> str:
    """
    Resolves the path to today's active streaming CSV file.
    Searches all MetaTrader 5 terminal instance directories and the common
    files folder. Returns the most recently modified match, or None.
    """
    today_str = datetime.now(timezone.utc).strftime("%Y%m%d")
    target    = f"LiveStream_{symbol}_{timeframe}_{today_str}.csv"

    try:
        instances = [
            d for d in os.listdir(MT5_APPDATA)
            if os.path.isdir(os.path.join(MT5_APPDATA, d))
        ]
    except FileNotFoundError:
        raise FileNotFoundError(
            f"MT5 AppData directory not found at:\n  {MT5_APPDATA}\n"
            "Verify the APPDATA environment variable and MT5 installation."
        )

    candidates = []

    for inst in instances:
        candidate = os.path.join(
            MT5_APPDATA, inst, "MQL5", "Files", target
        )
        if os.path.isfile(candidate):
            candidates.append(candidate)

    common_candidate = os.path.join(
         MT5_APPDATA, "Common", "Files", target
    )
    if os.path.isfile(common_candidate):
        candidates.append(common_candidate)

    if not candidates:
        return None

    return max(candidates, key=os.path.getmtime)


class LiveStreamDaemon:
    """
    Tails an active LiveCSVStreamer output file, maintains rolling
    metric windows, checks for signal anomalies, and renders a live
    console dashboard at each polling interval.
    """

    def __init__(self, symbol        : str,
                       timeframe     : str,
                       poll_interval : int = POLL_INTERVAL,
                       rolling_window: int = ROLLING_WINDOW):
        self.symbol         = symbol
        self.timeframe      = timeframe
        self.poll_interval  = poll_interval
        self.rolling_window = rolling_window

        # Tail state
        self.active_file    = None
        self.file_offset    = 0
        self.header_parsed  = False
        self.column_map     = {}

        # Rolling metric windows
        self.equity_window   = deque(maxlen=rolling_window)
        self.slope_window    = deque(maxlen=rolling_window)
        self.whipsaw_deltas  = deque(maxlen=rolling_window)
        self.spread_window   = deque(maxlen=rolling_window)

        # Session-level state
        self.total_bars_seen  = 0
        self.last_false_flips = 0
        self.session_start    = datetime.now(timezone.utc)

    def _resolve_file(self) -> bool:
        path = resolve_active_file(self.symbol, self.timeframe)
        if path is None:
            return False

        if path != self.active_file:
            print(f"\n[Daemon] Active file: {os.path.basename(path)}")
            self.active_file   = path
            self.file_offset   = 0
            self.header_parsed = False
            self.column_map    = {}

        return True

    def _tail_new_rows(self) -> list:
        if not self.active_file or not os.path.isfile(self.active_file):
            return []

        new_rows = []

        with open(self.active_file, "r",
                  encoding="ansi", errors="replace") as f:
            f.seek(self.file_offset)
            new_bytes        = f.read()
            self.file_offset = f.tell()

        if not new_bytes.strip():
            return []

        reader = csv.DictReader(
            io.StringIO(new_bytes),
            fieldnames = list(self.column_map.keys())
                         if self.column_map else None
        )

        for row in reader:
            if not self.header_parsed:
                if "Bar_Time" in row or "Tick_Time" in row:
                    self.column_map    = {k: i
                                          for i, k in enumerate(row.keys())}
                    self.header_parsed = True
                    continue

            if row:
                new_rows.append(row)

        return new_rows

    def _process_bar_row(self, row: dict):
        try:
            equity      = float(row.get("Session_Equity",        0) or 0)
            slope       = int(row.get("Filter_Slope",            0) or 0)
            false_flips = int(row.get("False_Flips_Cumulative",  0) or 0)

            self.equity_window.append(equity)
            self.slope_window.append(slope)

            whipsaw_delta = max(0, false_flips - self.last_false_flips)
            self.whipsaw_deltas.append(whipsaw_delta)
            self.last_false_flips  = false_flips
            self.total_bars_seen  += 1

        except (ValueError, TypeError):
            pass

    def _process_tick_row(self, row: dict):
        try:
            spread = float(row.get("Spread_Points", 0) or 0)
            self.spread_window.append(spread)
        except (ValueError, TypeError):
            pass

    def _check_anomalies(self):
        if len(self.whipsaw_deltas) >= 5:
            recent_whipsaws = sum(list(self.whipsaw_deltas)[-5:])
            if recent_whipsaws >= WHIPSAW_DENSITY_THRESHOLD:
                logging.warning(
                    f"[{self.symbol} {self.timeframe}] High whipsaw density: "
                    f"{recent_whipsaws} false flips in last 5 bars."
                )

        if len(self.equity_window) >= 10:
            recent_equity = list(self.equity_window)
            equity_drop   = recent_equity[-10] - recent_equity[-1]
            equity_pct    = (equity_drop
                             / (recent_equity[-10] + 1e-9)) * 100
            if equity_pct > EQUITY_DRAWDOWN_THRESHOLD:
                logging.warning(
                    f"[{self.symbol} {self.timeframe}] Equity drawdown alert: "
                    f"{equity_pct:.1f}% decline over last 10 bars."
                )

    def _render_dashboard(self):
        equity_now  = self.equity_window[-1]  if self.equity_window  else 0.0
        equity_peak = max(self.equity_window)  if self.equity_window  else 0.0
        equity_dd   = ((equity_peak - equity_now)
                       / (equity_peak + 1e-9)) * 100

        slope_vals   = list(self.slope_window)
        rising_pct   = (slope_vals.count(1)  / len(slope_vals) * 100
                        if slope_vals else 0)
        falling_pct  = (slope_vals.count(-1) / len(slope_vals) * 100
                        if slope_vals else 0)

        avg_spread   = (sum(self.spread_window) / len(self.spread_window)
                        if self.spread_window else 0.0)

        recent_whips  = (sum(list(self.whipsaw_deltas)[-10:])
                        if self.whipsaw_deltas else 0)

        elapsed      = datetime.now(timezone.utc) - self.session_start
        hours, rem   = divmod(int(elapsed.total_seconds()), 3600)
        minutes      = rem // 60

        print("\033[H\033[J", end="")
        print(f"{'=' * 58}")
        print(f"  Live Stream Dashboard  |  "
              f"{self.symbol} {self.timeframe}")
        print(f"  Session: {hours:02d}h {minutes:02d}m  |  "
              f"Bars Seen: {self.total_bars_seen:,}")
        print(f"{'=' * 58}")
        print(f"  Equity Now    : {equity_now:>12.2f}")
        print(f"  Equity Peak   : {equity_peak:>12.2f}")
        print(f"  Rolling DD    : {equity_dd:>11.2f}%")
        print(f"{'─' * 58}")
        print(f"  Filter Slope  :  Rising {rising_pct:.0f}%  |  "
              f"Falling {falling_pct:.0f}%")
        print(f"  Avg Spread    : {avg_spread:>11.1f} pts")
        print(f"  Whipsaws (10b): {recent_whips:>11d}")
        print(f"{'─' * 58}")
        print(f"  Alert Log     :  {ALERT_LOG}")
        print(f"{'=' * 58}")

    def run(self):
        print(f"[Daemon] Starting. Symbol={self.symbol} "
              f"TF={self.timeframe} "
              f"Poll={self.poll_interval}s  "
              f"Window={self.rolling_window} bars")
        print(f"[Daemon] Press Ctrl+C to stop.\n")

        while True:
            try:
                if not self._resolve_file():
                    print(
                        f"[Daemon] Waiting for "
                        f"LiveStream_{self.symbol}_{self.timeframe}_"
                        f"{datetime.now(timezone.utc).strftime('%Y%m%d')}"
                        f".csv ..."
                    )
                    time.sleep(self.poll_interval)
                    continue

                new_rows = self._tail_new_rows()

                for row in new_rows:
                    if "Bar_Time" in row:
                        self._process_bar_row(row)
                    elif "Tick_Time" in row:
                        self._process_tick_row(row)

                if new_rows:
                    self._check_anomalies()

                if self.total_bars_seen > 0:
                    self._render_dashboard()

                time.sleep(self.poll_interval)

            except KeyboardInterrupt:
                print("\n[Daemon] Shutdown requested. Exiting cleanly.")
                break
            except Exception as exc:
                print(f"[Daemon] Unhandled error: {exc}")
                time.sleep(self.poll_interval)


# ── Entry Point ───────────────────────────────────────────────────────────────
if __name__ == "__main__":
    daemon = LiveStreamDaemon(
        symbol         = SYMBOL,
        timeframe      = TIMEFRAME,
        poll_interval  = POLL_INTERVAL,
        rolling_window = ROLLING_WINDOW
    )
    daemon.run()