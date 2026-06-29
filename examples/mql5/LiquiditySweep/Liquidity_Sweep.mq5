//+------------------------------------------------------------------+
//|                                    Liquidity Sweep with MA filter|
//|                                   Copyright 2025, MetaQuotes Ltd.|
//|                           https://www.mql5.com/en/users/lynnchris|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>

//--- Inputs
input bool   UseMAFilter       = false;    // Enable Moving Average Filter
input bool   ShowMA            = false;    // Show MA on chart
input int    MALength          = 20;       // MA period (must be >=1)
enum MA_Type {SMA=0, EMA, LWMA, VWMA, RMA, HMA};
input MA_Type MAType           = SMA;      // Moving Average type
input bool   PriceAboveMA      = true;     // Filter: price above MA?

enum Strictness {LessStrict=0, Strict};
input Strictness SignalStrict  = LessStrict; // Signal strictness
input bool   ColorChangeOnly   = false;    // Only on color-change candles

enum LabelType {None=0, Short, Full};
input LabelType LblType        = Full;     // Label type
input bool      PlotArrow      = true;     // Draw arrow on signal

//--- Chart drawing inputs
input int ArrowOffsetPoints    = 10;       // How many points above/below the candle for the arrow/text

//--- Colors
input color BullishColor       = clrLime;
input color BearishColor       = clrRed;

//--- Globals
datetime   lastBarTime = 0;
int        MAHandle    = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
// Validate MALength (cannot modify an input directly)
   if(MALength < 1)
     {
      Print("ERROR: MALength must be at least 1. Current value = ", MALength);
      return(INIT_FAILED);
     }

// Initialize timing
   lastBarTime = iTime(Symbol(), Period(), 0);

// Create MA handle if needed (only for built-in MAs: SMA, EMA, LWMA, RMA)
   if((MAType != VWMA && MAType != HMA) && (UseMAFilter || ShowMA))
     {
      ENUM_MA_METHOD method = (ENUM_MA_METHOD)MAType;
      MAHandle = iMA(Symbol(), Period(), MALength, 0, method, PRICE_CLOSE);
      if(MAHandle == INVALID_HANDLE)
        {
         Print("Failed to create MA handle (type=", EnumToString(MAType), ", length=", MALength, ")");
         return(INIT_FAILED);
        }
      if(ShowMA)
         ChartIndicatorAdd(0, 0, MAHandle);
     }

   Print("Liquidity Sweep EA initialized successfully.");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(MAHandle != INVALID_HANDLE)
      IndicatorRelease(MAHandle);
  }

//+------------------------------------------------------------------+
//| Tick handler                                                     |
//+------------------------------------------------------------------+
void OnTick()
  {
// Only run on a new closed candle (when iTime(...) changes)
   datetime current = iTime(Symbol(), Period(), 0);
   if(current != lastBarTime)
     {
      DetectLiquiditySweep(1);
      lastBarTime = current;
     }
  }

//+------------------------------------------------------------------+
//| Core detection logic                                             |
//+------------------------------------------------------------------+
void DetectLiquiditySweep(int shift)
  {
// Ensure enough history for any custom MA loops
   int requiredBars = shift + MALength;
   if(Bars(Symbol(), Period()) <= requiredBars)
     {
      // Not enough bars yet to calculate MA or do a proper comparison
      return;
     }

//--- Bar data (current vs previous)
   double o   = iOpen(Symbol(), Period(), shift);
   double c   = iClose(Symbol(), Period(), shift);
   double h   = iHigh(Symbol(), Period(), shift);
   double l   = iLow(Symbol(), Period(), shift);

   double o1  = iOpen(Symbol(), Period(), shift + 1);
   double c1  = iClose(Symbol(), Period(), shift + 1);
   double h1  = iHigh(Symbol(), Period(), shift + 1);
   double l1  = iLow(Symbol(), Period(), shift + 1);

//--- Color-change filter
   bool bullCC = (c > o && c1 < o1);
   bool bearCC = (c < o && c1 > o1);

//--- Liquidity sweep logic (LessStrict vs Strict)
   bool bullSweep, bearSweep;
   if(SignalStrict == LessStrict)
     {
      bullSweep = (c > o && l < l1 && c > o1 && c1 != o1);
      bearSweep = (c < o && h > h1 && c < o1 && c1 != o1);
     }
   else // Strict
     {
      bullSweep = (c > o && l < l1 && c > h1 && c1 != o1);
      bearSweep = (c < o && h > h1 && c < l1 && c1 != o1);
     }

// Apply color-change only if requested
   if(ColorChangeOnly)
     {
      bullSweep &= bullCC;
      bearSweep &= bearCC;
     }

//--- Moving Average filter (if enabled)
   if(UseMAFilter)
     {
      double maValue = 0.0;

      if(MAType == VWMA)
         maValue = CalcVWMA(shift);
      else
         if(MAType == HMA)
            maValue = CalcHMA(shift);
         else
           {
            // Built-in MA handle case
            double buf[];
            if(CopyBuffer(MAHandle, 0, shift, 1, buf) != 1)
              {
               // If no MA data available, skip this bar entirely
               return;
              }
            maValue = buf[0];
           }

      // If price must be above MA → bullSweep only if (c > maValue); force bearSweep off
      // If price must be below MA → bearSweep only if (c < maValue); force bullSweep off
      bool cond = PriceAboveMA ? (c > maValue) : (c < maValue);
      bullSweep &= cond;
      bearSweep &= !cond;
     }

//--- Draw the signal and/or send Alert if a sweep is detected
   if(bullSweep)
     {
      DrawSignal(shift, true);
      PrintFormat("Bullish sweep detected at %s, price=%.5f",
                  TimeToString(iTime(Symbol(), Period(), shift)), c);
     }
   if(bearSweep)
     {
      DrawSignal(shift, false);
      PrintFormat("Bearish sweep detected at %s, price=%.5f",
                  TimeToString(iTime(Symbol(), Period(), shift)), c);
     }
   if(bullSweep || bearSweep)
     {
      Alert("Liquidity Sweep detected on ", Symbol(), " ", EnumToString(Period()));
     }
  }

//+------------------------------------------------------------------+
//| Draw arrow or text label on the chart                             |
//+------------------------------------------------------------------+
void DrawSignal(int shift, bool bullish)
  {
   datetime t     = iTime(Symbol(), Period(), shift);
   double   price = bullish
                    ? (iLow(Symbol(), Period(), shift)  - ArrowOffsetPoints * _Point)
                    : (iHigh(Symbol(), Period(), shift) + ArrowOffsetPoints * _Point);

// Use (long)t to get a 64-bit integer for the timestamp
   string name = StringFormat("LS_%I64u", (long)t);

// If an object with this name already exists, delete it first
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);

   if(PlotArrow)
     {
      ENUM_OBJECT objType = bullish ? OBJ_ARROW_UP : OBJ_ARROW_DOWN;
      ObjectCreate(0, name, objType, 0, t, price);
      ObjectSetInteger(0, name, OBJPROP_COLOR, bullish ? BullishColor : BearishColor);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
     }
   else
      if(LblType != None)
        {
         ObjectCreate(0, name, OBJ_TEXT, 0, t, price);
         string txt;
         if(LblType == Short)
            txt = bullish ? "BS" : "SS";
         else // Full
            txt = bullish ? "Bull Sweep" : "Bear Sweep";

         ObjectSetString(0, name, OBJPROP_TEXT, txt);
         ObjectSetInteger(0, name, OBJPROP_COLOR, bullish ? BullishColor : BearishColor);
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
        }
  }

//+------------------------------------------------------------------+
//| Compute Volume-Weighted MA (VWMA)                                |
//+------------------------------------------------------------------+
double CalcVWMA(int shift)
  {
   double numerator   = 0.0;
   double denominator = 0.0;

   for(int i = shift; i < shift + MALength; i++)
     {
      double price = iClose(Symbol(), Period(), i);
      long   vol   = iVolume(Symbol(), Period(), i);

      // Explicitly cast 'vol' to double when multiplying/adding
      numerator   += price * (double)vol;
      denominator += (double)vol;
     }
   return (denominator > 0.0) ? (numerator / denominator) : 0.0;
  }

//+------------------------------------------------------------------+
//| Compute Hull Moving Average (HMA)                                |
//+------------------------------------------------------------------+
double CalcHMA(int shift)
  {
   int half = MALength / 2;
   double w1   = 0.0, sw1 = 0.0;
   double w2   = 0.0, sw2 = 0.0;

// 1) Weighted MA over half period
   for(int i = shift; i < shift + half; i++)
     {
      double p = iClose(Symbol(), Period(), i);
      int    weight = half - (i - shift);
      w1   += p * weight;
      sw1 += weight;
     }
   w1 = (sw1 > 0.0) ? (w1 / sw1) : 0.0;

// 2) Weighted MA over full period
   for(int i = shift; i < shift + MALength; i++)
     {
      double p = iClose(Symbol(), Period(), i);
      int    weight = MALength - (i - shift);
      w2   += p * weight;
      sw2 += weight;
     }
   w2 = (sw2 > 0.0) ? (w2 / sw2) : 0.0;

// 3) Final HMA value = 2 * (MA over half) – (MA over full)
   return 2.0 * w1 - w2;
  }
//+------------------------------------------------------------------+
