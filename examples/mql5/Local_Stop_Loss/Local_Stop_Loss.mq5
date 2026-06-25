//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2026, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property copyright   "Your Name"
#property link        "https://www.mql5.com/"
#property version     "1.00"
#property description "Local Stop Loss EA"
#property script_show_inputs

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Generic\HashSet.mqh>
#include <Generic\HashMap.mqh>

//--- Enums
enum StoplossType
  {
   stoploss_pips,     // Pips - non Yen pairs
   stoploss_pips_yen, // Pips - Yen pairs
   stoploss_points    // Points
  };

//--- Inputs
input group        "Stoploss Settings"
input StoplossType InpSlType = stoploss_points;   // Stoploss Type
input double       InpPriceRange = 0;             // Stop distance
input group        "Colors"
input color        InpLongColor = clrOrange;      // Buy Positions
input color        InpShortColor = clrPink;       // Sell Positions
input group        "EA Identification Parameters"
input ulong        InpMagicNumber = 12345;        // Magic Number

//--- Global variables
CTrade Trade;
double StoplossDistance;
CHashMap<ulong, double> gblOpenPositions;
int LeftOffset = 1;
bool gblLastShowLevels;
string CslPrefix = "csl_";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Input validation
   if(InpPriceRange <= 0)
     {
      MessageBox("Stop Distance value cannot be 0 or negative");
      return INIT_PARAMETERS_INCORRECT;
     }
   Trade.SetExpertMagicNumber(InpMagicNumber);
   StoplossDistance = GetStopDistance();

//--- Fetching the show trade levels chart property
   gblLastShowLevels = ChartGetInteger(ChartID(), CHART_SHOW_TRADE_LEVELS);

//--- Setting the value of the object description property
   SetTradeLabels(gblLastShowLevels);

//--- Running PositionsCheck() for the existing open positions
   PositionsCheck();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(ChartID(), CslPrefix);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   bool curShowLevels = ChartGetInteger(ChartID(), CHART_SHOW_TRADE_LEVELS);
   if(gblLastShowLevels != curShowLevels)
     {
      SetTradeLabels(curShowLevels);
      //--- Updating the show trade levels chart property
      gblLastShowLevels = curShowLevels;
     }
   PositionsCheck();
  }

//+------------------------------------------------------------------+
//| Scans and processes new positions, manages already processed ones|
//+------------------------------------------------------------------+
void PositionsCheck()
  {
   int curLeftBar = (int) ChartGetInteger(ChartID(), CHART_FIRST_VISIBLE_BAR);
   CHashSet<ulong> curPositions;
   int posCount = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      CPositionInfo posInfo;
      if(!posInfo.SelectByIndex(i))
         continue;
      if(posInfo.Symbol() != Symbol())
         continue;

      if(gblOpenPositions.ContainsKey(posInfo.Ticket()))
        {
         CheckProcessedPosition(posInfo, curLeftBar, posCount);
        }
      else
        {
         ProcessPosition(posInfo, curLeftBar, posCount);
        }
      curPositions.Add(posInfo.Ticket());
      posCount += 1;
     }

//--- Closed positions object cleanup
   ulong openPos[];
   double csl[];
   ArrayResize(openPos, gblOpenPositions.Count());
   ArrayResize(csl, gblOpenPositions.Count());
   int numPos = gblOpenPositions.CopyTo(openPos, csl);
   for(int i = numPos-1; i >= 0; i--)
     {
      if(!curPositions.Contains(openPos[i]))
        {
         CleanupPosition(openPos[i]);
        }
     }
  }

//+------------------------------------------------------------------+
//| Creates the objects for the open and local stop loss line        |
//+------------------------------------------------------------------+
void ProcessPosition(CPositionInfo &posInfo, int curLeftBar, int idx)
  {
   double   openPrice = posInfo.PriceOpen();
   double   cslPrice  = GetCslPrice(openPrice, posInfo.PositionType());
   color    lineColor = posInfo.PositionType() == POSITION_TYPE_BUY? InpLongColor : InpShortColor;
   string   openName  = GetOpenName(posInfo.Ticket());
   string   openLabel = GetOpenLabel(posInfo.PositionType(), posInfo.Volume(), openPrice);
   string   cslName   = GetCslName(posInfo.Ticket());
   int      subWindow = 0; // Main chart
   datetime time      = 0; // OBJ_HLINE has no time coordinate

//--- Create the open line
   ObjectCreate(ChartID(), openName, OBJ_HLINE, subWindow, time, openPrice);
   ObjectSetInteger(ChartID(), openName, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(ChartID(), openName, OBJPROP_STYLE, STYLE_DASHDOT);
   ObjectSetString(ChartID(), openName, OBJPROP_TEXT, openLabel);

//--- Create the stop loss line
   ObjectCreate(ChartID(), cslName, OBJ_HLINE, subWindow, time, cslPrice);
   ObjectSetInteger(ChartID(), cslName, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(ChartID(), cslName, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(ChartID(), cslName, OBJPROP_SELECTED, true);

//--- Draw the spacer line for the new position
   DrawSpacer(posInfo.Ticket(), openPrice, cslPrice, lineColor, curLeftBar, idx);

//--- Add position ticket to hashmap along with the stop price to mark as processed
   gblOpenPositions.Add(posInfo.Ticket(), cslPrice);
  }

//+------------------------------------------------------------------+
//| Checks for stop condition and closes the position if met         |
//+------------------------------------------------------------------+
void CheckProcessedPosition(CPositionInfo &posInfo, int curLeftBar, int idx)
  {
//--- Check if the stop loss line object exists
   string cslName = GetCslName(posInfo.Ticket());
   if(ObjectFind(ChartID(), cslName) < 0)
     {
      CleanupPosition(posInfo.Ticket());
      ProcessPosition(posInfo, curLeftBar, idx);
      return;
     }

//--- Evaluate the stop condition
   MqlTick curTick;
   SymbolInfoTick(Symbol(), curTick);

   double cslPrice = ObjectGetDouble(ChartID(), cslName, OBJPROP_PRICE);
   if((posInfo.PositionType() == POSITION_TYPE_BUY  && curTick.bid <= cslPrice) ||
      (posInfo.PositionType() == POSITION_TYPE_SELL && curTick.ask >= cslPrice))
     {
      Trade.PositionClose(posInfo.Ticket());
      CleanupPosition(posInfo.Ticket());
      return;
     }

//--- Draw the spacer line for an existing position
   DrawSpacer(posInfo.Ticket(), cslPrice, curLeftBar, idx);

//--- Update the value of the local stop loss in the hashmap
   double lastCsl;
   gblOpenPositions.TryGetValue(posInfo.Ticket(), lastCsl);

   if(lastCsl != cslPrice)
     {
      gblOpenPositions.TrySetValue(posInfo.Ticket(), cslPrice);
     }
  }

//+------------------------------------------------------------------+
//| Returns the stop distance for the input stop loss type           |
//+------------------------------------------------------------------+
double GetStopDistance()
  {
   switch(InpSlType)
     {
      case stoploss_pips:
         return InpPriceRange * 0.0001;

      case stoploss_pips_yen:
         return InpPriceRange * 0.01;

      case stoploss_points:
         return InpPriceRange;
     }
   return InpPriceRange; // This line is not really necessary as we have covered all the cases of the enumeration
  }

//+------------------------------------------------------------------+
//| Draws the spacer line for a newly detected position              |
//+------------------------------------------------------------------+
void DrawSpacer(ulong ticket, double openPrice, double cslPrice, color clr, int curLeftBar, int idx)
  {
   string spacerName = GetSpacerName(ticket);
   datetime time = iTime(Symbol(), Period(), curLeftBar-idx-LeftOffset);
   int subWindow = 0;
   ObjectCreate(ChartID(), spacerName, OBJ_TREND, subWindow, time, openPrice, time, cslPrice);
   ObjectSetInteger(ChartID(), spacerName, OBJPROP_COLOR, clr);
  }

//+------------------------------------------------------------------+
//| Draws the spacer line for an existing open position              |
//+------------------------------------------------------------------+
void DrawSpacer(ulong ticket, double cslPrice, int curLeftBar, int idx)
  {
   string spacerName = GetSpacerName(ticket);
   datetime newTime = iTime(Symbol(), Period(), curLeftBar-idx-LeftOffset);
   ObjectSetInteger(ChartID(), spacerName, OBJPROP_TIME, newTime);
   ObjectMove(ChartID(), spacerName, 1, newTime, cslPrice);
  }

//+------------------------------------------------------------------+
//| Deletes objects related to the input ticket                      |
//+------------------------------------------------------------------+
void CleanupPositionObjects(ulong ticket)
  {
   ObjectDelete(ChartID(), GetOpenName(ticket));
   ObjectDelete(ChartID(), GetCslName(ticket));
   ObjectDelete(ChartID(), GetSpacerName(ticket));
  }

//+------------------------------------------------------------------+
//| Deletes objects related to the input ticket and updates hashmap  |
//+------------------------------------------------------------------+
void CleanupPosition(ulong ticket)
  {
   CleanupPositionObjects(ticket);
   gblOpenPositions.Remove(ticket);
  }

//+------------------------------------------------------------------+
//| Sets the value of the object show description property           |
//+------------------------------------------------------------------+
void SetTradeLabels(bool isChartShowLevels)
  {
   if(!isChartShowLevels)
     {
      ChartSetInteger(ChartID(),CHART_SHOW_OBJECT_DESCR,true);
     }
   else
     {
      ChartSetInteger(ChartID(),CHART_SHOW_OBJECT_DESCR,false);
     }
  }

//+------------------------------------------------------------------+
//| Returns the price at which to create the local stop loss         |
//+------------------------------------------------------------------+
double GetCslPrice(double openPrice, ENUM_POSITION_TYPE posType)
  {
   return posType == POSITION_TYPE_BUY? openPrice - StoplossDistance : openPrice + StoplossDistance; // For buy: stop is below open price; for sell: stop is above open price
  }

//+------------------------------------------------------------------+
//| Returns the name of the open line for the input position ticket  |
//+------------------------------------------------------------------+
string GetOpenName(ulong ticket)
  {
   return CslPrefix + IntegerToString(ticket) + "_open";
  }

//+------------------------------------------------------------------+
//| Returns the display label for the open line                      |
//+------------------------------------------------------------------+
string GetOpenLabel(ENUM_POSITION_TYPE posType, double volume, double price)
  {
   string priceString = DoubleToString(volume,2) + " at " +DoubleToString(price, Digits()); // Volume normalized to 2 decimal places, price normalized to chart symbol Digits()
   return posType == POSITION_TYPE_BUY? " BUY " + priceString : " SELL " + priceString;
  }

//+------------------------------------------------------------------+
//| Returns the name for the local stop loss line                    |
//+------------------------------------------------------------------+
string GetCslName(ulong ticket)
  {
   return CslPrefix + IntegerToString(ticket) + "_line";
  }

//+------------------------------------------------------------------+
//| Returns the name of spacer line for the input position ticket    |
//+------------------------------------------------------------------+
string GetSpacerName(ulong ticket)
  {
   return CslPrefix + IntegerToString(ticket) + "_spacer";
  }
//+------------------------------------------------------------------+
