//+------------------------------------------------------------------+
//|                                                    SPIKE DETECTOR|
//|                                   Copyright 2025, MetaQuotes Ltd.|
//|                           https://www.mql5.com/en/users/lynnchris|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>

//─── INPUT PARAMETERS ───────────────────────────────────────────────
input string InpServerURL       = "http://127.0.0.1:5000/analyze";
input int    InpBufferBars      = 200;
input int    InpTimeoutMs       = 3000;
input bool   PollOnNewBarOnly   = true;
input int    MinSecsBetweenReq  = 10;

input color  ColorBuy           = clrLime;
input color  ColorSell          = clrRed;
input color  ColorClose         = clrOrange;
input int    ArrowSize          = 2;

input bool   DrawSLTPLines      = true;
input bool   EnableTrading      = true;
input double FixedLots          = 0.10;
input int    SlippagePoints     = 10;

input int    MaxRetry           = 3;
input bool   DebugPrintJSON     = true;
input bool   DebugPrintReply    = true;

//─── GLOBAL VARIABLES ──────────────────────────────────────────────
CTrade  trade;
datetime lastBarTime     = 0;
datetime lastReqTime     = 0;
int      retryCount      = 0;
string   objPrefix;
int      _digits;
double   tickSize;

//─── ENUM & STRUCT FOR SERVER MESSAGE ─────────────────────────────
enum ESignal
  {
   SIG_WAIT  = 0,
   SIG_BUY   = 1,
   SIG_SELL  = -1,
   SIG_CLOSE = 2
  };

struct SServerMsg
  {
   ESignal           code;
   double            conf;
   double            sl;
   double            tp;
  };

//+------------------------------------------------------------------+
//| Expert initialization                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpBufferBars < 2)
     {
      Print("Error: InpBufferBars must be ≥ 2");
      return(INIT_FAILED);
     }

   _digits   = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   objPrefix = StringFormat("SpikeEA_%I64d_", ChartID());

   PrintFormat("[SpikeEA] Initialized. Will POST %d bars to %s",
               InpBufferBars, InpServerURL);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   for(int i=ObjectsTotal(0)-1; i>=0; --i)
     {
      string name = ObjectName(0, i);
      if(StringFind(name, objPrefix) == 0)
         ObjectDelete(0, name);
     }
  }

//+------------------------------------------------------------------+
//| Expert tick                                                     |
//+------------------------------------------------------------------+
void OnTick()
  {
   datetime barTime = iTime(_Symbol, _Period, 0);
   if(PollOnNewBarOnly && barTime == lastBarTime)
      return;
   if(PollOnNewBarOnly)
      lastBarTime = barTime;
   if(TimeCurrent() - lastReqTime < MinSecsBetweenReq)
      return;

   MqlRates rates[];
   if(CopyRates(_Symbol, _Period, 0, InpBufferBars, rates) != InpBufferBars)
      return;
   ArraySetAsSeries(rates, true);

   string payload = BuildJSON(rates);
   if(DebugPrintJSON)
      PrintFormat("[SpikeEA] >>> %s", payload);

   SServerMsg msg;
   if(CallServer(payload, msg))
      ActOnSignal(msg);

   lastReqTime = TimeCurrent();
  }

//+------------------------------------------------------------------+
//| Build JSON from rates                                           |
//+------------------------------------------------------------------+
string BuildJSON(const MqlRates &r[])
  {
   string sym = _Symbol;
   StringReplace(sym, "\\", "\\\\");
   StringReplace(sym, "\"", "\\\"");

   string j = "{\"symbol\":\"" + sym + "\",\"prices\":[";
   for(int i = 0; i < InpBufferBars; i++)
     {
      j += DoubleToString(r[i].close, _digits);
      if(i < InpBufferBars - 1)
         j += ",";
     }
   j += "],\"timestamps\":[";
   for(int i = 0; i < InpBufferBars; i++)
     {
      j += IntegerToString(r[i].time);
      if(i < InpBufferBars - 1)
         j += ",";
     }
   j += "]}";
   return j;
  }

//+------------------------------------------------------------------+
//| HTTP POST + parse                                                |
//+------------------------------------------------------------------+
bool CallServer(const string &payload, SServerMsg &out)
  {
   uchar  body[];
   int    len = StringToCharArray(payload, body, 0, WHOLE_ARRAY, CP_UTF8);
   if(len > 0 && body[len-1] == 0)
      len--;
   ArrayResize(body, len);

   string hdr = "Content-Type: application/json\r\n";
   uchar  reply[];
   string resp_hdr;

   int status = WebRequest("POST", InpServerURL, hdr,
                           InpTimeoutMs, body, reply, resp_hdr);
   if(status <= 0)
     {
      PrintFormat("WebRequest error %d (retry %d/%d)",
                  GetLastError(), retryCount+1, MaxRetry);
      ResetLastError();
      if(++retryCount >= MaxRetry)
         retryCount = 0;
      return false;
     }
   retryCount = 0;

   string resp = CharArrayToString(reply);
   if(DebugPrintReply)
      PrintFormat("[SpikeEA] <<< HTTP %d – %s", status, resp);
   if(status != 200)
      return false;

   return ParseJSONLite(resp, out);
  }

//+------------------------------------------------------------------+
//| Lightweight JSON parser                                         |
//+------------------------------------------------------------------+
bool ParseJSONLite(const string &txt, SServerMsg &o)
  {
   o.code = SIG_WAIT;
   o.conf = 0.0;
   o.sl = 0.0;
   o.tp = 0.0;

// simple keyword checks
   if(StringFind(txt, "\"signal\":\"BUY\"")   >= 0)
      o.code = SIG_BUY;
   if(StringFind(txt, "\"signal\":\"SELL\"")  >= 0)
      o.code = SIG_SELL;
   if(StringFind(txt, "\"signal\":\"CLOSE\"") >= 0)
      o.code = SIG_CLOSE;

// parse numeric "signal":1 etc.
   int p = StringFind(txt, "\"signal\":");
   if(p >= 0)
     {
      p += StringLen("\"signal\":");
      // skip until digit or sign
      while(p < StringLen(txt) && !CharIsDigitOrSign((uchar)txt[p]))
         p++;
      string num = "";
      while(p < StringLen(txt) && CharIsDigitOrSign((uchar)txt[p]))
        {
         num += StringSubstr(txt, p, 1);
         p++;
        }
      if(StringLen(num) > 0)
        {
         int v = (int)StringToInteger(num);
         if(v ==  1)
            o.code = SIG_BUY;
         if(v == -1)
            o.code = SIG_SELL;
         if(v ==  2)
            o.code = SIG_CLOSE;
        }
     }

// parse doubles
   ParseJSONDouble(txt, "\"conf\":", o.conf);
   ParseJSONDouble(txt, "\"sl\":",   o.sl);
   ParseJSONDouble(txt, "\"tp\":",   o.tp);

   return true;
  }

//+------------------------------------------------------------------+
//| Extract double after key                                        |
//+------------------------------------------------------------------+
void ParseJSONDouble(const string &txt, const string &key, double &out)
  {
   int p = StringFind(txt, key);
   if(p >= 0)
     {
      p += StringLen(key);
      out = StringToDouble(StringSubstr(txt, p));
     }
  }

//+------------------------------------------------------------------+
//| Check if uchar is digit or sign                                 |
//+------------------------------------------------------------------+
bool CharIsDigitOrSign(uchar c)
  {
   return((c >= '0' && c <= '9') || c == '-' || c == '+');
  }

//+------------------------------------------------------------------+
//| Draw arrows/lines & optionally trade                             |
//+------------------------------------------------------------------+
void ActOnSignal(const SServerMsg &m)
  {
   static ESignal last = SIG_WAIT;
   if(m.code == SIG_WAIT || m.code == last)
      return;
   last = m.code;

// clear previous
   for(int i=ObjectsTotal(0)-1; i>=0; --i)
     {
      string name = ObjectName(0, i);
      if(StringFind(name, objPrefix) == 0)
         ObjectDelete(0, name);
     }

// arrow setup
   int arrow = 221;
   color clr = clrSilver;
   if(m.code == SIG_BUY)
     {
      arrow = 233;
      clr = ColorBuy;
     }
   if(m.code == SIG_SELL)
     {
      arrow = 234;
      clr = ColorSell;
     }
   if(m.code == SIG_CLOSE)
     {
      arrow = 158;
      clr = ColorClose;
     }
   string ts = TimeToString(TimeCurrent(), TIME_SECONDS);
   string id = objPrefix + "Arr_" + ts;
   double y  = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(ObjectCreate(0, id, OBJ_ARROW, 0, TimeCurrent(), y))
     {
      ObjectSetInteger(0, id, OBJPROP_ARROWCODE, arrow);
      ObjectSetInteger(0, id, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, id, OBJPROP_WIDTH, ArrowSize);
      PlaySound("alert.wav");
     }

// SL/TP lines
   if(DrawSLTPLines)
     {
      if(m.sl > 0)
        {
         string sl_id = objPrefix + "SL_" + ts;
         ObjectCreate(0, sl_id, OBJ_HLINE, 0, 0, m.sl);
         ObjectSetInteger(0, sl_id, OBJPROP_COLOR, clrRed);
         ObjectSetString(0, sl_id, OBJPROP_TEXT, "SL " + DoubleToString(m.sl, _digits));
        }
      if(m.tp > 0)
        {
         string tp_id = objPrefix + "TP_" + ts;
         ObjectCreate(0, tp_id, OBJ_HLINE, 0, 0, m.tp);
         ObjectSetInteger(0, tp_id, OBJPROP_COLOR, clrLime);
         ObjectSetString(0, tp_id, OBJPROP_TEXT, "TP " + DoubleToString(m.tp, _digits));
        }
     }

// trading
   if(EnableTrading)
     {
      bool hasPos = PositionSelect(_Symbol);
      if(m.code == SIG_BUY   && !hasPos)
         trade.Buy(FixedLots, _Symbol, 0, m.sl, m.tp, NULL);
      if(m.code == SIG_SELL  && !hasPos)
         trade.Sell(FixedLots, _Symbol, 0, m.sl, m.tp, NULL);
      if(m.code == SIG_CLOSE &&  hasPos)
         trade.PositionClose(_Symbol, SlippagePoints);
     }
  }
//+------------------------------------------------------------------+
