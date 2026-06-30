//+------------------------------------------------------------------+
//| FeatureEngine.mqh                                                |
//| Patrick M. Njoroge / Blueprint Quant                             |
//| https://www.mql5.com/en/users/patrickmnjoroge                    |
//|                                                                  |
//| Loads feature_spec.json, creates indicator handles, and builds   |
//| the raw feature vector that is passed directly to OnnxRun().     |
//|                                                                  |
//| IMPORTANT: The sklearn pipeline (StandardScaler + classifier)    |
//| was exported as a single ONNX graph via skl2onnx.  The scaler    |
//| is therefore baked into the ONNX model.  This function returns   |
//| RAW (unscaled) feature values.  Do NOT apply z-score             |
//| normalization here; doing so would double-scale the inputs and   |
//| corrupt inference results.                                       |
//|                                                                  |
//| The feature_spec.json still exports mean and std for diagnostic  |
//| validation — to confirm MQL5 raw values match Python outputs —   |
//| but they are not used for transformation.                        |
//|                                                                  |
//| Part of: MetaTrader 5 Machine Learning Blueprint (Part 17)       |
//+------------------------------------------------------------------+
#property strict

#ifndef FEATURE_ENGINE_MQH
#define FEATURE_ENGINE_MQH

//---- Maximum features this module can handle
#define FE_MAX_FEATURES 64

//+------------------------------------------------------------------+
//| ENUM_FEAT_TYPE: feature computation type.                        |
//|                                                                  |
//| Extend this enum and add a matching case in BuildFeatureVector() |
//| to support additional indicator types.                           |
//+------------------------------------------------------------------+
enum ENUM_FEAT_TYPE
  {
   FEAT_RSI,           // RSI(period)
   FEAT_ATR_NORM,      // ATR(period) / Close — normalised volatility
   FEAT_LOG_RETURN,    // log(Close[1] / Close[1+period])
   FEAT_MA_RATIO,      // Close / SMA(period) - 1.0
   FEAT_HIST_VOL,      // std-dev of log-returns over last (period) bars
  };

//+------------------------------------------------------------------+
//| SFeatureSpec: holds everything needed to compute one feature.    |
//|                                                                  |
//| mean and std are stored for diagnostic validation only — not     |
//| applied to the feature value before ONNX inference.              |
//+------------------------------------------------------------------+
struct SFeatureSpec
  {
   string            name;        // column name from Python pipeline
   int               index;       // position in the ONNX input tensor
   ENUM_FEAT_TYPE    type;        // computation type (see ENUM_FEAT_TYPE)
   int               lookback;    // indicator period / window length
   double            mean;        // training-set mean (diagnostic only)
   double            std_dev;     // training-set std  (diagnostic only)
  };

//---- Module-level state
static SFeatureSpec g_feat_specs[FE_MAX_FEATURES];
static int          g_n_features = 0;
static int          g_rsi_handle[FE_MAX_FEATURES];
static int          g_atr_handle[FE_MAX_FEATURES];
static int          g_ma_handle[FE_MAX_FEATURES];
static bool         g_handles_valid = false;

//+------------------------------------------------------------------+
//| _ParseFeatType: map the "type" string from JSON to the enum.     |
//+------------------------------------------------------------------+
ENUM_FEAT_TYPE _ParseFeatType(const string type_str)
  {
   if(type_str == "RSI")
      return(FEAT_RSI);
   if(type_str == "ATR_NORM")
      return(FEAT_ATR_NORM);
   if(type_str == "RETURN")
      return(FEAT_LOG_RETURN);
   if(type_str == "MA_RATIO")
      return(FEAT_MA_RATIO);
   if(type_str == "HIST_VOL")
      return(FEAT_HIST_VOL);
   PrintFormat("_ParseFeatType: unknown type '%s', defaulting to FEAT_RSI", type_str);
   return(FEAT_RSI);
  }

//+------------------------------------------------------------------+
//| _ExtractJsonString: extract the first string value for a key.    |
//+------------------------------------------------------------------+
string _ExtractJsonString(const string json, const string key)
  {
   string search = "\"" + key + "\":\"";
   int    pos    = StringFind(json, search);
   if(pos < 0)
      return("");
   int start = pos + StringLen(search);
   int end   = StringFind(json, "\"", start);
   if(end < 0)
      return("");
   return(StringSubstr(json, start, end - start));
  }

//+------------------------------------------------------------------+
//| _ExtractJsonNumber: extract the first numeric value for a key.   |
//+------------------------------------------------------------------+
double _ExtractJsonNumber(const string json, const string key)
  {
   string search = "\"" + key + "\":";
   int    pos    = StringFind(json, search);
   if(pos < 0)
      return(0.0);
   int start = pos + StringLen(search);
   return(StringToDouble(StringSubstr(json, start)));
  }

//+------------------------------------------------------------------+
//| LoadFeatureSpec: parse feature_spec.json and create handles.     |
//|                                                                  |
//| The JSON is an array of objects:                                 |
//|   [{"name":"..","index":N,"type":"..","lookback":N,              |
//|     "mean":N,"std":N}, ...]                                      |
//|                                                                  |
//| Returns the number of features loaded, or -1 on error.           |
//+------------------------------------------------------------------+
int LoadFeatureSpec(const string spec_path)
  {
   int fh = FileOpen(spec_path, FILE_READ | FILE_TXT | FILE_COMMON);
   if(fh == INVALID_HANDLE)
     {
      PrintFormat("LoadFeatureSpec: cannot open %s, error=%d",
                  spec_path, GetLastError());
      return(-1);
     }

   string json = "";
   while(!FileIsEnding(fh))
      json += FileReadString(fh);
   FileClose(fh);

//--- Walk through feature objects bounded by '{' ... '}'
   g_n_features = 0;
   int pos = 0;
   while(pos < StringLen(json) && g_n_features < FE_MAX_FEATURES)
     {
      int obj_start = StringFind(json, "{", pos);
      if(obj_start < 0)
         break;
      int obj_end = StringFind(json, "}", obj_start);
      if(obj_end < 0)
         break;

      string obj = StringSubstr(json, obj_start, obj_end - obj_start + 1);
      pos = obj_end + 1;

      int feat_idx  = (int)_ExtractJsonNumber(obj, "index");
      int lookback  = (int)_ExtractJsonNumber(obj, "lookback");
      double mean   = _ExtractJsonNumber(obj, "mean");
      double std_v  = _ExtractJsonNumber(obj, "std");
      string name   = _ExtractJsonString(obj, "name");
      string type_s = _ExtractJsonString(obj, "type");

      if(name == "" || type_s == "")
         continue;

      SFeatureSpec sp;
      sp.name     = name;
      sp.index    = feat_idx;
      sp.type     = _ParseFeatType(type_s);
      sp.lookback = (lookback > 0) ? lookback : 14;
      sp.mean     = mean;
      sp.std_dev  = (std_v > 0) ? std_v : 1.0;

      g_feat_specs[g_n_features] = sp;
      g_n_features++;
     }

   PrintFormat("LoadFeatureSpec: %d features loaded from %s",
               g_n_features, spec_path);
   return(g_n_features);
  }

//+------------------------------------------------------------------+
//| CreateIndicatorHandles: create and validate all handles.         |
//|                                                                  |
//| Call once from OnInit() after LoadFeatureSpec().                 |
//| Returns true if all handles are valid.                           |
//+------------------------------------------------------------------+
bool CreateIndicatorHandles()
  {
   ArrayInitialize(g_rsi_handle, INVALID_HANDLE);
   ArrayInitialize(g_atr_handle, INVALID_HANDLE);
   ArrayInitialize(g_ma_handle,  INVALID_HANDLE);

   for(int i = 0; i < g_n_features; i++)
     {
      ENUM_FEAT_TYPE t = g_feat_specs[i].type;
      int            lb = g_feat_specs[i].lookback;

      if(t == FEAT_RSI)
        {
         g_rsi_handle[i] = iRSI(_Symbol, _Period, lb, PRICE_CLOSE);
         if(g_rsi_handle[i] == INVALID_HANDLE)
           {
            PrintFormat("CreateIndicatorHandles: iRSI failed for feature %d", i);
            return(false);
           }
        }
      else
         if(t == FEAT_ATR_NORM)
           {
            g_atr_handle[i] = iATR(_Symbol, _Period, lb);
            if(g_atr_handle[i] == INVALID_HANDLE)
              {
               PrintFormat("CreateIndicatorHandles: iATR failed for feature %d", i);
               return(false);
              }
           }
         else
            if(t == FEAT_MA_RATIO)
              {
               g_ma_handle[i] = iMA(_Symbol, _Period, lb, 0, MODE_SMA, PRICE_CLOSE);
               if(g_ma_handle[i] == INVALID_HANDLE)
                 {
                  PrintFormat("CreateIndicatorHandles: iMA failed for feature %d", i);
                  return(false);
                 }
              }
      //--- FEAT_LOG_RETURN and FEAT_HIST_VOL use raw price copy, no handle needed
     }

   g_handles_valid = true;
   return(true);
  }

//+------------------------------------------------------------------+
//| ReleaseIndicatorHandles: release all handles.                    |
//|                                                                  |
//| Call from OnDeinit().                                            |
//+------------------------------------------------------------------+
void ReleaseIndicatorHandles()
  {
   for(int i = 0; i < g_n_features; i++)
     {
      if(g_rsi_handle[i] != INVALID_HANDLE)
        {
         IndicatorRelease(g_rsi_handle[i]);
         g_rsi_handle[i] = INVALID_HANDLE;
        }
      if(g_atr_handle[i] != INVALID_HANDLE)
        {
         IndicatorRelease(g_atr_handle[i]);
         g_atr_handle[i] = INVALID_HANDLE;
        }
      if(g_ma_handle[i] != INVALID_HANDLE)
        {
         IndicatorRelease(g_ma_handle[i]);
         g_ma_handle[i] = INVALID_HANDLE;
        }
     }
   g_handles_valid = false;
  }

//+------------------------------------------------------------------+
//| BuildFeatureVector: compute raw features for the closed bar.     |
//|                                                                  |
//| Fills the features[] array with one raw (unscaled) value per     |
//| feature.  The sklearn StandardScaler is baked into the ONNX      |
//| graph; these raw values are passed directly to OnnxRun().        |
//|                                                                  |
//| Bar index convention: bar 1 = the most recently CLOSED bar.      |
//| Bar index 0 = the still-forming bar.  All calculations use       |
//| bar 1 to prevent look-ahead bias at the tick level.              |
//|                                                                  |
//| Returns false if any indicator read fails.                       |
//+------------------------------------------------------------------+
bool BuildFeatureVector(float &features[])
  {
   if(!g_handles_valid || g_n_features == 0)
     {
      Print("BuildFeatureVector: handles not initialised");
      return(false);
     }

   if(ArrayResize(features, g_n_features) < 0)
     {
      Print("BuildFeatureVector: ArrayResize failed");
      return(false);
     }

   double buf[1];

   for(int i = 0; i < g_n_features; i++)
     {
      ENUM_FEAT_TYPE t  = g_feat_specs[i].type;
      int            lb = g_feat_specs[i].lookback;
      double         raw = 0.0;

      switch(t)
        {
         case FEAT_RSI:
           {
            if(CopyBuffer(g_rsi_handle[i], 0, 1, 1, buf) < 0)
              {
               PrintFormat("BuildFeatureVector: CopyBuffer RSI[%d] failed, err=%d",
                           i, GetLastError());
               return(false);
              }
            raw = buf[0];
            break;
           }

         case FEAT_ATR_NORM:
           {
            if(CopyBuffer(g_atr_handle[i], 0, 1, 1, buf) < 0)
              {
               PrintFormat("BuildFeatureVector: CopyBuffer ATR[%d] failed, err=%d",
                           i, GetLastError());
               return(false);
              }
            double close1 = iClose(_Symbol, _Period, 1);
            raw = (close1 > 0) ? buf[0] / close1 : 0.0;
            break;
           }

         case FEAT_LOG_RETURN:
           {
            double c1 = iClose(_Symbol, _Period, 1);
            double c0 = iClose(_Symbol, _Period, lb + 1);
            raw = (c1 > 0 && c0 > 0) ? MathLog(c1 / c0) : 0.0;
            break;
           }

         case FEAT_MA_RATIO:
           {
            if(CopyBuffer(g_ma_handle[i], 0, 1, 1, buf) < 0)
              {
               PrintFormat("BuildFeatureVector: CopyBuffer MA[%d] failed, err=%d",
                           i, GetLastError());
               return(false);
              }
            double close1 = iClose(_Symbol, _Period, 1);
            raw = (buf[0] > 0) ? (close1 / buf[0]) - 1.0 : 0.0;
            break;
           }

         case FEAT_HIST_VOL:
           {
            double closes[];
            if(CopyClose(_Symbol, _Period, 1, lb + 1, closes) < 0)
              {
               PrintFormat("BuildFeatureVector: CopyClose[%d] failed, err=%d",
                           i, GetLastError());
               return(false);
              }
            double log_ret[];
            if(ArrayResize(log_ret, lb) < 0)
               return(false);
            for(int j = 0; j < lb; j++)
               log_ret[j] = MathLog(closes[j] / closes[j + 1]);
            double mean_r = 0.0;
            for(int j = 0; j < lb; j++)
               mean_r += log_ret[j];
            mean_r /= lb;
            double var_r = 0.0;
            for(int j = 0; j < lb; j++)
               var_r += (log_ret[j] - mean_r) * (log_ret[j] - mean_r);
            raw = MathSqrt(var_r / (lb - 1));
            break;
           }

         default:
            raw = 0.0;
            break;
        }

      features[i] = (float)raw;  // cast to float; ONNX input is float32
     }

   return(true);
  }

#endif // FEATURE_ENGINE_MQH
