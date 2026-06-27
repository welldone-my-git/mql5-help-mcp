//+------------------------------------------------------------------+
//|                                          DVN Session Boxes       |
//|                                Copyright 2026, DVN CORE         |
//|                       https://www.mql5.com/en/users/wazatrader  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, DVN CORE"
#property link      "https://www.mql5.com/en/users/wazatrader"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

//--- Inputs -----------------------------------------------------------
input group "=== Session Hours (GMT) ==="
input int   InpAsiaStartGMT    = 0;   // Asia start (GMT)
input int   InpAsiaEndGMT      = 8;   // Asia end (GMT)
input int   InpLondonStartGMT  = 7;   // London start (GMT)
input int   InpLondonEndGMT    = 16;  // London end (GMT)
input int   InpNYStartGMT      = 12;  // New York start (GMT)
input int   InpNYEndGMT        = 21;  // New York end (GMT)
input int   InpBrokerGMTOffset = 2;   // Broker server offset vs GMT (hours)

input group "=== Display ==="
input int   InpBoxLookbackDays = 50;            // Past days to draw
input color InpAsiaColor       = clrSlateBlue;  // Asia box color
input color InpLondonColor     = clrSeaGreen;   // London box color
input color InpNYColor         = clrGoldenrod;  // New York box color

//--- Globals ----------------------------------------------------------
string g_prefix = "DVN_SB_" + IntegerToString((int)ChartID()) + "_";

struct SessionDef
{
   string name;
   int    startGMT;
   int    endGMT;
   color  clr;
};

SessionDef g_sessions[3];
bool g_drawn = false;

//+------------------------------------------------------------------+
int OnInit()
{
   g_sessions[0].name     = "Asia";
   g_sessions[0].startGMT = InpAsiaStartGMT;
   g_sessions[0].endGMT   = InpAsiaEndGMT;
   g_sessions[0].clr      = InpAsiaColor;

   g_sessions[1].name     = "London";
   g_sessions[1].startGMT = InpLondonStartGMT;
   g_sessions[1].endGMT   = InpLondonEndGMT;
   g_sessions[1].clr      = InpLondonColor;

   g_sessions[2].name     = "NewYork";
   g_sessions[2].startGMT = InpNYStartGMT;
   g_sessions[2].endGMT   = InpNYEndGMT;
   g_sessions[2].clr      = InpNYColor;

   g_drawn = false;
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, g_prefix);
}

//+------------------------------------------------------------------+
void OnTimer()
{
   if(!g_drawn)
      DrawSessionBoxes();
}

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
   if(!g_drawn)
      DrawSessionBoxes();
   return rates_total;
}

//+------------------------------------------------------------------+
void DrawSessionBoxes()
{
   MqlRates rates[];
   int barsNeeded = InpBoxLookbackDays * 24;
   int copied = CopyRates(_Symbol, PERIOD_H1, 0, MathMax(barsNeeded, 24), rates);
   if(copied <= 0) return;

   ArraySetAsSeries(rates, false);
   ObjectsDeleteAll(0, g_prefix);

   for(int s = 0; s < 3; s++)
   {
      datetime lastDay = 0;
      double   boxHigh = -DBL_MAX, boxLow = DBL_MAX;
      datetime boxStart = 0, boxEnd = 0;
      bool     active = false;
      int      boxIdx = 0;

      for(int i = 0; i < copied; i++)
      {
         MqlDateTime dt;
         TimeToStruct(rates[i].time, dt);

         int gmtHour = dt.hour - InpBrokerGMTOffset;
         if(gmtHour < 0)   gmtHour += 24;
         if(gmtHour >= 24) gmtHour -= 24;

         datetime dayKey = rates[i].time - (rates[i].time % 86400);
         bool inSession = IsHourInSession(gmtHour, g_sessions[s].startGMT, g_sessions[s].endGMT);

         if(inSession)
         {
            if(!active || dayKey != lastDay)
            {
               if(active)
                  CreateBox(s, boxIdx++, boxStart, boxEnd, boxHigh, boxLow);

               active   = true;
               lastDay  = dayKey;
               boxStart = rates[i].time;
               boxHigh  = rates[i].high;
               boxLow   = rates[i].low;
            }
            else
            {
               if(rates[i].high > boxHigh) boxHigh = rates[i].high;
               if(rates[i].low  < boxLow)  boxLow  = rates[i].low;
            }
            boxEnd = rates[i].time + PeriodSeconds(PERIOD_H1);
         }
         else
         {
            if(active)
            {
               CreateBox(s, boxIdx++, boxStart, boxEnd, boxHigh, boxLow);
               active = false;
            }
         }
      }
      if(active)
         CreateBox(s, boxIdx++, boxStart, boxEnd, boxHigh, boxLow);
   }

   g_drawn = true;
   EventKillTimer();
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
void CreateBox(int s, int idx, datetime t1, datetime t2, double hi, double lo)
{
   string name = g_prefix + g_sessions[s].name + "_" + IntegerToString(idx);
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);

   ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, hi, t2, lo);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      g_sessions[s].clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE,      STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,      1);
   ObjectSetInteger(0, name, OBJPROP_FILL,       true);
   ObjectSetInteger(0, name, OBJPROP_BACK,       true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
}

//+------------------------------------------------------------------+
bool IsHourInSession(int gmtHour, int startGMT, int endGMT)
{
   if(startGMT <= endGMT)
      return (gmtHour >= startGMT && gmtHour < endGMT);
   return (gmtHour >= startGMT || gmtHour < endGMT);
}
//+------------------------------------------------------------------+