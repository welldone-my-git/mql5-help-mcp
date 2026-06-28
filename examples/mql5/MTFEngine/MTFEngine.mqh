//+------------------------------------------------------------------+
//|                                                    MTFEngine.mqh |
//|          Multi-timeframe indicator engine for MQL5 EAs.          |
//+------------------------------------------------------------------+
#property strict

//--- Maximum indicator slots. Increase if more than 20 are needed.
#define MTF_MAX_HANDLES 20

//+------------------------------------------------------------------+
//| MTFHandle struct                                                 |
//| Stores metadata the engine needs for one handle.                 |
//+------------------------------------------------------------------+
struct MTFHandle
  {
   int               handle;       // Indicator handle returned by iXxx()
   ENUM_TIMEFRAMES   timeframe;    // Timeframe the indicator runs on
   string            label;        // Human-readable name for log messages
   string            symbol;       // Symbol the indicator is attached to
   datetime          last_htf_bar; // Open time of last HTF bar read at index 1
  };

//--- Internal state
MTFHandle g_mtf_handles[MTF_MAX_HANDLES];
int       g_mtf_count = 0;
datetime  g_last_bar  = 0;

//+------------------------------------------------------------------+
//| RegisterHandle                                                   |
//+------------------------------------------------------------------+
int RegisterHandle(int handle,ENUM_TIMEFRAMES tf,string label,string symbol)
  {
   if(g_mtf_count >= MTF_MAX_HANDLES)
     {
      PrintFormat("MTFEngine: Slot limit reached (%d).",MTF_MAX_HANDLES);
      return(-1);
     }
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("MTFEngine: Invalid handle for '%s'. Error: %d",label,GetLastError());
      return(-1);
     }

   g_mtf_handles[g_mtf_count].handle       = handle;
   g_mtf_handles[g_mtf_count].timeframe    = tf;
   g_mtf_handles[g_mtf_count].label        = label;
   g_mtf_handles[g_mtf_count].symbol       = symbol;
   g_mtf_handles[g_mtf_count].last_htf_bar = 0;

   PrintFormat("MTFEngine: Handle allocated for %s",label);
   return(g_mtf_count++);
  }

//+------------------------------------------------------------------+
//| IsReady                                                          |
//+------------------------------------------------------------------+
bool IsReady()
  {
   for(int i = 0; i < g_mtf_count; i++)
     {
      if(g_mtf_handles[i].handle == INVALID_HANDLE)
        {
         return(false);
        }

      //--- Check 1: buffer contains data
      double buf[1];
      if(CopyBuffer(g_mtf_handles[i].handle,0,1,1,buf) < 1)
        {
         return(false);
        }

      //--- Check 2: HTF bar at index 1 is synchronised
      datetime htf_bar = iTime(g_mtf_handles[i].symbol,g_mtf_handles[i].timeframe,1);
      if(htf_bar == 0)
        {
         return(false);
        }
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| IsNewBar                                                         |
//+------------------------------------------------------------------+
bool IsNewBar()
  {
   datetime current_bar = iTime(_Symbol,PERIOD_CURRENT,0);
   if(current_bar == g_last_bar)
     {
      return(false);
     }
   g_last_bar = current_bar;
   return(true);
  }

//+------------------------------------------------------------------+
//| ReadBuffer (scalar form)                                         |
//+------------------------------------------------------------------+
double ReadBuffer(int slot,int buffer_num=0,int bar_shift=1)
  {
   if(slot < 0 || slot >= g_mtf_count)
     {
      return(EMPTY_VALUE);
     }

   double buf[1];
   if(CopyBuffer(g_mtf_handles[slot].handle,buffer_num,bar_shift,1,buf) < 1)
     {
      PrintFormat("MTFEngine: CopyBuffer failed for '%s'. Error: %d",g_mtf_handles[slot].label,GetLastError());
      return(EMPTY_VALUE);
     }

   if(bar_shift == 1)
     {
      g_mtf_handles[slot].last_htf_bar = iTime(g_mtf_handles[slot].symbol,g_mtf_handles[slot].timeframe,1);
     }

   return(buf[0]);
  }

//+------------------------------------------------------------------+
//| ReadBuffer (array form)                                          |
//+------------------------------------------------------------------+
int ReadBuffer(int slot,double &result[],int buffer_num=0,int bar_shift=1,int count=2)
  {
   if(slot < 0 || slot >= g_mtf_count)
     {
      return(0);
     }

   ArrayResize(result,count);
   int copied = CopyBuffer(g_mtf_handles[slot].handle,buffer_num,bar_shift,count,result);
   if(copied < count)
     {
      PrintFormat("MTFEngine: ReadBuffer[%d] failed for '%s'. Error: %d",slot,g_mtf_handles[slot].label,GetLastError());
     }
   return(copied);
  }

//+------------------------------------------------------------------+
//| ReadPrevBuffer                                                   |
//+------------------------------------------------------------------+
double ReadPrevBuffer(int slot,int buffer_num=0)
  {
   return(ReadBuffer(slot,buffer_num,2));
  }

//+------------------------------------------------------------------+
//| GetHandleCount                                                   |
//+------------------------------------------------------------------+
int GetHandleCount()
  {
   return(g_mtf_count);
  }

//+------------------------------------------------------------------+
//| ReleaseAll                                                       |
//+------------------------------------------------------------------+
void ReleaseAll()
  {
   for(int i = 0; i < g_mtf_count; i++)
     {
      if(g_mtf_handles[i].handle != INVALID_HANDLE)
        {
         PrintFormat("MTFEngine: Releasing handle for %s",g_mtf_handles[i].label);
         IndicatorRelease(g_mtf_handles[i].handle);
         g_mtf_handles[i].handle = INVALID_HANDLE;
        }
     }
   g_mtf_count = 0;
   g_last_bar  = 0;
   Print("MTFEngine: All handles released.");
  }

//+------------------------------------------------------------------+
//| AddMA helper                                                     |
//+------------------------------------------------------------------+
int AddMA(string symbol,ENUM_TIMEFRAMES tf,int period,ENUM_MA_METHOD method=MODE_EMA,ENUM_APPLIED_PRICE price=PRICE_CLOSE,int shift=0)
  {
   string label = StringFormat("MA(%d,%s,%s)",period,EnumToString(method),EnumToString(tf));
   int h = iMA(symbol,tf,period,shift,method,price);
   return(RegisterHandle(h,tf,label,symbol));
  }

//+------------------------------------------------------------------+
//| AddRSI helper                                                    |
//+------------------------------------------------------------------+
int AddRSI(string symbol,ENUM_TIMEFRAMES tf,int period,ENUM_APPLIED_PRICE price=PRICE_CLOSE)
  {
   string label = StringFormat("RSI(%d,%s)",period,EnumToString(tf));
   int h = iRSI(symbol,tf,period,price);
   return(RegisterHandle(h,tf,label,symbol));
  }

//+------------------------------------------------------------------+
//| AddATR helper                                                    |
//+------------------------------------------------------------------+
int AddATR(string symbol,ENUM_TIMEFRAMES tf,int period)
  {
   string label = StringFormat("ATR(%d,%s)",period,EnumToString(tf));
   int h = iATR(symbol,tf,period);
   return(RegisterHandle(h,tf,label,symbol));
  }

//+------------------------------------------------------------------+
//| AddStochastic helper                                             |
//+------------------------------------------------------------------+
int AddStochastic(string symbol,ENUM_TIMEFRAMES tf,int k_period=5,int d_period=3,int slowing=3)
  {
   string label = StringFormat("Stoch(%d,%d,%d,%s)",k_period,d_period,slowing,EnumToString(tf));
   int h = iStochastic(symbol,tf,k_period,d_period,slowing,MODE_SMA,STO_LOWHIGH);
   return(RegisterHandle(h,tf,label,symbol));
  }

//+------------------------------------------------------------------+
//| AddMACD helper                                                   |
//+------------------------------------------------------------------+
int AddMACD(string symbol,ENUM_TIMEFRAMES tf,int fast_ema=12,int slow_ema=26,int signal_period=9)
  {
   string label = StringFormat("MACD(%d,%d,%d,%s)",fast_ema,slow_ema,signal_period,EnumToString(tf));
   int h = iMACD(symbol,tf,fast_ema,slow_ema,signal_period,PRICE_CLOSE);
   return(RegisterHandle(h,tf,label,symbol));
  }

//+------------------------------------------------------------------+
//| AddBands helper                                                  |
//+------------------------------------------------------------------+
int AddBands(string symbol,ENUM_TIMEFRAMES tf,int period=20,int band_shift=0,double deviation=2.0)
  {
   string label = StringFormat("BB(%d,%.1f,%s)",period,deviation,EnumToString(tf));
   int h = iBands(symbol,tf,period,band_shift,deviation,PRICE_CLOSE);
   return(RegisterHandle(h,tf,label,symbol));
  }

//+------------------------------------------------------------------+
//| AddCustom (no inputs)                                            |
//+------------------------------------------------------------------+
int AddCustom(string symbol,ENUM_TIMEFRAMES tf,string path,string label)
  {
   int h = iCustom(symbol,tf,path);
   return(RegisterHandle(h,tf,label,symbol));
  }

//+------------------------------------------------------------------+
//| AddCustom (with input parameters)                                |
//+------------------------------------------------------------------+
int AddCustom(string symbol,ENUM_TIMEFRAMES tf,string path,string label,string p1,string p2="",string p3="",string p4="")
  {
   int h;
   if(p4 != "")
      h = iCustom(symbol,tf,path,p1,p2,p3,p4);
   else
      if(p3 != "")
         h = iCustom(symbol,tf,path,p1,p2,p3);
      else
         if(p2 != "")
            h = iCustom(symbol,tf,path,p1,p2);
         else
            h = iCustom(symbol,tf,path,p1);

   return(RegisterHandle(h,tf,label,symbol));
  }
//+------------------------------------------------------------------+