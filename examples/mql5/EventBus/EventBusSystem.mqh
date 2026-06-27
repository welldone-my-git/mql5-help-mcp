//+------------------------------------------------------------------+
//|  EventBusSystem.mqh                                              |
//|  Consolidated include file for the CEventBus publish-subscribe   |
//|  architecture. Contains all type definitions, interfaces, the    |
//|  bus implementation, and all three EA component modules.         |
//|                                                                  |
//|  Include order within this file is significant:                  |
//|    1. Enum and struct definitions (no dependencies)              |
//|    2. IEventListener abstract base (depends on struct)           |
//|    3. CEventBus (depends on IEventListener)                      |
//|    4. CSignalEngine (depends on CEventBus)                       |
//|    5. COrderManager (depends on CEventBus + IEventListener)      |
//|    6. CDrawdownMonitor (depends on CEventBus + IEventListener)   |
//+------------------------------------------------------------------+
#ifndef EVENTBUSSYSTEM_MQH
#define EVENTBUSSYSTEM_MQH

//--- Event type enumeration: used as routing key in CEventBus
enum ENUM_EA_EVENT
  {
   EA_EVENT_SIGNAL_LONG    = 0,  // Signal: Market Long Condition Detected
   EA_EVENT_SIGNAL_SHORT   = 1,  // Signal: Market Short Condition Detected
   EA_EVENT_SIGNAL_FLAT    = 2,  // Signal: No Active Directional Bias
   EA_EVENT_ORDER_FILL     = 3,  // Execution: Order Fill Confirmed
   EA_EVENT_ORDER_REJECT   = 4,  // Execution: Order Rejected by Broker
   EA_EVENT_DRAWDOWN_WARN  = 5,  // Risk: Drawdown Warning Threshold Crossed
   EA_EVENT_DRAWDOWN_HALT  = 6,  // Risk: Hard Drawdown Limit Reached
   EA_EVENT_SESSION_OPEN   = 7,  // Session: Market Session Begin
   EA_EVENT_SESSION_CLOSE  = 8   // Session: Market Session End
  };

//--- Total number of distinct event types (used to size subscription table)
#define EA_EVENT_COUNT 9

//+------------------------------------------------------------------+
//|  SEventPayload                                                   |
//|  Fixed-layout event record passed by const reference at          |
//|  dispatch time. Stack-allocatable; no heap allocation required   |
//|  for numeric payloads. String field may be left empty for        |
//|  high-frequency event paths to avoid allocation overhead.        |
//+------------------------------------------------------------------+
struct SEventPayload
  {
   ENUM_EA_EVENT     event_type;       // Routing key identifying the event class
   datetime          timestamp;        // Server time at point of publication
   long              order_ticket;     // Position/order ticket (0 if not applicable)
   double            value_primary;    // Primary numeric payload (price, drawdown %, etc.)
   double            value_secondary;  // Secondary numeric payload (volume, SL level, etc.)
   string            message;          // Human-readable diagnostic string (optional)
  };

//+------------------------------------------------------------------+
//| Listener Interface                                               |
//+------------------------------------------------------------------+
class IEventListener
  {
public:
   //--- Pure virtual dispatch method. Payload is passed by const reference
   //    to avoid copying the structure onto each listener's stack frame.
   virtual void      OnEvent(const SEventPayload &payload) = 0;

   //--- Virtual destructor ensures correct destruction through base pointer.
   virtual          ~IEventListener() {}
  };

//+------------------------------------------------------------------+
//|  Subscription Slot Wrapper                                       |
//|  MQL5 does not support two-dimensional dynamic pointer arrays    |
//|  (IEventListener*[][]) directly. A thin wrapper struct holds     |
//|  one dynamic pointer array per event slot, and the bus           |
//|  maintains a fixed-length array of these wrapper objects.        |
//+------------------------------------------------------------------+
struct SListenerSlot
  {
   IEventListener    *listeners[];  // Dynamic array of subscriber pointers for one event type
   int               count;         // Active subscriber count in this slot

                     SListenerSlot() : count(0) { ArrayResize(listeners,0); }
  };

//+------------------------------------------------------------------+
//|   Event Bus                                                      |
//+------------------------------------------------------------------+
class CEventBus
  {
private:
   //--- One slot wrapper per event type, indexed by ENUM_EA_EVENT value.
   SListenerSlot     m_slots[EA_EVENT_COUNT];

   //--- Logging flag: when true, dispatch activity is printed to the journal.
   bool              m_logging_enabled;

public:
                     CEventBus(bool enable_logging=false);
                    ~CEventBus();

   bool              Subscribe(ENUM_EA_EVENT event_type,IEventListener *listener);
   bool              Unsubscribe(ENUM_EA_EVENT event_type,IEventListener *listener);
   void              Publish(const SEventPayload &payload);
   int               SubscriberCount(ENUM_EA_EVENT event_type) const;
   void              Clear();
  };

//+------------------------------------------------------------------+
//|  Constructor                                                     |
//+------------------------------------------------------------------+
CEventBus::CEventBus(bool enable_logging=false)
   : m_logging_enabled(enable_logging)
  {
// Slots are zero-initialised by SListenerSlot default constructor
  }

//+------------------------------------------------------------------+
//|  Destructor                                                      |
//+------------------------------------------------------------------+
CEventBus::~CEventBus()
  {
   Clear();
  }

//+------------------------------------------------------------------+
//|  Subscribe                                                       |
//+------------------------------------------------------------------+
bool CEventBus::Subscribe(ENUM_EA_EVENT event_type,IEventListener *listener)
  {
   if(listener == NULL)
     {
      PrintFormat("[CEventBus] Subscribe failed: null listener pointer for event %d.",(int)event_type);
      return(false);
     }

   int slot = (int)event_type;
   if(slot < 0 || slot >= EA_EVENT_COUNT)
     {
      PrintFormat("[CEventBus] Subscribe failed: event type %d out of range.",slot);
      return(false);
     }

//--- Check for duplicate registration
   for(int i=0; i<m_slots[slot].count; i++)
     {
      if(m_slots[slot].listeners[i] == listener)
        {
         if(m_logging_enabled)
            PrintFormat("[CEventBus] Subscribe skipped: listener already registered for event %d.",slot);
         return(false);
        }
     }

   int new_count = m_slots[slot].count + 1;
   ArrayResize(m_slots[slot].listeners,new_count);
   m_slots[slot].listeners[m_slots[slot].count] = listener;
   m_slots[slot].count = new_count;

   if(m_logging_enabled)
      PrintFormat("[CEventBus] Subscribed: listener registered for event %d. Total: %d.",slot,new_count);

   return(true);
  }

//+------------------------------------------------------------------+
//|  Unsubscribe                                                     |
//+------------------------------------------------------------------+
bool CEventBus::Unsubscribe(ENUM_EA_EVENT event_type,IEventListener *listener)
  {
   int slot = (int)event_type;
   if(slot < 0 || slot >= EA_EVENT_COUNT)
      return(false);

   for(int i=0; i<m_slots[slot].count; i++)
     {
      if(m_slots[slot].listeners[i] == listener)
        {
         //--- Compact the array by shifting remaining elements left
         for(int j=i; j<m_slots[slot].count-1; j++)
            m_slots[slot].listeners[j] = m_slots[slot].listeners[j+1];

         m_slots[slot].count--;
         ArrayResize(m_slots[slot].listeners,m_slots[slot].count);

         if(m_logging_enabled)
            PrintFormat("[CEventBus] Unsubscribed: listener removed from event %d. Remaining: %d.",
                        slot,m_slots[slot].count);
         return(true);
        }
     }

   return(false);
  }

//+------------------------------------------------------------------+
//|  Publish                                                         |
//+------------------------------------------------------------------+
void CEventBus::Publish(const SEventPayload &payload)
  {
   int slot = (int)payload.event_type;
   if(slot < 0 || slot >= EA_EVENT_COUNT)
     {
      PrintFormat("[CEventBus] Publish failed: event type %d out of range.",slot);
      return;
     }

   if(m_logging_enabled)
      PrintFormat("[CEventBus] Publishing event %d to %d subscriber(s).",slot,m_slots[slot].count);

   for(int i=0; i<m_slots[slot].count; i++)
     {
      IEventListener *listener = m_slots[slot].listeners[i];

      //--- Validate pointer before dispatch to guard against deleted objects.
      //    POINTER_DYNAMIC indicates a live heap object; anything else is unsafe.
      if(CheckPointer(listener) == POINTER_DYNAMIC)
        {
         listener.OnEvent(payload);
        }
      else
        {
         PrintFormat("[CEventBus] WARNING: Stale pointer detected in slot %d at index %d. "
                     "Skipping dispatch. Call Unsubscribe() before destroying listeners.",slot,i);
        }
     }
  }

//+------------------------------------------------------------------+
//|  SubscriberCount                                                 |
//+------------------------------------------------------------------+
int CEventBus::SubscriberCount(ENUM_EA_EVENT event_type) const
  {
   int slot = (int)event_type;
   if(slot < 0 || slot >= EA_EVENT_COUNT)
      return(0);
   return(m_slots[slot].count);
  }

//+------------------------------------------------------------------+
//|  Clear                                                           |
//+------------------------------------------------------------------+
void CEventBus::Clear()
  {
   for(int i=0; i<EA_EVENT_COUNT; i++)
     {
      ArrayResize(m_slots[i].listeners,0);
      m_slots[i].count = 0;
     }

   if(m_logging_enabled)
      Print("[CEventBus] All subscriptions cleared.");
  }

//+------------------------------------------------------------------+
//| Signal Engine Component                                          |
//+------------------------------------------------------------------+
class CSignalEngine
  {
private:
   CEventBus         *m_bus;
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_ma_fast;
   int               m_ma_slow;
   int               m_handle_fast;
   int               m_handle_slow;
   ENUM_EA_EVENT     m_last_signal;

public:
                     CSignalEngine(CEventBus *bus,const string &symbol,
                                   ENUM_TIMEFRAMES tf,int fast_period,int slow_period);
                    ~CSignalEngine();

   bool              Initialize();
   void              Evaluate();
  };

//+------------------------------------------------------------------+
//|  Constructor                                                     |
//+------------------------------------------------------------------+
CSignalEngine::CSignalEngine(CEventBus *bus,const string &symbol,
                             ENUM_TIMEFRAMES tf,int fast_period,int slow_period)
   : m_bus(bus),
     m_symbol(symbol),
     m_timeframe(tf),
     m_ma_fast(fast_period),
     m_ma_slow(slow_period),
     m_handle_fast(INVALID_HANDLE),
     m_handle_slow(INVALID_HANDLE),
     m_last_signal(EA_EVENT_SIGNAL_FLAT)
  {
  }

//+------------------------------------------------------------------+
//|  Destructor                                                      |
//+------------------------------------------------------------------+
CSignalEngine::~CSignalEngine()
  {
   if(m_handle_fast != INVALID_HANDLE)
      IndicatorRelease(m_handle_fast);
   if(m_handle_slow != INVALID_HANDLE)
      IndicatorRelease(m_handle_slow);
  }

//+------------------------------------------------------------------+
//|  Initialize                                                      |
//+------------------------------------------------------------------+
bool CSignalEngine::Initialize()
  {
   m_handle_fast = iMA(m_symbol,m_timeframe,m_ma_fast,0,MODE_EMA,PRICE_CLOSE);
   m_handle_slow = iMA(m_symbol,m_timeframe,m_ma_slow,0,MODE_EMA,PRICE_CLOSE);

   if(m_handle_fast == INVALID_HANDLE || m_handle_slow == INVALID_HANDLE)
     {
      Print("[CSignalEngine] Failed to create MA indicator handles. Check symbol and timeframe.");
      return(false);
     }

   return(true);
  }

//+------------------------------------------------------------------+
//|  Evaluate                                                        |
//+------------------------------------------------------------------+
void CSignalEngine::Evaluate()
  {
   if(m_bus == NULL || CheckPointer(m_bus) != POINTER_DYNAMIC)
      return;

   double fast_buf[2];
   double slow_buf[2];

   if(CopyBuffer(m_handle_fast,0,0,2,fast_buf) < 2 ||
      CopyBuffer(m_handle_slow,0,0,2,slow_buf) < 2)
     {
      Print("[CSignalEngine] Insufficient indicator data. Skipping evaluation.");
      return;
     }

   bool is_long  = (fast_buf[0] > slow_buf[0] && fast_buf[1] <= slow_buf[1]);
   bool is_short = (fast_buf[0] < slow_buf[0] && fast_buf[1] >= slow_buf[1]);

   ENUM_EA_EVENT signal = EA_EVENT_SIGNAL_FLAT;
   if(is_long)
      signal = EA_EVENT_SIGNAL_LONG;
   if(is_short)
      signal = EA_EVENT_SIGNAL_SHORT;

   if(signal == m_last_signal)
      return;

   m_last_signal = signal;

   SEventPayload payload;
   payload.event_type      = signal;
   payload.timestamp       = TimeCurrent();
   payload.order_ticket    = 0;
   payload.value_primary   = (fast_buf[0] + slow_buf[0]) / 2.0;
   payload.value_secondary = 0.0;
   payload.message         = "MA Crossover Signal [" + m_symbol + "]";

   m_bus.Publish(payload);
  }

//+------------------------------------------------------------------+
//| Order Manager Component                                          |
//+------------------------------------------------------------------+
class COrderManager : public IEventListener
  {
private:
   CEventBus         *m_bus;
   string            m_symbol;
   double            m_lot_size;
   double            m_sl_points;
   double            m_tp_points;
   ulong             m_magic;
   bool              m_trading_allowed;

public:
                     COrderManager(CEventBus *bus,const string &symbol,
                                   double lot_size,double sl_pts,double tp_pts,ulong magic);
                    ~COrderManager();

   virtual void      OnEvent(const SEventPayload &payload);

private:
   void              ProcessSignalLong(const SEventPayload &payload);
   void              ProcessSignalShort(const SEventPayload &payload);
   void              PublishFill(long ticket,double fill_price,double volume);
   void              PublishReject(double requested_price,double requested_volume,
                                   const string &reason);
  };

//+------------------------------------------------------------------+
//|  Constructor                                                     |
//+------------------------------------------------------------------+
COrderManager::COrderManager(CEventBus *bus,const string &symbol,
                             double lot_size,double sl_pts,double tp_pts,ulong magic)
   : m_bus(bus),
     m_symbol(symbol),
     m_lot_size(lot_size),
     m_sl_points(sl_pts),
     m_tp_points(tp_pts),
     m_magic(magic),
     m_trading_allowed(true)
  {
  }

//+------------------------------------------------------------------+
//|  Destructor                                                      |
//+------------------------------------------------------------------+
COrderManager::~COrderManager()
  {
  }

//+------------------------------------------------------------------+
//|  OnEvent                                                         |
//+------------------------------------------------------------------+
void COrderManager::OnEvent(const SEventPayload &payload)
  {
   switch((int)payload.event_type)
     {
      case EA_EVENT_SIGNAL_LONG:
         if(m_trading_allowed)
            ProcessSignalLong(payload);
         break;

      case EA_EVENT_SIGNAL_SHORT:
         if(m_trading_allowed)
            ProcessSignalShort(payload);
         break;

      case EA_EVENT_DRAWDOWN_HALT:
         m_trading_allowed = false;
         PrintFormat("[COrderManager] Trading halted by drawdown event. Reason: %s",payload.message);
         break;

      case EA_EVENT_SESSION_OPEN:
         m_trading_allowed = true;
         break;

      default:
         break;
     }
  }

//+------------------------------------------------------------------+
//|  ProcessSignalLong                                               |
//+------------------------------------------------------------------+
void COrderManager::ProcessSignalLong(const SEventPayload &payload)
  {
   MqlTradeRequest  request = {};
   MqlTradeResult   result  = {};

   double ask = SymbolInfoDouble(m_symbol,SYMBOL_ASK);
   double sl  = ask - m_sl_points * _Point;
   double tp  = ask + m_tp_points * _Point;

   request.action       = TRADE_ACTION_DEAL;
   request.symbol       = m_symbol;
   request.volume       = m_lot_size;
   request.type         = ORDER_TYPE_BUY;
   request.price        = ask;
   request.sl           = sl;
   request.tp           = tp;
   request.deviation    = 10;
   request.magic        = m_magic;
   request.comment      = "EventBus LONG";
   request.type_filling = ORDER_FILLING_IOC;

   if(OrderSend(request,result))
     {
      if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
         PublishFill((long)result.deal,result.price,result.volume);
      else
         PublishReject(ask,m_lot_size,StringFormat("Retcode: %d",(int)result.retcode));
     }
   else
     {
      PublishReject(ask,m_lot_size,StringFormat("OrderSend failed. Error: %d",GetLastError()));
     }
  }

//+------------------------------------------------------------------+
//|  ProcessSignalShort                                              |
//+------------------------------------------------------------------+
void COrderManager::ProcessSignalShort(const SEventPayload &payload)
  {
   MqlTradeRequest  request = {};
   MqlTradeResult   result  = {};

   double bid = SymbolInfoDouble(m_symbol,SYMBOL_BID);
   double sl  = bid + m_sl_points * _Point;
   double tp  = bid - m_tp_points * _Point;

   request.action       = TRADE_ACTION_DEAL;
   request.symbol       = m_symbol;
   request.volume       = m_lot_size;
   request.type         = ORDER_TYPE_SELL;
   request.price        = bid;
   request.sl           = sl;
   request.tp           = tp;
   request.deviation    = 10;
   request.magic        = m_magic;
   request.comment      = "EventBus SHORT";
   request.type_filling = ORDER_FILLING_IOC;

   if(OrderSend(request,result))
     {
      if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
         PublishFill((long)result.deal,result.price,result.volume);
      else
         PublishReject(bid,m_lot_size,StringFormat("Retcode: %d",(int)result.retcode));
     }
   else
     {
      PublishReject(bid,m_lot_size,StringFormat("OrderSend failed. Error: %d",GetLastError()));
     }
  }

//+------------------------------------------------------------------+
//|  PublishFill                                                     |
//+------------------------------------------------------------------+
void COrderManager::PublishFill(long ticket,double fill_price,double volume)
  {
   if(m_bus == NULL || CheckPointer(m_bus) != POINTER_DYNAMIC)
      return;

   SEventPayload ev;
   ev.event_type      = EA_EVENT_ORDER_FILL;
   ev.timestamp       = TimeCurrent();
   ev.order_ticket    = ticket;
   ev.value_primary   = fill_price;
   ev.value_secondary = volume;
   ev.message         = m_symbol;

   m_bus.Publish(ev);
  }

//+------------------------------------------------------------------+
//|  PublishReject                                                   |
//+------------------------------------------------------------------+
void COrderManager::PublishReject(double requested_price,double requested_volume,
                                  const string &reason)
  {
   if(m_bus == NULL || CheckPointer(m_bus) != POINTER_DYNAMIC)
      return;

   SEventPayload ev;
   ev.event_type      = EA_EVENT_ORDER_REJECT;
   ev.timestamp       = TimeCurrent();
   ev.order_ticket    = 0;
   ev.value_primary   = requested_price;
   ev.value_secondary = requested_volume;
   ev.message         = reason;

   m_bus.Publish(ev);
  }

//+------------------------------------------------------------------+
//| Drawndown Monitor Component                                      |
//+------------------------------------------------------------------+
class CDrawdownMonitor : public IEventListener
  {
private:
   CEventBus         *m_bus;
   double            m_warn_threshold_pct;
   double            m_halt_threshold_pct;
   double            m_session_equity_peak;
   bool              m_halt_published;

public:
                     CDrawdownMonitor(CEventBus *bus,double warn_pct,double halt_pct);
                    ~CDrawdownMonitor();

   virtual void      OnEvent(const SEventPayload &payload);
   void              Evaluate();
   void              ResetSession();
  };

//+------------------------------------------------------------------+
//|  Constructor                                                     |
//+------------------------------------------------------------------+
CDrawdownMonitor::CDrawdownMonitor(CEventBus *bus,double warn_pct,double halt_pct)
   : m_bus(bus),
     m_warn_threshold_pct(warn_pct),
     m_halt_threshold_pct(halt_pct),
     m_session_equity_peak(0.0),
     m_halt_published(false)
  {
   m_session_equity_peak = AccountInfoDouble(ACCOUNT_EQUITY);
  }

//+------------------------------------------------------------------+
//|  Destructor                                                      |
//+------------------------------------------------------------------+
CDrawdownMonitor::~CDrawdownMonitor()
  {
  }

//+------------------------------------------------------------------+
//|  OnEvent                                                         |
//+------------------------------------------------------------------+
void CDrawdownMonitor::OnEvent(const SEventPayload &payload)
  {
   switch((int)payload.event_type)
     {
      case EA_EVENT_ORDER_FILL:
        {
         double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
         if(current_equity > m_session_equity_peak)
            m_session_equity_peak = current_equity;
        }
      break;

      case EA_EVENT_SESSION_OPEN:
         ResetSession();
         break;

      default:
         break;
     }
  }

//+------------------------------------------------------------------+
//|  Evaluate                                                        |
//+------------------------------------------------------------------+
void CDrawdownMonitor::Evaluate()
  {
   if(m_bus == NULL || CheckPointer(m_bus) != POINTER_DYNAMIC)
      return;

   if(m_session_equity_peak <= 0.0)
      return;

   double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double drawdown_pct   = ((m_session_equity_peak - current_equity) / m_session_equity_peak) * 100.0;

   if(drawdown_pct <= 0.0)
     {
      m_session_equity_peak = current_equity;
      return;
     }

   if(drawdown_pct >= m_halt_threshold_pct && !m_halt_published)
     {
      m_halt_published = true;

      SEventPayload ev;
      ev.event_type      = EA_EVENT_DRAWDOWN_HALT;
      ev.timestamp       = TimeCurrent();
      ev.order_ticket    = 0;
      ev.value_primary   = drawdown_pct;
      ev.value_secondary = m_halt_threshold_pct;
      ev.message         = StringFormat("Equity %.2f / Peak %.2f - Hard limit %.1f%% reached.",
                                        current_equity,m_session_equity_peak,m_halt_threshold_pct);
      m_bus.Publish(ev);
      return;
     }

   if(drawdown_pct >= m_warn_threshold_pct && drawdown_pct < m_halt_threshold_pct)
     {
      SEventPayload ev;
      ev.event_type      = EA_EVENT_DRAWDOWN_WARN;
      ev.timestamp       = TimeCurrent();
      ev.order_ticket    = 0;
      ev.value_primary   = drawdown_pct;
      ev.value_secondary = m_warn_threshold_pct;
      ev.message         = StringFormat("Drawdown %.2f%% - Warning threshold %.1f%% crossed.",
                                        drawdown_pct,m_warn_threshold_pct);
      m_bus.Publish(ev);
     }
  }

//+------------------------------------------------------------------+
//|  ResetSession                                                    |
//+------------------------------------------------------------------+
void CDrawdownMonitor::ResetSession()
  {
   m_session_equity_peak = AccountInfoDouble(ACCOUNT_EQUITY);
   m_halt_published      = false;

   Print("[CDrawdownMonitor] Session reset. New equity peak: ",m_session_equity_peak);
  }

#endif // EVENTBUSSYSTEM_MQH
//+------------------------------------------------------------------+