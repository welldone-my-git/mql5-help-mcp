//+------------------------------------------------------------------+
//|                                                      Slippage Tool|
//|                                   Copyright 2025, MetaQuotes Ltd.|
//|                           https://www.mql5.com/en/users/lynnchris|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double VWAP(int minutes);
double Flow(int sec);

enum eCorner { COR_LT = 0, COR_LB = 1, COR_RT = 2, COR_RB = 3 };
enum eAlertMode { AM_SINGLE = 0, AM_ROLLING_CLEAR = 1, AM_POOL_REUSE = 2 };

// inputs
input string           InpSymbol              = "";
input ENUM_TIMEFRAMES  InpTF                  = PERIOD_M1;
input int              InpATRperiod           = 14;
input int              InpVWAPminutes         = 1440;
input int              InpImbWindowSec        = 30;
input double           InpCheapSpreadFrac     = 0.50;
input double           InpFlowTh              = 0.30;
input double           InpFlowHystFactor      = 0.80;
input double           InpRiskPct             = 1.0;
input double           InpStopATRmult         = 1.2;
input bool             InpAutoTrade           = false;
input bool             InpEnableAlerts        = true;
input bool             InpMarkAlertsOnChart   = true;
input int              InpMaxAlertMarkers     = 6;
input eAlertMode       InpAlertMode           = AM_ROLLING_CLEAR;
input int              InpAlertMaxAgeSec      = 300;
input bool             InpShowPanel           = true;
input bool             InpChangeChartTF       = false;
input eCorner          InpCorner              = COR_LT;
input int              InpXoff                = 8;
input int              InpYoff                = 36;
input string           InpFont                = "Consolas";
input int              InpFontSize            = 10;
input color            InpTextColor           = clrWhite;
input uchar            InpPanelOpacity        = 160;
input int              InpPanelWidthPx        = 520;
input bool             InpCompactMode         = false;
input uint             InpRingSize            = 20000;
input uint             InpTimerSec            = 2;

// globals
string    g_sym="";
double    g_point=0, g_tickVal=0, g_tickSize=0;
double    g_volMin=0, g_volMax=0, g_volStep=0;
int       g_atrHandle = INVALID_HANDLE;
CTrade    g_tr;
string    g_prefix = "ESGP_";
string    g_lbl = g_prefix + "lbl";
string    g_bg  = g_prefix + "bg";
string    g_header = g_prefix + "hdr";
string    g_spBar = g_prefix + "spbar";
string    g_atrBar = g_prefix + "atrbar";
string    g_flowBar = g_prefix + "flowbar";
string    g_vwapLbl = g_prefix + "vwap";
string    g_lastTradeLbl = g_prefix + "last";
datetime  g_lastRefresh = 0;
MqlTick   g_latestTick;
datetime  g_time[];
double    g_bid[], g_ask[], g_last[], g_vol[];
int       g_head = -1, g_used = 0, g_size = 0;
double    g_prevSpread = 0, g_prevATR = 0, g_prevVWAP = 0, g_prevFlow = 0;
int g_panelW = 0;
int g_panelH = 0;
bool buyF=false, sellF=false;
int  g_alertIndex = 0;
string g_alertNames[];

// helpers
double SafeDiv(double a,double b) { return (b==0 ? 0 : a/b); }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void BufInit(int n)
  {
   if(n<128)
      n=128;
   g_size = n;
   ArrayResize(g_time,n);
   ArrayResize(g_bid,n);
   ArrayResize(g_ask,n);
   ArrayResize(g_last,n);
   ArrayResize(g_vol,n);
   g_head = -1;
   g_used = 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void BufAdd(const MqlTick &q)
  {
   if(g_size<=0)
      return;
   g_head = (g_head + 1) % g_size;
   g_time[g_head] = q.time;
   g_bid[g_head] = q.bid;
   g_ask[g_head] = q.ask;
   g_last[g_head] = q.last;
   double vol = (q.volume_real>0 ? q.volume_real : q.volume);
   g_vol[g_head] = (vol>0 ? vol : 1.0);
   if(g_used < g_size)
      g_used++;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Mid(int idx)
  {
   if(idx<0 || idx>=g_size)
      return 0;
   if(g_last[idx] > 0)
      return g_last[idx];
   if(g_bid[idx]>0 && g_ask[idx]>0)
      return 0.5*(g_bid[idx]+g_ask[idx]);
   return 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double SpreadPips()
  {
   MqlTick t;
   if(!SymbolInfoTick(g_sym,t))
      return 0;
   if(g_point==0)
      return 0;
   return (t.ask - t.bid)/g_point;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double ATR()
  {
   if(g_atrHandle==INVALID_HANDLE)
      return 0;
   double buf[];
   int copied = CopyBuffer(g_atrHandle,0,0,1,buf);
   if(copied==1)
      return buf[0];
   return 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double ATR_Avg(int bars)
  {
   if(g_atrHandle==INVALID_HANDLE || bars <= 0)
      return 0;
   int cap = MathMin(bars, 200);
   double buf[];
   int copied = CopyBuffer(g_atrHandle,0,0,cap,buf);
   if(copied <= 0)
      return 0;
   double s = 0;
   for(int i=0;i<copied;i++)
      s += buf[i];
   return s / copied;
  }

uint ARGB(color c, int a) { if(a<0) a=0; if(a>255) a=255; return ((uint)a<<24) | (c & 0x00FFFFFF); }
double RR(double entry,double stop,double tp) { return (entry-stop!=0 ? (tp-entry)/(entry-stop) : 0); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Acc(datetime since,double &pxVol,double &vol,int &up,int &dn,bool flowNeeded)
  {
   pxVol=vol=0;
   up=dn=0;
   if(g_used==0)
      return;
   int idx = g_head;
   double prev = DBL_MAX;
   for(int i=0;i<g_used;i++)
     {
      if(g_time[idx] < since)
         break;
      double p = Mid(idx);
      if(p<=0)
        {
         idx--;
         if(idx<0)
            idx=g_size-1;
         continue;
        }
      double w = (g_vol[idx]>0 ? g_vol[idx] : 1.0);
      pxVol += p*w;
      vol += w;
      if(flowNeeded && prev!=DBL_MAX)
        {
         if(p>prev)
            up++;
         else
            if(p<prev)
               dn++;
        }
      prev = p;
      idx--;
      if(idx<0)
         idx = g_size-1;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double VWAP(int minutes)
  {
   if(minutes <= 0)
      return 0;
   datetime since = TimeCurrent() - (datetime)minutes*60;
   double px=0,v=0;
   int u,d;
   Acc(since,px,v,u,d,false);
   return (v>0 ? px/v : 0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Flow(int sec)
  {
   if(sec <= 0)
      return 0;
   datetime since = TimeCurrent() - sec;
   double px=0,v=0;
   int up=0,dn=0;
   Acc(since,px,v,up,dn,true);
   int tot = up+dn;
   return (tot ? double(up-dn)/tot : 0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int ComputeXDist(int xOff,int panelW) { return InpXoff + xOff; }
int ComputeYDist(int yOff,int panelH) { return InpYoff + yOff; }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void EnsureObj(string name,ENUM_OBJECT type)
  {
   if(ObjectFind(0,name) == -1)
      ObjectCreate(0,name,type,0,0,0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ClearPanelObjects()
  {
   int total = ObjectsTotal(0);
   for(int i=total-1;i>=0;i--)
     {
      string nm = ObjectName(0,i);
      if(StringFind(nm,g_prefix,0) == 0)
         ObjectDelete(0,nm);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetLabelIfChanged(string name, int corner, int xdist, int ydist, string text, int fontsize, color col, string font)
  {
   EnsureObj(name, OBJ_LABEL);
   if((int)ObjectGetInteger(0,name,OBJPROP_CORNER) != corner)
      ObjectSetInteger(0,name,OBJPROP_CORNER,corner);
   if((int)ObjectGetInteger(0,name,OBJPROP_XDISTANCE) != xdist)
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,xdist);
   if((int)ObjectGetInteger(0,name,OBJPROP_YDISTANCE) != ydist)
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,ydist);
   string cur = ObjectGetString(0,name,OBJPROP_TEXT);
   if(cur != text)
      ObjectSetString(0,name,OBJPROP_TEXT,text);
   if((int)ObjectGetInteger(0,name,OBJPROP_FONTSIZE) != fontsize)
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fontsize);
   if((int)ObjectGetInteger(0,name,OBJPROP_COLOR) != (int)col)
      ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   string curF = ObjectGetString(0,name,OBJPROP_FONT);
   if(curF != font)
      ObjectSetString(0,name,OBJPROP_FONT,font);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetRectIfChanged(string name, int corner, int xdist, int ydist, int xsize, int ysize, uint bgARGB)
  {
   EnsureObj(name, OBJ_RECTANGLE_LABEL);
   if((int)ObjectGetInteger(0,name,OBJPROP_CORNER) != corner)
      ObjectSetInteger(0,name,OBJPROP_CORNER,corner);
   if((int)ObjectGetInteger(0,name,OBJPROP_XDISTANCE) != xdist)
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,xdist);
   if((int)ObjectGetInteger(0,name,OBJPROP_YDISTANCE) != ydist)
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,ydist);
   if((int)ObjectGetInteger(0,name,OBJPROP_XSIZE) != xsize)
      ObjectSetInteger(0,name,OBJPROP_XSIZE,xsize);
   if((int)ObjectGetInteger(0,name,OBJPROP_YSIZE) != ysize)
      ObjectSetInteger(0,name,OBJPROP_YSIZE,ysize);
   if((uint)ObjectGetInteger(0,name,OBJPROP_BGCOLOR) != bgARGB)
      ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bgARGB);
   if((uint)ObjectGetInteger(0,name,OBJPROP_COLOR) != bgARGB)
      ObjectSetInteger(0,name,OBJPROP_COLOR,bgARGB);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreatePanelObjects()
  {
   EnsureObj(g_bg, OBJ_RECTANGLE_LABEL);
   EnsureObj(g_header, OBJ_LABEL);
   EnsureObj(g_lbl, OBJ_LABEL);
   EnsureObj(g_vwapLbl, OBJ_LABEL);
   EnsureObj(g_prefix + "risk", OBJ_LABEL);
   EnsureObj(g_header + "_time", OBJ_LABEL);
   EnsureObj(g_spBar + "_bg", OBJ_RECTANGLE_LABEL);
   EnsureObj(g_spBar, OBJ_RECTANGLE_LABEL);
   EnsureObj(g_spBar + "_lbl", OBJ_LABEL);
   EnsureObj(g_atrBar + "_bg", OBJ_RECTANGLE_LABEL);
   EnsureObj(g_atrBar + "_lbl", OBJ_LABEL);
   EnsureObj(g_flowBar + "_neg_bg", OBJ_RECTANGLE_LABEL);
   EnsureObj(g_flowBar + "_neg", OBJ_RECTANGLE_LABEL);
   EnsureObj(g_flowBar + "_pos_bg", OBJ_RECTANGLE_LABEL);
   EnsureObj(g_flowBar + "_pos", OBJ_RECTANGLE_LABEL);
   EnsureObj(g_flowBar + "_lbl", OBJ_LABEL);
   EnsureObj(g_lastTradeLbl, OBJ_LABEL);
   string objs[] = {g_bg,g_header,g_lbl,g_vwapLbl,g_prefix+"risk",g_header+"_time",
                    g_spBar,g_spBar+"_bg",g_spBar+"_lbl",
                    g_atrBar,g_atrBar+"_bg",g_atrBar+"_lbl",
                    g_flowBar+"_neg",g_flowBar+"_neg_bg",g_flowBar+"_pos",g_flowBar+"_pos_bg",g_flowBar+"_lbl",
                    g_lastTradeLbl
                   };
   for(int i=0;i<ArraySize(objs);i++)
      ObjectSetInteger(0,objs[i],OBJPROP_SELECTABLE,false);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void InitAlertPool()
  {
   if(InpMaxAlertMarkers <= 0)
      return;
   if(ArraySize(g_alertNames) != InpMaxAlertMarkers)
     {
      ArrayResize(g_alertNames, InpMaxAlertMarkers);
      for(int i=0;i<InpMaxAlertMarkers;i++)
         g_alertNames[i] = g_prefix + "alert_" + IntegerToString(i);
      g_alertIndex = g_alertIndex % MathMax(1,InpMaxAlertMarkers);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ClearAllAlertMarkers()
  {
   int total = ObjectsTotal(0);
   for(int i=total-1;i>=0;i--)
     {
      string nm = ObjectName(0,i);
      if(StringFind(nm, g_prefix + "alert", 0) == 0)
         ObjectDelete(0, nm);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void AutoClearOldAlerts()
  {
   if(InpAlertMaxAgeSec <= 0)
      return;
   int total = ObjectsTotal(0);
   datetime now = TimeCurrent();
   for(int i=total-1;i>=0;i--)
     {
      string nm = ObjectName(0,i);
      if(StringFind(nm, g_prefix + "alert", 0) != 0)
         continue;
      string tip = ObjectGetString(0,nm,OBJPROP_TOOLTIP);
      if(StringLen(tip) == 0)
         continue;
      long created = (long)StringToInteger(tip);
      if(created <= 0)
         continue;
      if((now - (datetime)created) > InpAlertMaxAgeSec)
         ObjectDelete(0, nm);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawAlertMarker(bool isBuy)
  {
   if(!InpMarkAlertsOnChart || InpMaxAlertMarkers <= 0)
      return;
   AutoClearOldAlerts();
   if(InpAlertMode == AM_POOL_REUSE)
      InitAlertPool();
   string nm;
   if(InpAlertMode == AM_SINGLE)
     {
      nm = g_prefix + "alert";
      if(ObjectFind(0,nm) != -1)
         ObjectDelete(0,nm);
     }
   else
      if(InpAlertMode == AM_ROLLING_CLEAR)
        {
         ClearAllAlertMarkers();
         nm = g_prefix + "alert_" + IntegerToString((int)TimeCurrent());
        }
      else
        {
         if(ArraySize(g_alertNames) == 0)
            InitAlertPool();
         nm = g_alertNames[g_alertIndex];
         if(ObjectFind(0,nm) != -1)
            ObjectDelete(0,nm);
         g_alertIndex = (g_alertIndex + 1) % MathMax(1, InpMaxAlertMarkers);
        }
   if(ObjectFind(0,nm) != -1)
      ObjectDelete(0,nm);
   ObjectCreate(0,nm, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0,nm,OBJPROP_CORNER,InpCorner);
   int baseYOffset = InpYoff + 6;
   int yOffset = baseYOffset;
   int xNudge = 0;
   if(InpAlertMode == AM_POOL_REUSE)
     {
      int slot = (g_alertIndex==0 ? InpMaxAlertMarkers-1 : g_alertIndex-1);
      yOffset = InpYoff + 6 + (slot * (InpFontSize + 2));
      xNudge = (slot % 3) * 4;
     }
   ObjectSetInteger(0,nm,OBJPROP_XDISTANCE, InpXoff + xNudge);
   ObjectSetInteger(0,nm,OBJPROP_YDISTANCE, yOffset);
   ObjectSetString(0,nm,OBJPROP_TEXT, isBuy ? "▲ BUY" : "▼ SELL");
   ObjectSetInteger(0,nm,OBJPROP_COLOR, isBuy ? clrLime : clrRed);
   ObjectSetInteger(0,nm,OBJPROP_FONTSIZE, InpFontSize+3);
   ObjectSetString(0,nm,OBJPROP_FONT, InpFont);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
   ObjectSetString(0,nm,OBJPROP_TOOLTIP, IntegerToString((int)TimeCurrent()));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdatePanelObjects(int w,int h,string header,string summary,string vwapTxt,string flowTxt,double spPips,double atrPips,double flow,string riskTxt,string tstr,bool cheap,double spFrac,double atrFrac,double flowAbs)
  {
   int font = (InpCompactMode ? InpFontSize-1 : InpFontSize);
   int padding = 14;
   int xStart = 8;
   int headerH = font + 8;
   int lineH   = font + 6;
   int spreadBarH = 18;
   int atrBarH = 14;
   int flowBarH = 12;
   int sectionGap = 8;
   int labelGap = 6;
   int pushLeft = 6;
   int rightPadding = xStart;
   double cw = 0.58;
   color base = cheap ? clrDarkGreen : clrDarkRed;
   uint bgARGB = ARGB(base, InpPanelOpacity);
   SetRectIfChanged(g_bg, InpCorner, ComputeXDist(0,w), ComputeYDist(0,h), w, h, bgARGB);
   int cursorY = padding;
   int headerX = (int)(w/2 - (StringLen(header) * font * cw) / 2);
   SetLabelIfChanged(g_header, InpCorner, ComputeXDist(headerX,w), ComputeYDist(cursorY, h), header, InpFontSize+2, InpTextColor, InpFont);
   cursorY += headerH + 6;
   SetLabelIfChanged(g_lbl, InpCorner, ComputeXDist(xStart,w), ComputeYDist(cursorY, h), summary, font, InpTextColor, InpFont);
   cursorY += lineH + 4;
   SetLabelIfChanged(g_vwapLbl, InpCorner, ComputeXDist(xStart,w), ComputeYDist(cursorY, h), vwapTxt + "  |  " + flowTxt, font, InpTextColor, InpFont);
   cursorY += lineH + sectionGap;
   string spLabel = StringFormat("Spread: %.1f pips", spPips);
   string atrLabelStr = StringFormat("ATR: %.1f pips", atrPips);
   string flowLabelStr = StringFormat("Flow: %.2f", flow);
   int spLabelW = (int)(StringLen(spLabel) * font * cw);
   int atrLabelW = (int)(StringLen(atrLabelStr) * font * cw);
   int flowLabelW = (int)(StringLen(flowLabelStr) * font * cw);
   int labelColCandidate = MathMax(spLabelW, MathMax(atrLabelW, flowLabelW)) + 16;
   int maxLabelCol = MathMax(40, (w - xStart*2) / 2);
   int labelCol = MathMin(labelColCandidate, maxLabelCol);
   int maxLabelChars = MathMax(4, (int)MathFloor((double)(labelCol - 8) / (font * cw)));
   if(StringLen(spLabel) > maxLabelChars)
      spLabel = StringSubstr(spLabel,0,maxLabelChars-3) + "...";
   if(StringLen(atrLabelStr) > maxLabelChars)
      atrLabelStr = StringSubstr(atrLabelStr,0,maxLabelChars-3) + "...";
   if(StringLen(flowLabelStr) > maxLabelChars)
      flowLabelStr = StringSubstr(flowLabelStr,0,maxLabelChars-3) + "...";
   int spLabelY = cursorY + MathMax(0, (spreadBarH - font)/2);
   SetLabelIfChanged(g_spBar + "_lbl", InpCorner, ComputeXDist(xStart,w), ComputeYDist(spLabelY, h), spLabel, font-1, InpTextColor, InpFont);
   int spBarX = xStart + labelCol + labelGap - pushLeft;
   int barW = w - spBarX - rightPadding;
   if(barW < 40)
     {
      barW = 40;
      spBarX = MathMax(xStart + labelCol + labelGap - pushLeft, w - rightPadding - barW);
     }
   SetRectIfChanged(g_spBar + "_bg", InpCorner, ComputeXDist(spBarX,w), ComputeYDist(cursorY,h), barW, spreadBarH, ARGB(clrSilver, (int)(InpPanelOpacity/2)));
   int pad = 4;
   int fgW = (int)MathMax(2, MathMin(barW-pad*2, MathRound(spFrac * (barW-pad*2))));
   SetRectIfChanged(g_spBar, InpCorner, ComputeXDist(spBarX+pad,w), ComputeYDist(cursorY+pad,h), fgW, spreadBarH-pad*2, ARGB(cheap?clrLime:clrOrange, InpPanelOpacity));
   cursorY += spreadBarH + sectionGap;
   int atrLabelY = cursorY + MathMax(0, (atrBarH - font)/2);
   SetLabelIfChanged(g_atrBar + "_lbl", InpCorner, ComputeXDist(xStart,w), ComputeYDist(atrLabelY, h), atrLabelStr, font-1, InpTextColor, InpFont);
   int atrBarX = xStart + labelCol + labelGap - pushLeft;
   int atrBarAvailableW = w - atrBarX - rightPadding;
   if(atrBarAvailableW < 40)
     {
      atrBarAvailableW = 40;
      atrBarX = MathMax(xStart + labelCol + labelGap - pushLeft, w - rightPadding - atrBarAvailableW);
     }
   SetRectIfChanged(g_atrBar + "_bg", InpCorner, ComputeXDist(atrBarX,w), ComputeYDist(cursorY,h), atrBarAvailableW, atrBarH, ARGB(clrSilver, (int)(InpPanelOpacity/2)));
   int atrFgW = (int)MathMax(2, MathMin(atrBarAvailableW-pad*2, MathRound(atrFrac * (atrBarAvailableW-pad*2))));
   SetRectIfChanged(g_atrBar, InpCorner, ComputeXDist(atrBarX+pad,w), ComputeYDist(cursorY+pad,h), atrFgW, atrBarH-pad*2, ARGB(clrBlue, InpPanelOpacity));
   cursorY += atrBarH + sectionGap;
   int flowLabelY = cursorY + MathMax(0, (flowBarH - font)/2);
   SetLabelIfChanged(g_flowBar + "_lbl", InpCorner, ComputeXDist(xStart,w), ComputeYDist(flowLabelY, h), flowLabelStr, font-1, InpTextColor, InpFont);
   int flowBarX = xStart + labelCol + labelGap - pushLeft;
   int flowBarWtotal = w - flowBarX - rightPadding;
   if(flowBarWtotal < 60)
     {
      flowBarWtotal = 60;
      flowBarX = MathMax(xStart + labelCol + labelGap - pushLeft, w - rightPadding - flowBarWtotal);
     }
   int halfW = (flowBarWtotal - 10) / 2;
   SetRectIfChanged(g_flowBar + "_neg_bg", InpCorner, ComputeXDist(flowBarX,w), ComputeYDist(cursorY,h), halfW, flowBarH, ARGB(clrSilver, (int)(InpPanelOpacity/2)));
   SetRectIfChanged(g_flowBar + "_neg", InpCorner, ComputeXDist(flowBarX+pad,w), ComputeYDist(cursorY+pad,h), (flow<0 ? (int)(halfW*flowAbs) : 0), flowBarH-pad*2, ARGB(clrRed, InpPanelOpacity));
   int posX = flowBarX + halfW + 10;
   SetRectIfChanged(g_flowBar + "_pos_bg", InpCorner, ComputeXDist(posX,w), ComputeYDist(cursorY,h), halfW, flowBarH, ARGB(clrSilver, (int)(InpPanelOpacity/2)));
   SetRectIfChanged(g_flowBar + "_pos", InpCorner, ComputeXDist(posX+pad,w), ComputeYDist(cursorY+pad,h), (flow>0 ? (int)(halfW*flowAbs) : 0), flowBarH-pad*2, ARGB(clrLime, InpPanelOpacity));
   cursorY += flowBarH + sectionGap;
   int availRiskW = w - xStart*2;
   int maxRiskChars = MathMax(8, (int)MathFloor((double)(availRiskW) / (font * cw)));
   string riskOut = riskTxt;
   if(StringLen(riskOut) > maxRiskChars)
      riskOut = StringSubstr(riskOut,0,maxRiskChars-3) + "...";
   SetLabelIfChanged(g_prefix+"risk", InpCorner, ComputeXDist(xStart,w), ComputeYDist(cursorY, h), riskOut, font-1, InpTextColor, InpFont);
   cursorY += lineH + 6;
   int rightMargin = 12;
   int footerTextW = (int)(StringLen("Updated: " + tstr) * font * cw);
   int footerX = MathMax(8, w - rightMargin - footerTextW);
   int footerY = h - padding - MathMax(10, font-2);
   if(footerY <= cursorY + 4)
      footerY = cursorY + 8;
   SetLabelIfChanged(g_header + "_time", InpCorner, ComputeXDist(footerX,w), ComputeYDist(footerY,h), "Updated: " + tstr, font-2, InpTextColor, InpFont);
   int lastY = MathMax(cursorY, footerY - (lineH + 6));
   SetLabelIfChanged(g_lastTradeLbl, InpCorner, ComputeXDist(xStart,w), ComputeYDist(lastY, h), ObjectGetString(0,g_lastTradeLbl,OBJPROP_TEXT), InpFontSize-1, InpTextColor, InpFont);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_sym = (InpSymbol=="") ? _Symbol : InpSymbol;
   if(!SymbolSelect(g_sym,true))
      return INIT_FAILED;
   if(InpChangeChartTF)
      ChartSetSymbolPeriod(0,g_sym,InpTF);
   g_point    = SymbolInfoDouble(g_sym,SYMBOL_POINT);
   g_tickVal  = SymbolInfoDouble(g_sym,SYMBOL_TRADE_TICK_VALUE);
   g_tickSize = SymbolInfoDouble(g_sym,SYMBOL_TRADE_TICK_SIZE);
   g_volMin  = SymbolInfoDouble(g_sym,SYMBOL_VOLUME_MIN);
   g_volMax  = SymbolInfoDouble(g_sym,SYMBOL_VOLUME_MAX);
   g_volStep = SymbolInfoDouble(g_sym,SYMBOL_VOLUME_STEP);
   g_atrHandle = iATR(g_sym,InpTF,InpATRperiod);
   if(g_atrHandle==INVALID_HANDLE)
      return INIT_FAILED;
   BufInit((int)InpRingSize);
   ClearPanelObjects();
   if(InpShowPanel)
     {
      if(ObjectFind(0,g_lbl) == -1)
         ObjectCreate(0,g_lbl,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,g_lbl,OBJPROP_CORNER,InpCorner);
      ObjectSetInteger(0,g_lbl,OBJPROP_XDISTANCE,InpXoff);
      ObjectSetInteger(0,g_lbl,OBJPROP_YDISTANCE,InpYoff);
      ObjectSetInteger(0,g_lbl,OBJPROP_COLOR,InpTextColor);
      ObjectSetInteger(0,g_lbl,OBJPROP_FONTSIZE,InpFontSize);
      ObjectSetString(0,g_lbl,OBJPROP_FONT,InpFont);
     }
   if(InpShowPanel)
      CreatePanelObjects();
   if(InpAlertMode == AM_POOL_REUSE)
      InitAlertPool();
   EventSetTimer((int)InpTimerSec);
   PrintFormat("ESGP initialized for %s (TF=%s)", g_sym, EnumToString(InpTF));
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   ClearPanelObjects();
   ClearAllAlertMarkers();
   if(g_atrHandle!=INVALID_HANDLE)
     {
      IndicatorRelease(g_atrHandle);
      g_atrHandle = INVALID_HANDLE;
     }
   Comment("");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   MqlTick q;
   if(SymbolInfoTick(g_sym,q))
     {
      g_latestTick = q;
      BufAdd(q);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer()
  {
   MqlTick t;
   if(SymbolInfoTick(g_sym,t))
     {
      if(g_used==0 || g_time[g_head]!=t.time)
         BufAdd(t);
     }
   if((int)(TimeCurrent() - g_lastRefresh) < (int)InpTimerSec)
      return;
   g_lastRefresh = TimeCurrent();
   if(g_used==0)
     {
      if(InpShowPanel)
         SetLabelIfChanged(g_lbl, InpCorner, InpXoff, InpYoff, "waiting for live ticks…", InpFontSize, InpTextColor, InpFont);
      else
         Comment("waiting for live ticks…");
      return;
     }
   double spPips = SpreadPips();
   double atrPts = ATR();
   double atrPips = (atrPts>0 && g_point>0 ? atrPts/g_point : 0);
   bool cheap  = (atrPts>0 && spPips < atrPips*InpCheapSpreadFrac);
   double vwap   = VWAP(InpVWAPminutes);
   double flow   = Flow(InpImbWindowSec);
   double bal   = AccountInfoDouble(ACCOUNT_BALANCE);
   double bid   = SymbolInfoDouble(g_sym,SYMBOL_BID);
   double stop  = bid - InpStopATRmult * atrPts;
   double riskPx= bid - stop;
   double ticks = (g_tickSize>0 ? riskPx/g_tickSize : 0);
   double cashPerLot = ticks * g_tickVal;
   double maxLoss = bal * InpRiskPct / 100.0;
   double rawLot = (cashPerLot>0 ? maxLoss / cashPerLot : 0);
   double lot = (g_volStep>0 ? MathFloor(rawLot/g_volStep)*g_volStep : 0);
   if(g_volStep <= 0 || g_volMin <= 0 || g_volMax <= 0)
      lot = 0;
   else
     {
      lot = MathMax(lot, g_volMin);
      lot = MathMin(lot, g_volMax);
     }
   double tp2   = bid + 2*riskPx;
   double rr    = (riskPx>0 ? RR(bid,stop,tp2) : 0);
   string header = StringFormat("%s  [%s]", g_sym, EnumToString(InpTF));
   string summary = StringFormat("Cheap: %s | Imbalance: %.1f %%", cheap ? "YES" : "no", flow*100);
   string vwapTxt = (vwap>0 ? StringFormat("VWAP: %.5f", vwap) : "VWAP: -");
   string flowTxt = StringFormat("Imbalance: %.1f %%", flow*100);
   string riskTxt = StringFormat("Lot@1R %.2f | Stop %.1f pips | TP2R %.1f pips | R/R %.2f", lot, (riskPx/g_point), (2*riskPx/g_point), rr);
   double atrAvgPts = ATR_Avg(InpATRperiod * 3);
   double atrAvgPips = (atrAvgPts>0 && g_point>0 ? atrAvgPts/g_point : atrPips);
   double atrFrac = 0.5;
   if(atrAvgPips > 0.000001)
      atrFrac = MathMin(1.0, atrPips / atrAvgPips);
   double spFrac = (atrPips>0 ? MathMin(1.0, spPips / (atrAvgPips * InpCheapSpreadFrac)) : 0);
   bool needUpdate = (MathAbs(spPips - g_prevSpread) > 0.05) || (MathAbs(atrPips - g_prevATR) > 0.05) || (MathAbs(flow - g_prevFlow) > 0.01) || (MathAbs(vwap - g_prevVWAP) > g_point);
   if(InpShowPanel && needUpdate)
     {
      g_prevSpread = spPips;
      g_prevATR = atrPips;
      g_prevFlow = flow;
      g_prevVWAP = vwap;
      int font = (InpCompactMode ? InpFontSize-1 : InpFontSize);
      int padding = 14;
      double cw = 0.58;
      string rowsList[4];
      rowsList[0] = header;
      rowsList[1] = summary;
      rowsList[2] = vwapTxt + "  |  " + flowTxt;
      rowsList[3] = riskTxt;
      int maxLen = 0;
      for(int i=0;i<ArraySize(rowsList);i++)
         if(StringLen(rowsList[i])>maxLen)
            maxLen = StringLen(rowsList[i]);
      int approxW = (int)(maxLen * font * cw) + padding*2;
      int w = MathMax(InpPanelWidthPx, approxW);
      int headerH = font + 8;
      int lineH = font + 6;
      int spreadBarH = 18;
      int atrBarH = 14;
      int flowBarH = 12;
      int footH = MathMax(10, font-2);
      int h = padding*2 + headerH + lineH + lineH + spreadBarH + atrBarH + flowBarH + lineH + footH + 52;
      g_panelW = w;
      g_panelH = h;
      UpdatePanelObjects(w,h,header,summary,vwapTxt,flowTxt,spPips,atrPips,flow,riskTxt,TimeToString(TimeCurrent(),TIME_SECONDS),cheap,spFrac,atrFrac,MathMin(1.0,MathAbs(flow)));
     }
   else
      if(!InpShowPanel)
         Comment(header + "\n" + summary + "\n" + vwapTxt + " | " + flowTxt + "\n" + riskTxt);
   if(InpEnableAlerts && cheap)
     {
      double resetThresh = InpFlowTh * InpFlowHystFactor;
      if(flow >= InpFlowTh && !buyF)
        { Alert("BUY edge: cheap spread + buy flow"); buyF = true; sellF = false; if(InpMarkAlertsOnChart) DrawAlertMarker(true); }
      else
         if(flow < resetThresh)
            buyF = false;
      if(flow <= -InpFlowTh && !sellF)
        { Alert("SELL edge: cheap spread + sell flow"); sellF = true; buyF = false; if(InpMarkAlertsOnChart) DrawAlertMarker(false); }
      else
         if(flow > -resetThresh)
            sellF = false;
     }
  }
//+------------------------------------------------------------------+
