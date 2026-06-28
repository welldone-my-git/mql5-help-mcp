//+------------------------------------------------------------------+
//|                                           NewsFilterDemo.mq5     |
//|                                Optimized with Live Dashboard     |
//+------------------------------------------------------------------+
#property strict
#property description "News Filter Demo — Smart Logs and Dashboard"

#include <Trade\Trade.mqh>
#include "NewsFilter.mqh"

//--- INPUTS
input group "=== News Filter Options ==="
input bool     InpNewsFilterEnabled  = true;  // Enable News Filter
input bool     InpReduceSizeOnNews   = true;  // Reduce Lot on News Days
input double   InpNewsDayLotFactor   = 0.5;   // Risk Reduction Factor

input group "=== MA Strategy ==="
input int      InpFastPeriod         = 20;    // EMA Fast Period
input int      InpSlowPeriod         = 50;    // EMA Slow Period
input double   InpBaseLotSize        = 0.1;   // Base Lot Size
input int      InpStopLossPips       = 30;    // Stop Loss (Pips)
input int      InpTakeProfitPips     = 60;    // Take Profit (Pips)

//--- GLOBALS
CTrade      g_Trade;
int         g_FastHandle     = INVALID_HANDLE;
int         g_SlowHandle     = INVALID_HANDLE;
datetime    g_LastBarTime    = 0;

//--- Summary Counters
int         g_TotalSignals   = 0;
int         g_PreEventBlocks = 0;
int         g_PostEventBlocks = 0;
int         g_TradesTotal    = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_FastHandle = iMA(_Symbol, PERIOD_CURRENT, InpFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_SlowHandle = iMA(_Symbol, PERIOD_CURRENT, InpSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);

   if(g_FastHandle == INVALID_HANDLE || g_SlowHandle == INVALID_HANDLE)
      return(INIT_FAILED);

   g_Trade.SetExpertMagicNumber(20240801);
   g_Trade.SetDeviationInPoints(20);

//--- Initialize news filter based on environment
   if(InpNewsFilterEnabled)
     {
      bool isTesting = (bool)MQLInfoInteger(MQL_TESTER);
      NewsFilterInit(isTesting);
     }

//--- Create Dashboard Label
   ObjectCreate(0, "NewsStatus", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "NewsStatus", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "NewsStatus", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, "NewsStatus", OBJPROP_YDISTANCE, 20);
   ObjectSetString(0, "NewsStatus", OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, "NewsStatus", OBJPROP_FONTSIZE, 12);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Print backtest summary for analysis
   if(MQLInfoInteger(MQL_TESTER))
     {
      Print("=== News Filter Backtest Summary ===");
      PrintFormat("Total Signals Detected: %d", g_TotalSignals);
      PrintFormat("Blocked by Pre-News Window: %d", g_PreEventBlocks);
      PrintFormat("Blocked by Post-News Window: %d", g_PostEventBlocks);
      PrintFormat("Trades Opened: %d", g_TradesTotal);
      Print("====================================");
     }

   ObjectDelete(0, "NewsStatus");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   string statusText  = "NEWS FILTER: ACTIVE";
   color  statusColor = clrLimeGreen;

//--- 1. Update Dashboard State
   if(InpNewsFilterEnabled)
     {
      if(IsNewsWindow())
        {
         statusText  = "NEWS BLOCK: PRE-EVENT BLOCK ACTIVE";
         statusColor = clrRed;
        }
      else
         if(IsPostNewsWindow())
           {
            statusText  = "NEWS BLOCK: POST-EVENT BLOCK ACTIVE";
            statusColor = clrOrangeRed;
           }
     }
   else
     {
      statusText  = "NEWS FILTER: DISABLED";
      statusColor = clrGray;
     }

   ObjectSetString(0, "NewsStatus", OBJPROP_TEXT, statusText);
   ObjectSetInteger(0, "NewsStatus", OBJPROP_COLOR, statusColor);

//--- 2. Strategy Logic
   if(Bars(_Symbol, PERIOD_CURRENT) < InpSlowPeriod)
      return;

   datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(barTime == g_LastBarTime)
      return;
   g_LastBarTime = barTime;

   double fast[2], slow[2];
   if(CopyBuffer(g_FastHandle, 0, 1, 2, fast) < 2)
      return;
   if(CopyBuffer(g_SlowHandle, 0, 1, 2, slow) < 2)
      return;

   bool bullCross = (fast[1] <= slow[1] && fast[0] > slow[0]);
   bool bearCross = (fast[1] >= slow[1] && fast[0] < slow[0]);

   if(!bullCross && !bearCross)
      return;
   if(PositionSelect(_Symbol))
      return;

   g_TotalSignals++;

//--- 3. Blocking Logic
   if(InpNewsFilterEnabled)
     {
      if(IsNewsWindow())
        {
         g_PreEventBlocks++;
         return;
        }
      if(IsPostNewsWindow())
        {
         g_PostEventBlocks++;
         return;
        }
     }

//--- 4. Risk Reduction Calculation
   double lotSize = InpBaseLotSize;
   if(InpNewsFilterEnabled && InpReduceSizeOnNews && IsHighImpactNewsToday())
     {
      lotSize = NormalizeDouble(InpBaseLotSize * InpNewsDayLotFactor, 2);
     }

//--- 5. Trade Execution
   double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double pipSize = (digits == 5 || digits == 3) ? point * 10.0 : point;

   if(bullCross)
     {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl  = ask - InpStopLossPips * pipSize;
      double tp  = ask + InpTakeProfitPips * pipSize;

      if(g_Trade.Buy(lotSize, _Symbol, ask, sl, tp))
         g_TradesTotal++;
     }
   else
      if(bearCross)
        {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double sl  = bid + InpStopLossPips * pipSize;
         double tp  = bid - InpTakeProfitPips * pipSize;

         if(g_Trade.Sell(lotSize, _Symbol, bid, sl, tp))
            g_TradesTotal++;
        }
  }
//+------------------------------------------------------------------+