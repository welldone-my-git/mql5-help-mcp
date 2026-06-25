//+------------------------------------------------------------------+
//|                                                CReturnBuffer.mqh |
//| Rolling return series buffer using a circular array template.    |
//+------------------------------------------------------------------+
#ifndef __CRETURNBUFFER_MQH__
#define __CRETURNBUFFER_MQH__

//+------------------------------------------------------------------+
//| Class CReturnBuffer                                              |
//| Purpose: Provides a fast, fixed-size rolling circular cache for  |
//|          storing quantitative returns. Tracks running statistical|
//|          aggregates (mean, variance) using single-pass logic.    |
//+------------------------------------------------------------------+
class CReturnBuffer
  {
private:
   double            m_data[];        // Circular storage array
   int               m_capacity;      // Maximum window index lookback depth
   int               m_head;          // Index coordinate pointer of oldest element
   int               m_count;         // Total active initialized valid records
   double            m_sum;           // Incremental running sum aggregate for mean
   double            m_sumSq;         // Incremental sum-of-squares for variance

public:
                     CReturnBuffer(void);
                    ~CReturnBuffer(void);

   bool              Init(const int capacity);
   void              Push(const double value);
   bool              IsFull(void) const;
   int               Count(void) const;
   int               Capacity(void) const;
   double            Get(const int offset) const;
   double            Mean(void) const;
   double            Variance(void) const;
   double            StdDev(void) const;
   void              Reset(void);
  };

//+------------------------------------------------------------------+
//| Default Class Constructor                                        |
//+------------------------------------------------------------------+
CReturnBuffer::CReturnBuffer(void) : m_capacity(0),
   m_head(0),
   m_count(0),
   m_sum(0.0),
   m_sumSq(0.0)
  {
  }

//+------------------------------------------------------------------+
//| Class Destructor                                                 |
//+------------------------------------------------------------------+
CReturnBuffer::~CReturnBuffer(void)
  {
//--- Reclaim assigned dynamic array memory structures
   ArrayFree(m_data);
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//| Purpose: Allocates initial fixed memory sizing structures.       |
//+------------------------------------------------------------------+
bool CReturnBuffer::Init(const int capacity)
  {
//--- Enforce minimum size threshold validation for variance tracking equations
   if(capacity < 2)
     {
      Print("CReturnBuffer::Init - capacity must be >= 2, received: ", capacity);
      return(false);
     }

//--- Establish base ground variables properties
   m_capacity = capacity;
   m_head     = 0;
   m_count    = 0;
   m_sum      = 0.0;
   m_sumSq    = 0.0;

//--- Perform physical dynamic sizing check vector
   if(ArrayResize(m_data, m_capacity) != m_capacity)
     {
      Print("CReturnBuffer::Init - ArrayResize failed for capacity: ", capacity);
      return(false);
     }

//--- Clean memory pool structures completely
   ArrayInitialize(m_data, 0.0);
   return(true);
  }

//+------------------------------------------------------------------+
//| Push                                                             |
//| Purpose: Writes a value to the current ring buffer position,     |
//|          auto-evicting the oldest element if at capacity.        |
//+------------------------------------------------------------------+
void CReturnBuffer::Push(const double value)
  {
//--- Check if sliding memory ring context is saturated
   if(m_count == m_capacity)
     {
      //--- Evict historical oldest data entry from statistical tracking metrics
      double evicted = m_data[m_head];
      m_sum   -= evicted;
      m_sumSq -= evicted * evicted;
     }
   else
     {
      //--- Expand tracked sample size registry directly
      m_count++;
     }

//--- Overwrite historical ring offset slot with newly arrived data point
   m_data[m_head] = value;
   m_sum          += value;
   m_sumSq        += value * value;

//--- Advance write head pointer wrapping around capacity limits cleanly
   m_head = (m_head + 1) % m_capacity;
  }

//+------------------------------------------------------------------+
//| IsFull                                                           |
//+------------------------------------------------------------------+
bool CReturnBuffer::IsFull(void) const
  {
   return(m_count == m_capacity);
  }

//+------------------------------------------------------------------+
//| Count                                                            |
//+------------------------------------------------------------------+
int CReturnBuffer::Count(void) const
  {
   return(m_count);
  }

//+------------------------------------------------------------------+
//| Capacity                                                         |
//+------------------------------------------------------------------+
int CReturnBuffer::Capacity(void) const
  {
   return(m_capacity);
  }

//+------------------------------------------------------------------+
//| Get                                                              |
//| Purpose: Sequential zero-based index query where 0 is newest.    |
//+------------------------------------------------------------------+
double CReturnBuffer::Get(const int offset) const
  {
//--- Trap invalid or uninitialized out-of-bounds queries.
   if(offset < 0 || offset >= m_count)
      return(0.0);

//--- Map logical historical array request into the physical circular memory ring index
   int physIdx = (m_head - 1 - offset + m_capacity * 2) % m_capacity;
   return(m_data[physIdx]);
  }

//+------------------------------------------------------------------+
//| Mean                                                             |
//+------------------------------------------------------------------+
double CReturnBuffer::Mean(void) const
  {
   if(m_count == 0)
      return(0.0);

   return(m_sum / (double)m_count);
  }

//+------------------------------------------------------------------+
//| Variance                                                         |
//| Purpose: Computes unbiased sample variance (N-1 denominator).    |
//+------------------------------------------------------------------+
double CReturnBuffer::Variance(void) const
  {
//--- Sample statistical models require at least two active item nodes
   if(m_count < 2)
      return(0.0);

   double n    = (double)m_count;
   double mean = m_sum / n;

//--- Apply standard mathematical expansion form equation
   double var  = (m_sumSq - n * mean * mean) / (n - 1.0);

//--- Defensively filter out floating point inaccuracies below absolute zero
   return(MathMax(var, 0.0));
  }

//+------------------------------------------------------------------+
//| StdDev                                                           |
//+------------------------------------------------------------------+
double CReturnBuffer::StdDev(void) const
  {
   return(MathSqrt(Variance()));
  }

//+------------------------------------------------------------------+
//| Reset                                                            |
//| Purpose: Resets statistical counters and wipes tracking values.  |
//+------------------------------------------------------------------+
void CReturnBuffer::Reset(void)
  {
//--- Reset runtime indices tracking metrics counters
   m_head  = 0;
   m_count = 0;
   m_sum   = 0.0;
   m_sumSq = 0.0;

//--- Return storage elements array fields data to structural baseline definitions
   ArrayInitialize(m_data, 0.0);
  }

#endif // __CRETURNBUFFER_MQH__
//+------------------------------------------------------------------+