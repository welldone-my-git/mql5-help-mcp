//+------------------------------------------------------------------+
//|                                              StrategyContext.mqh |
//| CStrategyContext: owns the FSM state pointer and all four        |
//| concrete state instances. Mediates all transitions via           |
//| SetState(), enforcing the OnExit/OnEnter lifecycle sequence.     |
//|                                                                  |
//| Do not include this file directly from the EA.                   |
//| Include StrategyContextImpl.mqh instead, which resolves the      |
//| full dependency chain in the correct compilation order.          |
//+------------------------------------------------------------------+
#ifndef STRATEGYCONTEXT_MQH
#define STRATEGYCONTEXT_MQH

#include "IState.mqh"

//--- Forward declarations: full definitions are in States.mqh
class CIdleState;
class CEntryState;
class CInTradeState;
class CExitState;

//+------------------------------------------------------------------+
//| Class CStrategyContext                                           |
//| Purpose: Keeps strategy parameters and handles states lifecycle  |
//+------------------------------------------------------------------+
class CStrategyContext
  {
private:
   IState           *m_current_state;     // Current active state interface pointer
   CIdleState       *m_state_idle;        // Allocated concrete idle state instance
   CEntryState      *m_state_entry;       // Allocated concrete entry state instance
   CInTradeState    *m_state_in_trade;    // Allocated concrete in-trade state instance
   CExitState       *m_state_exit;        // Allocated concrete exit state instance

   string            m_symbol;            // Work asset symbol name
   ulong             m_magic;             // Expert Advisor unique magic number identifier
   int               m_ma_fast_handle;    // Fast Moving Average indicator engine handle
   int               m_ma_slow_handle;    // Slow Moving Average indicator engine handle
   ulong             m_last_ticket;       // Last processed order position ticket ID
   long              m_tick_count;        // Continuous counter of tracking input ticks
   long              m_state_entry_tick;  // Global tick count recorded at state entry
   int               m_pending_direction; // Ordered trade pending execution vector

public:
   //--- Implemented in StrategyContextImpl.mqh (requires full state definitions)
                     CStrategyContext(string symbol, ulong magic,
                                      int ma_fast_handle, int ma_slow_handle);
                    ~CStrategyContext(void);

   //--- Core lifecycle state control mechanisms
   void               Update(void);
   void               SetState(IState *next_state);
   ENUM_STRATEGY_STATE GetCurrentStateId(void)   const;
   string             GetCurrentStateName(void) const;

   //--- Scalar property state engine accessors
   string             GetSymbol(void)           const;
   ulong              GetMagic(void)            const;
   int                GetFastMAHandle(void)     const;
   int                GetSlowMAHandle(void)     const;
   ulong              GetLastTicket(void)       const;
   void               SetLastTicket(ulong ticket);
   long               GetTickCount(void)        const;
   long               GetStateEntryTick(void)   const;
   int                GetPendingDirection(void) const;
   void               SetPendingDirection(int direction);

   //--- Implemented in StrategyContextImpl.mqh (return types need full definitions)
   CIdleState        *GetIdleState(void)        const;
   CEntryState       *GetEntryState(void)       const;
   CInTradeState     *GetInTradeState(void)     const;
   CExitState        *GetExitState(void)        const;
  };

//+------------------------------------------------------------------+
//| Drive current state evaluation sequence logic                    |
//+------------------------------------------------------------------+
void CStrategyContext::Update(void)
  {
   m_tick_count++;
   if(CheckPointer(m_current_state) == POINTER_DYNAMIC)
     {
      m_current_state.Evaluate(&this);
     }
  }

//+------------------------------------------------------------------+
//| Safe sequential processing of transitions between distinct states|
//+------------------------------------------------------------------+
void CStrategyContext::SetState(IState *next_state)
  {
   if(next_state == NULL)
      return;

   if(next_state == m_current_state)
      return;

   string from_name = m_current_state.GetStateName();
   string to_name   = next_state.GetStateName();

   m_current_state.OnExit(&this);
   m_current_state    = next_state;
   m_state_entry_tick = m_tick_count;
   m_current_state.OnEnter(&this);

   PrintFormat("[CStrategyContext] Transition: %s -> %s | Tick: %s",
               from_name, to_name, IntegerToString(m_tick_count));
  }

//+------------------------------------------------------------------+
//| Get the unique enumeration token of the current active state    |
//+------------------------------------------------------------------+
ENUM_STRATEGY_STATE CStrategyContext::GetCurrentStateId(void) const
  {
   return(m_current_state.GetStateId());
  }

//+------------------------------------------------------------------+
//| Get the human-readable text label of the current active state    |
//+------------------------------------------------------------------+
string CStrategyContext::GetCurrentStateName(void) const
  {
   return(m_current_state.GetStateName());
  }

//+------------------------------------------------------------------+
//| Scalar Accessors Implementations                                 |
//+------------------------------------------------------------------+
string CStrategyContext::GetSymbol(void) const
  {
   return(m_symbol);
  }

ulong CStrategyContext::GetMagic(void) const
  {
   return(m_magic);
  }

int CStrategyContext::GetFastMAHandle(void) const
  {
   return(m_ma_fast_handle);
  }

int CStrategyContext::GetSlowMAHandle(void) const
  {
   return(m_ma_slow_handle);
  }

ulong CStrategyContext::GetLastTicket(void) const
  {
   return(m_last_ticket);
  }

long CStrategyContext::GetTickCount(void) const
  {
   return(m_tick_count);
  }

long CStrategyContext::GetStateEntryTick(void) const
  {
   return(m_state_entry_tick);
  }

int CStrategyContext::GetPendingDirection(void) const
  {
   return(m_pending_direction);
  }

void CStrategyContext::SetLastTicket(ulong ticket)
  {
   m_last_ticket = ticket;
  }

void CStrategyContext::SetPendingDirection(int direction)
  {
   m_pending_direction = direction;
  }

#endif // STRATEGYCONTEXT_MQH
//+------------------------------------------------------------------+