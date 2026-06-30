//+------------------------------------------------------------------+
#property copyright "© 2026, ChukwuBuikem"
#property link      "https://www.mql5.com/en/users/bikeen"
#property version   "1.50"
#property indicator_chart_window
#property  indicator_plots 0
#property description "Adaptive Support & Resistance indicator that automatically detects, tracks,"
#property description "and updates the nearest valid S/R levels using configurable confirmation bars."
#property description "Levels dynamically shift after confirmed breakouts and extend forward in real time."
#define DEF_PROGNAME "SNRTrader_Companion#"
#define SUPPORT_LEVEL DEF_PROGNAME + "Support"
#define RESISTANCE_LEVEL DEF_PROGNAME + "Resistance"

// Structure to store SNR properties
struct st_SNR {
//---+
   int index;
   double price;
   datetime  time, updateTime;
   bool isBroken;
   // constructor
   st_SNR(): index(rightLeftBars), price(EMPTY_VALUE), time(LONG_MAX),
      updateTime(LONG_MAX), isBroken(false) {}
};

//-- INPUTS
input group "+== Sentinel Settings ==+"
input int rightLeftBars = 3;//Confirmation bars for SNR
input color rColor = clrRed;//Resistance level color
input color sColor = clrGreen;//Support level color
input int lineWidth = 2;//Line size

//- Global variables
st_SNR sState;
st_SNR rState;
int barIndex = -1;
//+------------------------------------------------------------------+
//|indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
//- Validate Input
   if(rightLeftBars < 1) {
      Print("Confirmation bars must be >= 1");
      return INIT_FAILED;
   }
//- Detect and draw SNR levels. Also mark broken
   if((barIndex = findNextResistanceIndex(rState.index, true, DBL_MIN)) != -1)
      moveLevel(barIndex, RESISTANCE_LEVEL, false, rState);
   if((barIndex = findNextSupportIndex(sState.index, true, DBL_MAX)) != -1)
      moveLevel(barIndex, SUPPORT_LEVEL, true, sState);
   for(int w = 1; w <= rightLeftBars; w++) {
      if(isLevelBroken(w, sState, false)) {
         markBroken(SUPPORT_LEVEL, sState, iTime(_Symbol, PERIOD_CURRENT, 1));
         break;
      }
   }
   for(int w = 1; w <= rightLeftBars; w++) {
      if(isLevelBroken(w, rState, true)) {
         markBroken(RESISTANCE_LEVEL, rState, iTime(_Symbol, PERIOD_CURRENT, 1));
         break;
      }
   }
   ChartRedraw();
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//|indicator Deinitialization function                         |
//+------------------------------------------------------------------+
void OnDeinit(const int32_t reason) {
//- Delete all chart objects
   ObjectsDeleteAll(0, DEF_PROGNAME);
   ChartRedraw();//Force chart to redraw immediately
}
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int32_t rates_total,
                const int32_t prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int32_t &spread[]) {
//---
   if(prev_calculated != rates_total && prev_calculated > 0) {
      ArraySetAsSeries(time, true);
      //========================================
      //Check breakout of CURRENT levels
      //========================================
      if(!rState.isBroken && isLevelBroken(1, rState, true) && rState.updateTime == LONG_MAX) {
         markBroken(RESISTANCE_LEVEL, rState, time[1]);
         return rates_total;
      }
      if(!sState.isBroken && isLevelBroken(1, sState, false) && sState.updateTime == LONG_MAX) {
         markBroken(SUPPORT_LEVEL, sState, time[1]);
         return rates_total;
      }
      //========================================
      // Check if UPDATE is due (moveLeft)
      //========================================
      if(rState.isBroken && time[0] >= rState.updateTime) {
         if((barIndex = findNextResistanceIndex(rState.index, true, iHigh(_Symbol, PERIOD_CURRENT, 1))) != -1)
            moveLevel(barIndex, RESISTANCE_LEVEL, false, rState);
         return rates_total;
      }
      if(sState.isBroken && time[0] >= sState.updateTime) {
         if((barIndex = findNextSupportIndex(sState.index, true, iLow(_Symbol, PERIOD_CURRENT, 1))) != -1)
            moveLevel(barIndex, SUPPORT_LEVEL, true, sState);
         return rates_total;
      }
      //==========================================
      // No update? Look forward for newer levels
      //==========================================
      if(!rState.isBroken && (barIndex = findNextResistanceIndex(rightLeftBars, true, iHigh(_Symbol, PERIOD_CURRENT, 1))) != -1 && time[barIndex] != rState.time) {
         moveLevel(barIndex, RESISTANCE_LEVEL, false, rState);
         return rates_total;
      }
      if(!sState.isBroken && (barIndex = findNextSupportIndex(rightLeftBars, true, iLow(_Symbol, PERIOD_CURRENT, 1))) != -1 && time[barIndex] != sState.time ) {
         moveLevel(barIndex, SUPPORT_LEVEL, true, sState);
         return rates_total;
      }
      //=================================================
      // Nothing happened : extend levels into the future
      //=================================================
      extendLevel(SUPPORT_LEVEL, sState);
      extendLevel(RESISTANCE_LEVEL, rState);

   }
   return(rates_total);
}
//+------------------------------------------------------------------+
//| Function to validate a resistance level                          |
//+------------------------------------------------------------------+
bool isValidResistance(const MqlRates &rates[], const int index, const int confirmBars) {
//---
   int totalBars = ArraySize(rates);
//--- Index boundary validation
   if(index < confirmBars)return false;
   if(index >= totalBars - confirmBars)return false;

   for(int w = 1; w <= confirmBars; w++) {
      if(index - w < 1)return false;
      //- Look right
      if(rates[index].high < rates[index - w].high) return false;
      //- Look left
      if(rates[index].high < rates[index + w].high) return false;
   }
   return true;
}
//+------------------------------------------------------------------+
//| Function to validate a support level                             |
//+------------------------------------------------------------------+
bool isValidSupport(const MqlRates &rates[], const int index, const int confirmBars) {
//---
   int totalBars = ArraySize(rates);
//--- Index boundary validation
   if(index < confirmBars)return false;
   if(index >= totalBars - confirmBars)return false;

   for(int w = 1; w <= confirmBars; w++) {
      if(index - w < 1)return false;
      //- Look right
      if(rates[index].low > rates[index - w].low) return false;
      //- Look left
      if(rates[index].low > rates[index + w].low) return false;
   }
   return true;
}
//+------------------------------------------------------------------+
//| Function to get the index of next resistance level               |
//+------------------------------------------------------------------+
int findNextResistanceIndex(const int startIndex, const bool moveLeft, const double maxPrice) {
//---
   MqlRates rates[] = {};
   ArraySetAsSeries(rates, true);
   int bars = Bars(_Symbol, PERIOD_CURRENT);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, bars, rates) < bars)
      return -1;

   int step = moveLeft ? 1 : -1;
   //- Check boundary
   int lower = MathMax(rightLeftBars, 1);
   int upper = bars - rightLeftBars - 1;

   for(int w = startIndex + step;
         w >= lower &&
         w <= upper;
         w += step) {
      if(isValidResistance(rates, w, rightLeftBars))
         //- High must be > than broken level
         if(moveLeft && rates[w].high > maxPrice)
            return w;
      //- High can also be < than broken level
         else if(!moveLeft && rates[w].high < maxPrice)
            return w;
   }
   return -1;//Invalid index
}
//+------------------------------------------------------------------+
//| Function to get the index of next support level                  |
//+------------------------------------------------------------------+
int findNextSupportIndex(const int startIndex, const bool moveLeft, const double minPrice) {
//---
   MqlRates rates[] = {};
   ArraySetAsSeries(rates, true);
   int bars = Bars(_Symbol, PERIOD_CURRENT);

   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, bars, rates) < bars)
      return -1;
   int step = moveLeft ? 1 : -1;
   //- Check boundary
   int lower = MathMax(rightLeftBars, 1);
   int upper = bars - rightLeftBars - 1;

   for(int w = startIndex + step;
         w >= lower &&
         w <= upper;
         w += step) {
      if(isValidSupport(rates, w, rightLeftBars))
         //- Low must be < than broken level
         if(moveLeft && rates[w].low < minPrice)
            return w;
      //- Low can also be > than broken level
         else if(!moveLeft && rates[w].low > minPrice)
            return w;
   }
   return -1;//Invalid index
}
//+------------------------------------------------------------------+
void moveLevel(const int index, const string objName,
               const bool isSupport, st_SNR &strct ) {
//---
   MqlRates rate[1];
   if(CopyRates(_Symbol, _Period, index, 1, rate) != 1)
      return;
//-Support works with low price, while resistance works with high price
   double price = (isSupport) ? rate[0].low : rate[0].high;
//- choose color
   color clr = (isSupport) ? sColor : rColor;
//- Extend to into the future
   datetime t2 = iTime(_Symbol, _Period, 0) + (PeriodSeconds() * 10);

   if(ObjectFind(0, objName) == -1) {
      //- Create new object on first run
      if(ObjectCreate(0, objName, OBJ_TREND, 0, rate[0].time, price, t2, price)) {
         ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, lineWidth);
         ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetString(0, objName, OBJPROP_TOOLTIP, "\n");
      }
   } else {
      //- Move object to desired time and price
      ObjectMove(0, objName, 0, rate[0].time, price);
      ObjectMove(0, objName, 1, t2, price);
      ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
   }
//- Save properies of SNR
   strct.index = index;
   strct.price = price;
   strct.isBroken = false;
   strct.time = rate[0].time;
   strct.updateTime = LONG_MAX;
   ChartRedraw();
   return;
}
//+------------------------------------------------------------------+
void markBroken(string objName, st_SNR &st, datetime time) {
//---
   if(ObjectFind(0, objName) == -1)return;
   //- Set to broken state
   st.isBroken   = true;
   //- Set time to update/ detect newer level
   st.updateTime = time + PeriodSeconds();
   ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DASH);
}
//+------------------------------------------------------------------+
bool isLevelBroken(int index, st_SNR &level, bool isResistance) {
//---
   if(level.price == EMPTY_VALUE || level.isBroken)
      return false;

   double barCloseX = iClose(_Symbol, _Period, index);
   if(isResistance) {
      // Resistance broken if price closes above it
      if(barCloseX > level.price) {
         return true;
      }
   } else {
      // Support broken if price closes below it
      if(barCloseX < level.price) {
         return true;
      }
   }
   return false;
}
//+------------------------------------------------------------------+
void extendLevel(const string objName, st_SNR &level) {
//---
   if(ObjectFind(0, objName) != -1 && !level.isBroken) {
      //-Extend level anchor 2(index=1) into the future, current bar + 10
      datetime t2 = iTime(_Symbol, _Period, 0) + (PeriodSeconds() * 10);
      ObjectMove(0, objName, 1, t2, level.price);
   }
}
//+------------------------------------------------------------------+
