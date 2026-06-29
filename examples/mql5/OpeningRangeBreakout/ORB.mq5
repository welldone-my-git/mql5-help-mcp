//+------------------------------------------------------------------+
//|                                                   ORB Breakout EA|
//|                                   Copyright 2025, MetaQuotes Ltd.|
//|                           https://www.mql5.com/en/users/lynnchris|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>

//--- inputs: session & range
input int            SessionIndex    = 0;            // which trading session
input int            RangeMinutes    = 15;           // opening range length
//--- inputs: ATR filter
input ENUM_TIMEFRAMES TF              = PERIOD_M1;   // ATR timeframe
input int            ATRPeriod       = 14;           // ATR period
input double         ATRMultiplier   = 1.5;          // ATR × multiplier
//--- inputs: entry arrows & alerts
input int            ArrowUpCode     = 233;          // Wingdings ↑
input int            ArrowDnCode     = 234;          // Wingdings ↓
input color          ArrowUpColor    = clrLime;      // color for long arrow
input color          ArrowDnColor    = clrRed;       // color for short arrow
input bool           SendEmailAlert  = false;        // send email on signal?
input bool           PushNotify      = false;        // send push on signal?
input string         EmailSubject    = "ORB Signal"; // subject line

//+------------------------------------------------------------------+
//|  Capture the opening range                                       |
//+------------------------------------------------------------------+
class CRangeCapture
  {
private:
   datetime          startTime;
   double            hi, lo;
public:
   void              Init(datetime t, double price)
     {
      startTime = t;
      hi = lo = price;
     }
   void              Update(double price, datetime now)
     {
      if(now < startTime + RangeMinutes*60)
        {
         hi = MathMax(hi, price);
         lo = MathMin(lo, price);
        }
     }
   bool              IsDefined(datetime now) const { return(now >= startTime + RangeMinutes*60); }
   double            High()       const { return hi; }
   double            Low()        const { return lo; }
  };
static CRangeCapture g_range;

//+------------------------------------------------------------------+
//|  ATR‑based stop & target                                         |
//+------------------------------------------------------------------+
class CATRModule
  {
private:
   int               handle;
public:
   bool              Init()
     {
      handle = INVALID_HANDLE;
      handle = iATR(_Symbol, TF, ATRPeriod);
      return(handle != INVALID_HANDLE);
     }
   double            Value() const
     {
      double buf[];
      if(handle != INVALID_HANDLE && CopyBuffer(handle, 0, 0, 1, buf) == 1)
         return buf[0] * ATRMultiplier;
      return 0.0;
     }
   void              Release()
     {
      if(handle != INVALID_HANDLE)
         IndicatorRelease(handle);
     }
  };
static CATRModule g_atr;

//+------------------------------------------------------------------+
//|  Break‑and‑retest logic                                          |
//+------------------------------------------------------------------+
class CRetestSignal
  {
private:
   bool              breakLong;
   bool              breakShort;
   bool              retested;
public:
   void              Reset()
     {
      breakLong  = false;
      breakShort = false;
      retested   = false;
     }
   void              OnBreak(double close, double h, double l)
     {
      breakLong  = (close > h);
      breakShort = (close < l);
      retested   = false;
     }
   bool              CheckRetest(const MqlRates &r, bool &isLong)
     {
      // LONG side
      if(breakLong)
        {
         if(!retested && r.low <= g_range.High())
           {
            retested = true;
            isLong   = true;
            return false;
           }
         if(retested && r.close > g_range.High())
           {
            isLong = true;
            return true;
           }
        }
      // SHORT side
      else
         if(breakShort)
           {
            if(!retested && r.high >= g_range.Low())
              {
               retested = true;
               isLong   = false;
               return false;
              }
            if(retested && r.close < g_range.Low())
              {
               isLong = false;
               return true;
              }
           }
      return false;
     }
  };
static CRetestSignal g_retest;

//+------------------------------------------------------------------+
//|  On‑chart dashboard                                              |
//+------------------------------------------------------------------+
class CDashboard
  {
private:
   string            name;
public:
   void              Init()
     {
      name = "ORB_Info";
      if(ObjectFind(0, name) < 0)
        {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 30);
        }
     }
   void              Update(const string &txt)
     {               ObjectSetString(0, name, OBJPROP_TEXT, txt); }
   void              Delete()
     {
      if(ObjectFind(0, name) >= 0)
         ObjectDelete(0, name);
     }
  };
static CDashboard g_dash;

//--- trade interface
static CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(!g_atr.Init())
     {
      Print("ERROR: failed to init ATR");
      return INIT_FAILED;
     }
   g_dash.Init();
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   g_atr.Release();
   ObjectDelete(0, "ORB_High");
   ObjectDelete(0, "ORB_Low");
   ObjectDelete(0, "ORB_Range");
   g_dash.Delete();
  }

//+------------------------------------------------------------------+
//| Tick handler                                                     |
//+------------------------------------------------------------------+
void OnTick()
  {
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);

   static bool    inited        = false;
   static int     state         = 0;
   static datetime sessionStart;

//--- initialize session
   if(!inited)
     {
      datetime from, to;
      if(!SymbolInfoSessionTrade(_Symbol,
                                 (ENUM_DAY_OF_WEEK)dt.day_of_week,
                                 SessionIndex,
                                 from, to))
        {
         Print("ERROR: session times unavailable");
         return;
        }
      sessionStart = (now - now % 86400) + (from % 86400);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      g_range.Init(sessionStart, bid);
      g_retest.Reset();
      inited = true;
      state   = 0;
      Alert("ORB session start: " +
            TimeToString(sessionStart, TIME_DATE|TIME_MINUTES));
     }

//--- grab latest bar
   MqlRates r[1];
   if(CopyRates(_Symbol, TF, 0, 1, r) != 1)
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double h   = g_range.High();
   double l   = g_range.Low();

//--- state machine
   switch(state)
     {
      // CAPTURE
      case 0:
         g_range.Update(bid, now);
         if(g_range.IsDefined(now))
           {
            state = 1;
            ObjectCreate(0, "ORB_High",  OBJ_HLINE,     0, 0, h);
            ObjectCreate(0, "ORB_Low",   OBJ_HLINE,     0, 0, l);
            ObjectCreate(0, "ORB_Range", OBJ_RECTANGLE, 0,
                         sessionStart, h,
                         sessionStart + RangeMinutes*60, l);
            Alert(StringFormat("Range defined: H=%.5f L=%.5f", h, l));
           }
         break;

      // WAIT FOR BREAK
      case 1:
         if(r[0].close > h || r[0].close < l)
           {
            g_retest.OnBreak(r[0].close, h, l);
            state = 2;
            Alert(r[0].close > h ? "Breakout Long" : "Breakout Short");
           }
         break;

      // WAIT FOR RETEST
      case 2:
        {
         bool isLong = false;
         if(g_retest.CheckRetest(r[0], isLong))
           {
            double atr = g_atr.Value();
            double sl  = isLong ? r[0].close - atr
                         : r[0].close + atr;
            double tp  = isLong ? r[0].close + atr
                         : r[0].close - atr;
            // draw arrow
            string arrowName = "ORB_Arrow_" + IntegerToString((int)r[0].time);
            ObjectCreate(0, arrowName, OBJ_ARROW, 0,
                         r[0].time,
                         isLong
                         ? r[0].low  - SymbolInfoDouble(_Symbol, SYMBOL_POINT)*5
                         : r[0].high + SymbolInfoDouble(_Symbol, SYMBOL_POINT)*5);
            ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE,
                             isLong ? ArrowUpCode : ArrowDnCode);
            ObjectSetInteger(0, arrowName, OBJPROP_COLOR,
                             isLong ? ArrowUpColor : ArrowDnColor);

            // alerts
            string msg = (isLong ? "LONG" : "SHORT") +
                         StringFormat(" Signal @%.5f SL=%.5f TP=%.5f",
                                      r[0].close, sl, tp);
            Alert(msg);
            if(PushNotify)
               SendNotification(msg);
            if(SendEmailAlert)
               SendMail(EmailSubject, msg);

            state = 3;
           }
        }
      break;

      // DONE
      case 3:
         break;
     }

//--- update dashboard
   double atrNow = g_atr.Value();
   string info = StringFormat("State=%d ATR=%.4f Range=%.4f",
                              state, atrNow, h - l);
   g_dash.Update(info);

//--- reset at midnight
   static datetime lastDay = 0;
   datetime today = now - now % 86400;
   if(today != lastDay)
     {
      lastDay = today;
      inited  = false;
      state   = 0;
      ObjectDelete(0, "ORB_High");
      ObjectDelete(0, "ORB_Low");
      ObjectDelete(0, "ORB_Range");
     }
  }
//+------------------------------------------------------------------+
