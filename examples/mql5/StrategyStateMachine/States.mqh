//+------------------------------------------------------------------+
//|                                                       States.mqh |
//| Concrete FSM state implementations:                              |
//|    CIdleState     - awaiting entry signal                        |
//|    CEntryState    - order submission and fill confirmation       |
//|    CInTradeState  - position monitoring and trailing stop        |
//|    CExitState     - position close and confirmation              |
//|                                                                  |
//| This file includes StrategyContext.mqh so that CStrategyContext  |
//| is fully declared before any state method body references it.    |
//| Do not include this file directly from the EA; include           |
//| StrategyContextImpl.mqh which manages the full chain.            |
//+------------------------------------------------------------------+
#ifndef STATES_MQH
#define STATES_MQH

#include "StrategyContext.mqh"

//+------------------------------------------------------------------+
//| Class CIdleState                                                 |
//| Purpose: Represents the market scanning and entry wait state     |
//+------------------------------------------------------------------+
class CIdleState : public IState
  {
private:
   double            m_last_fast_ma;   // Previous bar fast MA value for crossover detection
   double            m_last_slow_ma;   // Previous bar slow MA value for crossover detection

public:
                     CIdleState(void);
   virtual void      OnEnter(CStrategyContext *ctx);
   virtual void      Evaluate(CStrategyContext *ctx);
   virtual void      OnExit(CStrategyContext *ctx);
   virtual ENUM_STRATEGY_STATE GetStateId(void)   const { return(STATE_IDLE); }
   virtual string    GetStateName(void) const { return("CIdleState"); }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CIdleState::CIdleState(void) : m_last_fast_ma(0.0),
                               m_last_slow_ma(0.0)
  {
  }

//+------------------------------------------------------------------+
//| Actions performed when entering the Idle state                   |
//+------------------------------------------------------------------+
void CIdleState::OnEnter(CStrategyContext *ctx)
  {
   m_last_fast_ma = 0.0;
   m_last_slow_ma = 0.0;
   Print("[CIdleState] Entered. Awaiting entry signal.");
  }

//+------------------------------------------------------------------+
//| Core evaluation loop tracking technical indicator crossovers     |
//+------------------------------------------------------------------+
void CIdleState::Evaluate(CStrategyContext *ctx)
  {
   string symbol = ctx.GetSymbol();

   //--- Retrieve two bars of each MA to detect crossover
   double fast_buf[2], slow_buf[2];
   if(CopyBuffer(ctx.GetFastMAHandle(), 0, 0, 2, fast_buf) < 2 ||
      CopyBuffer(ctx.GetSlowMAHandle(), 0, 0, 2, slow_buf) < 2)
     {
      return;
     }

   double fast_curr = fast_buf[0];
   double slow_curr = slow_buf[0];
   double fast_prev = fast_buf[1];
   double slow_prev = slow_buf[1];

   //--- Guard: ensure no existing position with this magic number exists
   bool position_exists = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetSymbol(i) == symbol &&
         PositionGetInteger(POSITION_MAGIC) == (long)ctx.GetMagic())
        {
         position_exists = true;
         break;
        }
     }
   if(position_exists)
     {
      return;
     }

   //--- Guard: spread within tolerance (200 points maximum)
   long spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(spread > 200)
     {
      return;
     }

   //--- Detect Moving Average technical crossover signals
   bool long_signal  = (fast_prev <= slow_prev && fast_curr > slow_curr);
   bool short_signal = (fast_prev >= slow_prev && fast_curr < slow_curr);

   if(long_signal)
     {
      ctx.SetPendingDirection(1);
      ctx.SetState(ctx.GetEntryState());
     }
   else if(short_signal)
     {
      ctx.SetPendingDirection(-1);
      ctx.SetState(ctx.GetEntryState());
     }
  }

//+------------------------------------------------------------------+
//| Actions performed when exiting the Idle state                    |
//+------------------------------------------------------------------+
void CIdleState::OnExit(CStrategyContext *ctx)
  {
   Print("[CIdleState] Exiting. Direction set: " + IntegerToString(ctx.GetPendingDirection()));
  }

//+------------------------------------------------------------------+
//| Class CEntryState                                                |
//| Purpose: Processes trade order execution and fill confirmation   |
//+------------------------------------------------------------------+
class CEntryState : public IState
  {
private:
   bool              m_order_submitted; // True once the entry order has been sent
   int               m_retry_count;     // Number of fill-confirmation ticks elapsed

public:
                     CEntryState(void);
   virtual void      OnEnter(CStrategyContext *ctx);
   virtual void      Evaluate(CStrategyContext *ctx);
   virtual void      OnExit(CStrategyContext *ctx);
   virtual ENUM_STRATEGY_STATE GetStateId(void)   const { return(STATE_ENTRY); }
   virtual string    GetStateName(void) const { return("CEntryState"); }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CEntryState::CEntryState(void) : m_order_submitted(false),
                                 m_retry_count(0)
  {
  }

//+------------------------------------------------------------------+
//| Submits order execution details upon state entry                 |
//+------------------------------------------------------------------+
void CEntryState::OnEnter(CStrategyContext *ctx)
  {
   m_order_submitted = false;
   m_retry_count     = 0;

   string symbol    = ctx.GetSymbol();
   int    direction = ctx.GetPendingDirection();

   double ask   = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid   = SymbolInfoDouble(symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

   double price = (direction == 1) ? ask : bid;
   double sl    = (direction == 1) ? price - 500 * point : price + 500 * point;
   double tp    = (direction == 1) ? price + 1000 * point : price - 1000 * point;

   MqlTradeRequest      request = {};
   MqlTradeResult       result  = {};
   MqlTradeCheckResult  check   = {};

   request.action       = TRADE_ACTION_DEAL;
   request.symbol       = symbol;
   request.volume       = 0.01;
   request.type         = (direction == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price        = price;
   request.sl           = sl;
   request.tp           = tp;
   request.deviation    = 10;
   request.magic        = ctx.GetMagic();
   request.comment      = "FSM Entry [" + IntegerToString(direction) + "]";
   request.type_filling = ORDER_FILLING_IOC;

   if(!OrderCheck(request, check))
     {
      PrintFormat("[CEntryState] OrderCheck failed. Retcode: %s. Reverting to idle.",
                  IntegerToString(check.retcode));
      ctx.SetPendingDirection(0);
      ctx.SetState(ctx.GetIdleState());
      return;
     }

   if(OrderSend(request, result))
     {
      ctx.SetLastTicket(result.deal);
      m_order_submitted = true;
      PrintFormat("[CEntryState] Order submitted. Deal: %s | Price: %s",
                  IntegerToString((int)result.deal),
                  DoubleToString(result.price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
     }
   else
     {
      PrintFormat("[CEntryState] OrderSend failed. Retcode: %s. Reverting to idle.",
                  IntegerToString(result.retcode));
      ctx.SetPendingDirection(0);
      ctx.SetState(ctx.GetIdleState());
     }
  }

//+------------------------------------------------------------------+
//| Monitors transaction confirmations or tracks expiration timeouts |
//+------------------------------------------------------------------+
void CEntryState::Evaluate(CStrategyContext *ctx)
  {
   if(!m_order_submitted)
     {
      return;
     }

   m_retry_count++;
   string symbol = ctx.GetSymbol();

   //--- Check for confirmed fill: position with correct magic exists
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetSymbol(i) == symbol &&
         PositionGetInteger(POSITION_MAGIC) == (long)ctx.GetMagic())
        {
         Print("[CEntryState] Fill confirmed. Transitioning to CInTradeState.");
         ctx.SetState(ctx.GetInTradeState());
         return;
        }
     }

   //--- Timeout after 10 ticks without fill confirmation
   if(m_retry_count >= 10)
     {
      Print("[CEntryState] Fill timeout. Reverting to CIdleState.");
      ctx.SetPendingDirection(0);
      ctx.SetState(ctx.GetIdleState());
     }
  }

//+------------------------------------------------------------------+
//| Actions performed when exiting the Entry state                   |
//+------------------------------------------------------------------+
void CEntryState::OnExit(CStrategyContext *ctx)
  {
   Print("[CEntryState] Exiting entry phase.");
  }

//+------------------------------------------------------------------+
//| Class CInTradeState                                              |
//| Purpose: Manages live positions and trailing stop mechanisms     |
//+------------------------------------------------------------------+
class CInTradeState : public IState
  {
private:
   double            m_trailing_activation;  // Profit in points to activate trailing stop
   double            m_trailing_distance;    // Trailing stop distance in points

public:
                     CInTradeState(void);
   virtual void      OnEnter(CStrategyContext *ctx);
   virtual void      Evaluate(CStrategyContext *ctx);
   virtual void      OnExit(CStrategyContext *ctx);
   virtual ENUM_STRATEGY_STATE GetStateId(void)   const { return(STATE_IN_TRADE); }
   virtual string    GetStateName(void) const { return("CInTradeState"); }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CInTradeState::CInTradeState(void) : m_trailing_activation(300.0),
                                     m_trailing_distance(150.0)
  {
  }

//+------------------------------------------------------------------+
//| Actions performed when entering the InTrade state                |
//+------------------------------------------------------------------+
void CInTradeState::OnEnter(CStrategyContext *ctx)
  {
   Print("[CInTradeState] Entered. Monitoring open position.");
  }

//+------------------------------------------------------------------+
//| Analyzes market adjustments to apply active trailing mitigations |
//+------------------------------------------------------------------+
void CInTradeState::Evaluate(CStrategyContext *ctx)
  {
   string symbol = ctx.GetSymbol();
   ulong  magic  = ctx.GetMagic();
   bool   found  = false;

   //--- Locate the managed position
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetSymbol(i) != symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)magic)
         continue;

      found = true;
      double open_price  = PositionGetDouble(POSITION_PRICE_OPEN);
      double current_sl  = PositionGetDouble(POSITION_SL);
      double current_bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double current_ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double point       = SymbolInfoDouble(symbol, SYMBOL_POINT);
      long   pos_type    = PositionGetInteger(POSITION_TYPE);
      ulong  pos_ticket  = (ulong)PositionGetInteger(POSITION_TICKET);

      //--- Check MA crossover for exit signal
      double fast_buf[2], slow_buf[2];
      if(CopyBuffer(ctx.GetFastMAHandle(), 0, 0, 2, fast_buf) >= 2 &&
         CopyBuffer(ctx.GetSlowMAHandle(), 0, 0, 2, slow_buf) >= 2)
        {
         bool exit_long  = (pos_type == POSITION_TYPE_BUY  &&
                            fast_buf[0] < slow_buf[0] &&
                            fast_buf[1] >= slow_buf[1]);
         bool exit_short = (pos_type == POSITION_TYPE_SELL &&
                            fast_buf[0] > slow_buf[0] &&
                            fast_buf[1] <= slow_buf[1]);

         if(exit_long || exit_short)
           {
            Print("[CInTradeState] Exit signal detected. Transitioning to CExitState.");
            ctx.SetState(ctx.GetExitState());
            return;
           }
        }

      //--- Trailing stop update for long position
      if(pos_type == POSITION_TYPE_BUY)
        {
         double profit_points = (current_bid - open_price) / point;
         if(profit_points >= m_trailing_activation)
           {
            double new_sl = current_bid - m_trailing_distance * point;
            if(new_sl > current_sl + point)
              {
               MqlTradeRequest req = {};
               MqlTradeResult  res = {};
               req.action   = TRADE_ACTION_SLTP;
               req.symbol   = symbol;
               req.sl       = new_sl;
               req.tp       = PositionGetDouble(POSITION_TP);
               req.position = pos_ticket;
               if(OrderSend(req, res))
                 {
                  PrintFormat("[CInTradeState] Trailing SL updated to: %s",
                              DoubleToString(new_sl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
                 }
              }
           }
        }

      //--- Trailing stop update for short position
      if(pos_type == POSITION_TYPE_SELL)
        {
         double profit_points = (open_price - current_ask) / point;
         if(profit_points >= m_trailing_activation)
           {
            double new_sl = current_ask + m_trailing_distance * point;
            if(new_sl < current_sl - point || current_sl == 0.0)
              {
               MqlTradeRequest req = {};
               MqlTradeResult  res = {};
               req.action   = TRADE_ACTION_SLTP;
               req.symbol   = symbol;
               req.sl       = new_sl;
               req.tp       = PositionGetDouble(POSITION_TP);
               req.position = pos_ticket;
               if(OrderSend(req, res))
                 {
                  PrintFormat("[CInTradeState] Trailing SL updated to: %s",
                              DoubleToString(new_sl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
                 }
              }
           }
        }
      break;
     }

   //--- Position closed externally: transition to idle without exit state
   if(!found)
     {
      Print("[CInTradeState] Position closed externally. Transitioning to CIdleState.");
      ctx.SetState(ctx.GetIdleState());
     }
  }

//+------------------------------------------------------------------+
//| Actions performed when exiting the InTrade state                 |
//+------------------------------------------------------------------+
void CInTradeState::OnExit(CStrategyContext *ctx)
  {
   Print("[CInTradeState] Exiting trade monitoring phase.");
  }

//+------------------------------------------------------------------+
//| Class CExitState                                                 |
//| Purpose: Handles position teardown and liquidations securely     |
//+------------------------------------------------------------------+
class CExitState : public IState
  {
private:
   int               m_close_attempts;  // Number of close order submission attempts
   int               m_max_attempts;    // Maximum allowed close attempts before fallback

public:
                     CExitState(void);
   virtual void      OnEnter(CStrategyContext *ctx);
   virtual void      Evaluate(CStrategyContext *ctx);
   virtual void      OnExit(CStrategyContext *ctx);
   virtual ENUM_STRATEGY_STATE GetStateId(void)   const { return(STATE_EXIT); }
   virtual string    GetStateName(void) const { return("CExitState"); }

private:
   void              SubmitClose(CStrategyContext *ctx);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CExitState::CExitState(void) : m_close_attempts(0),
                               m_max_attempts(5)
  {
  }

//+------------------------------------------------------------------+
//| Actions performed when entering the Exit state                   |
//+------------------------------------------------------------------+
void CExitState::OnEnter(CStrategyContext *ctx)
  {
   m_close_attempts = 0;
   Print("[CExitState] Entered. Submitting close order.");
   SubmitClose(ctx);
  }

//+------------------------------------------------------------------+
//| Dispatches raw order liquidations into the trade execution queue |
//+------------------------------------------------------------------+
void CExitState::SubmitClose(CStrategyContext *ctx)
  {
   string symbol = ctx.GetSymbol();
   ulong  magic  = ctx.GetMagic();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetSymbol(i) != symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)magic)
         continue;

      long   pos_type   = PositionGetInteger(POSITION_TYPE);
      double volume     = PositionGetDouble(POSITION_VOLUME);
      ulong  pos_ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      double price      = (pos_type == POSITION_TYPE_BUY)
                          ? SymbolInfoDouble(symbol, SYMBOL_BID)
                          : SymbolInfoDouble(symbol, SYMBOL_ASK);

      MqlTradeRequest request = {};
      MqlTradeResult  result  = {};

      request.action       = TRADE_ACTION_DEAL;
      request.symbol       = symbol;
      request.volume       = volume;
      request.type         = (pos_type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      request.price        = price;
      request.deviation    = 10;
      request.magic        = magic;
      request.position     = pos_ticket;
      request.comment      = "FSM Exit";
      request.type_filling = ORDER_FILLING_IOC;

      m_close_attempts++;

      if(OrderSend(request, result))
        {
         PrintFormat("[CExitState] Close order submitted. Deal: %s",
                     IntegerToString((int)result.deal));
        }
      else
        {
         PrintFormat("[CExitState] Close order failed. Retcode: %s | Attempt: %s",
                     IntegerToString(result.retcode),
                     IntegerToString(m_close_attempts));
        }
      return;
     }
  }

//+------------------------------------------------------------------+
//| Verifies closing status and executes retries if required         |
//+------------------------------------------------------------------+
void CExitState::Evaluate(CStrategyContext *ctx)
  {
   string symbol = ctx.GetSymbol();
   ulong  magic  = ctx.GetMagic();

   //--- Check whether position has been closed
   bool still_open = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetSymbol(i) == symbol &&
         PositionGetInteger(POSITION_MAGIC) == (long)magic)
        {
         still_open = true;
         break;
        }
     }

   if(!still_open)
     {
      Print("[CExitState] Position confirmed closed. Transitioning to CIdleState.");
      ctx.SetPendingDirection(0);
      ctx.SetState(ctx.GetIdleState());
      return;
     }

   //--- Retry close if position still open and under attempt limit
   if(m_close_attempts < m_max_attempts)
     {
      Print("[CExitState] Position still open. Retrying close.");
      SubmitClose(ctx);
     }
   else
     {
      //--- Max retries exhausted: return to monitoring to avoid orphaned position
      Print("[CExitState] Max close attempts reached. Returning to CInTradeState.");
      ctx.SetState(ctx.GetInTradeState());
     }
  }

//+------------------------------------------------------------------+
//| Actions performed when exiting the Exit state                    |
//+------------------------------------------------------------------+
void CExitState::OnExit(CStrategyContext *ctx)
  {
   Print("[CExitState] Exiting close phase.");
  }

#endif // STATES_MQH
//+------------------------------------------------------------------+