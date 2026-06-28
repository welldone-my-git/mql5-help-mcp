//+------------------------------------------------------------------+
//|                                                   NewsFilter.mqh |
//+------------------------------------------------------------------+
#property strict

//--- Input parameters
input int      InpPreEventMins     = 30;
input int      InpPostEventMins    = 30;
input bool     InpFilterHigh       = true;
input bool     InpFilterMedium     = false;
input string   InpManualCurrencies = "";
input bool     InpUseCsvFallback   = false;
input string   InpCsvFileName      = "NewsCalendarLog_EURUSD.csv";

//--- Internal cache
#define NF_MAX_EVENTS 3000

datetime g_nfEventTimes[NF_MAX_EVENTS];
int      g_nfEventCount   = 0;
datetime g_nfLastRefresh  = 0;
datetime g_nfLastRelease  = 0;
bool     g_nfHighToday    = false;
bool     g_nfCsvLoaded    = false;

//+------------------------------------------------------------------+
//| Helper: Get Currencies                                           |
//+------------------------------------------------------------------+
void NF_GetCurrencies(string &cur1, string &cur2)
  {
   if(StringLen(InpManualCurrencies) >= 3)
     {
      string parts[];
      StringSplit(InpManualCurrencies, ',', parts);
      cur1 = (ArraySize(parts) > 0) ? parts[0] : "";
      cur2 = (ArraySize(parts) > 1) ? parts[1] : "";
      StringTrimLeft(cur1);
      StringTrimRight(cur1);
      StringTrimLeft(cur2);
      StringTrimRight(cur2);
      return;
     }

   string sym = _Symbol;
   int dotPos = StringFind(sym, ".");
   if(dotPos > 0)
      sym = StringSubstr(sym, 0, dotPos);
   int usPos = StringFind(sym, "_");
   if(usPos > 0)
      sym = StringSubstr(sym, 0, usPos);

   if(StringLen(sym) == 6)
     {
      cur1 = StringSubstr(sym, 0, 3);
      cur2 = StringSubstr(sym, 3, 3);
     }
   else
     {
      cur1 = "USD";
      cur2 = "";
     }
  }

//+------------------------------------------------------------------+
//| Helper: Country Codes                                            |
//+------------------------------------------------------------------+
string NF_CountryForCurrency(string currency)
  {
   StringToUpper(currency);
   if(currency == "USD")
      return("US");
   if(currency == "EUR")
      return("EU");
   if(currency == "GBP")
      return("GB");
   if(currency == "JPY")
      return("JP");
   if(currency == "AUD")
      return("AU");
   if(currency == "CAD")
      return("CA");
   if(currency == "CHF")
      return("CH");
   if(currency == "NZD")
      return("NZ");
   return("");
  }

//+------------------------------------------------------------------+
//| Load from Live API                                               |
//+------------------------------------------------------------------+
void NF_LoadEvents()
  {
   g_nfEventCount  = 0;
   g_nfLastRelease = 0;
   g_nfHighToday   = false;
   datetime now    = TimeCurrent();
   datetime window = now + 86400;
   int tzOffset    = (int)(TimeCurrent() - TimeGMT());

   string cur1, cur2;
   NF_GetCurrencies(cur1, cur2);
   string countries[2];
   countries[0] = NF_CountryForCurrency(cur1);
   countries[1] = NF_CountryForCurrency(cur2);

   for(int c = 0; c < 2; c++)
     {
      if(StringLen(countries[c]) == 0)
         continue;
      MqlCalendarEvent events[];
      int evCount = CalendarEventByCountry(countries[c], events);
      if(evCount <= 0)
         continue;

      for(int i = 0; i < evCount; i++)
        {
         bool isHigh = (events[i].importance == CALENDAR_IMPORTANCE_HIGH);
         bool isMed  = (events[i].importance == CALENDAR_IMPORTANCE_MODERATE);
         if(!isHigh && !(InpFilterMedium && isMed))
            continue;

         MqlCalendarValue values[];
         int valCount = CalendarValueHistoryByEvent(events[i].id, values, now - 86400, window);
         if(valCount <= 0)
            continue;

         for(int v = 0; v < valCount; v++)
           {
            datetime evTime = values[v].time + tzOffset;
            if(evTime > now && evTime <= window)
              {
               if(g_nfEventCount < NF_MAX_EVENTS)
                 {
                  g_nfEventTimes[g_nfEventCount] = evTime;
                  g_nfEventCount++;
                  if(isHigh)
                     g_nfHighToday = true;
                 }
              }
            if(evTime <= now && evTime > g_nfLastRelease)
               g_nfLastRelease = evTime;
           }
        }
     }
   g_nfLastRefresh = now;
   PrintFormat("NewsFilter: Live API refreshed. %d events loaded.", g_nfEventCount);
  }

//+------------------------------------------------------------------+
//| Load from CSV                                                    |
//+------------------------------------------------------------------+
void NF_LoadCsv(string fileName)
  {
   if(g_nfCsvLoaded)
      return;

   g_nfEventCount = 0;
   g_nfHighToday  = false;
   g_nfLastRelease = 0;

   int handle = FileOpen(fileName, FILE_READ | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(handle == INVALID_HANDLE)
      handle = FileOpen(fileName, FILE_READ | FILE_CSV | FILE_ANSI | FILE_COMMON, ';');

   if(handle == INVALID_HANDLE)
     {
      PrintFormat("NewsFilter ERROR: Could not open file %s", fileName);
      return;
     }

   string cur1, cur2;
   NF_GetCurrencies(cur1, cur2);
   StringToUpper(cur1);
   StringToUpper(cur2);

//--- Skip 2 header lines
   for(int i = 0; i < 2; i++)
     {
      while(!FileIsLineEnding(handle) && !FileIsEnding(handle))
         FileReadString(handle);
     }

   int loadedCount = 0;
   bool arrayFullWarning = false;

   while(!FileIsEnding(handle))
     {
      string dtStr  = FileReadString(handle);
      string name   = FileReadString(handle);
      string impact = FileReadString(handle);
      string curr   = FileReadString(handle);

      while(!FileIsLineEnding(handle) && !FileIsEnding(handle))
         FileReadString(handle);

      if(dtStr == "" || dtStr == NULL)
         continue;

      StringTrimLeft(curr);
      StringTrimRight(curr);
      StringToUpper(curr);
      if(curr != cur1 && curr != cur2)
         continue;

      StringTrimLeft(impact);
      StringTrimRight(impact);
      StringToUpper(impact);
      if(!(impact == "HIGH" || (InpFilterMedium && impact == "MEDIUM")))
         continue;

      string cleanDate = dtStr;
      StringReplace(cleanDate, ".", "-");
      datetime evTime = StringToTime(cleanDate);

      if(evTime == 0)
         continue;

      //--- Check for array capacity
      if(g_nfEventCount < NF_MAX_EVENTS)
        {
         g_nfEventTimes[g_nfEventCount] = evTime;
         g_nfEventCount++;
         if(impact == "HIGH")
            g_nfHighToday = true;
         loadedCount++;
        }
      else
        {
         arrayFullWarning = true;
        }
     }
   FileClose(handle);
   g_nfCsvLoaded = true;

//--- MQL5 BACKTEST HEALTH CHECKS
   if(MQLInfoInteger(MQL_TESTER))
     {
      datetime testStart = TimeCurrent();

      if(g_nfEventCount > 0)
        {
         datetime firstEvent = g_nfEventTimes[0];
         datetime lastEvent  = g_nfEventTimes[g_nfEventCount - 1];

         //--- 1. Start Date Gap check
         if(testStart > 0 && firstEvent > testStart)
           {
            PrintFormat("NewsFilter WARNING: Backtest starts at %s, but CSV begins at %s.",
                        TimeToString(testStart), TimeToString(firstEvent));
           }

         //--- 2. Complete Mismatch Check (CSV is entirely too old)
         if(testStart > 0 && lastEvent < testStart)
           {
            PrintFormat("NewsFilter CRITICAL ERROR: CSV ended on %s, before backtest started on %s!",
                        TimeToString(lastEvent), TimeToString(testStart));
           }

         //--- 3. Early Finish / End Date Notice
         PrintFormat("NewsFilter INFO: CSV coverage spans from %s to %s.",
                     TimeToString(firstEvent), TimeToString(lastEvent));
         PrintFormat("NewsFilter NOTICE: If your backtest runs past %s, news filtering will stop working.",
                     TimeToString(lastEvent));
        }
      else
        {
         Print("NewsFilter WARNING: No matching events found in CSV.");
        }
     }

   PrintFormat("NewsFilter: SUCCESS! Loaded %d events from %s.", g_nfEventCount, fileName);
  }

//+------------------------------------------------------------------+
//| Initialization (Universal Priority Strategy)                     |
//+------------------------------------------------------------------+
void NewsFilterInit(bool forceCsv = false)
  {
   string targetFile = "";

//--- 1. Priority: Exact User Input
   if(InpCsvFileName != "" && FileIsExist(InpCsvFileName, FILE_COMMON))
      targetFile = InpCsvFileName;

//--- 2. Priority: Standard Script Format
   else
      if(FileIsExist("NewsCalendarLog_" + _Symbol + ".csv", FILE_COMMON))
         targetFile = "NewsCalendarLog_" + _Symbol + ".csv";

      //--- 3. Priority: Pattern Match (Auto-detect files with date stamps)
      else
        {
         string searchPattern = "NewsCalendarLog_" + _Symbol + "_*.csv";
         long searchHandle;
         string foundFile;

         searchHandle = FileFindFirst(searchPattern, foundFile, FILE_COMMON);
         if(searchHandle != INVALID_HANDLE)
           {
            targetFile = foundFile;
            FileFindClose(searchHandle);
            PrintFormat("NewsFilter: Auto-detected date-stamped file: %s", targetFile);
           }
        }

//--- Execution Logic
   if((bool)MQLInfoInteger(MQL_TESTER) || forceCsv || InpUseCsvFallback)
     {
      if(targetFile != "")
        {
         if(!g_nfCsvLoaded)
            NF_LoadCsv(targetFile);
        }
      else
        {
         Print("NewsFilter ERROR: No matching CSV found! Please provide the full filename in inputs.");
        }
     }
   else
     {
      NF_LoadEvents();
     }
  }

//+------------------------------------------------------------------+
//| Pre-News Window Check                                            |
//+------------------------------------------------------------------+
bool IsNewsWindow()
  {
   datetime now = TimeCurrent();
   if(!(bool)MQLInfoInteger(MQL_TESTER) && !InpUseCsvFallback)
     {
      if(now - g_nfLastRefresh >= 3600)
         NF_LoadEvents();
     }
   long preSec = (long)InpPreEventMins * 60;
   for(int i = 0; i < g_nfEventCount; i++)
     {
      long diff = (long)g_nfEventTimes[i] - (long)now;
      if(diff >= 0 && diff <= preSec)
         return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Post-News Window Check                                           |
//+------------------------------------------------------------------+
bool IsPostNewsWindow()
  {
   datetime now = TimeCurrent();
   g_nfLastRelease = 0;

   for(int i = 0; i < g_nfEventCount; i++)
     {
      if(g_nfEventTimes[i] <= now)
        {
         if(g_nfEventTimes[i] > g_nfLastRelease)
            g_nfLastRelease = g_nfEventTimes[i];
        }
     }

   if(g_nfLastRelease == 0)
      return(false);

   long elapsed = (long)now - (long)g_nfLastRelease;
   return(elapsed >= 0 && elapsed <= (long)InpPostEventMins * 60);
  }

//+------------------------------------------------------------------+
//| High Impact Checker                                              |
//+------------------------------------------------------------------+
bool IsHighImpactNewsToday()
  {
   return(g_nfHighToday);
  }
//+------------------------------------------------------------------+