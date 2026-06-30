//+------------------------------------------------------------------+
//| CPCVBacktest.mq5                                                 |
//|                                                                  |
//| Expert advisor for CPCV backtesting via the Strategy Tester's    |
//| optimization mode.                                               |
//|                                                                  |
//| Each optimization pass simulates one combinatorial backtest path.|
//| The "parameter" being optimized is InpPathIndex (0 to phi-1).    |
//| No actual parameter optimization occurs; the tester's parallel   |
//| agent infrastructure is repurposed for concurrent path           |
//| simulation.                                                      |
//|                                                                  |
//| Setup:                                                           |
//|   1. Run export_pipeline_artifacts.py to populate                |
//|      Common\Files\ml_artifacts\                                  |
//|   2. Set InpPathIndex: from=0, to=phi-1, step=1                  |
//|      For N=6, k=2 this means to=4 (phi=5 paths).                 |
//|   3. Model: Every tick based on real ticks                       |
//|   4. Optimization: Complete (slow)                               |
//|   5. Date range: full events span from the Python pipeline       |
//|                                                                  |
//| Part of: MetaTrader 5 Machine Learning Blueprint (Part 17)       |
//+------------------------------------------------------------------+
#property copyright "Patrick M. Njoroge"
#property link      "https://www.mql5.com/en/users/patricknjoroge743"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <FeatureEngine.mqh>
#include <Calibrator.mqh>

//---- Artifact directory inside Common\Files\
#define ARTIFACTS_DIR  "ml_artifacts\\"

//---- Minimum position fraction below which we close (not open)
#define MIN_SIZE_THRESHOLD 0.05

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input int    InpPathIndex      = 0;             // CPCV path (0 to phi-1); iterated by optimizer
input double InpKellyFraction  = 0.5;           // Kelly fraction (0=off, 1=full Kelly)
input double InpPayoffRatio    = 1.5;           // Expected payoff ratio (win/loss)
input double InpSlAtr          = 1.5;           // Stop-loss in ATR multiples
input string InpModelFile      = "model.onnx";  // ONNX model filename

//---- Global handles and state
static long   g_onnx_handle    = INVALID_HANDLE;
static int    g_atr_sl_handle  = INVALID_HANDLE;

//---- Path mask (sorted array for binary search)
static datetime g_test_bars[];
static int      g_n_test_bars  = 0;

//---- New-bar guard
static datetime g_last_bar_time = 0;

//---- Per-path P&L recording
static datetime g_bar_times[];
static double   g_bar_pnl[];
static int      g_n_records    = 0;

//---- Trade object
static CTrade g_trade;

//+------------------------------------------------------------------+
//| NormalizeLot: clamp raw lot to broker step and limits.           |
//+------------------------------------------------------------------+
double NormalizeLot(string symbol, double raw_lot)
  {
   double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double mn   = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double mx   = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lot  = MathRound(raw_lot / step) * step;
   lot = MathMax(mn, MathMin(mx, lot));
   return(NormalizeDouble(lot, 2));
  }

//+------------------------------------------------------------------+
//| CheckMargin: return false if margin is insufficient.             |
//+------------------------------------------------------------------+
bool CheckMargin(string symbol, double lots, ENUM_ORDER_TYPE order_type)
  {
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
      return(false);
   double price  = (order_type == ORDER_TYPE_SELL) ? tick.bid : tick.ask;
   double margin = 0.0;
   double free   = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(!OrderCalcMargin(order_type, symbol, lots, price, margin))
     {
      PrintFormat("CheckMargin: OrderCalcMargin failed, error=%d", GetLastError());
      return(false);
     }
   if(margin > free)
     {
      PrintFormat("CheckMargin: insufficient margin (need %.2f, have %.2f)",
                  margin, free);
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| LoadPathMask: read path_N.csv into a sorted datetime array.      |
//|                                                                  |
//| The array is sorted so IsTestBar() can binary-search in O(log n).|
//| FILE_COMMON resolves the path relative to Common\Files\ so both  |
//| the MQL5 EA and the Python export script can reach it.           |
//+------------------------------------------------------------------+
bool LoadPathMask(int path_index)
  {
   string fname = StringFormat(ARTIFACTS_DIR + "path_%d.csv", path_index);
   int fh = FileOpen(fname, FILE_READ | FILE_CSV | FILE_COMMON, ",");
   if(fh == INVALID_HANDLE)
     {
      PrintFormat("LoadPathMask: cannot open %s, error=%d", fname, GetLastError());
      return(false);
     }

   FileReadString(fh);  // skip header ("timestamp")

   g_n_test_bars = 0;
   if(ArrayResize(g_test_bars, 0) < 0)
     {
      Print("LoadPathMask: ArrayResize init failed");
      FileClose(fh);
      return(false);
     }

   while(!FileIsEnding(fh))
     {
      string ts_str = FileReadString(fh);
      if(StringLen(ts_str) == 0)
         continue;
      datetime ts = StringToTime(ts_str);
      if(ArrayResize(g_test_bars, g_n_test_bars + 1) < 0)
        {
         Print("LoadPathMask: ArrayResize failed at row ", g_n_test_bars);
         FileClose(fh);
         return(false);
        }
      g_test_bars[g_n_test_bars] = ts;
      g_n_test_bars++;
     }
   FileClose(fh);

   ArraySort(g_test_bars);  // sort ascending for binary search
   PrintFormat("LoadPathMask: path %d — %d test bars loaded",
               path_index, g_n_test_bars);
   return(g_n_test_bars > 0);
  }

//+------------------------------------------------------------------+
//| IsTestBar: return true when bar_time is in the path mask.        |
//+------------------------------------------------------------------+
bool IsTestBar(datetime bar_time)
  {
   if(g_n_test_bars == 0)
      return(false);
   int lo = 0, hi = g_n_test_bars - 1;
   while(lo <= hi)
     {
      int mid = (lo + hi) / 2;
      if(g_test_bars[mid] == bar_time)
         return(true);
      else
         if(g_test_bars[mid] < bar_time)
            lo = mid + 1;
         else
            hi = mid - 1;
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| GetSignal: map calibrated probability to signed position [-1,1]. |
//|                                                                  |
//| Mirrors the GetSignal() logic from Part 10: the probability is   |
//| re-centered at 0.5 and the excess is mapped to direction and     |
//| strength.                                                        |
//+------------------------------------------------------------------+
double GetSignal(double cal_prob, int num_classes)
  {
   if(num_classes != 2)
      return(0.0);
   double m = cal_prob - 0.5;
   if(MathAbs(m) < 1e-9)
      return(0.0);
   return((m > 0) ? 1.0 : -1.0);
  }

//+------------------------------------------------------------------+
//| KellyMultiplier: payoff-adjusted fractional Kelly.               |
//|                                                                  |
//| Mirrors the Kelly sizing from Part 11.                           |
//| f* = (p * (b+1) - 1) / b  where b = payoff ratio                |
//+------------------------------------------------------------------+
double KellyMultiplier(double cal_prob, double payoff_ratio, double fraction)
  {
   double f_star = (cal_prob * (payoff_ratio + 1.0) - 1.0) / payoff_ratio;
   if(f_star <= 0)
      return(0.0);
   return(MathMin(f_star * fraction, 1.0));
  }

//+------------------------------------------------------------------+
//| ComputeSlPrice: compute stop-loss price from ATR multiple.       |
//+------------------------------------------------------------------+
double ComputeSlPrice(bool is_buy, double entry_price)
  {
   double atr_buf[1];
   if(CopyBuffer(g_atr_sl_handle, 0, 1, 1, atr_buf) < 0)
     {
      PrintFormat("ComputeSlPrice: CopyBuffer failed, error=%d", GetLastError());
      return(0.0);
     }
   double atr = atr_buf[0];
   double sl_pts = InpSlAtr * atr;
   int stops_min = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double min_sl = stops_min * _Point;
   sl_pts = MathMax(sl_pts, min_sl);
   return(is_buy ? entry_price - sl_pts : entry_price + sl_pts);
  }

//+------------------------------------------------------------------+
//| ClosePosition: close all open positions for this symbol.         |
//+------------------------------------------------------------------+
void ClosePosition()
  {
   if(!PositionSelect(_Symbol))
      return;
   double vol = PositionGetDouble(POSITION_VOLUME);
   long   type = PositionGetInteger(POSITION_TYPE);
   if(type == POSITION_TYPE_BUY)
      g_trade.Sell(vol, _Symbol, 0, 0, 0, "CPCV close long");
   else
      g_trade.Buy(vol, _Symbol, 0, 0, 0, "CPCV close short");
  }

//+------------------------------------------------------------------+
//| ExecuteOrder: open or reverse a fractional position.             |
//|                                                                  |
//| fractional_size is in [-1, 1]: positive = long, negative = short.|
//| Lot size is derived from equity and the Kelly fraction.          |
//+------------------------------------------------------------------+
void ExecuteOrder(double fractional_size, datetime bar_time)
  {
   double abs_size = MathAbs(fractional_size);
   bool   is_long  = (fractional_size > 0);

//--- Below threshold: close any open position
   if(abs_size < MIN_SIZE_THRESHOLD)
     {
      ClosePosition();
      return;
     }

//--- Compute raw lot size from fractional position
   double equity    = AccountInfoDouble(ACCOUNT_EQUITY);
   double tick_val  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double atr_buf[1];
   if(CopyBuffer(g_atr_sl_handle, 0, 1, 1, atr_buf) < 0)
      return;
   double sl_pts = InpSlAtr * atr_buf[0];
   if(sl_pts < _Point)
      return;

   double raw_lots = (equity * abs_size) / (sl_pts * tick_val / tick_size);
   double lots     = NormalizeLot(_Symbol, raw_lots);

   ENUM_ORDER_TYPE order_type = is_long ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!CheckMargin(_Symbol, lots, order_type))
      return;

//--- Compute stop-loss price
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;
   double entry = is_long ? tick.ask : tick.bid;
   double sl    = ComputeSlPrice(is_long, entry);

//--- Reverse or open
   if(PositionSelect(_Symbol))
     {
      long pos_type = PositionGetInteger(POSITION_TYPE);
      bool pos_long = (pos_type == POSITION_TYPE_BUY);
      if(is_long != pos_long)
        {
         ClosePosition();
         if(is_long)
            g_trade.Buy(lots, _Symbol, 0, sl, 0, "CPCV reverse long");
         else
            g_trade.Sell(lots, _Symbol, 0, sl, 0, "CPCV reverse short");
        }
      //--- Same direction: no action (size rebalancing deferred to next signal)
     }
   else
     {
      if(is_long)
         g_trade.Buy(lots, _Symbol, 0, sl, 0, "CPCV open long");
      else
         g_trade.Sell(lots, _Symbol, 0, sl, 0, "CPCV open short");
     }

//--- Record bar for per-path CSV
   if(ArrayResize(g_bar_times, g_n_records + 1) >= 0 &&
      ArrayResize(g_bar_pnl,   g_n_records + 1) >= 0)
     {
      g_bar_times[g_n_records] = bar_time;
      g_bar_pnl[g_n_records]   = AccountInfoDouble(ACCOUNT_EQUITY);
      g_n_records++;
     }
  }

//+------------------------------------------------------------------+
//| WritePathCSV: write per-bar equity to a results CSV.             |
//|                                                                  |
//| Python's cpcv_postprocess.py reads these files from              |
//| Common\Files\ml_artifacts\results\path_N.csv                    |
//+------------------------------------------------------------------+
void WritePathCSV(int path_index)
  {
   string fname = StringFormat(ARTIFACTS_DIR + "results\\path_%d.csv", path_index);
   int fh = FileOpen(fname, FILE_WRITE | FILE_CSV | FILE_COMMON, ",");
   if(fh == INVALID_HANDLE)
     {
      PrintFormat("WritePathCSV: cannot open %s, error=%d", fname, GetLastError());
      return;
     }
   FileWrite(fh, "timestamp,equity");
   for(int i = 0; i < g_n_records; i++)
      FileWrite(fh, TimeToString(g_bar_times[i]) + "," +
                DoubleToString(g_bar_pnl[i], 2));
   FileClose(fh);
   PrintFormat("WritePathCSV: path %d — %d records written to %s",
               path_index, g_n_records, fname);
  }

//+------------------------------------------------------------------+
//| ComputePathSharpe: Sharpe ratio of bar-level equity returns.     |
//+------------------------------------------------------------------+
double ComputePathSharpe()
  {
   if(g_n_records < 2)
      return(0.0);
   double ret[];
   if(ArrayResize(ret, g_n_records - 1) < 0)
      return(0.0);
   for(int i = 0; i < g_n_records - 1; i++)
      ret[i] = (g_bar_pnl[i + 1] - g_bar_pnl[i]) / MathMax(g_bar_pnl[i], 1.0);
   double mean_r = 0.0;
   for(int i = 0; i < g_n_records - 1; i++)
      mean_r += ret[i];
   mean_r /= (g_n_records - 1);
   double var_r = 0.0;
   for(int i = 0; i < g_n_records - 1; i++)
      var_r += (ret[i] - mean_r) * (ret[i] - mean_r);
   double std_r = MathSqrt(var_r / (g_n_records - 2));
   if(std_r < 1e-9)
      return(0.0);
   return(mean_r / std_r * MathSqrt(252.0));
  }

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_trade.SetDeviationInPoints(10);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);

//--- ATR handle for stop-loss computation
   g_atr_sl_handle = iATR(_Symbol, _Period, 14);
   if(g_atr_sl_handle == INVALID_HANDLE)
     {
      Print("OnInit: iATR failed, error=", GetLastError());
      return(INIT_FAILED);
     }

//--- Load feature specification
   string spec_path = ARTIFACTS_DIR + "feature_spec.json";
   g_n_features = LoadFeatureSpec(spec_path);
   if(g_n_features <= 0)
     {
      Print("OnInit: LoadFeatureSpec failed");
      return(INIT_FAILED);
     }

//--- Create all indicator handles referenced by the feature spec
   if(!CreateIndicatorHandles())
     {
      Print("OnInit: CreateIndicatorHandles failed");
      return(INIT_FAILED);
     }

//--- Load path mask for this optimization pass
   if(!LoadPathMask(InpPathIndex))
     {
      PrintFormat("OnInit: LoadPathMask failed for path %d", InpPathIndex);
      return(INIT_FAILED);
     }

//--- Load calibrator
   if(!LoadCalibrator(ARTIFACTS_DIR))
     {
      Print("OnInit: LoadCalibrator failed");
      return(INIT_FAILED);
     }

//--- Load ONNX model
   string model_path = ARTIFACTS_DIR + InpModelFile;
   g_onnx_handle = OnnxCreate(model_path, ONNX_DEFAULT);
   if(g_onnx_handle == INVALID_HANDLE)
     {
      PrintFormat("OnInit: OnnxCreate failed, error=%d", GetLastError());
      return(INIT_FAILED);
     }

   long input_shape[]  = {1, g_n_features};
   long output_shape[] = {1, 2};
   if(!OnnxSetInputShape(g_onnx_handle, 0, input_shape))
     {
      PrintFormat("OnInit: OnnxSetInputShape failed, error=%d", GetLastError());
      return(INIT_FAILED);
     }
   OnnxSetOutputShape(g_onnx_handle, 0, output_shape);

   PrintFormat("OnInit: path=%d, features=%d, test_bars=%d",
               InpPathIndex, g_n_features, g_n_test_bars);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- New-bar guard: only act once per closed bar
   datetime current = iTime(_Symbol, _Period, 0);
   if(current == g_last_bar_time)
      return;
   g_last_bar_time = current;

//--- Use the most recently CLOSED bar (index 1)
   datetime bar_time = iTime(_Symbol, _Period, 1);

//--- Skip if this bar is not in the current path's test window
   if(!IsTestBar(bar_time))
      return;

//--- Build raw feature vector (scaler is baked into ONNX — no z-score here)
   float features[];
   if(!BuildFeatureVector(features))
      return;

//--- ONNX inference: 2D input tensor required by OnnxRun
   float input_data[1][FE_MAX_FEATURES];
   for(int i = 0; i < g_n_features; i++)
      input_data[0][i] = features[i];

   float output_data[1][2];
   if(!OnnxRun(g_onnx_handle, ONNX_DEFAULT, input_data, output_data))
     {
      PrintFormat("OnTick: OnnxRun failed, error=%d", GetLastError());
      return;
     }
   double raw_prob = (double)output_data[0][1];  // P(class=1)

//--- Apply calibration map
   double cal_prob = ApplyCalibrator(raw_prob);

//--- Compute signal and Kelly fraction
   double signal    = GetSignal(cal_prob, 2);
   double kelly_m   = KellyMultiplier(cal_prob, InpPayoffRatio, InpKellyFraction);
   double final_size = signal * kelly_m;

//--- Execute
   ExecuteOrder(final_size, bar_time);
  }

//+------------------------------------------------------------------+
//| OnTester: return path Sharpe as the optimization criterion.      |
//+------------------------------------------------------------------+
double OnTester()
  {
   return(ComputePathSharpe());
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ClosePosition();
   WritePathCSV(InpPathIndex);

   ReleaseIndicatorHandles();

   if(g_atr_sl_handle != INVALID_HANDLE)
     {
      IndicatorRelease(g_atr_sl_handle);
      g_atr_sl_handle = INVALID_HANDLE;
     }

   if(g_onnx_handle != INVALID_HANDLE)
     {
      OnnxRelease(g_onnx_handle);
      g_onnx_handle = INVALID_HANDLE;
     }
  }
//+------------------------------------------------------------------+
