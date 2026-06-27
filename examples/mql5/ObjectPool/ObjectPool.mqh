//+------------------------------------------------------------------+
//|                                                   ObjectPool.mqh |
//|  CObjectPool<T>: generic free-list object pool template.         |
//|  Pre-allocates a fixed capacity of T instances at construction.  |
//|  Acquire() is O(1) via integer index stack. Release() is O(1)    |
//|  because T must expose GetPoolIndex()/SetPoolIndex() so the      |
//|  slot index is carried by the object itself, eliminating the     |
//|  membership scan entirely.                                       |
//|                                                                  |
//| T must implement:                                                |
//|    void  Reset()              — clears payload to default state  |
//|    int   GetPoolIndex() const — returns stored slot index        |
//|    void  SetPoolIndex(int)    — stores the slot index            |
//|    void  SetInUse(bool)       — records in-use flag              |
//|    bool  IsInUse()    const   — returns in-use flag              |
//|    bool  IsPooled()   const   — returns pool ownership flag      |
//|    void  SetPooled(bool)      — records pool ownership flag      |
//+------------------------------------------------------------------+
#ifndef OBJECTPOOL_MQH
#define OBJECTPOOL_MQH

//+------------------------------------------------------------------+
//| Class CObjectPool                                                |
//| Purpose: Provides dynamic recycling memory pools for classes     |
//+------------------------------------------------------------------+
template<typename T>
class CObjectPool
  {
private:
   T                 *m_objects[];       // Pre-allocated object pointer array
   int                m_free_indices[];  // Index stack of available slot positions
   int                m_capacity;        // Total pool capacity set at construction
   int                m_free_count;      // Current number of available slots

public:
                      CObjectPool(int capacity);
                     ~CObjectPool(void);

   T                 *Acquire(void);
   void               Release(T *obj);
   int                FreeCount(void)    const;
   int                Capacity(void)     const;
   double             Utilization(void)  const;
   bool               IsExhausted(void)  const;
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
template<typename T>
CObjectPool::CObjectPool(int capacity)
   : m_capacity(capacity),
     m_free_count(capacity)
  {
   ArrayResize(m_objects,      m_capacity);
   ArrayResize(m_free_indices, m_capacity);

   //--- Instantiate all objects and record their slot indices
   for(int i = 0; i < m_capacity; i++)
     {
      m_objects[i] = new T();
      m_objects[i].SetPoolIndex(i);   // Store slot index inside the object (O(1) release)
      m_objects[i].SetInUse(false);   // Mark as free at construction
      m_objects[i].SetPooled(true);   // All pre-allocated objects belong to this pool
      m_free_indices[i] = i;
     }
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
template<typename T>
CObjectPool::~CObjectPool(void)
  {
   //--- Safe deallocation of internal objects
   for(int i = 0; i < m_capacity; i++)
     {
      if(CheckPointer(m_objects[i]) == POINTER_DYNAMIC)
        {
         delete m_objects[i];
         m_objects[i] = NULL;
        }
     }

   ArrayFree(m_objects);
   ArrayFree(m_free_indices);
  }

//+------------------------------------------------------------------+
//| Acquire an instance pointer from the pool                        |
//| Returns NULL when pool is exhausted; caller must check.          |
//| No heap allocation occurs on this path after construction.       |
//+------------------------------------------------------------------+
template<typename T>
T *CObjectPool::Acquire(void)
  {
   //--- O(1) pool path: return next available object from free stack
   if(m_free_count > 0)
     {
      m_free_count--;
      T *obj = m_objects[m_free_indices[m_free_count]];
      obj.SetInUse(true);
      return(obj);
     }

   //--- Pool exhausted: caller must handle null
   //--- Do NOT fall back to new T() here: doing so reintroduces heap
   //--- allocation into the hot path, defeating the entire purpose of
   //--- the pool. Size the pool correctly in OnInit() instead.
   Print("[CObjectPool] WARNING: Pool exhausted. NULL returned. Increase pool capacity.");
   return(NULL);
  }

//+------------------------------------------------------------------+
//| Release an active object pointer back to the pool                |
//| O(1): uses the slot index stored inside the object itself.       |
//+------------------------------------------------------------------+
template<typename T>
void CObjectPool::Release(T *obj)
  {
   if(obj == NULL)
      return;

   //--- Guard against double-release
   if(!obj.IsInUse())
     {
      Print("[CObjectPool] WARNING: Double-release detected. Object was already free.");
      return;
     }

   //--- Only accept objects that belong to this pool instance
   if(!obj.IsPooled())
     {
      Print("[CObjectPool] WARNING: Released pointer does not belong to this pool. Ignored.");
      return;
     }

   //--- Validate the stored slot index is in range
   int slot = obj.GetPoolIndex();
   if(slot < 0 || slot >= m_capacity || m_objects[slot] != obj)
     {
      Print("[CObjectPool] WARNING: Invalid slot index on released object. Ignored.");
      return;
     }

   //--- Reset business-state payload (ownership metadata is NOT touched by Reset)
   obj.Reset();
   obj.SetInUse(false);

   //--- Return slot to free stack in O(1)
   m_free_indices[m_free_count] = slot;
   m_free_count++;
  }

//+------------------------------------------------------------------+
//| Get count of unallocated available pool items                    |
//+------------------------------------------------------------------+
template<typename T>
int CObjectPool::FreeCount(void) const
  {
   return(m_free_count);
  }

//+------------------------------------------------------------------+
//| Get absolute predefined structure capacity                       |
//+------------------------------------------------------------------+
template<typename T>
int CObjectPool::Capacity(void) const
  {
   return(m_capacity);
  }

//+------------------------------------------------------------------+
//| Calculate utilization load percentage                            |
//+------------------------------------------------------------------+
template<typename T>
double CObjectPool::Utilization(void) const
  {
   if(m_capacity == 0)
      return(0.0);
   return(((m_capacity - m_free_count) / (double)m_capacity) * 100.0);
  }

//+------------------------------------------------------------------+
//| Evaluate if pool allocation elements are completely checked out  |
//+------------------------------------------------------------------+
template<typename T>
bool CObjectPool::IsExhausted(void) const
  {
   return(m_free_count == 0);
  }

#endif // OBJECTPOOL_MQH

//+------------------------------------------------------------------+