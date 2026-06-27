//+------------------------------------------------------------------+
//|                                             OrderBuilderDemo.mq5 |
//| Demonstration EA: exercises COrderBuilder across five order      |
//| types and intentionally provokes validation failure states to    |
//| verify error trapping and diagnostic output behavior.            |
//|                                                                  |
//| Order types demonstrated:                                        |
//|    1. Market buy with SL and TP                                  |
//|    2. Market sell with SL and TP                                 |
//|    3. Pending buy limit with expiry                              |
//|    4. Pending sell stop                                          |
//|    5. Pending buy stop-limit                                     |
//|    6. Intentional validation failure (inverted SL on buy)        |
//|    7. Intentional validation failure (volume out of range)       |
//|                                                                  |
//| Requires: OrderBuilder.mqh                                       |
//+------------------------------------------------------------------+
#property strict

#include "OrderBuilder.mqh"

//--- Input parameters
input group              "== Execution Settings =="
input double             inp_lot_size         = 0.01;     // Order Volume (Lots)
input ulong              inp_magic_number     = 303001;   // EA Magic Number
input ulong              inp_deviation        = 10;       // Maximum Slippage (Points)

input group              "== Risk Parameters =="
input double             inp_sl_points        = 500.0;    // Stop Loss Distance (Points)
input double             inp_tp_points        = 1000.0;   // Take Profit Distance (Points)

input group              "== Pending Order Settings =="
input double             inp_pending_offset   = 200.0;    // Pending Order Price Offset (Points)
input int                inp_expiry_seconds   = 3600;     // Pending Order Expiry Duration (Seconds)

input group              "== Diagnostics =="
input bool               inp_enable_logging   = true;     // Enable Verbose Build Diagnostics

//--- Global Context Storage Variables
COrderBuilder            g_builder;                       // Global instance of the fluent order builder (Stack-allocated)
bool                     g_orders_submitted   = false;    // Execution gate to ensure demonstrations run exactly once

//+------------------------------------------------------------------+
//| LogResult                                                        |
//| Purpose: Formats and outputs the transaction results or          |
//|          validation errors to the terminal journal.              |
//+------------------------------------------------------------------+
void LogResult(const string label, bool success, const string error_msg, const MqlTradeResult &result)
  {
   if(success)
     {
      PrintFormat("[%s] Order submitted successfully. Deal: %lld | Order: %lld | Retcode: %d",
                  label, result.deal, result.order, result.retcode);
     }
   else
     {
      PrintFormat("[%s] Submission failed. Reason: %s | Retcode: %d",
                  label, error_msg, result.retcode);
     }
  }

//+------------------------------------------------------------------+
//| DemoMarketBuy                                                    |
//| Purpose: Constructs and sends a fluent market buy order chain.   |
//+------------------------------------------------------------------+
void DemoMarketBuy(void)
  {
   MqlTradeResult result = {};
   g_builder.Reset();

//--- Calculate absolute protection levels based on current Ask price
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl  = ask - inp_sl_points * _Point;
   double tp  = ask + inp_tp_points * _Point;

//--- Build and dispatch fluent structural layout
   bool ok = g_builder.Symbol(_Symbol)
             .Volume(inp_lot_size)
             .Magic(inp_magic_number)
             .Comment("Demo: Market Buy")
             .Deviation(inp_deviation)
             .Buy()
             .AtMarket()
             .StopLoss(sl)
             .TakeProfit(tp)
             .Send(result);

   LogResult("Market Buy", ok, g_builder.ErrorMessage(), result);
  }

//+------------------------------------------------------------------+
//| DemoMarketSell                                                   |
//| Purpose: Constructs and sends a fluent market sell order chain.  |
//+------------------------------------------------------------------+
void DemoMarketSell(void)
  {
   MqlTradeResult result = {};
   g_builder.Reset();

//--- Calculate absolute protection levels based on current Bid price
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl  = bid + inp_sl_points * _Point;
   double tp  = bid - inp_tp_points * _Point;

//--- Build and dispatch fluent structural layout
   bool ok = g_builder.Symbol(_Symbol)
             .Volume(inp_lot_size)
             .Magic(inp_magic_number)
             .Comment("Demo: Market Sell")
             .Deviation(inp_deviation)
             .Sell()
             .AtMarket()
             .StopLoss(sl)
             .TakeProfit(tp)
             .Send(result);

   LogResult("Market Sell", ok, g_builder.ErrorMessage(), result);
  }

//+------------------------------------------------------------------+
//| DemoPendingBuyLimit                                              |
//| Purpose: Construct and send the buy limit pending order chain.   |
//+------------------------------------------------------------------+
void DemoPendingBuyLimit(void)
  {
   MqlTradeResult result = {};
   g_builder.Reset();

//--- Define a target entry limit price below current market with an expiration timestamp
   double ask         = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double limit_price = ask - inp_pending_offset * _Point;
   double sl          = limit_price - inp_sl_points * _Point;
   double tp          = limit_price + inp_tp_points * _Point;
   datetime expiry    = TimeCurrent() + inp_expiry_seconds;

//--- Build and dispatch fluent structural layout
   bool ok = g_builder.Symbol(_Symbol)
             .Volume(inp_lot_size)
             .Magic(inp_magic_number)
             .Comment("Demo: Buy Limit")
             .BuyLimit(limit_price)
             .StopLoss(sl)
             .TakeProfit(tp)
             .Expiry(expiry)
             .Send(result);

   LogResult("Pending Buy Limit", ok, g_builder.ErrorMessage(), result);
  }

//+------------------------------------------------------------------+
//| DemoPendingSellStop                                              |
//| Purpose: Construct and send the sell stop pending order chain.   |
//+------------------------------------------------------------------+
void DemoPendingSellStop(void)
  {
   MqlTradeResult result = {};
   g_builder.Reset();

//--- Define a target entry breakout stop price below current market
   double bid        = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double stop_price = bid - inp_pending_offset * _Point;
   double sl         = stop_price + inp_sl_points * _Point;
   double tp         = stop_price - inp_tp_points * _Point;

//--- Build and dispatch fluent structural layout
   bool ok = g_builder.Symbol(_Symbol)
             .Volume(inp_lot_size)
             .Magic(inp_magic_number)
             .Comment("Demo: Sell Stop")
             .SellStop(stop_price)
             .StopLoss(sl)
             .TakeProfit(tp)
             .Send(result);

   LogResult("Pending Sell Stop", ok, g_builder.ErrorMessage(), result);
  }

//+------------------------------------------------------------------+
//| DemoPendingBuyStopLimit                                          |
//| Purpose: Construct and send the advanced buy stop-limit chain.   |
//+------------------------------------------------------------------+
void DemoPendingBuyStopLimit(void)
  {
   MqlTradeResult result = {};
   g_builder.Reset();

//--- Define the activation stop price and the subsequent entry limit execution price
   double ask         = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double stop_price  = ask + inp_pending_offset * _Point;
   double limit_price = stop_price - (inp_pending_offset * 0.5) * _Point;
   double sl          = limit_price - inp_sl_points * _Point;
   double tp          = limit_price + inp_tp_points * _Point;

//--- Build and dispatch fluent structural layout
   bool ok = g_builder.Symbol(_Symbol)
             .Volume(inp_lot_size)
             .Magic(inp_magic_number)
             .Comment("Demo: Buy Stop-Limit")
             .BuyStopLimit(stop_price, limit_price)
             .StopLoss(sl)
             .TakeProfit(tp)
             .Send(result);

   LogResult("Pending Buy Stop-Limit", ok, g_builder.ErrorMessage(), result);
  }

//+------------------------------------------------------------------+
//| DemoInvalidStopLoss                                              |
//| Purpose: Expect local validation to reject the order layout early.|
//+------------------------------------------------------------------+
void DemoInvalidStopLoss(void)
  {
   MqlTradeResult result = {};
   g_builder.Reset();

//--- Deliberately set an invalid buy Stop Loss situated above the entry price
   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bad_sl = ask + inp_sl_points * _Point;

//--- Build and dispatch fluent structural layout
   bool ok = g_builder.Symbol(_Symbol)
             .Volume(inp_lot_size)
             .Magic(inp_magic_number)
             .Comment("Demo: Invalid SL")
             .Buy()
             .AtMarket()
             .StopLoss(bad_sl)
             .TakeProfit(ask + inp_tp_points * _Point)
             .Send(result);

   LogResult("Invalid SL (expected failure)", ok, g_builder.ErrorMessage(), result);
  }

//+------------------------------------------------------------------+
//| DemoInvalidVolume                                                |
//| Purpose: Assign an out-of-range volume configuration for checking|
//|          early-stage baseline failure traps.                     |
//+------------------------------------------------------------------+
void DemoInvalidVolume(void)
  {
   MqlTradeResult result = {};
   g_builder.Reset();

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

//--- Build and dispatch fluent structural layout
   bool ok = g_builder.Symbol(_Symbol)
             .Volume(9999.99)
             .Magic(inp_magic_number)
             .Buy()
             .AtMarket()
             .StopLoss(ask - inp_sl_points * _Point)
             .TakeProfit(ask + inp_tp_points * _Point)
             .Send(result);

   LogResult("Invalid Volume (expected failure)", ok, g_builder.ErrorMessage(), result);
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//| Purpose: Validates operational setup contexts parameters safely. |
//+------------------------------------------------------------------+
int OnInit(void)
  {
//--- Validate sanity of input parameters to ensure safe operating limits
   if(inp_sl_points <= 0.0 || inp_tp_points <= 0.0)
     {
      Print("[OrderBuilderDemo] Configuration error: SL and TP points must be positive.");
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(inp_lot_size <= 0.0)
     {
      Print("[OrderBuilderDemo] Configuration error: lot size must be positive.");
      return(INIT_PARAMETERS_INCORRECT);
     }

   PrintFormat("[OrderBuilderDemo] Initialized on %s. Will submit demonstration orders on first tick.", _Symbol);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//| Purpose: Executes sequential baseline closing logs on exit path.  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   PrintFormat("[OrderBuilderDemo] Deinitialized. Reason code: %d.", reason);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//| Purpose: Runs the structural pipeline evaluation test block once.  |
//+------------------------------------------------------------------+
void OnTick(void)
  {
//--- Enforce execution gate to run the test suite only once
   if(g_orders_submitted)
     {
      return;
     }

   g_orders_submitted = true;

   if(inp_enable_logging)
     {
      Print("[OrderBuilderDemo] --- Begin demonstration order sequence ---");
     }

//--- Execute all demonstration routines sequentially
   DemoMarketBuy();
   DemoMarketSell();
   DemoPendingBuyLimit();
   DemoPendingSellStop();
   DemoPendingBuyStopLimit();
   DemoInvalidStopLoss();
   DemoInvalidVolume();

   if(inp_enable_logging)
     {
      Print("[OrderBuilderDemo] --- Demonstration sequence complete ---");
     }
  }
//+------------------------------------------------------------------+