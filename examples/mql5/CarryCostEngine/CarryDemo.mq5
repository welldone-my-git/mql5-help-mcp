//+------------------------------------------------------------------+
//|                                                    CarryDemo.mq5 |
//+------------------------------------------------------------------+
#property strict

//--- Include the SwapTools library
#include <Trade\Trade.mqh>
#include "SwapTools.mqh"

//--- INPUT PARAMETERS
input group "Strategy Settings"
input bool   InpCarryAware     = true;   // Enable Carry-Aware Logic
input int    InpMA_Period      = 20;     // Trend Filter Period
input int    InpHoldDaysLimit  = 10;     // Maximum days to hold
input double InpCoveragePct    = 40.0;   // Swap coverage threshold (%)

input group "Money Management"
input double InpBaseLots       = 0.1;    // Baseline Lot Size
input double InpRiskMoney      = 100.0;  // Money at risk for carry scaling
input double InpTargetCarryPct = 5.0;    // Target carry as % of risk

//--- GLOBAL VARIABLES
CTrade   trade;
int      handle_ma;
datetime last_bar_time;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Warn if symbol is not AUDJPY.
//--- The EA was built and tested around AUDJPY carry dynamics.
//--- Swap direction and pip values differ on other instruments.
   if(_Symbol != "AUDJPY")
      Print("Warning: This EA is optimized for AUDJPY carry trade logic. "
            "Swap mode behaviour and carry direction may differ on other instruments.");

   handle_ma = iMA(_Symbol, _Period, InpMA_Period, 0, MODE_SMA, PRICE_CLOSE);
   if(handle_ma == INVALID_HANDLE)
     {
      Print("OnInit: failed to create MA handle — check symbol and period.");
      return(INIT_FAILED);
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Release the MA indicator handle to free terminal resources
   if(handle_ma != INVALID_HANDLE)
      IndicatorRelease(handle_ma);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- Gate all logic to one execution per new bar on the chart period.
//--- This prevents redundant calculations on every incoming tick.
   datetime current_bar_time = iTime(_Symbol, _Period, 0);
   if(current_bar_time == last_bar_time)
      return;
   last_bar_time = current_bar_time;

   ManageExistingPositions();
   CheckForEntries();
  }

//+------------------------------------------------------------------+
//| Checks for new long entry signals (AUDJPY carry bias)            |
//+------------------------------------------------------------------+
void CheckForEntries()
  {
//--- Skip if a position on this symbol is already open
   if(PositionSelect(_Symbol))
      return;

   double ma[];
   double price[];
   ArraySetAsSeries(ma, true);
   ArraySetAsSeries(price, true);

   if(CopyBuffer(handle_ma, 0, 0, 2, ma) < 2 ||
      CopyClose(_Symbol, _Period, 0, 2, price) < 2)
     {
      Print("CheckForEntries: insufficient indicator data — skipping bar.");
      return;
     }

//--- Entry condition: price above MA signals bullish trend
   if(price[0] > ma[0])
     {
      double lot_size = InpBaseLots;

      if(InpCarryAware)
        {
         //--- CarryAdjustedLotSize expects direction as 1 (long) or -1 (short),
         //--- not a position type enum. Pass 1 directly for a buy entry.
         lot_size = CarryAdjustedLotSize(_Symbol, 1, InpRiskMoney,
                                         InpHoldDaysLimit, InpTargetCarryPct, InpBaseLots);
        }

      if(!trade.Buy(lot_size, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), 0, 0, "CarryDemo Entry"))
         PrintFormat("CheckForEntries: Buy order failed — error %d", GetLastError());
     }
  }

//+------------------------------------------------------------------+
//| Manages open positions using carry-aware and baseline logic      |
//+------------------------------------------------------------------+
void ManageExistingPositions()
  {
   if(!PositionSelect(_Symbol))
      return;

   ulong    ticket    = PositionGetInteger(POSITION_TICKET);
   double   profit    = PositionGetDouble(POSITION_PROFIT);
   datetime open_t    = (datetime)PositionGetInteger(POSITION_TIME);
   int      days_held = (int)((TimeCurrent() - open_t) / 86400);

//--- CASE 1: BASELINE LOGIC (carry awareness disabled)
//--- Exit on time limit or trend reversal with no swap consideration.
//--- This is the comparison benchmark the article measures carry logic against.
   if(!InpCarryAware)
     {
      if(days_held >= InpHoldDaysLimit || IsTrendReversed())
        {
         if(!trade.PositionClose(ticket))
            PrintFormat("ManageExistingPositions: failed to close ticket #%I64u — error %d",
                        ticket, GetLastError());
         else
            Print("Baseline: Position closed on time limit or trend reversal.");
        }
      return;
     }

//--- CASE 2: CARRY-AWARE LOGIC
//--- This is the core demonstration of the article.
//--- The position is only closed if BOTH conditions are true:
//--- - something negative is happening (reversal OR drawdown), AND
//--- - carry income is insufficient to justify staying in.
//---
//--- This means a reversal signal alone will not close a position if
//--- the accumulated and expected swap income still covers the loss.
//--- That is intentional — it is precisely the carry-aware behaviour
//--- this EA exists to demonstrate.
   if(IsTrendReversed() || profit < 0)
     {
      if(!IsWorthHolding(ticket, InpHoldDaysLimit, InpCoveragePct))
        {
         if(!trade.PositionClose(ticket))
            PrintFormat("ManageExistingPositions: failed to close ticket #%I64u on carry exit — error %d",
                        ticket, GetLastError());
         else
            Print("Carry-Aware: Swap income does not cover drawdown — position closed.");
        }
      else
         Print("Carry-Aware: Reversal or drawdown detected, but carry coverage is sufficient — holding.");
     }
  }

//+------------------------------------------------------------------+
//| Returns true if price has crossed below the moving average       |
//+------------------------------------------------------------------+
bool IsTrendReversed()
  {
   double ma[];
   double price[];
   ArraySetAsSeries(ma, true);
   ArraySetAsSeries(price, true);

//--- Return false if indicator data is not yet available
   if(CopyBuffer(handle_ma, 0, 0, 1, ma) < 1 ||
      CopyClose(_Symbol, _Period, 0, 1, price) < 1)
     {
      Print("IsTrendReversed: insufficient data — returning false to avoid false exits.");
      return(false);
     }

   return(price[0] < ma[0]);
  }
//+------------------------------------------------------------------+