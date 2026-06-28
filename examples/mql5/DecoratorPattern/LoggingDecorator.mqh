//+------------------------------------------------------------------+
//|                                             LoggingDecorator.mqh |
//| CLoggingDecorator: logs indicator name and value to journal      |
//| on each GetValue() call. Passes value through unchanged.         |
//+------------------------------------------------------------------+
#ifndef LOGGINGDECORATOR_MQH
#define LOGGINGDECORATOR_MQH

#include "BaseDecorator.mqh"

//+------------------------------------------------------------------+
//| CLoggingDecorator                                                |
//| Purpose: Concrete structural decorator providing passive journal |
//|          telemetry tracking layer across IIndicator targets.     |
//+------------------------------------------------------------------+
class CLoggingDecorator : public CBaseDecorator
  {
private:
   bool              m_enabled;        // Controls whether logging output is active
   int               m_log_shift;      // Only log when shift equals this value (-1 = always)

public:
   //--- Lifecycle Management
                     CLoggingDecorator(IIndicator *wrapped, bool enabled, int log_shift);
                    ~CLoggingDecorator(void) {}

   //--- Interface Implementation Contract
   virtual double    GetValue(int shift);
   virtual string    GetName(void) const;
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//| Purpose: Maps base decorator instances and custom tracking flags |
//+------------------------------------------------------------------+
CLoggingDecorator::CLoggingDecorator(IIndicator *wrapped, bool enabled, int log_shift)
   : CBaseDecorator(wrapped),
     m_enabled(enabled),
     m_log_shift(log_shift)
  {
  }

//+------------------------------------------------------------------+
//| GetValue                                                         |
//| Purpose: Intercepts raw technical calculations and pipes data    |
//|          metrics safely into diagnostic logging streams.         |
//+------------------------------------------------------------------+
double CLoggingDecorator::GetValue(int shift)
  {
   if(m_wrapped == NULL)
     {
      return(0.0);
     }

   double value = m_wrapped.GetValue(shift);

   if(m_enabled && (m_log_shift < 0 || shift == m_log_shift))
     {
      Print("[LOGGER] " + m_wrapped.GetName() +
            " | Shift=" + IntegerToString(shift) +
            " | Value=" + DoubleToString(value, 5));
     }

   return(value);
  }

//+------------------------------------------------------------------+
//| GetName                                                          |
//| Purpose: Composes string representation labels reflecting logger |
//|          decoration presence.                                    |
//+------------------------------------------------------------------+
string CLoggingDecorator::GetName(void) const
  {
   if(m_wrapped == NULL)
     {
      return("Logging > Null");
     }

   return("Logging > " + m_wrapped.GetName());
  }

#endif // LOGGINGDECORATOR_MQH
//+------------------------------------------------------------------+