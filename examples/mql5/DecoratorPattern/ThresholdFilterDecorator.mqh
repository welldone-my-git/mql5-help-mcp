//+------------------------------------------------------------------+
//|                                   ThresholdFilterDecorator.mqh   |
//| CThresholdFilterDecorator: suppresses values outside a           |
//| configurable range by returning 0.0. Values within range pass    |
//| through unchanged. Optionally logs filter decisions.             |
//+------------------------------------------------------------------+
#ifndef THRESHOLDFILTERDECORATOR_MQH
#define THRESHOLDFILTERDECORATOR_MQH

#include "BaseDecorator.mqh"

//+------------------------------------------------------------------+
//| CThresholdFilterDecorator                                        |
//| Purpose: Concrete structural decorator that filters and isolates |
//|          out-of-bounds metrics across downstream data channels.  |
//+------------------------------------------------------------------+
class CThresholdFilterDecorator : public CBaseDecorator
  {
private:
   double            m_lower_bound;       // Values below this are suppressed
   double            m_upper_bound;       // Values above this are suppressed
   bool              m_log_decisions;     // When true, filter decisions are printed
   bool              m_last_passed;       // Result of most recent threshold evaluation

public:
   //--- Lifecycle Management
                     CThresholdFilterDecorator(IIndicator *wrapped, double lower_bound, double upper_bound, bool log_decisions);
                    ~CThresholdFilterDecorator(void) {}

   //--- Interface Implementation Contract
   virtual double    GetValue(int shift);
   virtual string    GetName(void) const;

   //--- Class Specific Methods
   bool              GetLastPassed(void) const;
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//| Purpose: Assigns filtering thresholds and runtime logging flags. |
//+------------------------------------------------------------------+
CThresholdFilterDecorator::CThresholdFilterDecorator(IIndicator *wrapped, double lower_bound, double upper_bound, bool log_decisions)
   : CBaseDecorator(wrapped),
     m_lower_bound(lower_bound),
     m_upper_bound(upper_bound),
     m_log_decisions(log_decisions),
     m_last_passed(false)
  {
  }

//+-------------------------------------------------------------------+
//| GetValue                                                          |
//| Purpose: Evaluates mathematical constraints against current logic |
//|          and blocks out-of-range market context data sweeps.      |
//+-------------------------------------------------------------------+
double CThresholdFilterDecorator::GetValue(int shift)
  {
   if(m_wrapped == NULL)
     {
      return(0.0);
     }

   double raw    = m_wrapped.GetValue(shift);
   bool   passed = (raw >= m_lower_bound && raw <= m_upper_bound);
   m_last_passed = passed;

   if(m_log_decisions && shift == 0)
     {
      string pass_str = passed ? "TRUE" : "FALSE";
      Print("[FILTER] " + m_wrapped.GetName() +
            " | Raw=" + DoubleToString(raw, 5) +
            " | Range=[" + DoubleToString(m_lower_bound, 2) +
            "," + DoubleToString(m_upper_bound, 2) + "]" +
            " | Passed=" + pass_str +
            " | Output=" + DoubleToString(passed ? raw : 0.0, 5));
     }

   return(passed ? raw : 0.0);
  }

//+------------------------------------------------------------------+
//| GetName                                                          |
//| Purpose: Composes identity mapping markers describing active     |
//|          structural data clipping paths.                         |
//+------------------------------------------------------------------+
string CThresholdFilterDecorator::GetName(void) const
  {
   if(m_wrapped == NULL)
     {
      return("Filter > Null");
     }

   return("Filter[" + DoubleToString(m_lower_bound, 0) +
          "-" + DoubleToString(m_upper_bound, 0) +
          "] > " + m_wrapped.GetName());
  }

//+------------------------------------------------------------------+
//| GetLastPassed                                                    |
//| Purpose: Queries state engine flags checking the last evaluated  |
//|          conditional status pass boundary.                       |
//+------------------------------------------------------------------+
bool CThresholdFilterDecorator::GetLastPassed(void) const
  {
   return(m_last_passed);
  }

#endif // THRESHOLDFILTERDECORATOR_MQH
//+------------------------------------------------------------------+