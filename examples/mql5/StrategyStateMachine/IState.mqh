//+------------------------------------------------------------------+
//|                                                       IState.mqh |
//| Abstract state interface for the strategy FSM.                   |
//| Every concrete state must implement all five virtual methods.    |
//+------------------------------------------------------------------+
#ifndef ISTATE_MQH
#define ISTATE_MQH

//--- Forward declaration: CStrategyContext is defined in StrategyContext.mqh
class CStrategyContext;

//+------------------------------------------------------------------+
//| Enumeration of execution states for the strategy FSM             |
//+------------------------------------------------------------------+
enum ENUM_STRATEGY_STATE
  {
   STATE_IDLE     = 0,  // No active position; awaiting valid entry signal
   STATE_ENTRY    = 1,  // Entry signal confirmed; order submission in progress
   STATE_IN_TRADE = 2,  // Position open; monitoring for exit conditions
   STATE_EXIT     = 3   // Exit condition triggered; closing position
  };

//+------------------------------------------------------------------+
//| Class IState                                                     |
//| Purpose: Interface defining actions within an execution state    |
//+------------------------------------------------------------------+
class IState
  {
public:
   //--- Lifecycle and state execution logic hooks
   virtual void               OnEnter(CStrategyContext *ctx) = 0;
   virtual void               Evaluate(CStrategyContext *ctx) = 0;
   virtual void               OnExit(CStrategyContext *ctx) = 0;

   //--- Metadata and state monitoring properties
   virtual ENUM_STRATEGY_STATE GetStateId(void) const = 0;
   virtual string             GetStateName(void) const = 0;

   //--- Virtual destructor ensuring clean polymorphic teardown
   virtual                   ~IState(void) {}
  };

#endif // ISTATE_MQH
//+------------------------------------------------------------------+