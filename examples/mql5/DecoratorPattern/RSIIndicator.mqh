//+------------------------------------------------------------------+
//|                                             RSIIndicator.mqh     |
//| CRSIIndicator: concrete IIndicator computing RSI values.         |
//| CMovingAverageIndicator: concrete IIndicator computing MA.       |
//| Both create and own their terminal indicator handles.            |
//+------------------------------------------------------------------+
#ifndef RSIINDICATOR_MQH
#define RSIINDICATOR_MQH

#include "IIndicator.mqh"

//+------------------------------------------------------------------+
//| CRSIIndicator                                                    |
//| Purpose: Concrete indicator class implementing the IIndicator    |
//|          interface to provide Relative Strength Index values.    |
//+------------------------------------------------------------------+
class CRSIIndicator : public IIndicator
  {
private:
   int               m_handle;         // Native system indicator handle reference
   string            m_symbol;         // Financial instrument symbol name
   int               m_period;         // Averaging computation period depth

public:
   //--- Lifecycle Management
                     CRSIIndicator(string symbol, ENUM_TIMEFRAMES tf, int period, ENUM_APPLIED_PRICE applied);
                    ~CRSIIndicator(void);

   //--- Interface Implementation Contract
   virtual double    GetValue(int shift);
   virtual string    GetName(void) const;
  };

//+--------------------------------------------------------------------+
//| Constructor                                                        |
//| Purpose: Validates requirements and hooks terminal indicator state |
//+--------------------------------------------------------------------+
CRSIIndicator::CRSIIndicator(string symbol, ENUM_TIMEFRAMES tf, int period, ENUM_APPLIED_PRICE applied)
   : m_symbol(symbol),
     m_period(period),
     m_handle(INVALID_HANDLE)
  {
   m_handle = iRSI(symbol, tf, period, applied);
   if(m_handle == INVALID_HANDLE)
     {
      Print("[CRSIIndicator] Failed to create RSI handle for " + symbol);
     }
  }

//+---------------------------------------------------------------------+
//| Destructor                                                          |
//| Purpose: Cleanly unloads native resources to prevent resource leaks |
//+---------------------------------------------------------------------+
CRSIIndicator::~CRSIIndicator(void)
  {
   if(m_handle != INVALID_HANDLE)
     {
      IndicatorRelease(m_handle);
      m_handle = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//| GetValue                                                         |
//| Purpose: Extracts buffer array metric output by dynamic step pass|
//+------------------------------------------------------------------+
double CRSIIndicator::GetValue(int shift)
  {
   if(m_handle == INVALID_HANDLE)
     {
      return(0.0);
     }

   double buf[1];
   if(CopyBuffer(m_handle, 0, shift, 1, buf) < 1)
     {
      return(0.0);
     }

   return(buf[0]);
  }

//+------------------------------------------------------------------+
//| GetName                                                          |
//| Purpose: Constructs complete localized indicator identity label  |
//+------------------------------------------------------------------+
string CRSIIndicator::GetName(void) const
  {
   return("RSI(" + IntegerToString(m_period) + ")[" + m_symbol + "]");
  }

//+------------------------------------------------------------------+
//| CMovingAverageIndicator                                          |
//| Purpose: Concrete indicator class implementing the IIndicator    |
//|          interface to provide Moving Average values.             |
//+------------------------------------------------------------------+
class CMovingAverageIndicator : public IIndicator
  {
private:
   int               m_handle;         // Native system indicator handle reference
   string            m_symbol;         // Financial instrument symbol name
   int               m_period;         // Averaging computation period depth

public:
   //--- Lifecycle Management
                     CMovingAverageIndicator(string symbol, ENUM_TIMEFRAMES tf, int period, int shift, ENUM_MA_METHOD method, ENUM_APPLIED_PRICE applied);
                    ~CMovingAverageIndicator(void);

   //--- Interface Implementation Contract
   virtual double    GetValue(int bar_shift);
   virtual string    GetName(void) const;
  };

//+--------------------------------------------------------------------+
//| Constructor                                                        |
//| Purpose: Connects terminal internal structure moving average state |
//+--------------------------------------------------------------------+
CMovingAverageIndicator::CMovingAverageIndicator(string symbol, ENUM_TIMEFRAMES tf, int period, int shift, ENUM_MA_METHOD method, ENUM_APPLIED_PRICE applied)
   : m_symbol(symbol),
     m_period(period),
     m_handle(INVALID_HANDLE)
  {
   m_handle = iMA(symbol, tf, period, shift, method, applied);
   if(m_handle == INVALID_HANDLE)
     {
      Print("[CMovingAverageIndicator] Failed to create MA handle for " + symbol);
     }
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//| Purpose: Releases core chart resource pointers on class unloading|
//+------------------------------------------------------------------+
CMovingAverageIndicator::~CMovingAverageIndicator(void)
  {
   if(m_handle != INVALID_HANDLE)
     {
      IndicatorRelease(m_handle);
      m_handle = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//| GetValue                                                         |
//| Purpose: Polls and maps core buffer outputs safely into strategy |
//+------------------------------------------------------------------+
double CMovingAverageIndicator::GetValue(int bar_shift)
  {
   if(m_handle == INVALID_HANDLE)
     {
      return(0.0);
     }

   double buf[1];
   if(CopyBuffer(m_handle, 0, bar_shift, 1, buf) < 1)
     {
      return(0.0);
     }

   return(buf[0]);
  }

//+------------------------------------------------------------------+
//| GetName                                                          |
//| Purpose: Generates a unified metadata tracking name tag identity |
//+------------------------------------------------------------------+
string CMovingAverageIndicator::GetName(void) const
  {
   return("MA(" + IntegerToString(m_period) + ")[" + m_symbol + "]");
  }

#endif // RSIINDICATOR_MQH
//+------------------------------------------------------------------+