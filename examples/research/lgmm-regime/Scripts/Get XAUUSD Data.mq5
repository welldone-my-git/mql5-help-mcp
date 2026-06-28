//+------------------------------------------------------------------+
//|                                                  CollectData.mq5 |
//|                                     Copyright 2023, Omega Joctan |
//|                        https://www.mql5.com/en/users/omegajoctan |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Omega Joctan"
#property link      "https://www.mql5.com/en/users/omegajoctan"
#property version   "1.00"
#property script_show_inputs

#include <Arrays\ArrayString.mqh>
#include <Arrays\ArrayObj.mqh>
#include <pandas.mqh> //https://www.mql5.com/en/articles/17030

input datetime start_date = D'2005.01.01';
input datetime end_date = D'2023.01.01';

input string symbol = "XAUUSD";
input ENUM_TIMEFRAMES timeframe = PERIOD_D1;

struct indicator_struct
 {
   long handle;
   CArrayString buffer_names; //buffer_names array
 };

indicator_struct indicators[15]; //Structure for keeping indicator handle alongside its buffer names 
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {  
//---
   
   vector time, open, high, low, close;
   if (!SymbolSelect(symbol, true))
      {
         printf("%s failed to select symbol %s, Error = %d",__FUNCTION__,symbol,GetLastError());
         return;
      }
   
 //---
   
   time.CopyRates(symbol, timeframe, COPY_RATES_TIME, start_date, end_date);
   open.CopyRates(symbol, timeframe, COPY_RATES_OPEN, start_date, end_date);
   high.CopyRates(symbol, timeframe, COPY_RATES_HIGH, start_date, end_date);
   low.CopyRates(symbol, timeframe, COPY_RATES_LOW, start_date, end_date);
   close.CopyRates(symbol, timeframe, COPY_RATES_CLOSE, start_date, end_date);

   CDataFrame df;
   
   df.insert("Time", time);
   df.insert("Open", open);
   df.insert("High", high);
   df.insert("Low", low);
   df.insert("Close", close);
   
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
   
//--- Get buffers
   
   for (uint ind=0; ind<indicators.Size(); ind++) //Loop through all the indicators
      {
         for (uint buffer_no=0; buffer_no<(uint)indicators[ind].buffer_names.Total(); buffer_no++) //Their buffer names resemble their buffer numbers 
            {
               string name = indicators[ind].buffer_names.At(buffer_no); //Get the name of the buffer, it is helpful for the DataFrame and CSV file
               
               vector buffer = {};
               if (!buffer.CopyIndicatorBuffer(indicators[ind].handle, buffer_no, start_date, end_date)) //Copy indicator buffer 
                  {
                     printf("func=%s line=%d | Failed to copy %s indicator buffer, Error = %d",__FUNCTION__,__LINE__,name,GetLastError());
                     continue;
                  }
               
               df.insert(name, buffer); //Insert a buffer vector and its name to a dataframe object
            }
      }

   df.to_csv(StringFormat("Oscillators.%s.%s.csv",symbol,EnumToString(timeframe)), true); //Save all the data to a CSV file
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

