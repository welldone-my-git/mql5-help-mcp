//+------------------------------------------------------------------+
//|                                                  MTFDemo.mq5     |
//|          Three-layer MTF EA using MTFEngine.mqh library.         |
//|    Layers: D1 EMA(200) trend, H4 RSI(14) momentum, H1 cross.     |
//+------------------------------------------------------------------+
#property strict
#property description "MTF Demo: D1 trend + H4 RSI + H1 cross entry"

#include <Trade\Trade.mqh>
#include "MTFEngine.mqh"

//--- Strategy inputs
input int      InpD1EmaPeriod    = 200;  // D1 EMA period (trend filter)
input int      InpH4RsiPeriod    = 14;   // H4 RSI period (momentum filter)
input double   InpRsiBullLevel   = 55.0; // RSI minimum for bullish confirmation
input double   InpRsiBearLevel   = 45.0; // RSI maximum for bearish confirmation
input int      InpH1FastPeriod   = 20;   // H1 fast EMA (entry signal)
input int      InpH1SlowPeriod   = 50;   // H1 slow EMA (entry signal)
input double   InpLotSize        = 0.1;  // Position size
input int      InpStopLossPips   = 30;   // Stop loss in pips
input int      InpTakeProfitPips = 60;   // Take profit in pips

//--- Engine slot indices returned by AddXxx(), used by ReadBuffer()
int g_slot_d1_ema   = -1; // D1 EMA(200) — trend layer
int g_slot_h4_rsi   = -1; // H4 RSI(14)  — momentum layer
int g_slot_h1_fast  = -1; // H1 EMA(20)  — fast line for crossover
int g_slot_h1_slow  = -1; // H1 EMA(50)  — slow line for crossover

CTrade g_trade;

//--- Diagnostic flags
bool g_diagnostic_printed = false;
int  g_bar_count          = 0; // Bar counter used for leak verification

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Register all indicators with the engine.
   g_slot_d1_ema  = AddMA(_Symbol,PERIOD_D1,InpD1EmaPeriod);
   g_slot_h4_rsi  = AddRSI(_Symbol,PERIOD_H4,InpH4RsiPeriod);
   g_slot_h1_fast = AddMA(_Symbol,PERIOD_H1,InpH1FastPeriod);
   g_slot_h1_slow = AddMA(_Symbol,PERIOD_H1,InpH1SlowPeriod);

//--- Abort if any handle failed to register
   if(g_slot_d1_ema < 0 || g_slot_h4_rsi < 0 || g_slot_h1_fast < 0 || g_slot_h1_slow < 0)
     {
      Print("MTFDemo: Initialization failed. One or more handles are invalid.");
      return(INIT_FAILED);
     }

   g_diagnostic_printed = false;
   g_bar_count          = 0;

//--- Start a one-second timer
   EventSetTimer(1);

   PrintFormat("MTFDemo: Initialized on %s %s. Handles registered: %d.",
               _Symbol,EnumToString(_Period),GetHandleCount());
   Print("MTFDemo: Waiting for first bar and indicator warmup.");

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
//--- One call releases every handle the engine created
   ReleaseAll();
  }

//+------------------------------------------------------------------+
//| PrintDiagnostic                                                  |
//+------------------------------------------------------------------+
void PrintDiagnostic()
  {
   if(g_diagnostic_printed)
     {
      return;
     }

   double d1_ema  = ReadBuffer(g_slot_d1_ema);
   double h4_rsi  = ReadBuffer(g_slot_h4_rsi);
   double h1_fast = ReadBuffer(g_slot_h1_fast);
   double h1_slow = ReadBuffer(g_slot_h1_slow);

   if(d1_ema == EMPTY_VALUE || h4_rsi == EMPTY_VALUE || h1_fast == EMPTY_VALUE || h1_slow == EMPTY_VALUE)
     {
      Print("MTFDemo: Diagnostic skipped — one or more buffers not yet ready.");
      return;
     }

   Print("══════════════════════════════════════════════════════");
   Print("MTFDemo DIAGNOSTIC — Bar Index 1 (last closed bar)");
   PrintFormat("D1 EMA(%d)  = %.5f  <- verify on a separate D1 chart",InpD1EmaPeriod,d1_ema);
   PrintFormat("H4 RSI(%d)   = %.2f   <- verify on a separate H4 chart",InpH4RsiPeriod,h4_rsi);
   PrintFormat("H1 EMA(%d)  = %.5f  <- verify on a separate H1 chart",InpH1FastPeriod,h1_fast);
   PrintFormat("H1 EMA(%d)  = %.5f  <- verify on a separate H1 chart",InpH1SlowPeriod,h1_slow);
   PrintFormat("Engine handle count: %d (must stay fixed at this value)",GetHandleCount());
   Print("══════════════════════════════════════════════════════");

   g_diagnostic_printed = true;
   EventKillTimer();
  }

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(g_diagnostic_printed)
     {
      return;
     }
   if(!IsReady())
     {
      return;
     }
   PrintDiagnostic();
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- Gate 1: Only process once per new H1 bar.
   if(!IsNewBar())
     {
      return;
     }

//--- Gate 2: Wait until all indicators have enough bars loaded.
   if(!IsReady())
     {
      return;
     }

//--- Diagnostic: print once after first valid bar
   if(!g_diagnostic_printed)
     {
      PrintDiagnostic();
     }

//--- Leak verification
   g_bar_count++;
   if(g_bar_count % 100 == 0)
     {
      PrintFormat("MTFDemo: Bar %d | Engine handles: %d | Expected: 4",g_bar_count,GetHandleCount());
     }

//--- Only manage one position for this demo
   if(PositionsTotal() > 0)
     {
      return;
     }

//--- Read values from closed bars
   double d1_ema = ReadBuffer(g_slot_d1_ema);
   double h4_rsi = ReadBuffer(g_slot_h4_rsi);

   double fast_vals[];
   double slow_vals[];

   int fast_copied = ReadBuffer(g_slot_h1_fast,fast_vals,0,1,2);
   int slow_copied = ReadBuffer(g_slot_h1_slow,slow_vals,0,1,2);

//--- Validate all reads
   if(d1_ema == EMPTY_VALUE || h4_rsi == EMPTY_VALUE || fast_copied < 2 || slow_copied < 2)
     {
      return;
     }

   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);

//--- Layer 1: D1 TREND FILTER
   bool bullish_trend = (bid > d1_ema);
   bool bearish_trend = (bid < d1_ema);

//--- Layer 2: H4 RSI MOMENTUM FILTER
   bool bullish_mom = (h4_rsi >= InpRsiBullLevel);
   bool bearish_mom = (h4_rsi <= InpRsiBearLevel);

//--- Layer 3: H1 EMA CROSSOVER ENTRY SIGNAL
   bool bullish_cross = (fast_vals[1] <= slow_vals[1] && fast_vals[0] > slow_vals[0]);
   bool bearish_cross = (fast_vals[1] >= slow_vals[1] && fast_vals[0] < slow_vals[0]);

//--- ENTRY LOGIC
   double point    = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   int    digits   = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double pip_size = (digits == 5 || digits == 3) ? point * 10.0 : point;

   if(bullish_trend && bullish_mom && bullish_cross)
     {
      double sl = ask - InpStopLossPips * pip_size;
      double tp = ask + InpTakeProfitPips * pip_size;
      if(g_trade.Buy(InpLotSize,_Symbol,ask,sl,tp,"MTFDemo"))
        {
         PrintFormat("BUY | D1 EMA=%.5f | H4 RSI=%.1f | H1 cross up",d1_ema,h4_rsi);
        }
     }
   else
      if(bearish_trend && bearish_mom && bearish_cross)
        {
         double sl = bid + InpStopLossPips * pip_size;
         double tp = bid - InpTakeProfitPips * pip_size;
         if(g_trade.Sell(InpLotSize,_Symbol,bid,sl,tp,"MTFDemo"))
           {
            PrintFormat("SELL | D1 EMA=%.5f | H4 RSI=%.1f | H1 cross down",d1_ema,h4_rsi);
           }
        }
  }
//+------------------------------------------------------------------+