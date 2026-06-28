//+------------------------------------------------------------------+
//|                                                BaseDecorator.mqh |
//| CBaseDecorator: abstract base for all decorators.                |
//| Owns the wrapped IIndicator* and provides default delegation.    |
//| Concrete decorators inherit this and override GetValue().        |
//+------------------------------------------------------------------+
#ifndef BASEDECORATOR_MQH
#define BASEDECORATOR_MQH

#include "IIndicator.mqh"

//+------------------------------------------------------------------+
//| CBaseDecorator                                                   |
//| Purpose: Abstract structural base class that implements the      |
//|          IIndicator pattern to wrap and extend indicators.       |
//+------------------------------------------------------------------+
class CBaseDecorator : public IIndicator
  {
protected:
   IIndicator       *m_wrapped;        // Pointer to the wrapped base indicator instance

public:
   //--- Lifecycle Management
                     CBaseDecorator(IIndicator *wrapped);
   virtual          ~CBaseDecorator(void);

   //--- Interface Implementation Contract
   virtual double    GetValue(int shift);
   virtual string    GetName(void) const;
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//| Purpose: Instantiates structural layers and binds an indicator   |
//+------------------------------------------------------------------+
CBaseDecorator::CBaseDecorator(IIndicator *wrapped)
   : m_wrapped(wrapped)
  {
  }

//+-------------------------------------------------------------------+
//| Destructor                                                        |
//| Purpose: Releases downstream dynamically allocated indicators.    |
//+-------------------------------------------------------------------+
CBaseDecorator::~CBaseDecorator(void)
  {
   if(CheckPointer(m_wrapped) == POINTER_DYNAMIC)
     {
      delete m_wrapped;
      m_wrapped = NULL;
     }
  }

//+-------------------------------------------------------------------+
//| GetValue                                                          |
//| Purpose: Delegates value retrieval to the wrapped indicator.      |
//+-------------------------------------------------------------------+
double CBaseDecorator::GetValue(int shift)
  {
   if(m_wrapped == NULL)
     {
      return(0.0);
     }
     
   return(m_wrapped.GetValue(shift));
  }

//+------------------------------------------------------------------+
//| GetName                                                          |
//| Purpose: Cascades identity metadata from wrapped references      |
//+------------------------------------------------------------------+
string CBaseDecorator::GetName(void) const
  {
   if(m_wrapped == NULL)
     {
      return("NullDecorator");
     }
     
   return(m_wrapped.GetName());
  }

#endif // BASEDECORATOR_MQH
//+------------------------------------------------------------------+