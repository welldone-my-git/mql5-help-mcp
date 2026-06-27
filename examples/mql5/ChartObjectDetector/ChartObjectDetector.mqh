//+------------------------------------------------------------------+
//|                                                   ChartObjectDetector.mqh |
//|                                 Copyright 2026, Clemence Benjamin|
//|                                               http://www.mql5.com|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Clemence Benjamin"
#property link      "https://www.mql5.com"
#property strict

//+------------------------------------------------------------------+
//| Structure to hold normalized object data                         |
//+------------------------------------------------------------------+
struct SChartObjectInfo
  {
   string            name;
   int               type;
   string            type_name;
   datetime          time1;
   datetime          time2;
   double            price1;
   double            price2;
  };

//+------------------------------------------------------------------+
//| Convert Object Type to Readable String                           |
//+------------------------------------------------------------------+
string ObjectTypeToString(int type)
  {
   switch(type)
     {
      case OBJ_TREND:
         return("TREND");
      case OBJ_RECTANGLE:
         return("RECTANGLE");
      case OBJ_CHANNEL:
         return("CHANNEL");
      case OBJ_HLINE:
         return("HLINE");
      case OBJ_VLINE:
         return("VLINE");
      case OBJ_FIBO:
         return("FIBO");
      default:
         return("UNKNOWN");
     }
  }

//+------------------------------------------------------------------+
//| Chart Object Detection Class                                     |
//+------------------------------------------------------------------+
class CChartObjectDetector
  {
private:
   long              m_chart_id;

public:
//+------------------------------------------------------------------+
//| Initialize detector                                              |
//+------------------------------------------------------------------+
   void              Init(long chart_id = 0)
     {
      m_chart_id = chart_id;
     }

//+------------------------------------------------------------------+
//| Get total objects                                                |
//+------------------------------------------------------------------+
   int               Total()
     {
      return(ObjectsTotal(m_chart_id));
     }

//+------------------------------------------------------------------+
//| Detect all chart objects                                         |
//+------------------------------------------------------------------+
   int               Detect(SChartObjectInfo &out_objects[])
     {
      int total = ObjectsTotal(m_chart_id);
      ArrayResize(out_objects, total);

      int count = 0;

      for(int i = 0; i < total; i++)
        {
         string name = ObjectName(m_chart_id, i);

         //--- Safety: skip invalid names
         if(name == "")
            continue;

         //--- Safety: ensure object still exists
         if(ObjectFind(m_chart_id, name) < 0)
            continue;

         int type = (int)ObjectGetInteger(m_chart_id, name, OBJPROP_TYPE);

         SChartObjectInfo obj;
         obj.name      = name;
         obj.type      = type;
         obj.type_name = ObjectTypeToString(type);

         //--- Initialize defaults
         obj.time1  = 0;
         obj.time2  = 0;
         obj.price1 = 0.0;
         obj.price2 = 0.0;

         //--- Extract object-specific properties
         ExtractProperties(name, type, obj);

         out_objects[count++] = obj;
        }

      //--- Resize to actual count
      ArrayResize(out_objects, count);

      return(count);
     }

private:
//+------------------------------------------------------------------+
//| Extract properties (MQL5-compliant indexed access)               |
//+------------------------------------------------------------------+
   void              ExtractProperties(string name, int type, SChartObjectInfo &obj)
     {
      switch(type)
        {
         case OBJ_TREND:
         case OBJ_CHANNEL:
         case OBJ_RECTANGLE:
           {
            //--- Anchor point 1
            obj.time1  = (datetime)ObjectGetInteger(m_chart_id, name, OBJPROP_TIME, 0);
            obj.price1 = ObjectGetDouble(m_chart_id, name, OBJPROP_PRICE, 0);

            //--- Anchor point 2
            obj.time2  = (datetime)ObjectGetInteger(m_chart_id, name, OBJPROP_TIME, 1);
            obj.price2 = ObjectGetDouble(m_chart_id, name, OBJPROP_PRICE, 1);
            break;
           }

         case OBJ_HLINE:
           {
            obj.price1 = ObjectGetDouble(m_chart_id, name, OBJPROP_PRICE, 0);
            break;
           }

         case OBJ_VLINE:
           {
            obj.time1 = (datetime)ObjectGetInteger(m_chart_id, name, OBJPROP_TIME, 0);
            break;
           }

         default:
           {
            //--- For unsupported objects, leave defaults
            break;
           }
        }
     }
  };
//+------------------------------------------------------------------+