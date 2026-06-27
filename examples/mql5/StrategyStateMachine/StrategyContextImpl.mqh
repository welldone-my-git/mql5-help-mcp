//+------------------------------------------------------------------+
//|                                          StrategyContextImpl.mqh |
//| Constructor, destructor, and concrete state accessor             |
//| implementations for CStrategyContext.                            |
//|                                                                  |
//| Include this file from the EA instead of StrategyContext.mqh.    |
//| Compilation order enforced by this file:                         |
//|    1. IState.mqh           (via StrategyContext.mqh)             |
//|    2. StrategyContext.mqh  (class declaration, forward decls)    |
//|    3. States.mqh           (full concrete state definitions)     |
//|    4. This file            (bodies requiring all of the above)   |
//+------------------------------------------------------------------+
#ifndef STRATEGYCONTEXTIMPL_MQH
#define STRATEGYCONTEXTIMPL_MQH

#include "StrategyContext.mqh"
#include "States.mqh"

//+------------------------------------------------------------------+
//| Constructor                                                      |
//| Purpose: Allocates states dynamically and initialises contexts   |
//+------------------------------------------------------------------+
CStrategyContext::CStrategyContext(string symbol, ulong magic,
                                   int ma_fast_handle, int ma_slow_handle)
   :  m_symbol(symbol),
      m_magic(magic),
      m_ma_fast_handle(ma_fast_handle),
      m_ma_slow_handle(ma_slow_handle),
      m_last_ticket(0),
      m_tick_count(0),
      m_state_entry_tick(0),
      m_pending_direction(0)
{
   //--- Instantiating concrete states on heap memory
   m_state_idle     = new CIdleState();
   m_state_entry    = new CEntryState();
   m_state_in_trade = new CInTradeState();
   m_state_exit     = new CExitState();

   //--- Set the initial baseline operational state to Idle
   m_current_state  = m_state_idle;
   m_current_state.OnEnter(&this);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//| Purpose: Frees allocated state heap pointers to prevent leaks    |
//+------------------------------------------------------------------+
CStrategyContext::~CStrategyContext(void)
{
   //--- Sequential memory verification and clean-up of allocated states
   if(CheckPointer(m_state_idle) == POINTER_DYNAMIC)
     {
      delete m_state_idle;
     }
     
   if(CheckPointer(m_state_entry) == POINTER_DYNAMIC)
     {
      delete m_state_entry;
     }
     
   if(CheckPointer(m_state_in_trade) == POINTER_DYNAMIC)
     {
      delete m_state_in_trade;
     }
     
   if(CheckPointer(m_state_exit) == POINTER_DYNAMIC)
     {
      delete m_state_exit;
     }
}

//+------------------------------------------------------------------+
//| GetIdleState                                                     |
//+------------------------------------------------------------------+
CIdleState* CStrategyContext::GetIdleState(void) const
{
   return(m_state_idle);
}

//+------------------------------------------------------------------+
//| GetEntryState                                                    |
//+------------------------------------------------------------------+
CEntryState* CStrategyContext::GetEntryState(void) const
{
   return(m_state_entry);
}

//+------------------------------------------------------------------+
//| GetInTradeState                                                  |
//+------------------------------------------------------------------+
CInTradeState* CStrategyContext::GetInTradeState(void) const
{
   return(m_state_in_trade);
}

//+------------------------------------------------------------------+
//| GetExitState                                                     |
//+------------------------------------------------------------------+
CExitState* CStrategyContext::GetExitState(void) const
{
   return(m_state_exit);
}

#endif // STRATEGYCONTEXTIMPL_MQH
//+------------------------------------------------------------------+