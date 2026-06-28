//+------------------------------------------------------------------+
//|                                               LGMM Indicator.mq5 |
//|                                          Copyright 2023, Omegafx |
//|                 https://www.mql5.com/en/users/omegajoctan/seller |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Omegafx"
#property link      "https://www.mql5.com/en/users/omegajoctan/seller"
#property version   "1.00"

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrDodgerBlue, clrLimeGreen, clrCrimson, clrOrange, clrYellow
#property indicator_width1  2

#include <Gaussian Mixture.mqh>
#include <Arrays\ArrayString.mqh>
#include <pandas.mqh>

CGaussianMixture lgmm;

input string symbol = "XAUUSD";
input ENUM_TIMEFRAMES timeframe = PERIOD_D1;

struct indicator_struct
 {
   long handle;
   CArrayString buffer_names;
 };

indicator_struct indicators[15];

//--- Indicator buffers

double ProbabilityBuffer[];
double ColorBuffer[];
double MaBuffer[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   
   if (!MQLInfoInteger(MQL_TESTER))
      if (!ChartSetSymbolPeriod(0, symbol, timeframe))
         {
            printf("%s failed to set the symbol and timeframe. Error = %s",__FUNCTION__,GetLastError());
            return INIT_FAILED;
         }
      
//---

   Comment("");
   
   // Set indicator properties
   SetIndexBuffer(0, ProbabilityBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);
   
   // Set histogram drawing style
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_HISTOGRAM);
   
   // Set indicator labels
   IndicatorSetString(INDICATOR_SHORTNAME, "LGMM Components Histogram");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   
//---
   
   string filename = StringFormat("LGMM.%s.%s.onnx",symbol, EnumToString(timeframe));
   if (!lgmm.Init(filename, ONNX_COMMON_FOLDER))
      {
         printf("%s Failed to initialize the GaussianMixture model (LGMM) in ONNX format file={%s}, Error = %d",__FUNCTION__,filename,GetLastError());
      }
   
//--- Oscillators
   
   indicators[0].handle = iATR(symbol, timeframe, 14);
   indicators[0].buffer_names.Add("ATR");
   
   indicators[1].handle = iBearsPower(symbol, timeframe, 13);
   indicators[1].buffer_names.Add("BearsPower");
   
   indicators[2].handle = iBullsPower(symbol, timeframe, 13);
   indicators[2].buffer_names.Add("BullsPower");
   
   indicators[3].handle = iChaikin(symbol, timeframe, 3, 10, MODE_EMA, VOLUME_TICK);
   indicators[3].buffer_names.Add("Chainkin");
   
   indicators[4].handle = iCCI(symbol, timeframe, 14, PRICE_OPEN);
   indicators[4].buffer_names.Add("CCI"); 
   
   indicators[5].handle = iDeMarker(symbol, timeframe, 14);
   indicators[5].buffer_names.Add("Demarker");
   
   indicators[6].handle = iForce(symbol, timeframe, 13, MODE_SMA, VOLUME_TICK);
   indicators[6].buffer_names.Add("Force");
   
   indicators[7].handle = iMACD(symbol, timeframe, 12, 26, 9, PRICE_OPEN);
   indicators[7].buffer_names.Add("MACD MAIN_LINE");
   indicators[7].buffer_names.Add("MACD SIGNAL_LINE");
   
   indicators[8].handle = iMomentum(symbol, timeframe, 14, PRICE_OPEN);
   indicators[8].buffer_names.Add("Momentum");
   
   indicators[9].handle = iOsMA(symbol, timeframe, 12, 26, 9, PRICE_OPEN);
   indicators[9].buffer_names.Add("OsMA");
   
   indicators[10].handle = iRSI(symbol, timeframe, 14, PRICE_OPEN);
   indicators[10].buffer_names.Add("RSI");
   
   indicators[11].handle = iRVI(symbol, timeframe, 10);
   indicators[11].buffer_names.Add("RVI MAIN_LINE");
   indicators[11].buffer_names.Add("RVI SIGNAL_LINE");
   
   indicators[12].handle = iStochastic(symbol, timeframe, 5, 3,3,MODE_SMA,STO_LOWHIGH);
   indicators[12].buffer_names.Add("StochasticOscillator MAIN_LINE");
   indicators[12].buffer_names.Add("StochasticOscillator SIGNAL_LINE");
   
   indicators[13].handle = iTriX(symbol, timeframe, 14, PRICE_OPEN);
   indicators[13].buffer_names.Add("TEMA");
   
   indicators[14].handle = iWPR(symbol, timeframe, 14);
   indicators[14].buffer_names.Add("WPR");
   
   for (uint i=0; i<indicators.Size(); i++)   
     if (indicators[i].handle==INVALID_HANDLE)
        {
          printf("%s Invalid %s handle, Error = %d",__FUNCTION__,indicators[i].buffer_names[0],GetLastError());
          return INIT_FAILED;
        }
           
//---
   return(INIT_SUCCEEDED);
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
                const int32_t &spread[])
  {      
//--- Main calculation loop
   
   int lookback = 20;
   
   for (int i = prev_calculated; i < rates_total && !IsStopped(); i++)
   {      
      if (i+1<lookback) //prevent data not found errors during copy buffer
         continue;
         
      int reverse_index = rates_total - 1 - i;
      
      //--- Get the indicators data
      
      vector x = getX(reverse_index, lookback);
      
      if (x.Size()==0)
         continue;
         
      pred_struct res = lgmm.predict(x);
      
      vector proba = res.proba;
      long label = res.label;
      
      ProbabilityBuffer[i] = proba.Max();
      
      // Determine color based on predicted label
      
      if (label == 0)
         ColorBuffer[i] = 0;
      else if (label == 1)
         ColorBuffer[i] = 1; 
      else if (label == 2)
         ColorBuffer[i] = 2; 
      else if (label == 3)
         ColorBuffer[i] = 3; 
      else
         ColorBuffer[i] = 4; 
     
      Comment("bars [",i+1,"/",rates_total,"]"," Proba: ",proba," label: ",label);
   }
   
//--- 
   return(rates_total);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
vector getX(uint start=0, uint count=10)
 {
//--- Get buffers

   CDataFrame df;
   for (uint ind=0; ind<indicators.Size(); ind++) //Loop through all the indicators
      {    
        uint buffers_total = indicators[ind].buffer_names.Total();
        
         for (uint buffer_no=0; buffer_no<buffers_total; buffer_no++) //Their buffer names resemble their buffer numbers 
            {
               string name = indicators[ind].buffer_names.At(buffer_no); //Get the name of the buffer, it is helpful for the DataFrame and CSV file
               
               vector buffer = {};
               if (!buffer.CopyIndicatorBuffer(indicators[ind].handle, buffer_no, start, count)) //Copy indicator buffer 
                  {
                     printf("func=%s line=%d | Failed to copy %s indicator buffer, Error = %d",__FUNCTION__,__LINE__,name,GetLastError());
                     continue;
                  }
               
               df.insert(name, buffer); //Insert a buffer vector and its name to a dataframe object
            }
      }
   
   if ((uint)df.shape()[0]==0)
      return vector::Zeros(0);
         
   return df.iloc(-1); //Return the latest information from the dataframe which is the most recent buffer
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
