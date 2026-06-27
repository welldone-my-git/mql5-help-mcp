//+------------------------------------------------------------------+
//|                                           InteractionDetector.mqh|
//|                                 Copyright 2026, Clemence Benjamin|
//|                                              https://www.mql5.com|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Clemence Benjamin"
#property link      "https://www.mql5.com"

#include "ComplexObjectDataCollector.mqh"

//+------------------------------------------------------------------+
//| Interaction types                                                |
//+------------------------------------------------------------------+
enum ENUM_INTERACTION
  {
   INTERACTION_NONE,              // no interaction
   INTERACTION_TOUCH,             // price is near a line/level
   INTERACTION_CROSS_UP,          // crossed above the line
   INTERACTION_CROSS_DOWN,        // crossed below the line
   INTERACTION_BREAKOUT_ABOVE,    // closed above a rectangle/channel
   INTERACTION_BREAKOUT_BELOW     // closed below a rectangle/channel
  };

//+------------------------------------------------------------------+
//| Interaction descriptor                                           |
//+------------------------------------------------------------------+
struct SInteraction
  {
   string            objName;        // object name as seen on the chart
   int               objType;        // ENUM_OBJECT type constant
   double            levelPrice;     // the price of the line/level touched
   ENUM_INTERACTION  action;         // type of interaction
   int               direction;      // 1=bullish, -1=bearish, 0=neutral
   string            side;           // "above" or "below" the line/level at touch moment
   string            levelText;      // e.g., "0.618" for Fibonacci, "Median" for pitchfork
  };

//+------------------------------------------------------------------+
//| Interaction detector class                                       |
//+------------------------------------------------------------------+
class CInteractionDetector : public CComplexObjectDetector
  {
private:
   bool              m_busy;             // re‑entrancy guard
   SInteraction      m_interactions[];   // list of detected interactions
   int               m_interactionCount; // number of detected interactions

   //--- State tracking by object name
   string            m_stateNames[];     // object names for state map
   int               m_stateValues[];    // -1=below, 1=above, 0=unknown, 2=touching
   int               m_stateCount;       // number of state entries

   //--- Private helper methods
   int               FindState(const string &name);
   void              SetState(const string &name, int value);

   //--- Object‑specific interaction checkers
   void              CheckTrendline(const SComplexObjectInfo &obj, double bid, double ask, datetime now);
   void              CheckHorizontalLine(const SComplexObjectInfo &obj, double bid, double ask);
   void              CheckRectangle(const SComplexObjectInfo &obj, double bid, double ask, datetime now);
   void              CheckFibonacci(const SComplexObjectInfo &obj, double bid, double ask);
   void              CheckChannel(const SComplexObjectInfo &obj, double bid, double ask, datetime now);
   void              CheckPitchfork(const SComplexObjectInfo &obj, double bid, double ask, datetime now);

   //--- Geometry helpers
   double            LineValueAtTime(datetime t, datetime t0, double p0, datetime t1, double p1);
   bool              IsValidObject(const SComplexObjectInfo &obj, double currentPrice, datetime now);

public:
   CInteractionDetector();
   //--- Main detection method
   int               DetectInteractions(double bid, double ask, datetime now);
   //--- Access to individual interactions
   bool              GetInteraction(int index, SInteraction &out) const;
   int               InteractionCount() const { return(m_interactionCount); }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CInteractionDetector::CInteractionDetector() : m_busy(false),
                                               m_interactionCount(0),
                                               m_stateCount(0)
  {
  }

//+------------------------------------------------------------------+
//| Find state index by name; return -1 if not found                 |
//+------------------------------------------------------------------+
int CInteractionDetector::FindState(const string &name)
  {
   for(int i=0; i<m_stateCount; i++)
     {
      if(m_stateNames[i]==name)
         return(i);
     }
   return(-1);
  }

//+------------------------------------------------------------------+
//| Set state for an object; create new entry if needed              |
//+------------------------------------------------------------------+
void CInteractionDetector::SetState(const string &name, int value)
  {
   int idx=FindState(name);
   if(idx<0)
     {
      //--- Create new state entry
      idx=m_stateCount;
      ArrayResize(m_stateNames, idx+1);
      ArrayResize(m_stateValues, idx+1);
      m_stateCount=idx+1;
      m_stateNames[idx]=name;
     }
   m_stateValues[idx]=value;
  }

//+------------------------------------------------------------------+
//| Main detection loop                                              |
//+------------------------------------------------------------------+
int CInteractionDetector::DetectInteractions(double bid, double ask, datetime now)
  {
   if(m_busy)
      return(0);
   m_busy=true;

   //--- Use inherited detector to get normalized objects
   SComplexObjectInfo objects[];
   int objCount=CComplexObjectDetector::Detect(objects);

   ArrayResize(m_interactions, objCount);
   m_interactionCount=0;

   double currentPrice=(bid+ask)/2.0;

   for(int i=0; i<objCount; i++)
     {
      //--- Skip objects that fail validation (too old, unrealistic line)
      if(!IsValidObject(objects[i], currentPrice, now))
         continue;

      //--- Dispatch to the correct checker based on object type
      switch(objects[i].type)
        {
         case OBJ_TREND:      CheckTrendline(objects[i], bid, ask, now); break;
         case OBJ_HLINE:      CheckHorizontalLine(objects[i], bid, ask); break;
         case OBJ_RECTANGLE:  CheckRectangle(objects[i], bid, ask, now); break;
         case OBJ_FIBO:
         case OBJ_FIBOTIMES:
         case OBJ_FIBOFAN:
         case OBJ_FIBOARC:    CheckFibonacci(objects[i], bid, ask); break;
         case OBJ_CHANNEL:    CheckChannel(objects[i], bid, ask, now); break;
         case OBJ_PITCHFORK:  CheckPitchfork(objects[i], bid, ask, now); break;
         default: break;
        }
     }

   //--- Clean up state entries for objects that no longer exist
   for(int i=m_stateCount-1; i>=0; i--)
     {
      bool found=false;
      for(int j=0; j<objCount; j++)
        {
         if(objects[j].name==m_stateNames[i])
           {
            found=true;
            break;
           }
        }
      if(!found)
        {
         //--- Remove stale state entry by swapping with last
         m_stateNames[i]=m_stateNames[m_stateCount-1];
         m_stateValues[i]=m_stateValues[m_stateCount-1];
         ArrayResize(m_stateNames, m_stateCount-1);
         ArrayResize(m_stateValues, m_stateCount-1);
         m_stateCount--;
        }
     }

   m_busy=false;
   return(m_interactionCount);
  }

//+------------------------------------------------------------------+
//| Validate object: ignore if times are too old or line price huge  |
//+------------------------------------------------------------------+
bool CInteractionDetector::IsValidObject(const SComplexObjectInfo &obj, double currentPrice, datetime now)
  {
   string symbol=ChartSymbol(m_chart_id);
   if(symbol=="")
      return(false);

   //--- Reject objects whose first anchor is older than 1000 bars
   if(obj.time1!=0)
     {
      int barShift=iBarShift(symbol, Period(), obj.time1, false);
      if(barShift<0 || barShift>1000)
         return(false);
     }

   //--- For sloped objects, check if the projected line price is realistic
   if(obj.type==OBJ_TREND || obj.type==OBJ_CHANNEL || obj.type==OBJ_PITCHFORK)
     {
      if(obj.time1!=0 && obj.time2!=0)
        {
         double linePrice=LineValueAtTime(now, obj.time1, obj.price1, obj.time2, obj.price2);
         if(MathAbs(linePrice)>MathAbs(currentPrice)*10 || MathAbs(linePrice)<MathAbs(currentPrice)*0.1)
            return(false);
        }
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| Accessor for a single interaction                                |
//+------------------------------------------------------------------+
bool CInteractionDetector::GetInteraction(int index, SInteraction &out) const
  {
   if(index<0 || index>=m_interactionCount)
      return(false);
   out=m_interactions[index];
   return(true);
  }

//+------------------------------------------------------------------+
//| Helper: line value at given time (linear interpolation)          |
//+------------------------------------------------------------------+
double CInteractionDetector::LineValueAtTime(datetime t, datetime t0, double p0, datetime t1, double p1)
  {
   if(t1==t0)
      return(p0);
   double slope=(p1-p0)/(double)(t1-t0);
   return(p0+slope*(double)(t-t0));
  }

//+------------------------------------------------------------------+
//| Trendline check                                                  |
//+------------------------------------------------------------------+
void CInteractionDetector::CheckTrendline(const SComplexObjectInfo &obj, double bid, double ask, datetime now)
  {
   //--- Validate anchor points
   if(obj.time1==0 || obj.time2==0)
      return;
   double t1=(double)obj.time1;
   double t2=(double)obj.time2;
   if(t2==t1)
      return;

   //--- Compute the line's price at the current time
   double linePrice=LineValueAtTime(now, obj.time1, obj.price1, obj.time2, obj.price2);
   double midPrice=(bid+ask)/2.0;
   double tolerance=5.0*SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   int state=FindState(obj.name);
   int prev=(state>=0) ? m_stateValues[state] : 0;

   bool isTouching=(MathAbs(midPrice-linePrice)<=tolerance);
   if(isTouching)
     {
      //--- Only report if not already touching
      if(prev!=2)
        {
         SInteraction inter;
         inter.objName    =obj.name;
         inter.objType    =obj.type;
         inter.levelPrice =linePrice;
         inter.action     =INTERACTION_TOUCH;
         inter.direction  =(linePrice>obj.price1) ? 1 : -1;
         inter.side       =(midPrice>linePrice) ? "above" : "below";
         inter.levelText  ="";
         m_interactions[m_interactionCount++]=inter;
         SetState(obj.name, 2);
        }
      return;
     }

   //--- Reset touch state if price moved away
   if(prev==2)
      SetState(obj.name, 0);

   //--- Detect cross if previous state was opposite
   int curr=(midPrice>linePrice) ? 1 : -1;

   if(prev!=0 && prev!=curr)
     {
      SInteraction inter;
      inter.objName    =obj.name;
      inter.objType    =obj.type;
      inter.levelPrice =linePrice;
      inter.action     =(curr==1) ? INTERACTION_CROSS_UP : INTERACTION_CROSS_DOWN;
      inter.direction  =curr;
      inter.side       =(curr==1) ? "above" : "below";
      inter.levelText  ="";
      m_interactions[m_interactionCount++]=inter;
     }
   SetState(obj.name, curr);
  }

//+------------------------------------------------------------------+
//| Horizontal line check                                            |
//+------------------------------------------------------------------+
void CInteractionDetector::CheckHorizontalLine(const SComplexObjectInfo &obj, double bid, double ask)
  {
   double linePrice=obj.price1;
   double midPrice=(bid+ask)/2.0;
   double tolerance=5.0*SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   int state=FindState(obj.name);
   int prev=(state>=0) ? m_stateValues[state] : 0;

   bool isTouching=(MathAbs(midPrice-linePrice)<=tolerance);
   if(isTouching)
     {
      if(prev!=2)
        {
         SInteraction inter;
         inter.objName    =obj.name;
         inter.objType    =obj.type;
         inter.levelPrice =linePrice;
         inter.action     =INTERACTION_TOUCH;
         inter.direction  =0;
         inter.side       =(midPrice>linePrice) ? "above" : "below";
         inter.levelText  ="";
         m_interactions[m_interactionCount++]=inter;
         SetState(obj.name, 2);
        }
     }
   else
     {
      if(prev==2)
         SetState(obj.name, 0);
     }
  }

//+------------------------------------------------------------------+
//| Rectangle check (entry/breakout)                                 |
//+------------------------------------------------------------------+
void CInteractionDetector::CheckRectangle(const SComplexObjectInfo &obj, double bid, double ask, datetime now)
  {
   double top=MathMax(obj.price1, obj.price2);
   double bottom=MathMin(obj.price1, obj.price2);
   double midPrice=(bid+ask)/2.0;

   int state=FindState(obj.name);
   int prev=(state>=0) ? m_stateValues[state] : 0;

   //--- Inside the rectangle – reset state
   if(midPrice>=bottom && midPrice<=top)
     {
      SetState(obj.name, 0);
     }
   //--- Breakout above
   else if(midPrice>top)
     {
      if(prev!=1)
        {
         SInteraction inter;
         inter.objName    =obj.name;
         inter.objType    =obj.type;
         inter.levelPrice =top;
         inter.action     =INTERACTION_BREAKOUT_ABOVE;
         inter.direction  =1;
         inter.side       ="above";
         inter.levelText  ="";
         m_interactions[m_interactionCount++]=inter;
        }
      SetState(obj.name, 1);
     }
   //--- Breakout below
   else if(midPrice<bottom)
     {
      if(prev!=-1)
        {
         SInteraction inter;
         inter.objName    =obj.name;
         inter.objType    =obj.type;
         inter.levelPrice =bottom;
         inter.action     =INTERACTION_BREAKOUT_BELOW;
         inter.direction  =-1;
         inter.side       ="below";
         inter.levelText  ="";
         m_interactions[m_interactionCount++]=inter;
        }
      SetState(obj.name, -1);
     }
  }

//+------------------------------------------------------------------+
//| Fibonacci level check                                            |
//+------------------------------------------------------------------+
void CInteractionDetector::CheckFibonacci(const SComplexObjectInfo &obj, double bid, double ask)
  {
   int levels=ArraySize(obj.fibo_prices);
   if(levels==0)
      return;
   double midPrice=(bid+ask)/2.0;
   double tolerance=5.0*SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   int state=FindState(obj.name);
   int prev=(state>=0) ? m_stateValues[state] : 0;

   for(int l=0; l<levels; l++)
     {
      double levelPrice=obj.fibo_prices[l];
      bool isTouching=(MathAbs(midPrice-levelPrice)<=tolerance);
      if(isTouching)
        {
         if(prev!=2)
           {
            SInteraction inter;
            inter.objName    =obj.name;
            inter.objType    =obj.type;
            inter.levelPrice =levelPrice;
            inter.action     =INTERACTION_TOUCH;
            inter.direction  =0;
            inter.side       =(midPrice>levelPrice) ? "above" : "below";
            //--- Include the ratio as level description (e.g., "0.618")
            inter.levelText  =DoubleToString(obj.fibo_ratios[l], 3);
            m_interactions[m_interactionCount++]=inter;
            SetState(obj.name, 2);
           }
         return;
        }
     }

   if(prev==2)
      SetState(obj.name, 0);
  }

//+------------------------------------------------------------------+
//| Channel check (two parallel lines)                               |
//+------------------------------------------------------------------+
void CInteractionDetector::CheckChannel(const SComplexObjectInfo &obj, double bid, double ask, datetime now)
  {
   if(obj.channel_time[0]==0 || obj.channel_time[1]==0)
      return;
   //--- Compute the current price of the base line
   double baseLine=LineValueAtTime(now, obj.channel_time[0], obj.channel_price[0],
                                  obj.channel_time[1], obj.channel_price[1]);
   double midPrice=(bid+ask)/2.0;
   double tolerance=5.0*SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   int state=FindState(obj.name);
   int prev=(state>=0) ? m_stateValues[state] : 0;

   //--- Touch of base line
   if(MathAbs(midPrice-baseLine)<=tolerance)
     {
      if(prev!=2)
        {
         SInteraction inter;
         inter.objName    =obj.name;
         inter.objType    =obj.type;
         inter.levelPrice =baseLine;
         inter.action     =INTERACTION_TOUCH;
         inter.direction  =0;
         inter.side       =(midPrice>baseLine) ? "above" : "below";
         inter.levelText  ="Base";
         m_interactions[m_interactionCount++]=inter;
         SetState(obj.name, 2);
        }
      return;
     }

   //--- Touch of opposite boundary (if third point exists)
   if(obj.channel_price[2]!=0.0)
     {
      double oppLine=LineValueAtTime(now, obj.channel_time[0], obj.channel_price[2],
                                   obj.channel_time[1], obj.channel_price[2]);
      if(MathAbs(midPrice-oppLine)<=tolerance)
        {
         if(prev!=2)
           {
            SInteraction inter;
            inter.objName    =obj.name;
            inter.objType    =obj.type;
            inter.levelPrice =oppLine;
            inter.action     =INTERACTION_TOUCH;
            inter.direction  =0;
            inter.side       =(midPrice>oppLine) ? "above" : "below";
            inter.levelText  ="Opposite";
            m_interactions[m_interactionCount++]=inter;
            SetState(obj.name, 2);
           }
         return;
        }
     }

   if(prev==2)
      SetState(obj.name, 0);
  }

//+------------------------------------------------------------------+
//| Pitchfork check (median line and additional levels)              |
//+------------------------------------------------------------------+
void CInteractionDetector::CheckPitchfork(const SComplexObjectInfo &obj, double bid, double ask, datetime now)
  {
   if(obj.pitchfork_handle_time[0]==0 || obj.pitchfork_median_time==0)
      return;
   //--- Compute the current price of the median line
   double medianNow=LineValueAtTime(now,
                                   obj.pitchfork_handle_time[0],
                                   obj.pitchfork_handle_price[0],
                                   obj.pitchfork_median_time,
                                   obj.pitchfork_median_price);
   double midPrice=(bid+ask)/2.0;
   double tolerance=5.0*SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   int state=FindState(obj.name);
   int prev=(state>=0) ? m_stateValues[state] : 0;

   //--- Median line touch
   if(MathAbs(midPrice-medianNow)<=tolerance)
     {
      if(prev!=2)
        {
         SInteraction inter;
         inter.objName    =obj.name;
         inter.objType    =obj.type;
         inter.levelPrice =medianNow;
         inter.action     =INTERACTION_TOUCH;
         inter.direction  =0;
         inter.side       =(midPrice>medianNow) ? "above" : "below";
         inter.levelText  ="Median";
         m_interactions[m_interactionCount++]=inter;
         SetState(obj.name, 2);
        }
      return;
     }

   //--- Additional pitchfork levels (user‑defined)
   int levels=ArraySize(obj.pitchfork_level_values);
   for(int l=0; l<levels; l++)
     {
      double levelPrice=medianNow+obj.pitchfork_level_values[l];
      if(MathAbs(midPrice-levelPrice)<=tolerance)
        {
         if(prev!=2)
           {
            SInteraction inter;
            inter.objName    =obj.name;
            inter.objType    =obj.type;
            inter.levelPrice =levelPrice;
            inter.action     =INTERACTION_TOUCH;
            inter.direction  =0;
            inter.side       =(midPrice>levelPrice) ? "above" : "below";
            //--- Use the text label set by the user (e.g., "61.8")
            inter.levelText  =obj.pitchfork_level_texts[l];
            m_interactions[m_interactionCount++]=inter;
            SetState(obj.name, 2);
           }
         return;
        }
     }

   if(prev==2)
      SetState(obj.name, 0);
  }
//+------------------------------------------------------------------+