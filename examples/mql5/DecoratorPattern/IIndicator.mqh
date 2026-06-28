//+------------------------------------------------------------------+
//|                                                   IIndicator.mqh |
//| Abstract indicator interface. Every concrete indicator and       |
//| every decorator implements this contract. Callers depend only    |
//| on IIndicator*, never on concrete types.                         |
//+------------------------------------------------------------------+
#ifndef IINDICATOR_MQH
#define IINDICATOR_MQH

//+------------------------------------------------------------------+
//| IIndicator                                                       |
//| Purpose: Interface defining the standard structural contract for |
//|          mathematical indicator components and data decorators.  |
//+------------------------------------------------------------------+
class IIndicator
  {
public:
   //--- Lifecycle Management
   virtual           ~IIndicator(void) {}

   //--- Interface Contract Methods
   virtual double     GetValue(int shift) = 0;
   virtual string     GetName(void) const = 0;
  };

#endif // IINDICATOR_MQH
//+------------------------------------------------------------------+