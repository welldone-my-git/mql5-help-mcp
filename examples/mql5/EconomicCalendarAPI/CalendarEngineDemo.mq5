//+------------------------------------------------------------------+
//|                                           CalendarEngineDemo.mq5 |
//| Minimal usage example for CalendarEngine.mqh.                    |
//+------------------------------------------------------------------+
#property strict

#include "CalendarEngine.mqh"

input string                         InpCurrency="USD";
input string                         InpCountry="";
input ENUM_CALENDAR_EVENT_IMPORTANCE InpMinImportance=CALENDAR_IMPORTANCE_HIGH;
input int                            InpRefreshSeconds=60;
input int                            InpLookAheadHours=24;
input int                            InpQuietBeforeMinutes=30;
input int                            InpQuietAfterMinutes=15;

CCalendarEngine Calendar;

int OnInit()
  {
   EventSetTimer(InpRefreshSeconds);

   if(!Calendar.GetUpcoming(InpLookAheadHours,InpCurrency,InpCountry,InpMinImportance))
      Print("Initial calendar load failed.");

   Calendar.PrintCache();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   Comment("");
  }

void OnTimer()
  {
   Calendar.GetUpcoming(InpLookAheadHours,InpCurrency,InpCountry,InpMinImportance);

   SNewsEvent news;
   if(Calendar.NextNews(news))
     {
      PrintFormat("Next news: %s | %s | %s",
                  TimeToString(news.time,TIME_DATE|TIME_MINUTES),
                  news.currency,
                  news.name);
     }
  }

void OnTick()
  {
   SNewsEvent news;
   string next_text="No upcoming news";

   if(Calendar.NextNews(news))
     {
      next_text=StringFormat("Next: %s %s %s",
                             TimeToString(news.time,TIME_DATE|TIME_MINUTES),
                             news.currency,
                             news.name);
     }

   if(!Calendar.IsQuietPeriod(InpQuietBeforeMinutes,InpQuietAfterMinutes))
     {
      Comment("News risk window: trading disabled\n",next_text);
      return;
     }

   if(Calendar.IsRedNewsNow(5,5))
     {
      Comment("Red news now\n",next_text);
      return;
     }

   Comment("Normal trading window\n",next_text);
  }
