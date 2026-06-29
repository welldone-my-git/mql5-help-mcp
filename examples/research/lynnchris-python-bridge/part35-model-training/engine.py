#!/usr/bin/env python3
# ────────────────────────────────────────────────────────────────
#  engine.py – Boom / Crash / Vol-75 ML back-end
#
#  • vectorised /upload_history  (<300 ms / 20 000 bars)
#  • /upload_spike_csv  accepts EA log (16 cols) and converts to 12 cols
#  • Prophet compiled once per symbol (cached 1 h)
#  • robust CSV writer  (always 12 columns)
#  • train() drops rows with non-numeric features
#  • SL/TP use ATR or % fallback → never identical
#  • backtest defaults to last 30 days if no range supplied
#  • CLI: collect · history · train · backtest · serve · info
#
#  REQS : pip install numpy pandas ta prophet cmdstanpy pykalman
#                         scikit-learn flask MetaTrader5 joblib pytz
# ────────────────────────────────────────────────────────────────

# ───────── USER SETTINGS ─────────────────────────────────────────
TERM_PATH  = r"C:\Program Files\MetaTrader 5\terminal64.exe"
LOGIN      = 4****21***
PASSWORD   = "*********"
SERVER     = "********"

SYMBOLS = [
    "Boom 900 Index",  "Crash 1000 Index",
    "Boom 300 Index",  "Crash 300 Index",
    "Boom 500 Index",  "Crash 500 Index",
    "Boom 1000 Index", "Volatility 75 (1s) Index"
]

LOOKAHEAD    = 10          # minutes ahead for the label
THRESH_LABEL = 0.0015      # 0.15 %
STEP_SECONDS = 60          # poll interval in live collect (s)

THR_BC_OPEN  = 0.45        # Boom/Crash open threshold
THR_O_OPEN   = 0.50        # Other symbols open
THR_O_CLOSE  = 0.30        # early-close threshold

ATR_PERIOD     = 14
SL_MULT        = 1.0
TP_MULT        = 2.0
ATR_FALLBACK_P = 0.002     # 0.2 % of price if ATR unavailable
SCALE_IN_DIST  = 1.0
MAX_ADDS       = 3

# ───────── FILES ────────────────────────────────────────────────
BASE_DIR   = r"C:\Users\hp\Pictures\Saved Pictures\Analysis EA"
CSV_FILE   = rf"{BASE_DIR}\training_set.csv"
MODEL_DIR  = rf"{BASE_DIR}\models"
GLOBAL_PKL = rf"{MODEL_DIR}\_global.pkl"

CSV_HEADER = [
    "timestamp","symbol","price","spike_mag","macd","rsi",
    "atr","slope","env_low","env_up","delta","label"
]

# ───────── imports / globals ─────────────────────────────────────
import os, sys, time, logging, warnings, argparse, threading, io
import datetime as dt
from pathlib import Path
from typing  import List, Dict, Tuple
import numpy  as np
import pandas as pd
from flask   import Flask, request, jsonify, abort
import ta, joblib, pytz
from sklearn.pipeline      import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble      import GradientBoostingClassifier
from prophet               import Prophet
from pykalman              import KalmanFilter
import MetaTrader5 as mt5

UTC = pytz.UTC
warnings.filterwarnings("ignore")
for m in ("prophet", "cmdstanpy"):
    logging.getLogger(m).setLevel(logging.WARNING)
logging.basicConfig(level=logging.INFO,
    format="%(asctime)s  %(levelname)-7s %(message)s", datefmt="%H:%M:%S")

Path(MODEL_DIR).mkdir(parents=True, exist_ok=True)
os.chdir(BASE_DIR)

# ───────── MT5 helpers ───────────────────────────────────────────
_mt5_lock = threading.Lock()
def init_mt5():
    if mt5.initialize(): return
    if not mt5.initialize(path=TERM_PATH, login=LOGIN,
                          password=PASSWORD, server=SERVER):
        sys.exit(f"MT5 init failed {mt5.last_error()}")

def ensure_symbol(sym): return mt5.symbol_select(sym, True)

# ───────── Prophet cache ─────────────────────────────────────────
_PROP_LOCK = threading.Lock()
_PROP: Dict[str, object] = {}      # None=pending | (model,timestamp)=ready

def _compile_prophet(df: pd.DataFrame, sym: str):
    mdl = Prophet(daily_seasonality=False, weekly_seasonality=False)
    mdl.fit(df)
    with _PROP_LOCK: _PROP[sym] = (mdl, time.time())
    logging.info("Prophet compiled for %s", sym)

def prophet_delta(prices: List[float], times: List[int], sym: str) -> float:
    if len(prices) < 20: return 0.0
    with _PROP_LOCK: entry = _PROP.get(sym)
    if entry is None:
        _PROP[sym] = None
        threading.Thread(target=_compile_prophet,
                         args=(pd.DataFrame({"ds": pd.to_datetime(times,unit='s'),
                                             "y": prices}), sym),
                         daemon=True).start()
        return 0.0
    if entry is None: return 0.0
    mdl, ts = entry
    if time.time() - ts > 3600:
        _PROP[sym] = None; return 0.0
    fut = mdl.make_future_dataframe(periods=1, freq='s')
    return float(mdl.predict(fut).iloc[-1]["yhat"] - prices[-1])

# ───────── tiny helpers ──────────────────────────────────────────
def z_spike(prices, win=20):
    if len(prices)<win: return False,0.0
    r=np.diff(prices[-win:]); z=(r[-1]-r.mean())/(r.std()+1e-6)
    return abs(z)>2.5, float(z)

def macd_div(prices):
    if len(prices)<35: return 0.0
    v=ta.trend.macd_diff(pd.Series(prices)).iloc[-1]
    return float(v) if pd.notna(v) else 0.0

def velocity(prices,n=3): return float(prices[-1]-prices[-n-1]) if len(prices)>=n+1 else 0.0

def combo_spike(prices):
    _,z=z_spike(prices); m=macd_div(prices); v=velocity(prices)
    s=abs(z)+abs(m)+abs(v)/(np.std(prices[-20:])+1e-6)
    return s>3.0, s

def kalman_slope(prices):
    if len(prices)<10: return 0.0
    s,_=KalmanFilter(initial_state_mean=0,n_dim_obs=1)\
           .filter(np.asarray(prices).reshape(-1,1))
    return float(s[-1,0]-s[-5,0])

def rsi_val(prices,l=14):
    if len(prices)<l+1: return 50.0
    v=ta.momentum.rsi(pd.Series(prices),l).iloc[-1]
    return float(v) if pd.notna(v) else 50.0

def offline_atr(h,l,c,per=ATR_PERIOD):
    if len(h)<per+1: return float('nan')
    v=ta.volatility.average_true_range(pd.Series(h),
                                       pd.Series(l),
                                       pd.Series(c),
                                       per).iloc[-1]
    return float(v) if pd.notna(v) else float('nan')

def offline_env(close,span=20,pc=0.3):
    if len(close)==0: return float('nan'),float('nan')
    ema=pd.Series(close).ewm(span=span).mean().iloc[-1]; band=ema*pc/100
    return float(ema-band), float(ema+band)

def atr_from_closes(closes, period=ATR_PERIOD):
    if len(closes)<period+1: return 0.0
    return float(np.abs(np.diff(closes[-period-1:])).mean())

FEATURES = ["spike_mag","macd","rsi","atr",
            "slope","env_low","env_up","delta"]

# ───────── CSV append helper ─────────────────────────────────────
def append_rows(rows: List[List]):
    if not rows: return
    pd.DataFrame(rows, columns=CSV_HEADER)\
      .to_csv(CSV_FILE, mode="a", index=False,
              header=not Path(CSV_FILE).exists())

# ───────── gen_row (train rows) ──────────────────────────────────
def gen_row(i, closes, times, sym, high=None, low=None):
    if i<LOOKAHEAD or i+LOOKAHEAD>=len(closes): return None
    seq=closes[:i]
    spike,mag=combo_spike(seq)
    if high is not None:
        atr=offline_atr(high[:i+1],low[:i+1],closes[:i+1])
        env_l,env_u=offline_env(seq)
    else: atr=env_l=env_u=0.0
    row=[times[i],sym,closes[i],mag,macd_div(seq),rsi_val(seq),
         atr,kalman_slope(seq),env_l,env_u,
         prophet_delta(seq,times[:i],sym)]
    ch=(closes[i+LOOKAHEAD]-closes[i])/closes[i]
    row.append("BUY" if ch>THRESH_LABEL else
               "SELL" if ch<-THRESH_LABEL else "WAIT")
    return row

# =================================================================
# 1) COLLECT LOOP (unchanged)
# =================================================================
def collect_loop():
    if not Path(CSV_FILE).exists(): append_rows([])
    last={}
    print("Collecting… CTRL-C to stop")
    while True:
        for sym in SYMBOLS:
            if not ensure_symbol(sym): continue
            bars=mt5.copy_rates_from_pos(sym,mt5.TIMEFRAME_M1,0,LOOKAHEAD+1)
            if bars is None or len(bars)<LOOKAHEAD+1: continue
            bars=bars[::-1]; ts=bars['time'][-1]
            if last.get(sym)==ts: continue
            last[sym]=ts
            closes=bars['close'].tolist(); times=bars['time'].tolist()
            row=gen_row(len(closes)-LOOKAHEAD-1,closes,times,sym)
            if row: append_rows([row])
        time.sleep(STEP_SECONDS)

# =================================================================
# 2) HISTORY IMPORT  (unchanged)
# =================================================================
def history_from_mt5(sym,start,end):
    if not ensure_symbol(sym): return
    with _mt5_lock:
        r=mt5.copy_rates_range(sym,mt5.TIMEFRAME_M1,
                               start.replace(tzinfo=UTC),
                               end.replace(tzinfo=UTC))
    if r is None or len(r)==0: return
    closes=r['close'].tolist(); times=r['time'].tolist()
    highs=r['high'].tolist();  lows=r['low'].tolist()
    rows=[]; tot=0
    for i in range(len(closes)-LOOKAHEAD):
        rw=gen_row(i,closes,times,sym,highs,lows)
        if rw: rows.append(rw); tot+=1
        if len(rows)>=5000: append_rows(rows); rows=[]
    append_rows(rows); print(sym,"imported",tot,"rows")

def history_from_file(sym,path):
    df=pd.read_csv(path)
    closes=df.close.tolist()
    times=(pd.to_datetime(df.time).astype(int)//10**9).tolist()
    highs=df.high.tolist() if 'high'in df else None
    lows =df.low.tolist()  if 'low' in df else None
    rows=[gen_row(i,closes,times,sym,highs,lows)
          for i in range(len(closes)-LOOKAHEAD)
          if gen_row(i,closes,times,sym,highs,lows)]
    append_rows(rows); print(sym,"imported",len(rows),"rows (file)")

def history_cli(a):
    if a.file:
        if not a.symbol: sys.exit("--file requires --symbol")
        history_from_file(a.symbol,a.file); return
    end=a.to or dt.datetime.utcnow()
    start=end-dt.timedelta(days=a.days) if a.days else a.from_
    for sym in SYMBOLS: history_from_mt5(sym,start,end)

# =================================================================
# 3) TRAIN MODELS (unchanged)
# =================================================================
def build_pipe(X,y):
    pipe=Pipeline([("sc",StandardScaler()),
                   ("gb",GradientBoostingClassifier(
                         n_estimators=400,learning_rate=0.05,
                         max_depth=3,random_state=42))])
    pipe.fit(X,y); return pipe

def train_models():
    if not Path(CSV_FILE).exists(): sys.exit("No training_set.csv")
    df=pd.read_csv(CSV_FILE)
    if "symbol" not in df.columns: sys.exit("CSV missing 'symbol' column")
    for col in FEATURES: df[col]=pd.to_numeric(df[col],errors="coerce")
    bad=df[FEATURES].isna().any(axis=1).sum()
    if bad: print(f"Discarding {bad} malformed rows"); df=df.dropna(subset=FEATURES)

    for sym in SYMBOLS:
        d=df[df.symbol==sym]
        if len(d)<400: print("Skip",sym,"(few rows)"); continue
        joblib.dump(build_pipe(d[FEATURES],
                               d.label.map({"WAIT":0,"BUY":1,"SELL":2})),
                    Path(MODEL_DIR)/f"{sym.replace(' ','_')}.pkl")
        print("model",sym,"saved")

    joblib.dump(build_pipe(df[FEATURES],
                           df.label.map({"WAIT":0,"BUY":1,"SELL":2})),
                GLOBAL_PKL)
    print("global model saved")

# =================================================================
# 4) SERVE  (upload_history / upload_spike_csv / analyze)
# =================================================================
app=Flask(__name__)
app.config["MAX_CONTENT_LENGTH"]=32*1024*1024
_cached:Dict[str,Tuple[float,object]]={}
_trades:Dict[str,Dict]={}

def load_model(sym):
    p=Path(MODEL_DIR)/f"{sym.replace(' ','_')}.pkl"
    if not p.exists(): p=Path(GLOBAL_PKL)
    mtime=p.stat().st_mtime
    mdl,ts=_cached.get(str(p),(None,0))
    if mdl is None or ts!=mtime:
        mdl=joblib.load(p); _cached[str(p)]=(mdl,mtime)
    return mdl

# ---- /upload_history --------------------------------------------
@app.route("/upload_history",methods=["POST"])
def upload_history():
    try:
        j=request.get_json(force=True)
        sym=j["symbol"]
        close=np.asarray(j["close"],dtype=float)
        ts   =np.asarray(j["time"],dtype=np.int64)
        high =np.asarray(j.get("high",close),dtype=float)
        low  =np.asarray(j.get("low" ,close),dtype=float)
    except Exception as e:
        abort(400,f"bad JSON {e}")

    if len(close)<LOOKAHEAD+2: return jsonify(status="ok",rows_written=0)

    cls_s=pd.Series(close); hi_s=pd.Series(high); lo_s=pd.Series(low)
    df=pd.DataFrame({"timestamp":ts,"price":close})
    r=cls_s.diff()
    df["spike_mag"]=((r.abs()>2.5*r.rolling(20).std()).astype(float)*
                     (r/(r.rolling(20).std()+1e-6)).abs()).fillna(0).values
    df["macd"]=ta.trend.macd_diff(cls_s).fillna(0).values
    df["rsi"]=ta.momentum.rsi(cls_s).fillna(50).values
    df["atr"]=ta.volatility.average_true_range(hi_s,lo_s,cls_s).fillna(0).values
    env=cls_s.ewm(span=20).mean()
    df["env_low"]=(env*0.997).values; df["env_up"]=(env*1.003).values
    kf=KalmanFilter(initial_state_mean=0,n_dim_obs=1)
    slope=kf.filter(close.reshape(-1,1))[0][:,0]
    df["slope"]=pd.Series(slope).diff(5).fillna(0).values
    df["delta"]=prophet_delta(close.tolist(),ts.tolist(),sym)
    chg=(cls_s.shift(-LOOKAHEAD)-cls_s)/cls_s
    df["label"]=np.where(chg>THRESH_LABEL,"BUY",
                 np.where(chg<-THRESH_LABEL,"SELL","WAIT"))
    out=df.iloc[:-LOOKAHEAD]
    append_rows(out.assign(symbol=sym).values.tolist())
    print(f"{sym:<25} {len(out):6d} rows")
    return jsonify(status="ok",rows_written=int(len(out)))

# ---- /upload_spike_csv (EA 16-column log) -----------------------
@app.route("/upload_spike_csv",methods=["POST"])
def upload_spike_csv():
    """
    Accepts EA output (16 columns) and maps to training_set format.
    Payload JSON:
      { "symbol": "...", "csv": "header\\nrow..." }  or
      { "symbol": "...", "rows":[ [...], [...]] }
    """
    try:
        j=request.get_json(force=True)
        sym=j["symbol"]
        if "csv" in j:
            df_ea=pd.read_csv(io.StringIO(j["csv"]))
        elif "rows" in j:
            df_ea=pd.DataFrame(j["rows"],columns=[
                "DateTime","Hour","Delta","VelThresh",
                "ATR_curr","ATR_prev","MA_curr","MA_prev",
                "Pivot","Spread","TickVol",
                "okATR","okTrend","okZone",
                "SpikeSize","Label"])
        else: abort(400,"need 'csv' or 'rows'")
    except Exception as e:
        abort(400,f"bad payload {e}")

    ts=pd.to_datetime(df_ea.DateTime).astype("int64")//10**9
    lab=df_ea.Label.map({0:"WAIT",1:"BUY"})
    out=pd.DataFrame({
        "timestamp":ts,
        "symbol"   :sym,
        "price"    :df_ea.Pivot,            # surrogate
        "spike_mag":df_ea.SpikeSize,
        "macd"     :0.0,
        "rsi"      :50.0,
        "atr"      :df_ea.ATR_curr,
        "slope"    :0.0,
        "env_low"  :0.0,
        "env_up"   :0.0,
        "delta"    :df_ea.Delta,
        "label"    :lab
    })
    append_rows(out.values.tolist())
    print(f"{sym:<25} {len(out):6d} EA-rows")
    return jsonify(status="ok",rows_written=int(len(out)))

# ---- /analyze ----------------------------------------------------
def decide_open(p_buy,p_sell,sym):
    if "Boom"  in sym: return "BUY"  if p_buy  > THR_BC_OPEN else "NONE"
    if "Crash" in sym: return "SELL" if p_sell > THR_BC_OPEN else "NONE"
    return "BUY" if p_buy>THR_O_OPEN else "SELL" if p_sell>THR_O_OPEN else "NONE"

def make_sl_tp(price,side,atr):
    return (price-atr*SL_MULT,price+atr*TP_MULT) if side=="BUY" else \
           (price+atr*SL_MULT,price-atr*TP_MULT)

@app.route("/analyze",methods=["POST"])
def api_analyze():
    j=request.get_json(force=True)
    sym=j["symbol"]
    prices=np.asarray(j["prices"],dtype=float)
    ts=np.asarray(j["timestamps"],dtype=np.int64)

    mdl=load_model(sym); cls=mdl.classes_
    idx=lambda l,p: p[list(cls).index(l)] if l in cls else 0.0
    feats=[combo_spike(prices)[1],macd_div(prices),rsi_val(prices),
           0,kalman_slope(prices),0,0,
           prophet_delta(prices.tolist(),ts.tolist(),sym)]
    proba=mdl.predict_proba(np.array([feats]))[0]
    p_buy,p_sell=idx(1,proba),idx(2,proba)
    price=prices[-1]; trade=_trades.get(sym); signal="WAIT"; side="NONE"

    if trade:                                # manage existing
        side=trade['side']
        if (side=="BUY" and price<=trade['sl']) or \
           (side=="SELL"and price>=trade['sl']):
            signal="CLOSE_SL"; _trades.pop(sym); side="NONE"
        elif (side=="BUY" and price>=trade['tp']) or \
             (side=="SELL"and price<=trade['tp']):
            signal="CLOSE_TP"; _trades.pop(sym); side="NONE"
        elif (side=="BUY" and p_buy<THR_O_CLOSE) or \
             (side=="SELL"and p_sell<THR_O_CLOSE):
            signal="CLOSE_EARLY"; _trades.pop(sym); side="NONE"

    if trade is None:                        # open new
        side=decide_open(p_buy,p_sell,sym)
        if side!="NONE":
            atr=atr_from_closes(prices)
            if atr==0: atr=price*ATR_FALLBACK_P
            sl,tp=make_sl_tp(price,side,atr)
            _trades[sym]=dict(side=side,entry=price,sl=sl,tp=tp,
                              adds=[],scale=atr*SCALE_IN_DIST,next=None)
            signal="OPEN"

    t=_trades.get(sym,{})
    return jsonify(signal=signal,side=side,
                   sl=t.get("sl"),tp=t.get("tp"),
                   strength=round(max(p_buy,p_sell),2),
                   Pbuy=round(p_buy,3),Psell=round(p_sell,3),
                   scale_in=t.get("next"))

def run_server(): init_mt5(); app.run("0.0.0.0",5000,threaded=True)

# =================================================================
# 5) BACKTEST  (uses same ATR logic)
# =================================================================
def backtest_one(sym,r):
    closes=list(r.close); times=list(r.time)
    highs=list(r.high);  lows=list(r.low)
    mdl=load_model(sym); cls=mdl.classes_
    idx=lambda l,p: p[list(cls).index(l)] if l in cls else 0.0
    trades=[]; trade=None
    for i in range(len(closes)):
        price=closes[i]
        feats=[combo_spike(closes[:i+1])[1],
               macd_div(closes[:i+1]),rsi_val(closes[:i+1]),
               offline_atr(highs[:i+1],lows[:i+1],closes[:i+1]),
               kalman_slope(closes[:i+1]),
               *offline_env(closes[:i+1]),
               prophet_delta(closes[:i+1],times[:i+1],sym)]
        pr=mdl.predict_proba(np.array([feats]))[0]
        pbuy,psell=idx(1,pr),idx(2,pr)

        if trade:
            side=trade['side']
            if (side=="BUY"and price<=trade['sl']) or \
               (side=="SELL"and price>=trade['sl']):
                trade['exit']=price; trade['why']="SL"
            elif (side=="BUY"and price>=trade['tp']) or \
                 (side=="SELL"and price<=trade['tp']):
                trade['exit']=price; trade['why']="TP"
            elif (side=="BUY"and pbuy<THR_O_CLOSE) or \
                 (side=="SELL"and psell<THR_O_CLOSE):
                trade['exit']=price; trade['why']="EARLY"
            if 'exit' in trade:
                pnl=(trade['exit']-trade['entry'])*(1 if side=="BUY" else -1)
                trades.append({**trade,"symbol":sym,"pnl":pnl}); trade=None

        if trade is None:
            side=decide_open(pbuy,psell,sym)
            if side!="NONE":
                atr=offline_atr(highs[:i+1],lows[:i+1],closes[:i+1])
                if np.isnan(atr) or atr==0:
                    atr=atr_from_closes(closes[:i+1])
                    if atr==0: atr=price*ATR_FALLBACK_P
                sl,tp=make_sl_tp(price,side,atr)
                trade=dict(side=side,entry=price,sl=sl,tp=tp,open_t=times[i])
    return trades

def backtest_cli(a):
    end=a.to or dt.datetime.utcnow()
    start=end-dt.timedelta(days=a.days) if a.days else a.from_
    alltr=[]
    for sym in SYMBOLS:
        if not ensure_symbol(sym): continue
        with _mt5_lock:
            r=mt5.copy_rates_range(sym,mt5.TIMEFRAME_M1,
                                   start.replace(tzinfo=UTC),
                                   end.replace(tzinfo=UTC))
        if r is None or len(r)==0: continue
        alltr.extend(backtest_one(sym,pd.DataFrame(r)))
    if not alltr: print("No trades"); return
    df=pd.DataFrame(alltr); g=df.groupby("symbol")["pnl"]
    print("\nResults")
    for sym,pnl in g:
        print(f"{sym:<22} n={len(pnl):4d}  PL={pnl.sum():>10.2f}")
    if a.log: df.to_csv(a.log,index=False); print("log saved",a.log)

# =================================================================
# 6) INFO
# =================================================================
def info():
    if Path(CSV_FILE).exists():
        df=pd.read_csv(CSV_FILE)
        print("CSV rows",len(df))
        print(df.label.value_counts())
    for p in Path(MODEL_DIR).glob("*.pkl"):
        m=joblib.load(p)
        print(p.name,"features",m.named_steps['sc'].n_features_in_)

# =================================================================
# 7) CLI
# =================================================================
if __name__=="__main__":
    root=argparse.ArgumentParser()
    sub=root.add_subparsers(dest="mode",required=True)

    sub.add_parser("collect")
    sub.add_parser("train")
    sub.add_parser("serve")
    sub.add_parser("info")

    h=sub.add_parser("history")
    g=h.add_mutually_exclusive_group(required=True)
    g.add_argument("--days",type=int)
    g.add_argument("--from",dest="from_",type=lambda s:dt.datetime.fromisoformat(s))
    h.add_argument("--to",type=lambda s:dt.datetime.fromisoformat(s))
    h.add_argument("--file"); h.add_argument("--symbol")

    bt=sub.add_parser("backtest")
    g2=bt.add_mutually_exclusive_group(required=False)   # optional now
    g2.add_argument("--days",type=int)
    g2.add_argument("--from",dest="from_",type=lambda s:dt.datetime.fromisoformat(s))
    bt.add_argument("--to",type=lambda s:dt.datetime.fromisoformat(s))
    bt.add_argument("--log")

    args=root.parse_args()
    if args.mode=="backtest" and not (args.days or args.from_):
        args.days=30   # default look-back

    if   args.mode=="collect":  init_mt5(); collect_loop()
    elif args.mode=="history":  init_mt5(); history_cli(args)
    elif args.mode=="train":    train_models()
    elif args.mode=="serve":    run_server()
    elif args.mode=="backtest": init_mt5(); backtest_cli(args)
    elif args.mode=="info":     info()