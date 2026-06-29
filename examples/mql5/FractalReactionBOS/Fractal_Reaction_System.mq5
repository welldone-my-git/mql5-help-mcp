//+------------------------------------------------------------------+
//|                                       Fractal Reaction System.mq5|
//|                               Copyright 2025, Christian Benjamin.|
//|                           https://www.mql5.com/en/users/lynnchris|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.0"
#property strict

#include <stdlib_mq5.mqh>

// user inputs
input bool   AutoDetectLength = false;    // if true choose fractal length automatically
input int    LengthInput      = 5;        // fractal length (odd, >=3)
input bool   ShowBull         = true;
input color  BullColor        = clrLime;
input bool   ShowBear         = true;
input color  BearColor        = clrRed;
input int    HorizontalRightBars = 0;     // how many bars to the right (0 = to break)
input int    HorizontalLeftExtend = 3;    // extend older side by N bars
input bool   DebugMode        = false;
input int    MaxFractalHistoryBars = 2000; // how many bars of fractal history to keep (prune older)

// alert/log options
input bool   EnableAlerts        = true;   // built-in alert popup
input bool   EnableNotifications = false;  // mobile/app notifications
input bool   EnableSound         = false;  // play a sound on alert
input string AlertSoundFile      = "alert.wav"; // sound file name (terminal sounds folder)

// internal globals (no executable statements at global scope)
long   g_chart_id;
int    g_length;
int    p_half;
int    ea_digits;
double ea_point, ea_point_pips;

// fractal storage
datetime bull_time[];
double bull_price[];
bool bull_marked[];
datetime bear_time[];
double bear_price[];
bool bear_marked[];

// market state: 0 none, 1 bullish, -1 bearish
int os_state = 0;

// prototypes
void ScanForFractals();
void ProcessFractalCrosses();
bool IsFractalHighAtShift(int shift);
bool IsFractalLowAtShift(int shift);
void DrawBreak(const string tag, datetime fract_time, double fract_price, datetime break_time, bool bullish);
void CreateAnchoredLabel(const string name, const string txt, datetime when, double price, color col);
void CreateTrendLine(const string name, datetime tLeft, double price, datetime tRight, color col, bool dashed=false);
void SafeDelete(const string name);
bool CrossedOver(double prevClose, double curClose, double level);
bool CrossedUnder(double prevClose, double curClose, double level);
string TimeframeToString(int period);
void CleanupObjectsByPrefix(const string prefix);
void PruneFractals(int keepBars);
void EmitLogAlert(const string msg);

//+------------------------------------------------------------------+
// OnInit
//+------------------------------------------------------------------+
int OnInit()
  {
   g_chart_id = ChartID();

// determine fractal length
   if(AutoDetectLength)
     {
      if(_Period <= PERIOD_H1)
         g_length = 5;
      else
         if(_Period <= PERIOD_H4)
            g_length = 7;
         else
            if(_Period <= PERIOD_D1)
               g_length = 9;
            else
               g_length = 11;
     }
   else
     {
      g_length = LengthInput;
     }

// sanitize length: minimum 3 and odd
   if(g_length < 3)
      g_length = 5;
   if((g_length % 2) == 0)
      g_length++; // make odd
   p_half = g_length / 2;

   ea_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   ea_point = Point();
   ea_point_pips = ea_point;
   if(ea_digits == 3 || ea_digits == 5)
      ea_point_pips = Point() * 10.0;

   ArrayResize(bull_time,0);
   ArrayResize(bull_price,0);
   ArrayResize(bull_marked,0);
   ArrayResize(bear_time,0);
   ArrayResize(bear_price,0);
   ArrayResize(bear_marked,0);

   if(DebugMode)
      PrintFormat("EA INIT: AutoDetect=%s LengthInput=%d g_length=%d p_half=%d chart=%d",
                  AutoDetectLength ? "true" : "false", LengthInput, g_length, p_half, g_chart_id);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
// OnDeinit - remove drawn objects added by this EA
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   CleanupObjectsByPrefix("CHB_");
  }

//+------------------------------------------------------------------+
// OnTick - called on every tick. We only run the scan once per new closed bar.
//+------------------------------------------------------------------+
void OnTick()
  {
   static datetime last_checked = 0;
   datetime t = iTime(_Symbol, _Period, 1); // latest closed bar time
   if(t == last_checked)
      return;
   last_checked = t;

   ScanForFractals();
   PruneFractals(MaxFractalHistoryBars);
   ProcessFractalCrosses();
  }

//----------------------- fractal scanning -----------------------------
void ScanForFractals()
  {
   int bars = iBars(_Symbol, _Period);
   if(bars <= g_length)
      return;

   int centerShift = p_half;
   if(centerShift >= bars)
      return;

// high fractal
   if(IsFractalHighAtShift(centerShift))
     {
      datetime t_fr = (datetime)iTime(_Symbol, _Period, centerShift);
      double   p_fr = iHigh(_Symbol, _Period, centerShift);

      bool exists = false;
      for(int i=0;i<ArraySize(bull_time);i++)
         if(bull_time[i]==t_fr)
           {
            exists = true;
            break;
           }
      if(!exists)
        {
         int n = ArraySize(bull_time);
         ArrayResize(bull_time, n+1);
         ArrayResize(bull_price, n+1);
         ArrayResize(bull_marked, n+1);
         bull_time[n] = t_fr;
         bull_price[n] = p_fr;
         bull_marked[n] = false;
         if(DebugMode)
            PrintFormat("FRAC_BULL DETECTED: t=%s price=%G", TimeToString(t_fr, TIME_DATE|TIME_SECONDS), p_fr);
        }
     }

// low fractal
   if(IsFractalLowAtShift(centerShift))
     {
      datetime t_fr = (datetime)iTime(_Symbol, _Period, centerShift);
      double   p_fr = iLow(_Symbol, _Period, centerShift);

      bool exists = false;
      for(int i=0;i<ArraySize(bear_time);i++)
         if(bear_time[i]==t_fr)
           {
            exists = true;
            break;
           }
      if(!exists)
        {
         int n = ArraySize(bear_time);
         ArrayResize(bear_time, n+1);
         ArrayResize(bear_price, n+1);
         ArrayResize(bear_marked, n+1);
         bear_time[n] = t_fr;
         bear_price[n] = p_fr;
         bear_marked[n] = false;
         if(DebugMode)
            PrintFormat("FRAC_BEAR DETECTED: t=%s price=%G", TimeToString(t_fr, TIME_DATE|TIME_SECONDS), p_fr);
        }
     }
  }

// helper: check if bar at shift is a high fractal
bool IsFractalHighAtShift(int shift)
  {
   int bars = iBars(_Symbol,_Period);
   int p = p_half;
   if(shift < 0 || shift >= bars)
      return(false);
   double center = iHigh(_Symbol,_Period,shift);
   for(int k=-p;k<=p;k++)
     {
      if(k==0)
         continue;
      int s = shift + k;
      if(s < 0 || s >= bars)
         return(false); // need full window
      if(iHigh(_Symbol,_Period,s) > center)
         return(false);
     }
   return(true);
  }

// helper: low fractal
bool IsFractalLowAtShift(int shift)
  {
   int bars = iBars(_Symbol,_Period);
   int p = p_half;
   if(shift < 0 || shift >= bars)
      return(false);
   double center = iLow(_Symbol,_Period,shift);
   for(int k=-p;k<=p;k++)
     {
      if(k==0)
         continue;
      int s = shift + k;
      if(s < 0 || s >= bars)
         return(false);
      if(iLow(_Symbol,_Period,s) < center)
         return(false);
     }
   return(true);
  }

//---------------------- process crosses & draw ------------------------
void ProcessFractalCrosses()
  {
   double prevClose = iClose(_Symbol,_Period,2);
   double curClose  = iClose(_Symbol,_Period,1);
   datetime curTime = (datetime)iTime(_Symbol,_Period,1);

// process bullish fractals (oldest-first)
   for(int i=0;i<ArraySize(bull_time);i++)
     {
      if(bull_marked[i])
         continue;
      double level = bull_price[i];
      if(CrossedOver(prevClose, curClose, level))
        {
         datetime fr_time = bull_time[i];
         string tag = "CHB_BULL_" + IntegerToString((int)fr_time);
         bool isChoCH = (os_state == -1);
         string niceName = isChoCH ? "Bull ChoCH" : "Bull BOS";

         if(ShowBull)
           {
            DrawBreak(tag, fr_time, level, curTime, true);
            CreateAnchoredLabel(tag + "_lbl", niceName, fr_time, level + 3*ea_point, BullColor);
           }

         os_state = 1;
         bull_marked[i] = true;

         // emit log & alerts
         string msg = StringFormat("%s detected: %s %s at %s price=%s",
                                   niceName, _Symbol, TimeframeToString(_Period), TimeToString(curTime, TIME_DATE|TIME_MINUTES), DoubleToString(level, ea_digits));
         EmitLogAlert(msg);

         if(DebugMode)
            PrintFormat("BULL_BREAK at %s price=%G type=%s", TimeToString(curTime), level, niceName);
        }
     }

// process bearish fractals
   for(int i=0;i<ArraySize(bear_time);i++)
     {
      if(bear_marked[i])
         continue;
      double level = bear_price[i];
      if(CrossedUnder(prevClose, curClose, level))
        {
         datetime fr_time = bear_time[i];
         string tag = "CHB_BEAR_" + IntegerToString((int)fr_time);
         bool isChoCH = (os_state == 1);
         string niceName = isChoCH ? "Bear ChoCH" : "Bear BOS";

         if(ShowBear)
           {
            DrawBreak(tag, fr_time, level, curTime, false);
            CreateAnchoredLabel(tag + "_lbl", niceName, fr_time, level - 3*ea_point, BearColor);
           }

         os_state = -1;
         bear_marked[i] = true;

         // emit log & alerts
         string msg = StringFormat("%s detected: %s %s at %s price=%s",
                                   niceName, _Symbol, TimeframeToString(_Period), TimeToString(curTime, TIME_DATE|TIME_MINUTES), DoubleToString(level, ea_digits));
         EmitLogAlert(msg);

         if(DebugMode)
            PrintFormat("BEAR_BREAK at %s price=%G type=%s", TimeToString(curTime), level, niceName);
        }
     }
  }

// central logging/alerting function
void EmitLogAlert(const string msg)
  {
// always print to experts log
   Print(msg);

// popup alert
   if(EnableAlerts)
      Alert(msg);

// send push notification (MetaQuotes ID required configured in terminal)
   if(EnableNotifications)
      SendNotification(msg);

// play sound file
   if(EnableSound && StringLen(AlertSoundFile) > 0)
      PlaySound(AlertSoundFile);
  }

// Draw horizontal/trend for the break; extend left a bit to touch recent level
void DrawBreak(const string tag, datetime fract_time, double fract_price, datetime break_time, bool bullish)
  {
   int barFr = iBarShift(_Symbol,_Period,fract_time,false);
   int barBreak = iBarShift(_Symbol,_Period,break_time,false);
   int bars = iBars(_Symbol,_Period);
   if(barFr == -1 || barBreak == -1)
      return;

// older shift = larger index, newer shift = smaller index
   int older_shift = MathMax(barFr, barBreak);
   int newer_shift = MathMin(barFr, barBreak);

// extend older side to the left by HorizontalLeftExtend (older_shift grows)
   older_shift = MathMin(older_shift + HorizontalLeftExtend, bars - 1);

// if user specified a positive HorizontalRightBars, move the newer edge toward the present (smaller shift)
   if(HorizontalRightBars > 0)
     {
      newer_shift = MathMax(newer_shift - HorizontalRightBars, 0);
     }

// sanity: ensure older_shift >= newer_shift, swap if not
   if(older_shift < newer_shift)
     {
      int tmp = older_shift;
      older_shift = newer_shift;
      newer_shift = tmp;
     }

   datetime tLeft  = (datetime)iTime(_Symbol,_Period,older_shift);
   datetime tRight = (datetime)iTime(_Symbol,_Period,newer_shift);

   string lineName = tag + "_line";
   CreateTrendLine(lineName, tLeft, fract_price, tRight, (bullish ? BullColor : BearColor), false);
  }

// create anchored text at time/price (foreground)
void CreateAnchoredLabel(const string name, const string txt, datetime when, double price, color col)
  {
   SafeDelete(name);
   if(ObjectCreate(g_chart_id, name, OBJ_TEXT, 0, when, price))
     {
      ObjectSetString(g_chart_id, name, OBJPROP_TEXT, txt);
      ObjectSetInteger(g_chart_id, name, OBJPROP_COLOR, (int)col);
      ObjectSetInteger(g_chart_id, name, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(g_chart_id, name, OBJPROP_BACK, false);         // foreground
      ObjectSetInteger(g_chart_id, name, OBJPROP_SELECTABLE, false);
      ObjectMove(g_chart_id, name, 0, when, price);
     }
   else
      if(DebugMode)
         PrintFormat("CreateAnchoredLabel failed '%s' err=%d", name, GetLastError());
  }

// create trend/horizontal line from tLeft->tRight at price
void CreateTrendLine(const string name, datetime tLeft, double price, datetime tRight, color col, bool dashed=false)
  {
   SafeDelete(name);
   if(ObjectCreate(g_chart_id, name, OBJ_TREND, 0, tLeft, price, tRight, price))
     {
      ObjectSetInteger(g_chart_id, name, OBJPROP_COLOR, (int)col);
      ObjectSetInteger(g_chart_id, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(g_chart_id, name, OBJPROP_STYLE, dashed ? STYLE_DASH : STYLE_SOLID);
      ObjectSetInteger(g_chart_id, name, OBJPROP_BACK, false);
      ObjectSetInteger(g_chart_id, name, OBJPROP_SELECTABLE, false);
     }
   else
      if(DebugMode)
         PrintFormat("CreateTrendLine failed '%s' err=%d", name, GetLastError());
  }

// safe delete
void SafeDelete(const string name)
  {
   if(ObjectFind(g_chart_id, name) >= 0)
      ObjectDelete(g_chart_id, name);
  }

// crossover helpers using closed bars
bool CrossedOver(double prevClose, double curClose, double level) { return (prevClose <= level && curClose > level); }
bool CrossedUnder(double prevClose, double curClose, double level) { return (prevClose >= level && curClose < level); }

// convert timeframe integer to readable string
string TimeframeToString(int period)
  {
   switch(period)
     {
      case PERIOD_M1:
         return("M1");
      case PERIOD_M5:
         return("M5");
      case PERIOD_M15:
         return("M15");
      case PERIOD_M30:
         return("M30");
      case PERIOD_H1:
         return("H1");
      case PERIOD_H4:
         return("H4");
      case PERIOD_D1:
         return("D1");
      case PERIOD_W1:
         return("W1");
      case PERIOD_MN1:
         return("MN1");
      default:
         return(IntegerToString(period));
     }
  }

// cleanup objects by prefix
void CleanupObjectsByPrefix(const string prefix)
  {
   long chart = g_chart_id;
   int total = ObjectsTotal(chart);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(chart, i);
      if(StringLen(name) >= StringLen(prefix) && StringSubstr(name,0,StringLen(prefix)) == prefix)
        {
         ObjectDelete(chart, name);
        }
     }
  }

// prune fractal arrays to keep memory bounded
void PruneFractals(int keepBars)
  {
   if(keepBars <= 0)
      return;

// prune bulls
   int nB = ArraySize(bull_time);
   if(nB > 0)
     {
      int write = 0;
      for(int i=0;i<nB;i++)
        {
         int sh = iBarShift(_Symbol,_Period,bull_time[i],false);
         // keep if shift valid and not older than keepBars (smaller or equal shifts are more recent)
         if(sh != -1 && sh <= keepBars)
           {
            bull_time[write] = bull_time[i];
            bull_price[write] = bull_price[i];
            bull_marked[write] = bull_marked[i];
            write++;
           }
        }
      if(write != nB)
        {
         ArrayResize(bull_time, write);
         ArrayResize(bull_price, write);
         ArrayResize(bull_marked, write);
         if(DebugMode)
            PrintFormat("Pruned bull fractals: kept=%d removed=%d", write, nB-write);
        }
     }

// prune bears
   int nS = ArraySize(bear_time);
   if(nS > 0)
     {
      int write = 0;
      for(int i=0;i<nS;i++)
        {
         int sh = iBarShift(_Symbol,_Period,bear_time[i],false);
         if(sh != -1 && sh <= keepBars)
           {
            bear_time[write] = bear_time[i];
            bear_price[write] = bear_price[i];
            bear_marked[write] = bear_marked[i];
            write++;
           }
        }
      if(write != nS)
        {
         ArrayResize(bear_time, write);
         ArrayResize(bear_price, write);
         ArrayResize(bear_marked, write);
         if(DebugMode)
            PrintFormat("Pruned bear fractals: kept=%d removed=%d", write, nS-write);
        }
     }
  }

//+------------------------------------------------------------------+
// End of EA
//+------------------------------------------------------------------+
