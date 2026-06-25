//+------------------------------------------------------------------+
//|                                          WeekendGapIndicator.mq5 |
//|                              Copyright 2026, Christian Benjamin. |
//|                          https://www.mql5.com/en/users/lynnchris |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Christian Benjamin."
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.0"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//+------------------------------------------------------------------+
//| INPUTS                                                           |
//+------------------------------------------------------------------+
input bool     ShowHistoricalGaps  = true;          // Show historical gaps
input int      MaxHistoricalWeeks  = 26;            // Maximum historical weeks (visual only)
input double   MinGapPips          = 0.5;           // Minimum gap size in pips
input bool     ShowDetailedLabels  = true;          // Show Fri Close / Mon Open / Mid levels
input color    ActiveFillColor     = clrGainsboro;  // Very light grey fill
input color    ActiveOutlineColor  = clrDimGray;    // Dark grey outline
input color    ReactionColor       = clrDarkOrange; // Reaction state
input color    MemoryOutlineColor  = clrSilver;     // Light silver memory lines
input int      ActiveFillOpacity   = 25;            // Fill opacity (0-100)
input int      LineWidth           = 2;             // Outline width
input int      FontSize            = 7;             // Small professional labels

//+------------------------------------------------------------------+
//| ENUMS & STRUCTURES                                               |
//+------------------------------------------------------------------+
enum ENUM_GAP_STATE
  {
   GAP_FRESH,
   GAP_PARTIAL,
   GAP_REACTION,
   GAP_FILLED,
   GAP_HISTORICAL
  };

struct WeekendGapRecord
  {
   datetime          startTime;
   datetime          endTime;
   double            gapHigh;
   double            gapLow;
   double            midpoint;
   bool              isGapDown;
   ENUM_GAP_STATE    state;
   bool              activeWeek;
  };

struct VisualSettings
  {
   color             activeFillColor;
   color             activeOutlineColor;
   color             reactionColor;
   color             memoryOutlineColor;
   int               activeFillOpacity;
   int               lineWidth;
   int               fontSize;
  };

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
WeekendGapRecord   m_gaps[];
VisualSettings     m_vis;
datetime           m_lastBarTime = 0;
bool               m_firstRun = true;

//+------------------------------------------------------------------+
//| HELPERS                                                          |
//+------------------------------------------------------------------+
string StateToString(ENUM_GAP_STATE state)
  {
   switch(state)
     {
      case GAP_FRESH:
         return "FRESH";
      case GAP_PARTIAL:
         return "PARTIAL";
      case GAP_REACTION:
         return "REACTION";
      case GAP_FILLED:
         return "FILLED";
      case GAP_HISTORICAL:
         return "HIST";
     }
   return "";
  }

//+------------------------------------------------------------------+
//| ColorSetAlpha: Apply alpha channel to a color                    |
//+------------------------------------------------------------------+
color ColorSetAlpha(color clr, uchar alpha)
  {
   return (color)((clr & 0x00FFFFFF) | ((uchar)alpha << 24));
  }

//+------------------------------------------------------------------+
//| GetWeekMonday: Return datetime of Monday of the given week       |
//+------------------------------------------------------------------+
datetime GetWeekMonday(datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   int daysSinceMonday = (dt.day_of_week == 0) ? 6 : (dt.day_of_week - 1);
   return t - daysSinceMonday * 86400 - (t % 86400);
  }

//+------------------------------------------------------------------+
//| PipSize: Return pip value for current symbol                     |
//+------------------------------------------------------------------+
double PipSize()
  {
   return (_Digits == 3 || _Digits == 5) ? (_Point * 10.0) : _Point;
  }

//+------------------------------------------------------------------+
//| GetNextMondayOpen: Calculate next Monday open time               |
//+------------------------------------------------------------------+
datetime GetNextMondayOpen(datetime thisMondayOpenTime)
  {
   return thisMondayOpenTime + 7 * 86400;
  }

//+------------------------------------------------------------------+
//| OBJECT CREATION & UPDATE                                         |
//+------------------------------------------------------------------+
string PrefixForIndex(int idx) { return "WG_" + IntegerToString(idx); }

//+------------------------------------------------------------------+
//| CreateGapObjects: Draw rectangle, lines and labels for a gap     |
//+------------------------------------------------------------------+
void CreateGapObjects(const WeekendGapRecord &gap, string prefix)
  {
   datetime leftTime  = gap.startTime;
   datetime rightEdge = GetNextMondayOpen(gap.startTime);
   long     weekLength = rightEdge - leftTime;

//--- Rectangle
   ObjectCreate(0, prefix + "_RECT", OBJ_RECTANGLE, 0,
                leftTime, gap.gapHigh, rightEdge, gap.gapLow);
   ObjectSetInteger(0, prefix + "_RECT", OBJPROP_COLOR, m_vis.activeOutlineColor);
   ObjectSetInteger(0, prefix + "_RECT", OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, prefix + "_RECT", OBJPROP_WIDTH, m_vis.lineWidth);
   ObjectSetInteger(0, prefix + "_RECT", OBJPROP_BACK, false);
   ObjectSetInteger(0, prefix + "_RECT", OBJPROP_FILL, true);
   ObjectSetInteger(0, prefix + "_RECT", OBJPROP_BGCOLOR,
                    ColorSetAlpha(m_vis.activeFillColor, (uchar)(m_vis.activeFillOpacity * 255 / 100)));

//--- Bold black week separator line
   ObjectCreate(0, prefix + "_VMARK", OBJ_VLINE, 0, leftTime, 0);
   ObjectSetInteger(0, prefix + "_VMARK", OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, prefix + "_VMARK", OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, prefix + "_VMARK", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, prefix + "_VMARK", OBJPROP_BACK, false);

//--- Midpoint line
   double mid = (gap.gapHigh + gap.gapLow) / 2.0;
   ObjectCreate(0, prefix + "_MID", OBJ_TREND, 0,
                leftTime, mid, rightEdge, mid);
   ObjectSetInteger(0, prefix + "_MID", OBJPROP_COLOR, clrDarkGray);
   ObjectSetInteger(0, prefix + "_MID", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, prefix + "_MID", OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, prefix + "_MID", OBJPROP_RAY_RIGHT, false);

//--- Main summary label – bold white, placed at 25% of week width
   double pipDist = (gap.gapHigh - gap.gapLow) / PipSize();
   string text = StringFormat("WG | %.1fp | %s", pipDist, StateToString(gap.state));
   datetime mainLabelTime = (datetime)(leftTime + (long)(weekLength * 0.25));
   ObjectCreate(0, prefix + "_LBL", OBJ_TEXT, 0, mainLabelTime, mid);
   ObjectSetString(0, prefix + "_LBL", OBJPROP_TEXT, text);
   ObjectSetInteger(0, prefix + "_LBL", OBJPROP_FONTSIZE, m_vis.fontSize);
   ObjectSetInteger(0, prefix + "_LBL", OBJPROP_COLOR, clrWhite);
   ObjectSetString(0, prefix + "_LBL", OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, prefix + "_LBL", OBJPROP_ANCHOR, ANCHOR_CENTER);

//--- Detailed level labels – inside the rectangle, bold white
   if(ShowDetailedLabels)
     {
      datetime detailTime = (datetime)(leftTime + (long)(weekLength * 0.05));
      double gapHeight = gap.gapHigh - gap.gapLow;
      double offset = gapHeight * 0.1;
      int smallFont = MathMax(m_vis.fontSize - 1, 6);

      //--- Friday close
      double friPrice = gap.isGapDown ? gap.gapHigh : gap.gapLow;
      string friText = StringFormat("Fri Close: %." + IntegerToString(_Digits) + "f", friPrice);
      ObjectCreate(0, prefix + "_TOP", OBJ_TEXT, 0, detailTime, gap.gapHigh - offset);
      ObjectSetString(0, prefix + "_TOP", OBJPROP_TEXT, friText);
      ObjectSetInteger(0, prefix + "_TOP", OBJPROP_FONTSIZE, smallFont);
      ObjectSetInteger(0, prefix + "_TOP", OBJPROP_COLOR, clrWhite);
      ObjectSetString(0, prefix + "_TOP", OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, prefix + "_TOP", OBJPROP_ANCHOR, ANCHOR_LEFT);

      //--- Monday open
      double monPrice = gap.isGapDown ? gap.gapLow : gap.gapHigh;
      string monText = StringFormat("Mon Open: %." + IntegerToString(_Digits) + "f", monPrice);
      ObjectCreate(0, prefix + "_BOT", OBJ_TEXT, 0, detailTime, gap.gapLow + offset);
      ObjectSetString(0, prefix + "_BOT", OBJPROP_TEXT, monText);
      ObjectSetInteger(0, prefix + "_BOT", OBJPROP_FONTSIZE, smallFont);
      ObjectSetInteger(0, prefix + "_BOT", OBJPROP_COLOR, clrWhite);
      ObjectSetString(0, prefix + "_BOT", OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, prefix + "_BOT", OBJPROP_ANCHOR, ANCHOR_LEFT);

      //--- Midpoint price
      string midText = StringFormat("Mid: %." + IntegerToString(_Digits) + "f", gap.midpoint);
      ObjectCreate(0, prefix + "_MIDPRICE", OBJ_TEXT, 0, detailTime, gap.midpoint);
      ObjectSetString(0, prefix + "_MIDPRICE", OBJPROP_TEXT, midText);
      ObjectSetInteger(0, prefix + "_MIDPRICE", OBJPROP_FONTSIZE, smallFont);
      ObjectSetInteger(0, prefix + "_MIDPRICE", OBJPROP_COLOR, clrWhite);
      ObjectSetString(0, prefix + "_MIDPRICE", OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, prefix + "_MIDPRICE", OBJPROP_ANCHOR, ANCHOR_LEFT);
     }
  }

//+------------------------------------------------------------------+
//| UpdateGapVisuals: Change appearance based on state (active/hist) |
//+------------------------------------------------------------------+
void UpdateGapVisuals(const WeekendGapRecord &gap, string prefix)
  {
   if(ObjectFind(0, prefix + "_RECT") < 0)
      return;

   if(!gap.activeWeek || gap.state == GAP_HISTORICAL)
     {
      //--- Historical – faint silver outline, no fill
      ObjectSetInteger(0, prefix + "_RECT", OBJPROP_COLOR, m_vis.memoryOutlineColor);
      ObjectSetInteger(0, prefix + "_RECT", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, prefix + "_RECT", OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, prefix + "_RECT", OBJPROP_BGCOLOR, clrNONE);
      ObjectSetInteger(0, prefix + "_RECT", OBJPROP_FILL, false);

      //--- Main label – dark grey, normal
      if(ObjectFind(0, prefix + "_LBL") >= 0)
        {
         ObjectSetInteger(0, prefix + "_LBL", OBJPROP_COLOR, clrDimGray);
         ObjectSetString(0, prefix + "_LBL", OBJPROP_FONT, "Arial");
        }
      //--- Detailed labels – dim grey, normal
      if(ObjectFind(0, prefix + "_TOP") >= 0)
        {
         ObjectSetInteger(0, prefix + "_TOP", OBJPROP_COLOR, clrDimGray);
         ObjectSetString(0, prefix + "_TOP", OBJPROP_FONT, "Arial");
        }
      if(ObjectFind(0, prefix + "_BOT") >= 0)
        {
         ObjectSetInteger(0, prefix + "_BOT", OBJPROP_COLOR, clrDimGray);
         ObjectSetString(0, prefix + "_BOT", OBJPROP_FONT, "Arial");
        }
      if(ObjectFind(0, prefix + "_MIDPRICE") >= 0)
        {
         ObjectSetInteger(0, prefix + "_MIDPRICE", OBJPROP_COLOR, clrDimGray);
         ObjectSetString(0, prefix + "_MIDPRICE", OBJPROP_FONT, "Arial");
        }
     }
   else
     {
      //--- Active week – solid outline with light fill
      ObjectSetInteger(0, prefix + "_RECT", OBJPROP_COLOR, m_vis.activeOutlineColor);
      ObjectSetInteger(0, prefix + "_RECT", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, prefix + "_RECT", OBJPROP_WIDTH, m_vis.lineWidth);
      ObjectSetInteger(0, prefix + "_RECT", OBJPROP_FILL, true);
      ObjectSetInteger(0, prefix + "_RECT", OBJPROP_BGCOLOR,
                       ColorSetAlpha(m_vis.activeFillColor, (uchar)(m_vis.activeFillOpacity * 255 / 100)));

      //--- Main label – bold white
      if(ObjectFind(0, prefix + "_LBL") >= 0)
        {
         ObjectSetInteger(0, prefix + "_LBL", OBJPROP_COLOR, clrWhite);
         ObjectSetString(0, prefix + "_LBL", OBJPROP_FONT, "Arial Bold");
        }
      //--- Detailed labels – bold white
      if(ObjectFind(0, prefix + "_TOP") >= 0)
        {
         ObjectSetInteger(0, prefix + "_TOP", OBJPROP_COLOR, clrWhite);
         ObjectSetString(0, prefix + "_TOP", OBJPROP_FONT, "Arial Bold");
        }
      if(ObjectFind(0, prefix + "_BOT") >= 0)
        {
         ObjectSetInteger(0, prefix + "_BOT", OBJPROP_COLOR, clrWhite);
         ObjectSetString(0, prefix + "_BOT", OBJPROP_FONT, "Arial Bold");
        }
      if(ObjectFind(0, prefix + "_MIDPRICE") >= 0)
        {
         ObjectSetInteger(0, prefix + "_MIDPRICE", OBJPROP_COLOR, clrWhite);
         ObjectSetString(0, prefix + "_MIDPRICE", OBJPROP_FONT, "Arial Bold");
        }
     }

//--- Update midpoint visibility
   if(ObjectFind(0, prefix + "_MID") >= 0)
      ObjectSetInteger(0, prefix + "_MID", OBJPROP_TIMEFRAMES,
                       (gap.activeWeek && gap.state != GAP_HISTORICAL) ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);

//--- Refresh main label text
   if(ObjectFind(0, prefix + "_LBL") >= 0)
     {
      double pipDist = (gap.gapHigh - gap.gapLow) / PipSize();
      string text = StringFormat("WG | %.1fp | %s", pipDist, StateToString(gap.state));
      ObjectSetString(0, prefix + "_LBL", OBJPROP_TEXT, text);
     }
  }

//+------------------------------------------------------------------+
//| DETECT WEEKEND GAPS (time gap)                                   |
//+------------------------------------------------------------------+
void DetectAllGaps(const datetime &time[],
                   const double   &open[],
                   const double   &close[],
                   int             rates_total)
  {
   ArrayResize(m_gaps, 0);
   if(rates_total < 2)
      return;

   datetime timeArr[];
   double   openArr[];
   double   closeArr[];
   ArraySetAsSeries(timeArr, true);
   ArraySetAsSeries(openArr, true);
   ArraySetAsSeries(closeArr, true);
   if(CopyTime(_Symbol, _Period, 0, rates_total, timeArr) < 0)
      return;
   if(CopyOpen(_Symbol, _Period, 0, rates_total, openArr) < 0)
      return;
   if(CopyClose(_Symbol, _Period, 0, rates_total, closeArr) < 0)
      return;

   double pip = PipSize();
   int limit = MathMin(rates_total - 1, 10000);

   for(int i = 1; i < limit; i++)
     {
      double diffSeconds = (double)(timeArr[i-1] - timeArr[i]);
      if(diffSeconds >= 172800)   //--- 48 hours
        {
         double fridayClose = closeArr[i];
         double mondayOpen  = openArr[i-1];
         double gapPips = MathAbs(mondayOpen - fridayClose) / pip;

         if(gapPips >= MinGapPips)
           {
            WeekendGapRecord gap;
            gap.startTime  = timeArr[i-1];
            gap.endTime    = GetNextMondayOpen(timeArr[i-1]);
            gap.gapHigh    = MathMax(mondayOpen, fridayClose);
            gap.gapLow     = MathMin(mondayOpen, fridayClose);
            gap.midpoint   = (gap.gapHigh + gap.gapLow) / 2.0;
            gap.isGapDown  = (fridayClose > mondayOpen);
            gap.activeWeek = (GetWeekMonday(timeArr[i-1]) == GetWeekMonday(TimeCurrent()));
            gap.state      = gap.activeWeek ? GAP_FRESH : GAP_HISTORICAL;

            int size = ArraySize(m_gaps);
            ArrayResize(m_gaps, size + 1);
            m_gaps[size] = gap;
           }
        }
     }

   Print("Weekend Gap Indicator: Detected ", ArraySize(m_gaps), " gaps.");
  }

//+------------------------------------------------------------------+
//| STATE UPDATE (active week only)                                  |
//+------------------------------------------------------------------+
void UpdateCurrentState()
  {
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   for(int i = 0; i < ArraySize(m_gaps); i++)
     {
      if(!m_gaps[i].activeWeek)
         continue;
      if(m_gaps[i].state == GAP_HISTORICAL || m_gaps[i].state == GAP_FILLED)
         continue;

      bool isGapDown = m_gaps[i].isGapDown;
      double high = m_gaps[i].gapHigh;
      double low  = m_gaps[i].gapLow;
      ENUM_GAP_STATE newState = m_gaps[i].state;

      if(isGapDown)
        {
         if(currentPrice > high)
            newState = GAP_FILLED;
         else
            if(currentPrice > low && currentPrice <= high)
              {
               if(m_gaps[i].state == GAP_FRESH)
                  newState = GAP_PARTIAL;
              }
            else
               if(currentPrice <= low)
                 {
                  if(m_gaps[i].state == GAP_PARTIAL)
                     newState = GAP_REACTION;
                 }
        }
      else
        {
         if(currentPrice < low)
            newState = GAP_FILLED;
         else
            if(currentPrice >= low && currentPrice < high)
              {
               if(m_gaps[i].state == GAP_FRESH)
                  newState = GAP_PARTIAL;
              }
            else
               if(currentPrice >= high)
                 {
                  if(m_gaps[i].state == GAP_PARTIAL)
                     newState = GAP_REACTION;
                 }
        }

      if(newState != m_gaps[i].state)
        {
         m_gaps[i].state = newState;
         UpdateGapVisuals(m_gaps[i], PrefixForIndex(i));
        }
     }
  }

//+------------------------------------------------------------------+
//| EVENT HANDLERS                                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   m_vis.activeFillColor    = ActiveFillColor;
   m_vis.activeOutlineColor = ActiveOutlineColor;
   m_vis.reactionColor      = ReactionColor;
   m_vis.memoryOutlineColor = MemoryOutlineColor;
   m_vis.activeFillOpacity  = ActiveFillOpacity;
   m_vis.lineWidth          = LineWidth;
   m_vis.fontSize           = FontSize;

   m_firstRun = true;
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit: Clean up objects on deinitialization                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, "WG_");
  }

//+------------------------------------------------------------------+
//| OnCalculate: Main indicator calculation function                 |
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
   if(rates_total < 2)
      return(0);

   if(m_firstRun)
     {
      DetectAllGaps(time, open, close, rates_total);
      for(int i = 0; i < ArraySize(m_gaps); i++)
         CreateGapObjects(m_gaps[i], PrefixForIndex(i));
      m_firstRun = false;
     }

   UpdateCurrentState();

   datetime currentBarTime = time[0];
   if(currentBarTime != m_lastBarTime)
     {
      m_lastBarTime = currentBarTime;
      datetime barMonday = GetWeekMonday(currentBarTime);
      for(int i = 0; i < ArraySize(m_gaps); i++)
        {
         if(m_gaps[i].activeWeek && m_gaps[i].startTime < barMonday)
           {
            m_gaps[i].activeWeek = false;
            m_gaps[i].state = GAP_HISTORICAL;
            UpdateGapVisuals(m_gaps[i], PrefixForIndex(i));
           }
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+