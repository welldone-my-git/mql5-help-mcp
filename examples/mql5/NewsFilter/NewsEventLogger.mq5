//+------------------------------------------------------------------+
//|                                          NewsEventLogger.mq5     |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs

//--- INPUTS
input group "=== Date Range Settings ==="
input datetime InpStartDate     = D'2023.01.01'; // Start Date
input datetime InpEndDate       = D'2024.01.01'; // End Date

input group "=== Filter & File Options ==="
input string   InpCurrencies    = "";            // Manual Currencies (Auto if empty)
input string   InpLogPrefix     = "NewsCalendarLog";
input bool     InpLogMedium     = false;         // Log medium-impact events

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//--- 1. Currency Detection
   string targetCurrencies = InpCurrencies;
   if(StringLen(targetCurrencies) == 0)
     {
      string base   = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
      string profit = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
      targetCurrencies = base + "," + profit;
     }

//--- 2. Generate Date-Stamped Filename
   string startStr = TimeToString(InpStartDate, TIME_DATE);
   string endStr   = TimeToString(InpEndDate, TIME_DATE);

   StringReplace(startStr, ".", "");
   StringReplace(endStr, ".", "");

   string filename = InpLogPrefix + "_" + _Symbol + "_" + startStr + "_" + endStr + ".csv";

//--- 3. File Creation
   int fileHandle = FileOpen(filename, FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(fileHandle == INVALID_HANDLE)
     {
      Print("NewsLogger ERROR: Cannot create file: ", GetLastError());
      return;
     }

//--- Write CSV headers
   FileWrite(fileHandle, "sep=,");
   FileWrite(fileHandle, "DateTime", "EventName", "Impact", "Currency", "CountryCode", "Forecast", "Previous", "Actual");

   string currencies[];
   int numCurrencies = StringSplit(targetCurrencies, ',', currencies);

   string codes[][2] =
     {
        {"USD", "US"}, {"EUR", "EU"}, {"GBP", "GB"}, {"JPY", "JP"},
        {"AUD", "AU"}, {"CAD", "CA"}, {"CHF", "CH"}, {"NZD", "NZ"},
        {"XAU", "US"}, {"XAG", "US"}, {"BTC", "US"}
     };

   int totalWritten = 0;
   int tzOffset = (int)(TimeCurrent() - TimeGMT());

//--- Process news data per currency
   for(int ci = 0; ci < numCurrencies; ci++)
     {
      string currency = currencies[ci];
      StringTrimLeft(currency);
      StringTrimRight(currency);
      StringToUpper(currency);

      string countryCode = "";
      for(int m = 0; m < ArrayRange(codes, 0); m++)
        {
         if(codes[m][0] == currency)
           {
            countryCode = codes[m][1];
            break;
           }
        }

      if(StringLen(countryCode) == 0)
         continue;

      MqlCalendarEvent events[];
      int evCount = CalendarEventByCountry(countryCode, events);

      //--- Iterate through events
      for(int i = 0; i < evCount; i++)
        {
         bool isHigh = (events[i].importance == CALENDAR_IMPORTANCE_HIGH);
         bool isMed  = (events[i].importance == CALENDAR_IMPORTANCE_MODERATE);

         if(!isHigh && !(InpLogMedium && isMed))
            continue;

         MqlCalendarValue values[];
         int vCount = CalendarValueHistoryByEvent(events[i].id, values, InpStartDate, InpEndDate);

         //--- Log specific values for the date range
         for(int v = 0; v < vCount; v++)
           {
            datetime adjustedTime = values[v].time + tzOffset;

            FileWrite(fileHandle,
                      TimeToString(adjustedTime, TIME_DATE | TIME_SECONDS),
                      events[i].name,
                      (isHigh ? "HIGH" : "MEDIUM"),
                      currency,
                      countryCode,
                      (values[v].forecast_value == DBL_MAX) ? "" : DoubleToString(values[v].forecast_value, 2),
                      (values[v].prev_value == DBL_MAX) ? "" : DoubleToString(values[v].prev_value, 2),
                      (values[v].actual_value == DBL_MAX) ? "" : DoubleToString(values[v].actual_value, 2));

            totalWritten++;
           }
        }
     }

//--- Close file and report status
   FileClose(fileHandle);

   PrintFormat("NewsLogger SUCCESS: %d events written.", totalWritten);
   PrintFormat("Filename: %s", filename);
  }
//+------------------------------------------------------------------+