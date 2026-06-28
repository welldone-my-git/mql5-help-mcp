//+------------------------------------------------------------------+
//|                                              TimingDecorator.mqh |
//| CTimingDecorator: measures execution time of the wrapped chain   |
//| in microseconds and logs the result. Value passes through        |
//| unchanged.                                                       |
//+------------------------------------------------------------------+
#ifndef TIMINGDECORATOR_MQH
#define TIMINGDECORATOR_MQH

#include "BaseDecorator.mqh"

//+------------------------------------------------------------------+
//| CTimingDecorator                                                 |
//| Purpose: Concrete structural decorator that measures and tracks  |
//|          execution benchmarking latency over downstream links.   |
//+------------------------------------------------------------------+
class CTimingDecorator : public CBaseDecorator
  {
private:
   bool              m_enabled;           // Controls whether timing output is active
   long              m_last_duration_us;  // Most recent measured duration in microseconds

public:
   //--- Lifecycle Management
                     CTimingDecorator(IIndicator *wrapped, bool enabled);
                    ~CTimingDecorator(void) {}

   //--- Interface Implementation Contract
   virtual double    GetValue(int shift);
   virtual string    GetName(void) const;

   //--- Class Specific Methods
   long              GetLastDurationUs(void) const;
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//| Purpose: Sets benchmarking runtime properties for active streams.|
//+------------------------------------------------------------------+
CTimingDecorator::CTimingDecorator(IIndicator *wrapped, bool enabled)
   : CBaseDecorator(wrapped),
     m_enabled(enabled),
     m_last_duration_us(0)
  {
  }

//+------------------------------------------------------------------+
//| GetValue                                                         |
//| Purpose: Profiles performance metrics by measuring execution     |
//|          microseconds across evaluation updates.                 |
//+------------------------------------------------------------------+
double CTimingDecorator::GetValue(int shift)
  {
   if(m_wrapped == NULL)
     {
      return(0.0);
     }

   long t_start = GetMicrosecondCount();
   double value = m_wrapped.GetValue(shift);
   long t_end   = GetMicrosecondCount();

   m_last_duration_us = t_end - t_start;

   if(m_enabled && shift == 0)
     {
      Print("[TIMER] " + m_wrapped.GetName() +
            " | Execution Time = " +
            IntegerToString(m_last_duration_us) + " us");
     }

   return(value);
  }

//+------------------------------------------------------------------+
//| GetName                                                          |
//| Purpose: Builds descriptive string reflecting benchmarking       |
//|          decorator layers.                                       |
//+------------------------------------------------------------------+
string CTimingDecorator::GetName(void) const
  {
   if(m_wrapped == NULL)
     {
      return("Timing > Null");
     }

   return("Timing > " + m_wrapped.GetName());
  }

//+------------------------------------------------------------------+
//| GetLastDurationUs                                                |
//| Purpose: Safely returns the most recently captured operational   |
//|          execution delay duration value.                         |
//+------------------------------------------------------------------+
long CTimingDecorator::GetLastDurationUs(void) const
  {
   return(m_last_duration_us);
  }

#endif // TIMINGDECORATOR_MQH
//+------------------------------------------------------------------+