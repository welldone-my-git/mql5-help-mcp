//+------------------------------------------------------------------+
//|                                    Market Structure Sentinel.mq5 |
//|                                             © 2026, ChukwuBuikem |
//|                             https://www.mql5.com/en/users/bikeen |
//+------------------------------------------------------------------+
#property copyright "© 2026, ChukwuBuikem"
#property link      "https://www.mql5.com/en/users/bikeen"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0
#property strict

#include <ChartObjects\ChartObjectsTxtControls.mqh>
#include <ChartObjects\ChartObjectsLines.mqh>

#define PROG_NAME "Market Structure Sentinel"
//--- Mini Dashboard constants
#define OUTER_PANEL PROG_NAME + "MiniDashboard_OuterPanel"
#define MAIN_HEADER PROG_NAME + "MiniDashboard_Header"
#define SUB_HEADER PROG_NAME + "MiniDashboard_SubHeader"
#define HEARDER_LABEL PROG_NAME + "MiniDashboard_Direction"
#define DIRECTION_LABEL PROG_NAME + "MiniDashboard_Arrow"
//--- Market Structure Constants
#define TRENDLINE PROG_NAME + "_Trendline"
#define TEXT PROG_NAME + "_Text"
//--- Keystroke Constants
#define KEY_H 72
#define KEY_S 83

#define CLR_DARK_NAVY   C'10,20,50'
#define CHART_ID ChartID()
//--- Custom Enumeration
enum ENUM_TREND
  {
//---
   TREND_UP,//Up trend
   TREND_DOWN,//Down trend
   TREND_RANGE,//Consolidation

  };
//--- Data structure
struct st_SwingPoint
  {
   //---
   datetime          time;
   double            price;
   bool              isBroken;
   //--- Constructor
                     st_SwingPoint(): time(LONG_MIN),
                     price(EMPTY_VALUE), isBroken(false) {}

  };
//--- Input settings
input int rightLeftBars = 3;        //Pivot strength (bars on each side)
input color bosColor = clrRed;      //Color for BOS
input color chochColor = clrPurple; //Color for CHOCH

//--- Global variables
st_SwingPoint swingHigh[2], swingLow[2];
int start = -1;
string marketContext = "";
color contextColor = clrNONE;
CChartObjectRectLabel rectLabel;
CChartObjectLabel label;
CChartObjectText text;
CChartObjectTrend trendLine;
ENUM_TREND currentTrend;
//+------------------------------------------------------------------+
//|                Initialization function                           |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   if(rightLeftBars <= 1)
     {
      Print("[INIT]: Pivot strength (bars) input must be > 1");
      return INIT_PARAMETERS_INCORRECT;
     }
   while(!SeriesInfoInteger(_Symbol, PERIOD_CURRENT, SERIES_SYNCHRONIZED) && !IsStopped())
     {
      Sleep(100);
     }
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 1, iBars(_Symbol, PERIOD_CURRENT), rates) > 0)
     {
      initialMarketStructure(rates);
     }
   showMiniDashboard(currentTrend);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//|              Cleanup function                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int32_t reason)
  {
//---
   ObjectsDeleteAll(CHART_ID, PROG_NAME);
   hideMiniDashboard();
   ChartRedraw(CHART_ID);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int32_t rates_total,
                const int32_t prev_calculated,
                const datetime & time[],
                const double & open[],
                const double & high[],
                const double & low[],
                const double & close[],
                const long & tick_volume[],
                const long & volume[],
                const int32_t &spread[])
  {
//---
   if(isNewCandle(time[rates_total - 1]))
     {
      ArraySetAsSeries(open, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(close, true);
      ArraySetAsSeries(time, true);
      //--- Detect break of swing high
      if(!swingHigh[0].isBroken && swingHigh[0].price != EMPTY_VALUE && close[1] > swingHigh[0].price)
        {
         //--- Break of swing high
         swingHigh[0].isBroken = true;
         marketContext = (currentTrend == TREND_UP) ? "BOS" : "CHOCH";
         contextColor = (marketContext == "BOS") ? bosColor : chochColor;
         drawTrendline(TRENDLINE, swingHigh[0].time, swingHigh[0].price,
                       time[1], swingHigh[0].price, contextColor, 2, marketContext);
         createText(TEXT, getMiddleCandleTime(swingHigh[0].time, time[1]) - PeriodSeconds(),
                    swingHigh[0].price + (30 * _Point), contextColor, marketContext);
         ChartRedraw(CHART_ID);
         return rates_total;
        }
      //--- Detect break of swing low
      if(!swingLow[0].isBroken && swingLow[0].price != EMPTY_VALUE && close[1] < swingLow[0].price)
        {
         //--- Break of swing low
         swingLow[0].isBroken = true;
         marketContext = (currentTrend == TREND_UP) ? "CHOCH" : "BOS";
         contextColor = (marketContext == "BOS") ? bosColor : chochColor;
         drawTrendline(TRENDLINE, swingLow[0].time, swingLow[0].price,
                       time[1], swingLow[0].price, contextColor, 2, marketContext);
         createText(TEXT, getMiddleCandleTime(swingLow[0].time, time[1]) - PeriodSeconds(),
                    swingLow[0].price - (10 * _Point), contextColor, marketContext);
         ChartRedraw(CHART_ID);
         return rates_total;
        }
      if(rates_total < (rightLeftBars + 1) * 2)
         return rates_total;
      //--- Detect swing high
      if(isSwingHigh(rightLeftBars + 1, high, close) && swingHigh[0].time != time[rightLeftBars + 1])
        {
         //--- Update swing high array
         swingHigh[1] = swingHigh[0];
         swingHigh[0].time = time[rightLeftBars + 1];
         swingHigh[0].price = high[rightLeftBars + 1];
         swingHigh[0].isBroken = false;
         //--- Update trend direction
         currentTrend = getTrendDirection(swingHigh, swingLow);
         //--- Pop up mini dashboard with latest trend direction
         showMiniDashboard(currentTrend);
         return rates_total;
        }
      //--- Detect swing low
      if(isSwingLow(rightLeftBars + 1, low, close) && swingLow[0].time != time[rightLeftBars + 1])
        {
         //--- Update swing low array
         swingLow[1] = swingLow[0];
         swingLow[0].time = time[rightLeftBars + 1];
         swingLow[0].price = low[rightLeftBars + 1];
         swingLow[0].isBroken = false;
         //--- Update trend direction
         currentTrend = getTrendDirection(swingHigh, swingLow);
         //--- Pop up mini dashboard with latest trend direction
         showMiniDashboard(currentTrend);
         return rates_total;
        }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//|                 Interactive toggle system                        |
//+------------------------------------------------------------------+
void OnChartEvent(const int32_t id, const long& lparam, const double& dparam, const string& sparam)
  {
//---
   int key = (int)lparam;
//--- Accept only "S" and "H" presses
   if(id != CHARTEVENT_KEYDOWN || (key != KEY_H && key != KEY_S))
      return;
   static ulong lastClick = 0;

   switch(key)
     {
      case KEY_S:
         //--- Double-click is set to happen under 500 milliseconds (ms)
         if(isDoubleClick(lastClick, 500))
            showMiniDashboard(currentTrend);
         break;
      case KEY_H:
         //--- Double-click is set to happen under 500 milliseconds (ms)
         if(isDoubleClick(lastClick, 500))
            hideMiniDashboard();
         break;
     }
  }
//+------------------------------------------------------------------+
//|                  New candle detection                            |
//+------------------------------------------------------------------+
bool isNewCandle(const datetime newOpenTime)
  {
//---
   static datetime lastOpenTime = LONG_MIN;
   if(lastOpenTime == LONG_MIN)
     {
      lastOpenTime = newOpenTime;
      return false;
     }
   if(lastOpenTime != newOpenTime)
     {
      lastOpenTime = newOpenTime;
      return true;
     }
   return false;
  }
//+------------------------------------------------------------------+
//|                  Swing high detection                            |
//+------------------------------------------------------------------+
bool isSwingHigh(const int index, const double &high[], const double &close[])
  {
//---
   int size = ArraySize(high);
//--- Index boundary validation
   if(index < rightLeftBars)
      return false;
   if(index >= (size - (rightLeftBars + 1)))
      return false;

   for(int w = 1; w <= rightLeftBars && (index - w) >= 1; w++)
     {
      //--- Look right (newer candles)
      if(high[index] < high[index - w])
         return false;
      //--- Look left (older candles)
      if(high[index] < high[index + w])
         return false;
     }
   return true;
  }
//+------------------------------------------------------------------+
//|                   Swing low detection                            |
//+------------------------------------------------------------------+
bool isSwingLow(const int index, const double &low[], const double &close[])
  {
//---
   int size = ArraySize(low);
//--- Index boundary validation
   if(index < rightLeftBars)
      return false;
   if(index >= (size - (rightLeftBars + 1)))
      return false;

   for(int w = 1; w <= rightLeftBars && (index - w) >= 1; w++)
     {
      //--- Look right (newer candles)
      if(low[index] > low[index - w])
         return false;
      //--- Look left (older candles)
      if(low[index] > low[index + w])
         return false;
     }
   return true;
  }
//+------------------------------------------------------------------+
//|                 Trend direction detection                        |
//+------------------------------------------------------------------+
ENUM_TREND getTrendDirection(const st_SwingPoint &high[],
                             const st_SwingPoint &low[])
  {
//--- Most recent pair of swing points
   if(high[0].time > low[1].time && high[1].time > low[1].time)
     {
      //--- Determine trend direction using highs
      return(high[0].price > high[1].price) ?
            TREND_UP : (high[0].price < high[1].price) ? TREND_DOWN : TREND_RANGE;
     }
   if(low[0].time > high[1].time && low[1].time > high[1].time)
     {
      //--- Determine trend direction using highs
      return(low[0].price > low[1].price) ?
            TREND_UP : (low[0].price < low[1].price) ? TREND_DOWN : TREND_RANGE;
     }

   return TREND_RANGE;// Default value
  }
//+------------------------------------------------------------------+
//|           Keystroke double click detection                       |
//+------------------------------------------------------------------+
bool isDoubleClick(ulong &lastClick, ulong thresholdMs)
  {
//---
   ulong now = GetTickCount();
   lastClick = now;

   return (now - lastClick <= thresholdMs);
  }
//+------------------------------------------------------------------+
//|             Normalized middle time detection                     |
//+------------------------------------------------------------------+
datetime getMiddleCandleTime(const datetime time1, const datetime time2)
  {
//---
   datetime rawMiddleTime = (time1 + time2) / 2;

   int nearestBar = iBarShift(_Symbol, PERIOD_CURRENT, rawMiddleTime, false);

   if(nearestBar < 0)
      return rawMiddleTime;

   return iTime(_Symbol, PERIOD_CURRENT, nearestBar);// Normalized value
  }
//+------------------------------------------------------------------+
//|                    Trendline creation                            |
//+------------------------------------------------------------------+
void drawTrendline(const string objName, const datetime time1,
                   const double price1, const datetime time2,
                   const double price2, const color clr,
                   const int width, const string tooltip)
  {
//---
   if(trendLine.Create(CHART_ID, objName, 0, time1, price1, time2, price2))
     {
      trendLine.Color(clr);
      trendLine.Width(width);
      trendLine.Tooltip(tooltip);
      trendLine.SetInteger(OBJPROP_HIDDEN, true);
     }
  }
//+------------------------------------------------------------------+
//|                      Text creation                               |
//+------------------------------------------------------------------+
void createText(const string objName, const datetime time, const double price, const color clr,
                const string display, const int fontSize = 10, const string font = "Arial")
  {
//---
   if(text.Create(CHART_ID, objName, 0, time, price))
     {
      text.Color(clr);
      text.Font(font);
      text.FontSize(fontSize);
      text.Tooltip(display);
      text.SetString(OBJPROP_TEXT, display);
      text.SetInteger(OBJPROP_HIDDEN, true);
     }
  }
//+------------------------------------------------------------------+
//|        Function to create rectangle labels                       |
//+------------------------------------------------------------------+
bool createRectLabel(const string objName, const int xDistance, const int yDistance,
                     const int xSize, const int ySize, const color clr, int borderWidth,
                     const color borderColor  = clrNONE, const ENUM_BORDER_TYPE borderType  = BORDER_FLAT,
                     const ENUM_LINE_STYLE  borderStyle = STYLE_SOLID)
  {
//---
   if(rectLabel.Create(CHART_ID, objName, 0, 0, 0, 0, 0))
     {
      rectLabel.X_Distance(xDistance);
      rectLabel.Y_Distance(yDistance);
      rectLabel.X_Size(xSize);
      rectLabel.Y_Size(ySize);
      rectLabel.BackColor(clr);
      rectLabel.SetInteger(OBJPROP_BORDER_COLOR, borderColor);
      rectLabel.SetInteger(OBJPROP_WIDTH, borderWidth);
      rectLabel.BorderType(borderType);
      rectLabel.Style(borderStyle);
      rectLabel.Corner(CORNER_RIGHT_UPPER);
      rectLabel.Tooltip("\n");
      rectLabel.SetInteger(OBJPROP_HIDDEN, true);
      return true;
     }
   return false;
  }
//+------------------------------------------------------------------+
//|        Function to create  labels                                |
//+------------------------------------------------------------------+
bool createLabel(const string objName, const int xDistance, const int yDistance,
                 const color clr, const string display, const int fontSize = 15,
                 const string font = "Arial", const string tooltip = "\n")
  {
//---
   if(label.Create(CHART_ID, objName, 0, 0, 0))
     {
      label.X_Distance(xDistance);
      label.Y_Distance(yDistance);
      label.Color(clr);
      label.Tooltip(tooltip);
      label.SetString(OBJPROP_TEXT, display);
      label.FontSize(fontSize);
      label.Font(font);
      label.SetInteger(OBJPROP_HIDDEN, true);
      return true;
     }
   return false;
  }
//+------------------------------------------------------------------+
//|             Trend direction arrows creation                      |
//+------------------------------------------------------------------+
void createDirectionalArrows(const ENUM_TREND trendDirection)
  {
//---
   string upArrow   = DIRECTION_LABEL + "_UP";
   string downArrow = DIRECTION_LABEL + "_DOWN";
//--- Create both arrow, then set color based on current market direction
   createLabel(upArrow, 710, 70, clrNONE, "▲", 30);
   createLabel(downArrow, 750, 70, clrNONE, "▼", 30);
//--- Up trend
   if(trendDirection == TREND_UP)
     {
      label.Attach(CHART_ID, upArrow, 0, 0);
      label.Tooltip("Up Trend");
      label.Color(clrLimeGreen);
      return;
     }
//--- Down trend
   if(trendDirection == TREND_DOWN)
     {
      label.Attach(CHART_ID, downArrow, 0, 0);
      label.Tooltip("Down Trend");
      label.Color(clrRed);
      return;
     }
//--- Ranging market
   label.Attach(CHART_ID, upArrow, 0, 0);
   label.Tooltip("Consolidation");
   label.Color(clrLimeGreen);
   label.Attach(CHART_ID, downArrow, 0, 0);
   label.Tooltip("Consolidation");
   label.Color(clrRed);
  }
//+------------------------------------------------------------------+
//|                     Mini dashboard display                       |
//+------------------------------------------------------------------+
void showMiniDashboard(const ENUM_TREND trendDirection)
  {
//---
   createRectLabel(OUTER_PANEL, 300, 20, 250, 130, CLR_DARK_NAVY, 3, CLR_DARK_NAVY, BORDER_FLAT, STYLE_DASHDOTDOT);
   createLabel(MAIN_HEADER, 595, 27, clrWhite, "Market Structure Sentinel", 13);
   createLabel(SUB_HEADER, 600, 80, clrGold, "Trend: ", 20);
   createDirectionalArrows(trendDirection);
   ChartRedraw(CHART_ID);
  }
//+------------------------------------------------------------------+
//|                  Hide mini dashboard                             |
//+------------------------------------------------------------------+
void hideMiniDashboard()
  {
//---
   ObjectsDeleteAll(CHART_ID, PROG_NAME + "MiniDashboard");
   ChartRedraw(CHART_ID);
  }
//+------------------------------------------------------------------+
//|       Detect swing high within MqlRates array[]                  |
//+------------------------------------------------------------------+
bool isRatesSwingHigh(const int index, const MqlRates & rates[])
  {
//---
   int size = ArraySize(rates);
//--- Index boundary validation
   if(index < rightLeftBars)
      return false;
   if(index >= size - (rightLeftBars + 1))
      return false;

   for(int w = 1; w <= rightLeftBars; w++)
     {
      if(index - w < 1)
         return false;
      //--- Look right (newer candles)
      if(rates[index].high < rates[index - w].high)
         return false;
      //--- Look left (older candles)
      if(rates[index].high < rates[index + w].high)
         return false;
     }
   return true;
  }
//+------------------------------------------------------------------+
//|       Detect swing low within MqlRates array[]                   |
//+------------------------------------------------------------------+
bool isRatesSwingLow(const int index, const MqlRates & rates[])
  {
//---
   int size = ArraySize(rates);
//--- Index boundary validation
   if(index < rightLeftBars)
      return false;
   if(index >= size - (rightLeftBars + 1))
      return false;

   for(int w = 1; w <= rightLeftBars; w++)
     {
      if(index - w < 1)
         return false;
      //--- Look right (newer candles)
      if(rates[index].low > rates[index - w].low)
         return false;
      //--- Look left (older candles)
      if(rates[index].low > rates[index + w].low)
         return false;
     }
   return true;
  }
//+------------------------------------------------------------------+
//|                  Initial structure state                         |
//+------------------------------------------------------------------+
void initialMarketStructure(const MqlRates &rates[])
  {
//---
   int lowCount = 0, highCount = 0;
//--- Detect last two swing highs and lows
   for(int w = rightLeftBars; w < ArraySize(rates) - rightLeftBars; w++)
     {
      //--- Detect swing low
      if(lowCount < 2 && isRatesSwingLow(w, rates))
        {
         //--- Save properties
         swingLow[lowCount].price = rates[w].low;
         swingLow[lowCount].time = rates[w].time;
         lowCount++;
        }
      //--- Detect swing high
      if(highCount < 2 && isRatesSwingHigh(w, rates))
        {
         //--- Save properties
         swingHigh[highCount].price = rates[w].high;
         swingHigh[highCount].time = rates[w].time;
         highCount++;
        }
      //--- Exit early when both buffers are filled
      if(lowCount >= 2 && highCount >= 2)
         break;
     }
//--- Determine trend direction using highs
   currentTrend = getTrendDirection(swingHigh, swingLow);
//--- Check break of recent swing high
   for(int w = iBarShift(_Symbol, PERIOD_CURRENT, swingHigh[0].time) - 1; w >= 0 && !swingHigh[0].isBroken; w--)
     {
      if(rates[w].close > swingHigh[0].price)
        {
         swingHigh[0].isBroken = true;
         marketContext = (currentTrend == TREND_UP) ? "BOS" : "CHOCH";
         contextColor = (marketContext == "BOS") ? bosColor : chochColor;
         drawTrendline(TRENDLINE, swingHigh[0].time, swingHigh[0].price,
                       rates[w].time, swingHigh[0].price, contextColor, 2, marketContext);
         createText(TEXT, getMiddleCandleTime(swingHigh[0].time, rates[w].time) - PeriodSeconds(),
                    swingHigh[0].price + (30 * _Point), contextColor, marketContext);
         ChartRedraw(CHART_ID);
        }
     }
//--- Check break of recent swing low
   for(int w = iBarShift(_Symbol, PERIOD_CURRENT, swingLow[0].time) - 1; w >= 0 && !swingLow[0].isBroken; w--)
     {
      if(rates[w].close < swingLow[0].price)
        {
         swingLow[0].isBroken = true;
         marketContext = (currentTrend == TREND_DOWN) ? "BOS" : "CHOCH";
         contextColor = (marketContext == "BOS") ? bosColor : chochColor;
         drawTrendline(TRENDLINE, swingLow[0].time, swingLow[0].price,
                       rates[w].time, swingLow[0].price, contextColor, 2, marketContext);
         createText(TEXT, getMiddleCandleTime(swingLow[0].time, rates[w].time) - PeriodSeconds(),
                    swingLow[0].price - (10 * _Point), contextColor, marketContext);
         ChartRedraw(CHART_ID);
        }
     }
  }
//+------------------------------------------------------------------+
