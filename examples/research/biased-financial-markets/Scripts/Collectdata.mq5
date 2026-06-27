//+------------------------------------------------------------------+
//|                                                  Collectdata.mq5 |
//|                                         Copyright 2024, Omegafx. |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Omegafx."
#property link      "https://www.mql5.com/en/users/omegajoctan/seller"
#property version   "1.00"

#include <pandas.mqh>

input string symbols = "EURUSD|USTEC|XAUUSD|USDJPY|BTCUSD|CA60|UK100";
input ENUM_TIMEFRAMES timeframe = PERIOD_D1;

input datetime start_date = D'01.01.2025';
input datetime end_date = D'01.01.2023';

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//---

   string symbolsArr[];
   ushort sep = StringGetCharacter("|",0);
   if (StringSplit(symbols, sep, symbolsArr)<0)
      {
         printf("Failed to obtain the symbols");
         return;
      }

//---

   for (uint i=0; i<symbolsArr.Size(); i++)
     {
         string symbol = symbolsArr[i];
         CDataFrame df;
         
         vector open, high, low, close;
         
         open.CopyRates(symbol, timeframe, COPY_RATES_OPEN,start_date, end_date);
         high.CopyRates(symbol, timeframe, COPY_RATES_HIGH,start_date, end_date);
         low.CopyRates(symbol, timeframe, COPY_RATES_LOW,start_date, end_date);
         close.CopyRates(symbol, timeframe, COPY_RATES_CLOSE,start_date, end_date);
         
         df.insert("Open", open);
         df.insert("High", high);
         df.insert("Low", low);
         df.insert("Close", close);
         
         df.head();
         
         string csv_name = StringFormat("%s.%s.data.csv", symbol, EnumToString(timeframe));
         df.to_csv(csv_name, true);
     }
  }
//+------------------------------------------------------------------+
