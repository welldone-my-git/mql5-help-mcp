//+------------------------------------------------------------------+
//|                                                BarBuilderEA.mq5  |
//|                                              Patrick M. Njoroge  |
//|                 https://www.mql5.com/en/users/patricknjoroge743  |
//+------------------------------------------------------------------+
//|  Example EA that constructs alternative bars from the live tick  |
//|  stream and writes them to CSV for downstream feature pipelines  |
//|  or parity testing against the Python afml.data_structures.bars  |
//|  implementation.                                                 |
//|                                                                  |
//|  Usage:                                                          |
//|    1. Drop onto a chart, set InpBarType and InpBarSize.          |
//|    2. For imbalance bars, ensure the JSON config file exists     |
//|       in MQL5/Files/Common or supply InpExpTicksInit directly.   |
//|    3. Run in Strategy Tester for parity verification, or on a    |
//|       live chart for deployment.                                 |
//|                                                                  |
//|  NOTE: All dollar-based bar types now use the mid-price          |
//|        ((bid + ask)/2) as the valuation basis. This reduces      |
//|        noise from bid-ask bounce and gives a more representative |
//|        trade value.                                              |
//+------------------------------------------------------------------+
#property copyright "Patrick M. Njoroge"
#property link      "https://www.mql5.com/en/users/patricknjoroge743"
#property version   "1.00"
#property strict

#include <AlternativeBars\CBarConstructor.mqh>
#include <AlternativeBars\CStandardBars.mqh>
#include <AlternativeBars\CImbalanceBars.mqh>
#include <AlternativeBars\CRunsBar.mqh>

//--- Bar type selector
enum ENUM_BAR_TYPE
  {
   BAR_TIME         = 0,
   BAR_TICK         = 1,
   BAR_VOLUME       = 2,
   BAR_DOLLAR       = 3,
   BAR_TICK_IMB     = 4,
   BAR_VOLUME_IMB   = 5,
   BAR_DOLLAR_IMB   = 6,
   BAR_TICK_RUNS     = 7,
   BAR_VOLUME_RUNS   = 8,
   BAR_DOLLAR_RUNS   = 9
  };

//--- Inputs
input ENUM_BAR_TYPE InpBarType         = BAR_DOLLAR;           // Bar type
input double        InpBarSize         = 10000000.0;           // Threshold (seconds for time; count for tick; volume/dollar units otherwise)
input double        InpExpTicksInit    = 300.0;                // Initial E_0[T] for imbalance/run bars
input double        InpExpImbInit      = 0.1;                  // Initial E_0[|imbalance|] for imbalance bars
input double        InpExpRunBuyInit   = 0.1;                  // Initial E_0[theta_buy/T] for run bars
input double        InpExpRunSellInit  = 0.1;                  // Initial E_0[theta_sell/T] for run bars
input int           InpEwmSpan         = 20;                   // EWM span for adaptation
input bool          InpUseStateFile    = true;                 // Persist EWM state across EA restarts
input string        InpStateFile       = "bar_state.bin";      // State file (MQL5/Files/Common)
input int           InpStateMaxAgeMin  = 1440;                 // Max staleness (minutes); older state is discarded

//--- Globals
CBarConstructor *g_bar          = NULL;
long             g_tick_num     = 0;
int              g_csv_handle   = INVALID_HANDLE;
datetime         g_state_saved  = 0;

//+------------------------------------------------------------------+
//| Factory — instantiate the bar constructor for the given type     |
//+------------------------------------------------------------------+
CBarConstructor *CreateBarConstructor(void)
  {
   switch(InpBarType)
     {
      case BAR_TIME:
         return new CTimeBar((int)InpBarSize);

      case BAR_TICK:
         return new CTickBar((int)InpBarSize);

      case BAR_VOLUME:
         return new CVolumeBar(InpBarSize);

      case BAR_DOLLAR:
         return new CDollarBar(InpBarSize);

      case BAR_TICK_IMB:
         return new CImbalanceBar(IMBALANCE_TICK,
                                  InpExpTicksInit,
                                  InpExpImbInit,
                                  InpEwmSpan);

      case BAR_VOLUME_IMB:
         return new CImbalanceBar(IMBALANCE_VOLUME,
                                  InpExpTicksInit,
                                  InpExpImbInit,
                                  InpEwmSpan);

      case BAR_DOLLAR_IMB:
         return new CImbalanceBar(IMBALANCE_DOLLAR,
                                  InpExpTicksInit,
                                  InpExpImbInit,
                                  InpEwmSpan);

      case BAR_TICK_RUNS:
         return new CRunsBar(IMBALANCE_TICK,
                            InpExpTicksInit,
                            InpExpRunBuyInit,
                            InpExpRunSellInit,
                            InpEwmSpan);

      case BAR_VOLUME_RUNS:
         return new CRunsBar(IMBALANCE_VOLUME,
                            InpExpTicksInit,
                            InpExpRunBuyInit,
                            InpExpRunSellInit,
                            InpEwmSpan);

      case BAR_DOLLAR_RUNS:
         return new CRunsBar(IMBALANCE_DOLLAR,
                            InpExpTicksInit,
                            InpExpRunBuyInit,
                            InpExpRunSellInit,
                            InpEwmSpan);
     }
   return NULL;
  }

//+------------------------------------------------------------------+
//| State file helpers                                               |
//+------------------------------------------------------------------+
bool RestoreState(void)
  {
   if(!InpUseStateFile)
      return false;
   if(!FileIsExist(InpStateFile, FILE_COMMON))
      return false;

   int fh = FileOpen(InpStateFile, FILE_READ | FILE_BIN | FILE_COMMON);
   if(fh == INVALID_HANDLE)
     {
      PrintFormat("RestoreState: FileOpen failed, err=%d", GetLastError());
      return false;
     }

//--- Check staleness
   datetime saved = (datetime)FileReadLong(fh);
   if((TimeCurrent() - saved) > (InpStateMaxAgeMin * 60))
     {
      FileClose(fh);
      PrintFormat("State file is stale (saved at %s); discarding.",
                  TimeToString(saved));
      return false;
     }

   g_tick_num = FileReadLong(fh);
   bool ok = g_bar.LoadState(fh);
   FileClose(fh);

   if(ok)
      PrintFormat("State restored: saved=%s, tick_num=%d, type=%s",
                  TimeToString(saved), g_tick_num, g_bar.BarType());
   return ok;
  }

//+------------------------------------------------------------------+
//| PersistState                                                     |
//+------------------------------------------------------------------+
bool PersistState(void)
  {
   if(!InpUseStateFile || g_bar == NULL)
      return false;

   int fh = FileOpen(InpStateFile, FILE_WRITE | FILE_BIN | FILE_COMMON);
   if(fh == INVALID_HANDLE)
     {
      PrintFormat("PersistState: FileOpen failed, err=%d", GetLastError());
      return false;
     }

   FileWriteLong(fh, (long)TimeCurrent());
   FileWriteLong(fh, g_tick_num);
   bool ok = g_bar.SaveState(fh);
   FileClose(fh);

   if(ok)
      PrintFormat("State saved at tick_num=%d", g_tick_num);
   return ok;
  }

//+------------------------------------------------------------------+
//| CSV output helpers                                               |
//+------------------------------------------------------------------+
bool OpenCsvOutput(void)
  {
   // Build a unique suffix from the parameters that distinguish runs
   string suffix;
   switch(InpBarType)
     {
      case BAR_TIME:
      case BAR_TICK:
      case BAR_VOLUME:
      case BAR_DOLLAR:
         suffix = StringFormat("%s_size%g",
                               g_bar.BarType(),
                               InpBarSize);
         break;

      default:   // all information bars (imbalance & run)
         suffix = StringFormat("%s_span%d_size%g",
                               g_bar.BarType(),
                               InpEwmSpan,
                               InpExpTicksInit);
         // For run bars, also append the buy/sell initial values
         if(InpBarType == BAR_TICK_RUNS ||
            InpBarType == BAR_VOLUME_RUNS ||
            InpBarType == BAR_DOLLAR_RUNS)
           {
            suffix += StringFormat("_buy%g_sell%g",
                                   InpExpRunBuyInit,
                                   InpExpRunSellInit);
           }
         break;
     }

   string fname = _Symbol + "_" + suffix + ".csv";

   bool existed = FileIsExist(fname);
   g_csv_handle = FileOpen(fname,
                           FILE_WRITE | FILE_READ | FILE_CSV | FILE_ANSI,
                           ',');
   if(g_csv_handle == INVALID_HANDLE)
     {
      PrintFormat("OpenCsvOutput: FileOpen('%s') failed, err=%d",
                  fname, GetLastError());
      return false;
     }

   FileSeek(g_csv_handle, 0, SEEK_END);
   if(!existed || FileTell(g_csv_handle) == 0)
     {
      FileWrite(g_csv_handle,
                "time", "open", "high", "low", "close",
                "mid_open", "mid_close",
                "tick_volume", "volume", "spread",
                "tick_num", "bar_type");
     }
   return true;
  }

//+------------------------------------------------------------------+
//| WriteBarToCsv                                                    |
//+------------------------------------------------------------------+
void WriteBarToCsv(const SBar &bar)
  {
   if(g_csv_handle == INVALID_HANDLE)
      return;
   FileWrite(g_csv_handle,
             TimeToString(bar.time, TIME_DATE | TIME_SECONDS),
             DoubleToString(bar.open,      _Digits),
             DoubleToString(bar.high,      _Digits),
             DoubleToString(bar.low,       _Digits),
             DoubleToString(bar.close,     _Digits),
             DoubleToString(bar.mid_open,  _Digits),
             DoubleToString(bar.mid_close, _Digits),
             IntegerToString(bar.tick_volume),
             DoubleToString(bar.volume,    2),
             DoubleToString(bar.spread,    5),
             IntegerToString(bar.tick_num),
             bar.bar_type);
   FileFlush(g_csv_handle);
  }

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_bar = CreateBarConstructor();
   if(g_bar == NULL)
     {
      Print("OnInit: unknown bar type");
      return INIT_FAILED;
     }

   RestoreState();

   if(!OpenCsvOutput())
     {
      delete g_bar;
      g_bar = NULL;
      return INIT_FAILED;
     }

   PrintFormat("BarBuilderEA: type=%s, bar_size=%g, state=%s, output=%s",
               g_bar.BarType(),
               InpBarSize,
               InpUseStateFile ? "persisted" : "ephemeral",
               _Symbol + "_" + g_bar.BarType() + ".csv");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;

   g_tick_num += 1;

   SBar bar;
   if(g_bar.ProcessTick(tick, g_tick_num, bar))
      WriteBarToCsv(bar);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_csv_handle != INVALID_HANDLE)
     {
      FileClose(g_csv_handle);
      g_csv_handle = INVALID_HANDLE;
     }

//--- Persist state unless the EA is being removed by the user
   if(reason == REASON_REMOVE)
     {
      if(InpUseStateFile && FileIsExist(InpStateFile, FILE_COMMON))
         FileDelete(InpStateFile, FILE_COMMON);
     }
   else
     {
      PersistState();
     }

   if(g_bar != NULL)
     {
      delete g_bar;
      g_bar = NULL;
     }
  }
//+------------------------------------------------------------------+