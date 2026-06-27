//+------------------------------------------------------------------+
//|                                                 EventBusDemo.mq5 |
//| Demonstration EA: wires CSignalEngine, COrderManager, and        |
//| CDrawdownMonitor through CEventBus with no direct cross-         |
//| component references. All communication flows through the bus.   |
//|                                                                  |
//| Tracks: EA_EVENT_SIGNAL_LONG, EA_EVENT_SIGNAL_SHORT,             |
//|        EA_EVENT_ORDER_FILL, EA_EVENT_ORDER_REJECT,               |
//|        EA_EVENT_DRAWDOWN_WARN, EA_EVENT_DRAWDOWN_HALT            |
//|                                                                  |
//| Requires: EventBusSystem.mqh (consolidated include)              |
//+------------------------------------------------------------------+
#property strict

//--- Single consolidated include replaces all six individual headers
#include "EventBusSystem.mqh"

//--- Input parameters
input group              "== Signal Configuration =="
input int                inp_ma_fast_period    = 9;           // Fast EMA Period
input int                inp_ma_slow_period    = 21;          // Slow EMA Period
input ENUM_TIMEFRAMES    inp_timeframe         = PERIOD_H1;   // Signal Evaluation Timeframe

input group              "== Order Configuration =="
input double             inp_lot_size          = 0.01;        // Order Volume (Lots)
input double             inp_sl_points         = 500;         // Stop Loss Distance (Points)
input double             inp_tp_points         = 1000;        // Take Profit Distance (Points)
input ulong              inp_magic_number      = 202401;      // EA Magic Number

input group              "== Risk Management =="
input double             inp_drawdown_warn_pct = 3.0;         // Drawdown Warning Threshold (%)
input double             inp_drawdown_halt_pct = 6.0;         // Drawdown Hard Halt Threshold (%)

input group              "== Diagnostics =="
input bool               inp_enable_logging    = true;        // Enable Verbose Event Diagnostics

//--- Module instances (heap-allocated for controlled lifetime)
CEventBus        *g_bus            = NULL;
CSignalEngine    *g_signal_engine  = NULL;
COrderManager    *g_order_manager  = NULL;
CDrawdownMonitor *g_risk_monitor   = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Validate thresholds
   if(inp_drawdown_warn_pct >= inp_drawdown_halt_pct)
     {
      Print("[EventBusDemo] Configuration error: warning threshold must be less than halt threshold.");
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(inp_ma_fast_period >= inp_ma_slow_period)
     {
      Print("[EventBusDemo] Configuration error: fast MA period must be less than slow MA period.");
      return(INIT_PARAMETERS_INCORRECT);
     }

//--- Construct the event bus
   g_bus = new CEventBus(inp_enable_logging);
   if(CheckPointer(g_bus) != POINTER_DYNAMIC)
     {
      Print("[EventBusDemo] Failed to allocate CEventBus.");
      return(INIT_FAILED);
     }

//--- Construct component modules
   g_signal_engine = new CSignalEngine(g_bus,_Symbol,inp_timeframe,
                                       inp_ma_fast_period,inp_ma_slow_period);
   g_order_manager = new COrderManager(g_bus,_Symbol,inp_lot_size,
                                       inp_sl_points,inp_tp_points,inp_magic_number);
   g_risk_monitor  = new CDrawdownMonitor(g_bus,inp_drawdown_warn_pct,inp_drawdown_halt_pct);

   if(CheckPointer(g_signal_engine) != POINTER_DYNAMIC ||
      CheckPointer(g_order_manager) != POINTER_DYNAMIC ||
      CheckPointer(g_risk_monitor) != POINTER_DYNAMIC)
     {
      Print("[EventBusDemo] Failed to allocate one or more component modules.");
      return(INIT_FAILED);
     }

//--- Initialize signal engine (creates indicator handles)
   if(!g_signal_engine.Initialize())
      return(INIT_FAILED);

//--- Wire subscriptions: order manager listens for signals and drawdown halts
   g_bus.Subscribe(EA_EVENT_SIGNAL_LONG,g_order_manager);
   g_bus.Subscribe(EA_EVENT_SIGNAL_SHORT,g_order_manager);
   g_bus.Subscribe(EA_EVENT_DRAWDOWN_HALT,g_order_manager);
   g_bus.Subscribe(EA_EVENT_SESSION_OPEN,g_order_manager);

//--- Wire subscriptions: risk monitor listens for fills to anchor equity baseline
   g_bus.Subscribe(EA_EVENT_ORDER_FILL,g_risk_monitor);
   g_bus.Subscribe(EA_EVENT_SESSION_OPEN,g_risk_monitor);

   PrintFormat("[EventBusDemo] Initialized on %s %s. Bus subscribers: "
               "LONG=%d, SHORT=%d, FILL=%d, HALT=%d.",
               _Symbol,EnumToString(inp_timeframe),
               g_bus.SubscriberCount(EA_EVENT_SIGNAL_LONG),
               g_bus.SubscriberCount(EA_EVENT_SIGNAL_SHORT),
               g_bus.SubscriberCount(EA_EVENT_ORDER_FILL),
               g_bus.SubscriberCount(EA_EVENT_DRAWDOWN_HALT));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Clear all subscriptions before destroying listener objects.
//--- This prevents the bus from holding dangling pointers during the
//--- brief window between Clear() and the delete calls below.
   if(CheckPointer(g_bus) == POINTER_DYNAMIC)
      g_bus.Clear();

//--- Delete component modules in dependency order (consumers before producers)
   if(CheckPointer(g_risk_monitor) == POINTER_DYNAMIC)
     {
      delete g_risk_monitor;
      g_risk_monitor = NULL;
     }
   if(CheckPointer(g_order_manager) == POINTER_DYNAMIC)
     {
      delete g_order_manager;
      g_order_manager = NULL;
     }
   if(CheckPointer(g_signal_engine) == POINTER_DYNAMIC)
     {
      delete g_signal_engine;
      g_signal_engine = NULL;
     }
   if(CheckPointer(g_bus) == POINTER_DYNAMIC)
     {
      delete g_bus;
      g_bus = NULL;
     }

   PrintFormat("[EventBusDemo] Deinitialized. Reason code: %d.",reason);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(CheckPointer(g_signal_engine) != POINTER_DYNAMIC ||
      CheckPointer(g_risk_monitor) != POINTER_DYNAMIC)
      return;

//--- Evaluate risk conditions first; a halt published here will
//--- suppress the order manager before the signal engine fires.
   g_risk_monitor.Evaluate();

//--- Evaluate signal conditions; any crossover will publish to the bus,
//--- which synchronously dispatches to the order manager if trading is allowed.
   g_signal_engine.Evaluate();
  }

//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD && inp_enable_logging)
     {
      PrintFormat("[EventBusDemo] Trade transaction: deal #%lld, symbol=%s, "
                  "type=%s, volume=%.2f, price=%.5f.",
                  trans.deal,
                  trans.symbol,
                  EnumToString(trans.deal_type),
                  trans.volume,
                  trans.price);
     }
  }
//+------------------------------------------------------------------+