//+------------------------------------------------------------------+
//|                                   ComplexObjectDataCollector.mqh |
//|                                Copyright 2026, Clemence Benjamin |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Clemence Benjamin"
#property link      "https://www.mql5.com"

#include "ChartObjectDetector.mqh"

//+------------------------------------------------------------------+
//| Helper: Determine if object type is analytical                   |
//+------------------------------------------------------------------+
bool IsAnalyticalObject(int type)
  {
   switch(type)
     {
      case OBJ_FIBO:
      case OBJ_FIBOTIMES:
      case OBJ_FIBOFAN:
      case OBJ_FIBOARC:
      case OBJ_CHANNEL:
      case OBJ_PITCHFORK:
      case OBJ_TREND:
      case OBJ_RECTANGLE:
         return(true);
      default:
         return(false);
     }
  }

//+------------------------------------------------------------------+
//| Extended structure for complex objects                           |
//+------------------------------------------------------------------+
struct SComplexObjectInfo : public SChartObjectInfo
  {
   //--- Fibonacci specific
   double            fibo_ratios[];      // level ratios (0.236, 0.382, etc.)
   double            fibo_prices[];      // actual price at each ratio
   //--- Channel specific (3 anchor points)
   datetime          channel_time[3];
   double            channel_price[3];
   //--- Pitchfork specific
   datetime          pitchfork_handle_time[2];
   double            pitchfork_handle_price[2];
   datetime          pitchfork_median_time;
   double            pitchfork_median_price;
   //--- Pitchfork additional levels (optional)
   double            pitchfork_level_values[];   // offset from median line (price units)
   string            pitchfork_level_texts[];    // description (e.g., "61.8")
  };

//+------------------------------------------------------------------+
//| Complex Object Detector Class                                    |
//+------------------------------------------------------------------+
class CComplexObjectDetector : public CChartObjectDetector
  {
public:
   int               Detect(SComplexObjectInfo &out_objects[]);

private:
   void              ExtractFibonacciLevels(string name, SComplexObjectInfo &obj);
   void              ComputeActualFibonacciPrices(SComplexObjectInfo &obj);
   void              ExtractChannelPoints(string name, SComplexObjectInfo &obj);
   void              ExtractPitchforkData(string name, SComplexObjectInfo &obj);
  };

//+------------------------------------------------------------------+
//| Detects all complex analytical objects                           |
//+------------------------------------------------------------------+
int CComplexObjectDetector::Detect(SComplexObjectInfo &out_objects[])
  {
   int total = ObjectsTotal(m_chart_id);
   ArrayResize(out_objects, total);
   int count = 0;

   for(int i = 0; i < total; i++)
     {
      string name = ObjectName(m_chart_id, i);
      if(name == "")
         continue;
      if(ObjectFind(m_chart_id, name) < 0)
         continue;

      int type = (int)ObjectGetInteger(m_chart_id, name, OBJPROP_TYPE);
      if(!IsAnalyticalObject(type))
         continue;

      SComplexObjectInfo obj;
      //--- Initialize base fields
      obj.name      = name;
      obj.type      = type;
      obj.type_name = ObjectTypeToString(type);
      obj.time1 = obj.time2 = 0;
      obj.price1 = obj.price2 = 0.0;

      //--- Extract base two points (using protected base method)
      ExtractProperties(name, type, obj);

      //--- Complex extractions
      if(type == OBJ_FIBO || type == OBJ_FIBOTIMES || type == OBJ_FIBOFAN || type == OBJ_FIBOARC)
        {
         ExtractFibonacciLevels(name, obj);
         ComputeActualFibonacciPrices(obj);
        }
      if(type == OBJ_CHANNEL)
         ExtractChannelPoints(name, obj);
      if(type == OBJ_PITCHFORK)
         ExtractPitchforkData(name, obj);

      out_objects[count++] = obj;
     }

   ArrayResize(out_objects, count);
   return(count);
  }

//+------------------------------------------------------------------+
//| Extracts Fibonacci level ratios                                  |
//+------------------------------------------------------------------+
void CComplexObjectDetector::ExtractFibonacciLevels(string name, SComplexObjectInfo &obj)
  {
   int levels = (int)ObjectGetInteger(m_chart_id, name, OBJPROP_LEVELS);
   if(levels <= 0)
      return;
   ArrayResize(obj.fibo_ratios, levels);
   ArrayResize(obj.fibo_prices, levels);
   for(int i = 0; i < levels; i++)
     {
      obj.fibo_ratios[i] = ObjectGetDouble(m_chart_id, name, OBJPROP_LEVELVALUE, i);
      obj.fibo_prices[i] = 0.0;
     }
  }

//+------------------------------------------------------------------+
//| Computes actual prices from ratios and anchor points             |
//+------------------------------------------------------------------+
void CComplexObjectDetector::ComputeActualFibonacciPrices(SComplexObjectInfo &obj)
  {
   double delta = obj.price2 - obj.price1;
   if(delta == 0.0)
      return;
   int size = ArraySize(obj.fibo_ratios);
   for(int i = 0; i < size; i++)
     {
      if(delta > 0)
         obj.fibo_prices[i] = obj.price1 + delta * obj.fibo_ratios[i];
      else
         obj.fibo_prices[i] = obj.price1 - fabs(delta) * obj.fibo_ratios[i];
     }
  }

//+------------------------------------------------------------------+
//| Extracts three channel points                                    |
//+------------------------------------------------------------------+
void CComplexObjectDetector::ExtractChannelPoints(string name, SComplexObjectInfo &obj)
  {
   for(int i = 0; i < 3; i++)
     {
      obj.channel_time[i]  = (datetime)ObjectGetInteger(m_chart_id, name, OBJPROP_TIME, i);
      obj.channel_price[i] = ObjectGetDouble(m_chart_id, name, OBJPROP_PRICE, i);
     }
  }

//+------------------------------------------------------------------+
//| Extracts pitchfork handle, median point, and additional levels  |
//+------------------------------------------------------------------+
void CComplexObjectDetector::ExtractPitchforkData(string name, SComplexObjectInfo &obj)
  {
//--- Handle points (indices 0 and 1)
   for(int i = 0; i < 2; i++)
     {
      obj.pitchfork_handle_time[i]  = (datetime)ObjectGetInteger(m_chart_id, name, OBJPROP_TIME, i);
      obj.pitchfork_handle_price[i] = ObjectGetDouble(m_chart_id, name, OBJPROP_PRICE, i);
     }
//--- Median point (index 2)
   obj.pitchfork_median_time  = (datetime)ObjectGetInteger(m_chart_id, name, OBJPROP_TIME, 2);
   obj.pitchfork_median_price = ObjectGetDouble(m_chart_id, name, OBJPROP_PRICE, 2);

//--- Additional levels (if any)
   int levels = (int)ObjectGetInteger(m_chart_id, name, OBJPROP_LEVELS);
   if(levels > 0)
     {
      ArrayResize(obj.pitchfork_level_values, levels);
      ArrayResize(obj.pitchfork_level_texts, levels);
      for(int i = 0; i < levels; i++)
        {
         obj.pitchfork_level_values[i] = ObjectGetDouble(m_chart_id, name, OBJPROP_LEVELVALUE, i);
         obj.pitchfork_level_texts[i]  = ObjectGetString(m_chart_id, name, OBJPROP_LEVELTEXT, i);
        }
     }
  }
//+------------------------------------------------------------------+