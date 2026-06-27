//+------------------------------------------------------------------+
//|                                                   SwapVerify.mq5 |
//|                                                   test script    |
//+------------------------------------------------------------------+
#include "SwapTools.mqh"

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   string sym        = _Symbol;
   double long_swap  = DailySwapInAccountCurrency(sym,1);
   double short_swap = DailySwapInAccountCurrency(sym,-1);
   int    mode       = (int)SymbolInfoInteger(sym,SYMBOL_SWAP_MODE);

   Print("=== SWAP VERIFICATION ===");
   Print("Symbol      : ",sym);
   Print("Swap mode   : ",mode);
   Print("Long  (raw): ",SymbolInfoDouble(sym,SYMBOL_SWAP_LONG));
   Print("Short (raw): ",SymbolInfoDouble(sym,SYMBOL_SWAP_SHORT));

   Print("Long  /lot/day (account CCY): ",DoubleToString(long_swap,4));
   Print("Short /lot/day (account CCY): ",DoubleToString(short_swap,4));

   double expected_swap = ExpectedSwapForPosition(sym,1,0.1,5);
   Print("5-day long carry at 0.1 lot: ",DoubleToString(expected_swap,2));
  }
//+------------------------------------------------------------------+