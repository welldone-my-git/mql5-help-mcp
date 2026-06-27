//+------------------------------------------------------------------+
//|                                               StateMachineEA.mq5 |
//| Demonstration EA binding CStrategyContext to live market ticks.  |
//| Prints state transition logs to the terminal journal and         |
//| displays the current active state on the chart via a label.      |
//|                                                                  |
//| Requires: StrategyContextImpl.mqh (pulls in the full chain:      |
//|    IState.mqh, StrategyContext.mqh, States.mqh)                  |
//+------------------------------------------------------------------+

#property strict

//--- Single include resolves the full dependency chain in correct order
#include <Strategy_State_Machine/StrategyContextImpl.mqh>

//--- Input parameters
input group              "== Strategy Configuration =="
input int                inp_ma_fast_period    = 9;           // Fast EMA Period
input int                inp_ma_slow_period    = 21;          // Slow EMA Period
input ENUM_TIMEFRAMES    inp_timeframe         = PERIOD_H1;   // Signal Evaluation Timeframe
input ulong              inp_magic_number      = 505001;      // EA Magic Number

input group              "== Diagnostics =="
input bool               inp_enable_logging    = true;        // Enable State Transition Journal Logging
input int                inp_log_interval      = 100;         // Tick Interval for Periodic State Log

//--- Global instances
CStrategyContext *g_context    = NULL;
long              g_tick_count = 0;

//--- Chart label layout configuration
string g_label_name = "FSM_STATE_LABEL";

//+------------------------------------------------------------------+
//| UpdateStateLabel                                                 |
//| Purpose: Updates or generates visual state indicator on the chart|
//+------------------------------------------------------------------+
void UpdateStateLabel(string state_name)
  {
   if(ObjectFind(0, g_label_name) < 0)
     {
      ObjectCreate(0, g_label_name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, g_label_name, OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(0, g_label_name, OBJPROP_YDISTANCE, 20);
      ObjectSetInteger(0, g_label_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, g_label_name, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, g_label_name, OBJPROP_COLOR, clrDodgerBlue);
     }
   ObjectSetString(0, g_label_name, OBJPROP_TEXT, "FSM State: " + state_name);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(void)
  {
   //--- Validate filter structure parameters
   if(inp_ma_fast_period >= inp_ma_slow_period)
     {
      Print("[StateMachineEA] Configuration error: fast period must be less than slow period.");
      return(INIT_PARAMETERS_INCORRECT);
     }

   //--- Create underlying technical indicator handles
   int fast_handle = iMA(_Symbol, inp_timeframe, inp_ma_fast_period, 0, MODE_EMA, PRICE_CLOSE);
   int slow_handle = iMA(_Symbol, inp_timeframe, inp_ma_slow_period, 0, MODE_EMA, PRICE_CLOSE);

   if(fast_handle == INVALID_HANDLE || slow_handle == INVALID_HANDLE)
     {
      Print("[StateMachineEA] Failed to create MA indicator handles.");
      return(INIT_FAILED);
     }

   //--- Construct context: ownership of handles passes into the state machine
   g_context = new CStrategyContext(_Symbol, inp_magic_number, fast_handle, slow_handle);

   if(CheckPointer(g_context) != POINTER_DYNAMIC)
     {
      Print("[StateMachineEA] Failed to allocate CStrategyContext.");
      return(INIT_FAILED);
     }

   PrintFormat("[StateMachineEA] Initialized on %s %s | Fast MA: %d | Slow MA: %d | Magic: %s",
               _Symbol,
               EnumToString(inp_timeframe),
               inp_ma_fast_period,
               inp_ma_slow_period,
               IntegerToString(inp_magic_number));

   UpdateStateLabel(g_context.GetCurrentStateName());
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_context) == POINTER_DYNAMIC)
     {
      //--- Securely release system indicator handles before deletion
      IndicatorRelease(g_context.GetFastMAHandle());
      IndicatorRelease(g_context.GetSlowMAHandle());
      delete g_context;
      g_context = NULL;
     }

   //--- Purge UI components from active chart window
   ObjectDelete(0, g_label_name);
   PrintFormat("[StateMachineEA] Deinitialized. Reason code: %d.", reason);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(void)
  {
   if(CheckPointer(g_context) != POINTER_DYNAMIC)
     {
      return;
     }

   g_tick_count++;

   //--- Delegate evaluation processing cycle to state architecture
   g_context.Update();

   //--- Synchronize display telemetry parameters
   UpdateStateLabel(g_context.GetCurrentStateName());

   //--- Execution tracking log output
   if(inp_enable_logging && g_tick_count % inp_log_interval == 0)
     {
      PrintFormat("[StateMachineEA] Tick %s | State: %s",
                  IntegerToString(g_tick_count),
                  g_context.GetCurrentStateName());
     }
  }
//+------------------------------------------------------------------+