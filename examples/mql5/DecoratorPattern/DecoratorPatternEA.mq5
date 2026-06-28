//+------------------------------------------------------------------+
//|                                           DecoratorPatternEA.mq5 |
//| Demonstration EA: constructs and exercises multiple decorator    |
//| chains, logs each layer independently, shows timing and          |
//| filtering effects, updates a chart comment panel, and            |
//| performs deterministic cleanup in OnDeinit().                    |
//|                                                                  |
//| Chain A: Timing > Logging > Filter > RSI                         |
//| Chain B: Timing > MA (no logging, no filter)                     |
//|                                                                  |
//| Requires:                                                        |
//|    IIndicator.mqh                                                |
//|    RSIIndicator.mqh                                              |
//|    BaseDecorator.mqh                                             |
//|    LoggingDecorator.mqh                                          |
//|    TimingDecorator.mqh                                           |
//|    ThresholdFilterDecorator.mqh                                  |
//|    CommentPanel.mqh                                              |
//+------------------------------------------------------------------+
#property strict

#include <Decorator_Pattern/RSIIndicator.mqh>
#include <Decorator_Pattern/LoggingDecorator.mqh>
#include <Decorator_Pattern/TimingDecorator.mqh>
#include <Decorator_Pattern/ThresholdFilterDecorator.mqh>
#include <Decorator_Pattern/CommentPanel.mqh>

//--- Input parameters
input group              "== Indicator Configuration =="
input int                inp_rsi_period          = 14;          // RSI Period
input ENUM_APPLIED_PRICE inp_rsi_applied         = PRICE_CLOSE; // RSI Applied Price
input int                inp_ma_period           = 21;          // MA Period
input ENUM_TIMEFRAMES    inp_timeframe           = PERIOD_H1;   // Indicator Timeframe

input group              "== Decorator Configuration =="
input bool               inp_enable_logging      = true;        // Enable Logging Decorator Output
input bool               inp_enable_timing       = true;        // Enable Timing Decorator Output
input bool               inp_enable_filter_log   = true;        // Enable Filter Decision Logging
input double             inp_filter_lower        = 40.0;        // Filter Lower Bound (RSI Units)
input double             inp_filter_upper        = 60.0;        // Filter Upper Bound (RSI Units)

input group              "== Diagnostics =="
input int                inp_log_interval        = 10;          // Tick Interval for Periodic Chain Log

//--- Global Context Storage Variables
IIndicator      *g_chain_a       = NULL;  // Chain A: Timing > Logging > Filter > RSI
IIndicator      *g_chain_b       = NULL;  // Chain B: Timing > MA (no logging, no filter)
IIndicator      *g_inner_rsi_obs = NULL;  // Non-owning observation pointer for raw RSI reads
CCommentPanel    g_panel;                 // Dashboard visualization panel
long             g_tick_count    = 0;     // Operational incoming tick counter

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//| Purpose: Allocates and dynamically links decorator chains        |
//+------------------------------------------------------------------+
int OnInit(void)
  {
   //--- Validate core input logic metrics
   if(inp_rsi_period <= 0 || inp_ma_period <= 0)
     {
      Print("[DecoratorPatternEA] Configuration error: periods must be positive.");
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(inp_filter_lower >= inp_filter_upper)
     {
      Print("[DecoratorPatternEA] Configuration error: lower bound must be less than upper.");
      return(INIT_PARAMETERS_INCORRECT);
     }

   //--- Construct Chain A bottom-up
   //--- Each constructor call transfers ownership to the next layer.
   CRSIIndicator *rsi = new CRSIIndicator(_Symbol, inp_timeframe, inp_rsi_period, inp_rsi_applied);
   if(CheckPointer(rsi) != POINTER_DYNAMIC)
     {
      Print("[DecoratorPatternEA] Failed to allocate CRSIIndicator.");
      return(INIT_FAILED);
     }

   //--- Non-owning observation pointer for raw RSI reads
   g_inner_rsi_obs = rsi;

   CThresholdFilterDecorator *filter = new CThresholdFilterDecorator(rsi, inp_filter_lower, inp_filter_upper, inp_enable_filter_log);
   if(CheckPointer(filter) != POINTER_DYNAMIC)
     {
      delete rsi;
      Print("[DecoratorPatternEA] Failed to allocate CThresholdFilterDecorator.");
      return(INIT_FAILED);
     }

   CLoggingDecorator *logger = new CLoggingDecorator(filter, inp_enable_logging, 0);
   if(CheckPointer(logger) != POINTER_DYNAMIC)
     {
      delete filter;
      Print("[DecoratorPatternEA] Failed to allocate CLoggingDecorator.");
      return(INIT_FAILED);
     }

   CTimingDecorator *timer_a = new CTimingDecorator(logger, inp_enable_timing);
   if(CheckPointer(timer_a) != POINTER_DYNAMIC)
     {
      delete logger;
      Print("[DecoratorPatternEA] Failed to allocate CTimingDecorator for chain A.");
      return(INIT_FAILED);
     }

   g_chain_a = timer_a;

   //--- Construct Chain B bottom-up: Timing > MA
   CMovingAverageIndicator *ma = new CMovingAverageIndicator(_Symbol, inp_timeframe, inp_ma_period, 0, MODE_EMA, PRICE_CLOSE);
   if(CheckPointer(ma) != POINTER_DYNAMIC)
     {
      delete g_chain_a;
      g_chain_a = NULL;
      Print("[DecoratorPatternEA] Failed to allocate CMovingAverageIndicator.");
      return(INIT_FAILED);
     }

   CTimingDecorator *timer_b = new CTimingDecorator(ma, inp_enable_timing);
   if(CheckPointer(timer_b) != POINTER_DYNAMIC)
     {
      delete ma;
      delete g_chain_a;
      g_chain_a = NULL;
      Print("[DecoratorPatternEA] Failed to allocate CTimingDecorator for chain B.");
      return(INIT_FAILED);
     }

   g_chain_b = timer_b;

   //--- Print chain structure out to terminal journal logs
   Print("[DecoratorPatternEA] Chain A: " + g_chain_a.GetName());
   Print("[DecoratorPatternEA] Chain B: " + g_chain_b.GetName());
   PrintFormat("[DecoratorPatternEA] Initialized on %s %s | RSI: %d | MA: %d | Filter: [%.1f, %.1f]",
               _Symbol, EnumToString(inp_timeframe), inp_rsi_period, inp_ma_period, inp_filter_lower, inp_filter_upper);

   return(INIT_SUCCEEDED);
  }

//+-------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//| Purpose: Cleanly destroys dynamically allocated decorator chains. |
//+-------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   //--- Deleting the outermost decorator destroys the entire internal chain branch.
   if(CheckPointer(g_chain_a) == POINTER_DYNAMIC)
     {
      delete g_chain_a;
      g_chain_a       = NULL;
      g_inner_rsi_obs = NULL;
     }

   if(CheckPointer(g_chain_b) == POINTER_DYNAMIC)
     {
      delete g_chain_b;
      g_chain_b = NULL;
     }

   g_panel.Clear();
   PrintFormat("[DecoratorPatternEA] Deinitialized. Reason code: %d.", reason);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//| Purpose: Executes sequential pipeline data evaluations on ticks  |
//+------------------------------------------------------------------+
void OnTick(void)
  {
   //--- Validate state pointers
   if(CheckPointer(g_chain_a) != POINTER_DYNAMIC || CheckPointer(g_chain_b) != POINTER_DYNAMIC)
     {
      return;
     }

   g_tick_count++;

   //--- Evaluate Chain A (bar 0): full Timing > Logging > Filter > RSI
   double chain_a_value = g_chain_a.GetValue(0);

   //--- Read raw RSI value for panel comparison bypassing decorators
   double raw_rsi = (g_inner_rsi_obs != NULL) ? g_inner_rsi_obs.GetValue(0) : 0.0;

   //--- Evaluate Chain B (bar 0): Timing > MA
   double chain_b_value = g_chain_b.GetValue(0);

   //--- Record metrics and refresh user panel
   g_panel.RecordValues(raw_rsi, chain_a_value);
   g_panel.Update(g_chain_a.GetName(), g_inner_rsi_obs, g_chain_a);

   //--- Periodic chain evaluation writeout to the log.
   if(g_tick_count % inp_log_interval == 0)
     {
      Print("=== Decorator Chain Evaluation | Tick " + IntegerToString(g_tick_count) + " ===");
      Print("Chain A name  : " + g_chain_a.GetName());
      Print("Chain A value : " + DoubleToString(chain_a_value, 5));
      Print("Raw RSI value : " + DoubleToString(raw_rsi, 5));
      Print("Chain B name  : " + g_chain_b.GetName());
      Print("Chain B value : " + DoubleToString(chain_b_value, 5));
      Print("================================================================");
     }
  }
//+------------------------------------------------------------------+