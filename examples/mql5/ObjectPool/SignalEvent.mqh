//+------------------------------------------------------------------+
//|                                                  SignalEvent.mqh |
//| CSignalEvent: poolable signal payload class.                     |
//| Implements the pool contract: Reset(), SetPooled(), IsPooled(),  |
//| SetPoolIndex(), GetPoolIndex(), SetInUse(), IsInUse().           |
//| Carries direction, reference price, strength, and timestamp      |
//| for one signal computation result.                               |
//|                                                                  |
//| Design note on Reset():                                          |
//|  Reset() clears ONLY business-state payload fields. Pool         |
//|  ownership metadata (m_is_pooled, m_pool_index, m_in_use) is     |
//|  managed exclusively by CObjectPool<T> and is NOT touched by     |
//|  Reset(). This separation keeps payload logic independent of     |
//|  the memory manager, and prevents Reset() from accidentally      |
//|  overwriting lifecycle state the pool depends on.                |
//+------------------------------------------------------------------+
#ifndef SIGNALEVENT_MQH
#define SIGNALEVENT_MQH

//+------------------------------------------------------------------+
//| Class CSignalEvent                                               |
//| Purpose: Encapsulates signal attributes with object-pool tracking|
//+------------------------------------------------------------------+
class CSignalEvent
  {
private:
   //--- Business-state payload (cleared by Reset())
   int               m_direction;    // Signal direction: 1 long, -1 short, 0 neutral
   double            m_price;        // Reference price at signal generation time
   double            m_strength;     // Normalized signal strength (0.0 to 1.0)
   datetime          m_timestamp;    // Server time at point of signal computation

   //--- Pool lifecycle metadata (NOT touched by Reset())
   bool              m_is_pooled;    // True when object was pre-allocated by a pool
   int               m_pool_index;   // Slot index inside the pool's m_objects[] array
   bool              m_in_use;       // True when the object has been Acquire()'d

public:
                     CSignalEvent(void);
                    ~CSignalEvent(void) {}

   //--- Pool contract: payload reset
   void              Reset(void);

   //--- Pool contract: ownership flag
   void              SetPooled(bool is_pooled);
   bool              IsPooled(void) const;

   //--- Pool contract: slot index (enables O(1) release without membership scan)
   void              SetPoolIndex(int index);
   int               GetPoolIndex(void) const;

   //--- Pool contract: in-use guard (double-release protection)
   void              SetInUse(bool in_use);
   bool              IsInUse(void) const;

   //--- Payload setters
   void              SetDirection(int direction);
   void              SetPrice(double price);
   void              SetStrength(double strength);
   void              SetTimestamp(datetime ts);

   //--- Payload getters
   int               GetDirection(void)  const;
   double            GetPrice(void)      const;
   double            GetStrength(void)   const;
   datetime          GetTimestamp(void)  const;
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSignalEvent::CSignalEvent(void)
  {
//--- Initialize payload to default state
   Reset();

//--- Initialize pool metadata to safe defaults.
//--- CObjectPool<T> will overwrite these immediately after construction
//--- via SetPooled(), SetPoolIndex(), and SetInUse().
   m_is_pooled  = false;
   m_pool_index = -1;
   m_in_use     = false;
  }

//+------------------------------------------------------------------+
//| Reset business-state payload fields to defaults for pool reuse.  |
//| Does NOT touch m_is_pooled, m_pool_index, or m_in_use.           |
//| Pool ownership metadata is the pool's responsibility, not the    |
//| object's payload logic.                                          |
//+------------------------------------------------------------------+
void CSignalEvent::Reset(void)
  {
   m_direction = 0;
   m_price     = 0.0;
   m_strength  = 0.0;
   m_timestamp = 0;
//--- m_is_pooled, m_pool_index, and m_in_use are intentionally NOT reset here.
//--- Pool lifecycle metadata is managed exclusively by CObjectPool<T>.
  }

//+------------------------------------------------------------------+
//| Set pool ownership flag                                          |
//+------------------------------------------------------------------+
void CSignalEvent::SetPooled(bool is_pooled)
  {
   m_is_pooled = is_pooled;
  }

//+------------------------------------------------------------------+
//| Check if object belongs to a pool instance                       |
//+------------------------------------------------------------------+
bool CSignalEvent::IsPooled(void) const
  {
   return(m_is_pooled);
  }

//+------------------------------------------------------------------+
//| Store slot index for O(1) release                                |
//+------------------------------------------------------------------+
void CSignalEvent::SetPoolIndex(int index)
  {
   m_pool_index = index;
  }

//+------------------------------------------------------------------+
//| Retrieve slot index for O(1) release                             |
//+------------------------------------------------------------------+
int CSignalEvent::GetPoolIndex(void) const
  {
   return(m_pool_index);
  }

//+------------------------------------------------------------------+
//| Set in-use flag (guards against double-release)                  |
//+------------------------------------------------------------------+
void CSignalEvent::SetInUse(bool in_use)
  {
   m_in_use = in_use;
  }

//+------------------------------------------------------------------+
//| Check if object is currently acquired (not yet released)         |
//+------------------------------------------------------------------+
bool CSignalEvent::IsInUse(void) const
  {
   return(m_in_use);
  }

//+------------------------------------------------------------------+
//| Set signal direction                                             |
//+------------------------------------------------------------------+
void CSignalEvent::SetDirection(int direction)
  {
   m_direction = direction;
  }

//+------------------------------------------------------------------+
//| Set baseline reference price                                     |
//+------------------------------------------------------------------+
void CSignalEvent::SetPrice(double price)
  {
   m_price = price;
  }

//+------------------------------------------------------------------+
//| Set normalized signal strength                                   |
//+------------------------------------------------------------------+
void CSignalEvent::SetStrength(double strength)
  {
   m_strength = strength;
  }

//+------------------------------------------------------------------+
//| Set generation timestamp                                         |
//+------------------------------------------------------------------+
void CSignalEvent::SetTimestamp(datetime ts)
  {
   m_timestamp = ts;
  }

//+------------------------------------------------------------------+
//| Get signal direction                                             |
//+------------------------------------------------------------------+
int CSignalEvent::GetDirection(void) const
  {
   return(m_direction);
  }

//+------------------------------------------------------------------+
//| Get reference price                                              |
//+------------------------------------------------------------------+
double CSignalEvent::GetPrice(void) const
  {
   return(m_price);
  }

//+------------------------------------------------------------------+
//| Get signal strength coefficient                                  |
//+------------------------------------------------------------------+
double CSignalEvent::GetStrength(void) const
  {
   return(m_strength);
  }

//+------------------------------------------------------------------+
//| Get generation timestamp                                         |
//+------------------------------------------------------------------+
datetime CSignalEvent::GetTimestamp(void) const
  {
   return(m_timestamp);
  }

#endif // SIGNALEVENT_MQH

//+------------------------------------------------------------------+