//+------------------------------------------------------------------+
//| EA_ZScore_Template.mq5                                           |
//| Minimal EA template using reusable signal engine                  |
//+------------------------------------------------------------------+
#property strict
#property version "1.00"

#include <Trade/Trade.mqh>
#include "ZScoreEngine_Essence.mqh"
#include "OncePerBar.mqh"

input int    InpPeriod     = 50;
input double InpEntrySigma = 2.5;
input double InpLots       = 0.10;

CZScoreEngine *g_signal = NULL;
COncePerBar   *g_bar    = NULL;
CTrade         g_trade;

int OnInit()
  {
   g_signal = new CZScoreEngine(_Symbol, PERIOD_CURRENT, InpPeriod);
   g_bar    = new COncePerBar(_Symbol, PERIOD_CURRENT);

   if(CheckPointer(g_signal) == POINTER_INVALID || CheckPointer(g_bar) == POINTER_INVALID)
      return INIT_FAILED;

   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(CheckPointer(g_signal) == POINTER_DYNAMIC) delete g_signal;
   if(CheckPointer(g_bar)    == POINTER_DYNAMIC) delete g_bar;
  }

void OnTick()
  {
   if(CheckPointer(g_bar) == POINTER_INVALID) return;
   if(!g_bar.IsNewBar()) return;

   if(CheckPointer(g_signal) == POINTER_INVALID) return;
   const double z = g_signal.Value(1); // closed bar only

   if(PositionSelect(_Symbol))
     {
      const long type = PositionGetInteger(POSITION_TYPE);

      if(type == POSITION_TYPE_BUY && z >= 0.0)
         g_trade.PositionClose(_Symbol);
      else if(type == POSITION_TYPE_SELL && z <= 0.0)
         g_trade.PositionClose(_Symbol);

      return;
     }

   if(z >= InpEntrySigma)
      g_trade.Sell(InpLots, _Symbol, 0.0, 0.0, 0.0, "ZScore short");
   else if(z <= -InpEntrySigma)
      g_trade.Buy(InpLots, _Symbol, 0.0, 0.0, 0.0, "ZScore long");
  }
