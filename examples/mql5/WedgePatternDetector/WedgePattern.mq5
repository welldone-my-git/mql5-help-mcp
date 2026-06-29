//+------------------------------------------------------------------+
//|                                                 WedgePattern.mq5 |
//|                               Copyright 2026, Christian Benjamin |
//|                          https://www.mql5.com/en/users/lynnchris |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Christian Benjamin"
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <Arrays/ArrayObj.mqh>

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input group "Pattern Detection Rules"
input int    PivotLeft           = 5;         // Pivot Left
input int    PivotRight          = 5;         // Pivot Right
input int    MinTouches          = 3;         // Min. Touches per Line

input group "Visual Design"
input color  RisingColor         = clrRed;        // Rising Wedge (Bearish)
input color  FallingColor        = clrLime;       // Falling Wedge (Bullish)
input int    MaxWedges           = 20;            // Max wedges displayed (oldest removed)
input bool   ExtendLines         = true;          // Extend wedge lines
input int    LineExtensionBars   = 30;            // Bars to extend (if ExtendLines=true)
input ENUM_LINE_STYLE LineStyle  = STYLE_SOLID;   // Line style for wedge lines
input int    LineWidth           = 1;             // Line width (1-5)
input bool   ShowLabels          = true;          // Show pattern labels
input int    LabelFontSize       = 8;             // Label font size
input bool   LabelWithBackground = false;         // Add background rectangle to labels
input color  LabelBgColor        = clrBlack;      // Label background color
input double LabelBgOpacity      = 0.7;           // Background opacity (0.0-1.0)

//+------------------------------------------------------------------+
//| Pivot point class                                                |
//+------------------------------------------------------------------+
class Pivot : public CObject
  {
public:
   int               index;
   datetime          time;
   double            price;

                     Pivot() {}
                     Pivot(int idx,datetime t,double p) : index(idx),time(t),price(p) {}
  };

//+------------------------------------------------------------------+
//| Wedge pattern class                                              |
//+------------------------------------------------------------------+
class Wedge : public CObject
  {
public:
   bool              isRising;
   int               upperStartIdx,upperEndIdx;
   double            upperStartPrice,upperEndPrice;
   int               lowerStartIdx,lowerEndIdx;
   double            lowerStartPrice,lowerEndPrice;
   double            upperSlope,lowerSlope;
   int               formationBar;
   int               eventBar;
   bool              isBroken,isFailed;
   datetime          upperStartTime,upperEndTime;
   datetime          lowerStartTime,lowerEndTime;
   string            upperLineName,lowerLineName;
   string            labelName;
   string            labelBgName; // for background rectangle

                     Wedge() {}

                     Wedge(bool rising,
         int usi, datetime ust, double usp, int uei, datetime uet, double uep,
         int lsi, datetime lst, double lsp, int lei, datetime let, double lep,
         double uslope, double lslope, int formBar)
      :              isRising(rising),
        upperStartIdx(usi), upperStartTime(ust), upperStartPrice(usp),
        upperEndIdx(uei),   upperEndTime(uet),   upperEndPrice(uep),
        lowerStartIdx(lsi), lowerStartTime(lst), lowerStartPrice(lsp),
        lowerEndIdx(lei),   lowerEndTime(let),   lowerEndPrice(lep),
        upperSlope(uslope), lowerSlope(lslope),
        formationBar(formBar), eventBar(-1), isBroken(false), isFailed(false)
     {
      string uid = IntegerToString(formBar)+"_"+IntegerToString(usi)+"_"+IntegerToString(lsi);
      upperLineName = "WEDGE_UPPER_"+uid;
      lowerLineName = "WEDGE_LOWER_"+uid;
      labelName     = "WEDGE_LABEL_"+uid;
      labelBgName   = "WEDGE_LABELBG_"+uid;
     }

                    ~Wedge() { Delete(); }

   double            UpperPriceAt(int barIdx) const { return upperStartPrice + upperSlope * (barIdx - upperStartIdx); }
   double            LowerPriceAt(int barIdx) const { return lowerStartPrice + lowerSlope * (barIdx - lowerStartIdx); }

   //+------------------------------------------------------------------+
   //| Check overlap with another wedge                                 |
   //+------------------------------------------------------------------+
   bool              OverlapsWith(Wedge *other) const
     {
      int thisStart = MathMin(upperStartIdx, lowerStartIdx);
      int thisEnd   = MathMax(upperEndIdx,   lowerEndIdx);
      int otherStart = MathMin(other.upperStartIdx, other.lowerStartIdx);
      int otherEnd   = MathMax(other.upperEndIdx,   other.lowerEndIdx);

      if(thisEnd < otherStart || otherEnd < thisStart)
         return false;

      int overlapStart = MathMax(thisStart, otherStart);
      int overlapEnd   = MathMin(thisEnd,   otherEnd);

      for(int bar=overlapStart; bar<=overlapEnd; bar++)
        {
         double thisUpper = UpperPriceAt(bar);
         double thisLower = LowerPriceAt(bar);
         double otherUpper = other.UpperPriceAt(bar);
         double otherLower = other.LowerPriceAt(bar);

         if(!(thisLower > otherUpper || otherLower > thisUpper))
            return true;
        }
      return false;
     }

   //+------------------------------------------------------------------+
   //| Draw wedge trendlines and optional label                         |
   //+------------------------------------------------------------------+
   void              Draw(void)
     {
      color clr = isRising ? RisingColor : FallingColor;

      //--- Upper trend line
      if(ExtendLines)
        {
         int upperExtIdx = upperEndIdx + LineExtensionBars;
         datetime upperExtTime = upperEndTime + PeriodSeconds(PERIOD_CURRENT) * LineExtensionBars;
         double upperExtPrice = UpperPriceAt(upperExtIdx);
         ObjectCreate(0, upperLineName, OBJ_TREND, 0, upperStartTime, upperStartPrice, upperExtTime, upperExtPrice);
        }
      else
         ObjectCreate(0, upperLineName, OBJ_TREND, 0, upperStartTime, upperStartPrice, upperEndTime, upperEndPrice);

      ObjectSetInteger(0, upperLineName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, upperLineName, OBJPROP_WIDTH, LineWidth);
      ObjectSetInteger(0, upperLineName, OBJPROP_STYLE, LineStyle);
      ObjectSetInteger(0, upperLineName, OBJPROP_RAY_RIGHT, false);

      //--- Lower trend line
      if(ExtendLines)
        {
         int lowerExtIdx = lowerEndIdx + LineExtensionBars;
         datetime lowerExtTime = lowerEndTime + PeriodSeconds(PERIOD_CURRENT) * LineExtensionBars;
         double lowerExtPrice = LowerPriceAt(lowerExtIdx);
         ObjectCreate(0, lowerLineName, OBJ_TREND, 0, lowerStartTime, lowerStartPrice, lowerExtTime, lowerExtPrice);
        }
      else
         ObjectCreate(0, lowerLineName, OBJ_TREND, 0, lowerStartTime, lowerStartPrice, lowerEndTime, lowerEndPrice);

      ObjectSetInteger(0, lowerLineName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, lowerLineName, OBJPROP_WIDTH, LineWidth);
      ObjectSetInteger(0, lowerLineName, OBJPROP_STYLE, LineStyle);
      ObjectSetInteger(0, lowerLineName, OBJPROP_RAY_RIGHT, false);

      //--- Label with formation date
      if(ShowLabels)
        {
         datetime formTime = upperStartTime;
         string baseTxt = (isRising ? "Rising" : "Falling") + " Wedge";
         string dateTxt = TimeToString(formTime, TIME_DATE);
         string txt = baseTxt + "\n" + dateTxt;

         datetime labelTime = MathMax(upperEndTime, lowerEndTime);
         double labelPrice = (upperEndPrice + lowerEndPrice) / 2.0;

         // Create background rectangle if requested
         if(LabelWithBackground)
           {
            int x, y;
            if(ChartTimePriceToXY(0, 0, labelTime, labelPrice, x, y))
              {
               int maxChars = 35;
               int textWidth  = (int)(LabelFontSize * 0.7 * maxChars);
               int lineHeight = (int)(LabelFontSize * 1.5);
               int textHeight = lineHeight * 2;

               int rectX = x;
               int rectY = y - textHeight / 2;
               int margin = 3;

               rectX -= margin;
               rectY -= margin;
               textWidth  += margin * 2;
               textHeight += margin * 2;

               ObjectCreate(0, labelBgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
               ObjectSetInteger(0, labelBgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
               ObjectSetInteger(0, labelBgName, OBJPROP_XDISTANCE, rectX);
               ObjectSetInteger(0, labelBgName, OBJPROP_YDISTANCE, rectY);
               ObjectSetInteger(0, labelBgName, OBJPROP_XSIZE, textWidth);
               ObjectSetInteger(0, labelBgName, OBJPROP_YSIZE, textHeight);
               ObjectSetInteger(0, labelBgName, OBJPROP_BACK, false);
               ObjectSetInteger(0, labelBgName, OBJPROP_FILL, true);
               uchar alpha = (uchar)(LabelBgOpacity * 255);
               uint bgColor = (alpha << 24) | (LabelBgColor & 0xFFFFFF);
               ObjectSetInteger(0, labelBgName, OBJPROP_COLOR, bgColor);
               ObjectSetInteger(0, labelBgName, OBJPROP_WIDTH, 0);
              }
           }

         ObjectCreate(0, labelName, OBJ_TEXT, 0, labelTime, labelPrice);
         ObjectSetString(0, labelName, OBJPROP_TEXT, txt);
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, clr);
         ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, LabelFontSize);
         ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
        }
     }

   //+------------------------------------------------------------------+
   //| Update wedge status - check for breakout or failure              |
   //+------------------------------------------------------------------+
   void              Update(int currentBar, datetime currentTime, double currentClose)
     {
      if(isBroken || isFailed)
         return;

      double upperNow = UpperPriceAt(currentBar);
      double lowerNow = LowerPriceAt(currentBar);

      bool upperBreak = currentClose > upperNow + Point()*3;
      bool lowerBreak = currentClose < lowerNow - Point()*3;

      if((isRising && lowerBreak) || (!isRising && upperBreak))
        {
         isBroken = true;
         eventBar = currentBar;
         color clr = isRising ? RisingColor : FallingColor;
         if(ShowLabels)
           {
            string baseTxt = (isRising ? "Rising" : "Falling") + " Wedge";
            string newTxt = baseTxt + "\nBREAKOUT";
            ObjectSetString(0, labelName, OBJPROP_TEXT, newTxt);
           }
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, clr);
        }
      else
         if((isRising && upperBreak) || (!isRising && lowerBreak) || upperNow <= lowerNow)
           {
            isFailed = true;
            eventBar = currentBar;
            if(ShowLabels)
              {
               string baseTxt = (isRising ? "Rising" : "Falling") + " Wedge";
               string newTxt = baseTxt + "\nFAILED";
               ObjectSetString(0, labelName, OBJPROP_TEXT, newTxt);
              }
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrGray);
           }
     }

   //+------------------------------------------------------------------+
   //| Delete all chart objects associated with this wedge              |
   //+------------------------------------------------------------------+
   void              Delete(void)
     {
      ObjectDelete(0, upperLineName);
      ObjectDelete(0, lowerLineName);
      ObjectDelete(0, labelName);
      ObjectDelete(0, labelBgName);
     }
  };

//+------------------------------------------------------------------+
//| Global storage                                                   |
//+------------------------------------------------------------------+
CArrayObj *pivotHighs = NULL;
CArrayObj *pivotLows  = NULL;
CArrayObj *wedges     = NULL;

//+------------------------------------------------------------------+
//| Check if bar at idx is a pivot high                              |
//+------------------------------------------------------------------+
bool IsPivotHigh(int idx, const double &high[], int left, int right)
  {
   if(idx-left < 0)
      return false;
   double val = high[idx];
   for(int i=idx-left; i<=idx+right; i++)
     {
      if(i==idx)
         continue;
      if(i >= ArraySize(high))
         return false;
      if(high[i] >= val)
         return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Check if bar at idx is a pivot low                               |
//+------------------------------------------------------------------+
bool IsPivotLow(int idx, const double &low[], int left, int right)
  {
   if(idx-left < 0)
      return false;
   double val = low[idx];
   for(int i=idx-left; i<=idx+right; i++)
     {
      if(i==idx)
         continue;
      if(i >= ArraySize(low))
         return false;
      if(low[i] <= val)
         return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Remove oldest wedges when limit is exceeded                      |
//+------------------------------------------------------------------+
void PruneOldWedges(void)
  {
   while(wedges.Total() > MaxWedges)
     {
      Wedge *oldest = dynamic_cast<Wedge*>(wedges.At(0));
      if(oldest)
         oldest.Delete();
      wedges.Delete(0);
     }
  }

//+------------------------------------------------------------------+
//| Check if new wedge overlaps with any existing active wedge       |
//+------------------------------------------------------------------+
bool OverlapsExistingWedge(Wedge *newWedge)
  {
   for(int i = 0; i < wedges.Total(); i++)
     {
      Wedge *w = dynamic_cast<Wedge*>(wedges.At(i));
      if(w == NULL)
         continue;
      if(w.isBroken || w.isFailed)
         continue;
      if(newWedge.OverlapsWith(w))
         return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Try to detect a new wedge pattern from recent pivots             |
//+------------------------------------------------------------------+
void TryDetectWedge(int currentBar, const datetime &time[], const double &close[])
  {
   int nHighs = pivotHighs.Total();
   int nLows  = pivotLows.Total();
   if(nHighs < MinTouches || nLows < MinTouches)
      return;

   Pivot *p1h = dynamic_cast<Pivot*>(pivotHighs.At(nHighs - MinTouches));
   Pivot *pNh = dynamic_cast<Pivot*>(pivotHighs.At(nHighs - 1));
   Pivot *p1l = dynamic_cast<Pivot*>(pivotLows.At(nLows - MinTouches));
   Pivot *pNl = dynamic_cast<Pivot*>(pivotLows.At(nLows - 1));

   if(!p1h || !pNh || !p1l || !pNl)
      return;

   double upperSlope = (pNh.price - p1h.price) / (pNh.index - p1h.index + 1e-10);
   double lowerSlope = (pNl.price - p1l.price) / (pNl.index - p1l.index + 1e-10);

   int wedgeType = 0;
   if(upperSlope > 0 && lowerSlope > 0 && lowerSlope > upperSlope)
      wedgeType = 1;
   if(upperSlope < 0 && lowerSlope < 0 && upperSlope < lowerSlope)
      wedgeType = 2;
   if(wedgeType == 0)
      return;

   double apexX = (p1l.price - p1h.price + upperSlope*p1h.index - lowerSlope*p1l.index) / (upperSlope - lowerSlope + 1e-10);
   if((int)MathRound(apexX) <= currentBar)
      return;

   bool isRising = (wedgeType == 1);
   Wedge *w = new Wedge(isRising, p1h.index, p1h.time, p1h.price, pNh.index, pNh.time, pNh.price,
                        p1l.index, p1l.time, p1l.price, pNl.index, pNl.time, pNl.price,
                        upperSlope, lowerSlope, currentBar);

   if(OverlapsExistingWedge(w))
     {
      delete w;
      return;
     }

   w.Draw();
   wedges.Add(w);
   PruneOldWedges();
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   pivotHighs = new CArrayObj();
   pivotHighs.FreeMode(true);
   pivotLows  = new CArrayObj();
   pivotLows.FreeMode(true);
   wedges     = new CArrayObj();
   wedges.FreeMode(true);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, "WEDGE_");
   if(pivotHighs)
      delete pivotHighs;
   if(pivotLows)
      delete pivotLows;
   if(wedges)
      delete wedges;
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   ArraySetAsSeries(time, false);
   ArraySetAsSeries(high, false);
   ArraySetAsSeries(low, false);
   ArraySetAsSeries(close, false);

   if(prev_calculated == 0)
     {
      ObjectsDeleteAll(0, "WEDGE_");
      pivotHighs.Clear();
      pivotLows.Clear();
      wedges.Clear();

      int startBar = PivotRight;
      int endBar   = rates_total - PivotRight - 1;

      for(int i = startBar; i <= endBar; i++)
        {
         bool newPivot = false;
         if(IsPivotHigh(i, high, PivotLeft, PivotRight))
           {
            pivotHighs.Add(new Pivot(i, time[i], high[i]));
            newPivot = true;
           }
         if(IsPivotLow(i, low, PivotLeft, PivotRight))
           {
            pivotLows.Add(new Pivot(i, time[i], low[i]));
            newPivot = true;
           }
         if(newPivot)
            TryDetectWedge(i, time, close);
        }
     }

   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   for(int i = start; i < rates_total; i++)
     {
      int possibleIdx = i - PivotRight;
      if(possibleIdx < 0)
         continue;

      bool newPivot = false;
      if(IsPivotHigh(possibleIdx, high, PivotLeft, PivotRight))
        {
         pivotHighs.Add(new Pivot(possibleIdx, time[possibleIdx], high[possibleIdx]));
         newPivot = true;
        }
      if(IsPivotLow(possibleIdx, low, PivotLeft, PivotRight))
        {
         pivotLows.Add(new Pivot(possibleIdx, time[possibleIdx], low[possibleIdx]));
         newPivot = true;
        }
      if(newPivot)
         TryDetectWedge(possibleIdx, time, close);
     }

   if(rates_total > 0)
     {
      int currentBar = rates_total - 1;
      for(int j = 0; j < wedges.Total(); j++)
        {
         Wedge *w = dynamic_cast<Wedge*>(wedges.At(j));
         if(w != NULL)
            w.Update(currentBar, time[currentBar], close[currentBar]);
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
