//+------------------------------------------------------------------+
//|                                                     trained model|
//|                                   Copyright 2025, MetaQuotes Ltd.|
//|                           https://www.mql5.com/en/users/lynnchris|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.0"
#property strict
#include <Trade\Trade.mqh>
#include <ChartObjects\ChartObjectsTxtControls.mqh>

//--- ENUM for signals
enum ESignal
  {
   SIG_WAIT  = 0,
   SIG_BUY   = 1,
   SIG_SELL  = -1,
   SIG_CLOSE = 2
  };

//--- STRUCT to hold server response
struct SServerMsg
  {
   ESignal code;
   double  conf;
   double  sl;
   double  tp;
  };

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input string InpServerURL      = "http://127.0.0.1:5000/analyze";
input int    InpBufferBars     = 60;      // bars to send
input int    InpPollInterval   = 60;      // seconds between polls
input int    InpTimeoutMs      = 5000;    // HTTP timeout (ms)
input bool   PollOnNewBarOnly  = true;    // only on new bar
input int    MinSecsBetweenReq = 10;      // throttle interval
input bool   EnableTrading     = false;   // auto-trade
input double FixedLots         = 0.1;
input int    SlippagePoints    = 10;

// Panel
input int   PanelX      = 10, PanelY      = 10;
input int   PanelW      = 240, PanelH      = 80;
input color PanelBG     = clrBlack;
input color PanelBorder = clrWhite;
input color TxtColor    = clrWhite;
input int   TxtSize     = 10;

// Debug/retry
input int    MaxRetry       = 3;
input bool   DebugPrintJSON = true;
input bool   DebugPrintReply= true;

//--- Logging
int    log_handle = INVALID_HANDLE;
string log_file   = "SignalEA_Enhanced.log";

//+------------------------------------------------------------------+
//| GLOBALS                                                          |
//+------------------------------------------------------------------+
CTrade   trade;
string   lastSignal      = "WAIT";
string   lastStatus      = "Never polled";
string   objPrefix;
int      _digits;
double   _point;
datetime lastRequestTime = 0;
int      retryCount      = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpBufferBars < 2)
      return(INIT_FAILED);

   // symbol precision & prefix
   _digits   = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   _point    = SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   objPrefix = StringFormat("SCEA_%I64d_",ChartID());

   EventSetTimer(InpPollInterval);
   DrawPanel();

   // open (or create) log file for appending
   log_handle = FileOpen(log_file, FILE_WRITE|FILE_READ|FILE_CSV|FILE_ANSI);
   if(log_handle != INVALID_HANDLE)
      FileSeek(log_handle, 0, SEEK_END);
   else
      Print("⚠️ Failed to open log file: ", log_file);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinit                                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   // delete all objects created by this EA
   for(int i=ObjectsTotal(0)-1; i>=0; --i)
     {
      string name = ObjectName(0,i);
      if(StringFind(name,objPrefix)==0 || StringFind(name,"SigPanel")==0)
         ObjectDelete(0,name);
     }

   // close log file
   if(log_handle != INVALID_HANDLE)
      FileClose(log_handle);
  }

//+------------------------------------------------------------------+
//| Timer handler                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   static datetime lastBar=0;
   datetime bar = iTime(_Symbol,_Period,0);
   if(PollOnNewBarOnly && bar==lastBar) return;
   lastBar = bar;

   if((int)(TimeCurrent()-lastRequestTime) < MinSecsBetweenReq) return;

   // copy rates
   MqlRates rates[];
   if(CopyRates(_Symbol,_Period,0,InpBufferBars,rates)!=InpBufferBars) return;
   ArraySetAsSeries(rates,true);

   // build JSON
   string payload = BuildJSON(rates);
   if(DebugPrintJSON) PrintFormat(">>> JSON: %s",payload);

   // call server & act
   SServerMsg msg;
   if(CallServer(payload,msg))
      ActOnSignal(msg);

   lastRequestTime = TimeCurrent();
   // ensure panel always up to date
   DrawPanel();
  }

//+------------------------------------------------------------------+
//| Build JSON                                                      |
//+------------------------------------------------------------------+
string BuildJSON(const MqlRates &rates[])
  {
   string s = StringFormat("{\"symbol\":\"%s\",\"prices\":[",_Symbol);
   for(int i=0; i<InpBufferBars; i++)
     {
      s += DoubleToString(rates[i].close,_digits);
      if(i<InpBufferBars-1) s += ",";
     }
   s += "],\"timestamps\":[";
   for(int i=0; i<InpBufferBars; i++)
     {
      s += IntegerToString(rates[i].time);
      if(i<InpBufferBars-1) s += ",";
     }
   s += "]}";
   return s;
  }

//+------------------------------------------------------------------+
//| Call REST API                                                   |
//+------------------------------------------------------------------+
bool CallServer(const string &payload, SServerMsg &out)
  {
   // payload → UTF-8 buffer
   char req[];
   int  len = StringToCharArray(payload,req,0,WHOLE_ARRAY,CP_UTF8);
   if(len<=0) return false;
   ArrayResize(req,len);

   // response buffer
   char resp[];
   ArrayResize(resp,8192);
   string hdrs_out;

   // headers + extra CRLF
   string hdrs =
     "Content-Type: application/json; charset=utf-8\r\n"
     "Accept: application/json\r\n"
     "\r\n";

   int status = WebRequest("POST",
                            InpServerURL,
                            hdrs,
                            "",
                            InpTimeoutMs,
                            req, len,
                            resp,
                            hdrs_out);
   if(status<=0)
     {
      int err = GetLastError();
      PrintFormat("WebRequest error %d (%d/%d)",err,retryCount+1,MaxRetry);
      ResetLastError();
      retryCount = (retryCount+1)%MaxRetry;
      lastStatus = StringFormat("Err %d",err);
      return false;
     }
   retryCount = 0;
   lastStatus = StringFormat("HTTP %d",status);

   string body = CharArrayToString(resp,0,ArraySize(resp),CP_UTF8);
   if(DebugPrintReply) PrintFormat("<<< HTTP %d hdr:\n%s\nbody:\n%s",
                                   status,hdrs_out,body);

   int p = StringFind(body,"\"signal\":\"");
   if(p<0) return false;
   p += StringLen("\"signal\":\"");
   int q = StringFind(body,"\"",p);
   lastSignal = StringSubstr(body,p,q-p);

   out.code = SIG_WAIT;
   if(lastSignal=="BUY")   out.code = SIG_BUY;
   else if(lastSignal=="SELL") out.code = SIG_SELL;
   else if(lastSignal=="CLOSE")out.code = SIG_CLOSE;

   out.sl   = 0.0;
   out.tp   = 0.0;
   out.conf = 0.0;
   ParseJSONDouble(body,"\"sl\":",  out.sl);
   ParseJSONDouble(body,"\"tp\":",  out.tp);
   ParseJSONDouble(body,"\"conf\":",out.conf);

   return true;
  }

//+------------------------------------------------------------------+
//| Extract double after JSON key                                   |
//+------------------------------------------------------------------+
void ParseJSONDouble(const string &txt,const string &key,double &val)
  {
   int p = StringFind(txt,key);
   if(p<0) return;
   p += StringLen(key);
   string num="";
   while(p<StringLen(txt))
     {
      ushort ch = txt[p];
      if(!((ch>=48 && ch<=57) || ch==46 || ch==45)) break;
      num += CharToString((uchar)ch);
      p++;
     }
   if(StringLen(num)) val = StringToDouble(num);
  }

//+------------------------------------------------------------------+
//| Act on signal: draw arrows, lines, trade, and log               |
//+------------------------------------------------------------------+
void ActOnSignal(const SServerMsg &m)
  {
   // --- Immediately log what we received ---
   string ts = TimeToString(TimeLocal(), TIME_DATE|TIME_SECONDS);
   // log to Experts tab
   PrintFormat("[%s] Signal → %s | SL=%.5f | TP=%.5f | Conf=%.2f",
               ts, lastSignal, m.sl, m.tp, m.conf);
   // append to file
   if(log_handle != INVALID_HANDLE)
      FileWrite(log_handle,
                ts,
                lastSignal,
                DoubleToString(m.sl, _digits),
                DoubleToString(m.tp, _digits),
                DoubleToString(m.conf, 2));

   // only handle non-WAIT signals
   if(m.code != SIG_WAIT)
     {
      static string last = "";
      if(last != lastSignal)
        {
         last = lastSignal;
         // delete old arrows/lines
         for(int i=ObjectsTotal(0)-1;i>=0;--i)
           {
            string name = ObjectName(0,i);
            if(StringFind(name,objPrefix)==0) ObjectDelete(0,name);
           }

         // determine arrow code/color
         int code = (m.code == SIG_BUY   ? 233 :
                    m.code == SIG_SELL  ? 234 : 158);
         color clr = (m.code == SIG_BUY   ? clrLime :
                    m.code == SIG_SELL  ? clrRed : clrOrange);

         // draw arrow
         string aid = objPrefix + "Arr_" + ts;
         double y   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(ObjectCreate(0,aid,OBJ_ARROW,0,TimeCurrent(),y))
           {
            ObjectSetInteger(0,aid,OBJPROP_ARROWCODE, code);
            ObjectSetInteger(0,aid,OBJPROP_COLOR,     clr);
            ObjectSetInteger(0,aid,OBJPROP_WIDTH,     2);
           }

         // draw SL/TP lines
         if(m.sl>0)
           {
            string sid = objPrefix + "SL_" + ts;
            ObjectCreate(0,sid,OBJ_HLINE,0,0,m.sl);
            ObjectSetInteger(0,sid,OBJPROP_COLOR,clrRed);
            ObjectSetString (0,sid,OBJPROP_TEXT,"SL=" + DoubleToString(m.sl,_digits));
           }
         if(m.tp>0)
           {
            string tid = objPrefix + "TP_" + ts;
            ObjectCreate(0,tid,OBJ_HLINE,0,0,m.tp);
            ObjectSetInteger(0,tid,OBJPROP_COLOR,clrLime);
            ObjectSetString (0,tid,OBJPROP_TEXT,"TP=" + DoubleToString(m.tp,_digits));
           }

         // optional auto-trade
         if(EnableTrading)
           {
            bool pos = PositionSelect(_Symbol);
            if(m.code==SIG_BUY   && !pos) trade.Buy (FixedLots,_Symbol,0,m.sl,m.tp);
            if(m.code==SIG_SELL  && !pos) trade.Sell(FixedLots,_Symbol,0,m.sl,m.tp);
            if(m.code==SIG_CLOSE &&  pos)  trade.PositionClose(_Symbol,SlippagePoints);
           }
        }
     }

   // always update panel
   DrawPanel();
  }

//+------------------------------------------------------------------+
//| Draw/update the info panel                                       |
//+------------------------------------------------------------------+
void DrawPanel()
  {
   const string pid = "SigPanel";
   if(ObjectFind(0,pid)<0)
      ObjectCreate(0,pid,OBJ_RECTANGLE_LABEL,0,0,0);

   ObjectSetInteger(0,pid,OBJPROP_CORNER,    CORNER_LEFT_UPPER);
   ObjectSetInteger(0,pid,OBJPROP_XDISTANCE, PanelX);
   ObjectSetInteger(0,pid,OBJPROP_YDISTANCE, PanelY);
   ObjectSetInteger(0,pid,OBJPROP_XSIZE,     PanelW);
   ObjectSetInteger(0,pid,OBJPROP_YSIZE,     PanelH);
   ObjectSetInteger(0,pid,OBJPROP_BACK,      true);
   ObjectSetInteger(0,pid,OBJPROP_BGCOLOR,   PanelBG);
   ObjectSetInteger(0,pid,OBJPROP_COLOR,     PanelBorder);
   ObjectSetInteger(0,pid,OBJPROP_STYLE,     STYLE_SOLID);

   string lines[4];
   lines[0] = StringFormat("Symbol : %s", _Symbol);
   lines[1] = StringFormat("Signal : %s", lastSignal);
   lines[2] = StringFormat("Status : %s",  lastStatus);
   lines[3] = StringFormat("Updated: %s", TimeToString(TimeLocal(),TIME_MINUTES));

   for(int i=0; i<4; i++)
     {
      string lbl = pid + "_L" + IntegerToString(i);
      if(ObjectFind(0,lbl)<0)
         ObjectCreate(0,lbl,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,lbl,OBJPROP_CORNER,    CORNER_LEFT_UPPER);
      ObjectSetInteger(0,lbl,OBJPROP_XDISTANCE, PanelX+6);
      ObjectSetInteger(0,lbl,OBJPROP_YDISTANCE, PanelY+4+(TxtSize+2)*i);
      ObjectSetInteger(0,lbl,OBJPROP_FONTSIZE,  TxtSize);
      ObjectSetInteger(0,lbl,OBJPROP_COLOR,     TxtColor);
      ObjectSetString(0,lbl,OBJPROP_TEXT,      lines[i]);
     }
  }
//+------------------------------------------------------------------+
