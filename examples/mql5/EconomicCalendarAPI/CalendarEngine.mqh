//+------------------------------------------------------------------+
//|                                               CalendarEngine.mqh |
//| Reusable Economic Calendar API facade for event-risk filtering.  |
//+------------------------------------------------------------------+
#pragma once

struct SNewsEvent
  {
   datetime                          time;
   string                            name;
   string                            currency;
   string                            country;
   ulong                             event_id;
   ENUM_CALENDAR_EVENT_IMPORTANCE    importance;
  };

class CCalendarEngine
  {
private:
   SNewsEvent                        m_cache[];
   datetime                          m_cache_from;
   datetime                          m_cache_to;
   string                            m_currency_filter;
   string                            m_country_filter;
   ENUM_CALENDAR_EVENT_IMPORTANCE    m_min_importance;

private:
   bool AddValue(const MqlCalendarValue &value,
                 const string currency_filter="",
                 const string country_filter="",
                 const ENUM_CALENDAR_EVENT_IMPORTANCE min_importance=CALENDAR_IMPORTANCE_LOW)
     {
      MqlCalendarEvent event;
      if(!CalendarEventById(value.event_id,event))
         return false;

      if(event.importance<min_importance)
         return false;

      string currency="";
      string country="";
      MqlCalendarCountry event_country;

      if(CalendarCountryById((long)event.country_id,event_country))
        {
         currency=event_country.currency;
         country=event_country.code;
        }

      if(currency_filter!="" && currency!=currency_filter)
         return false;

      if(country_filter!="" && country!=country_filter)
         return false;

      int size=ArraySize(m_cache);
      ArrayResize(m_cache,size+1);

      m_cache[size].time=value.time;
      m_cache[size].name=event.name;
      m_cache[size].currency=currency;
      m_cache[size].country=country;
      m_cache[size].event_id=value.event_id;
      m_cache[size].importance=event.importance;

      return true;
     }

public:
                     CCalendarEngine(void)
     {
      ClearCache();
     }

   void              ClearCache(void)
     {
      ArrayResize(m_cache,0);
      m_cache_from=0;
      m_cache_to=0;
      m_currency_filter="";
      m_country_filter="";
      m_min_importance=CALENDAR_IMPORTANCE_LOW;
     }

   int               Count(void) const
     {
      return ArraySize(m_cache);
     }

   datetime          CacheFrom(void) const
     {
      return m_cache_from;
     }

   datetime          CacheTo(void) const
     {
      return m_cache_to;
     }

   bool              At(const int index,SNewsEvent &event) const
     {
      if(index<0 || index>=ArraySize(m_cache))
         return false;

      event=m_cache[index];
      return true;
     }

   bool              Cache(const datetime from,
                           const datetime to,
                           const string currency_filter="",
                           const string country_filter="",
                           const ENUM_CALENDAR_EVENT_IMPORTANCE min_importance=CALENDAR_IMPORTANCE_HIGH)
     {
      ClearCache();

      MqlCalendarValue values[];
      ResetLastError();

      if(!CalendarValueHistory(values,from,to,country_filter,currency_filter))
        {
         PrintFormat("CalendarValueHistory failed. error=%d",GetLastError());
         return false;
        }

      for(int i=0;i<ArraySize(values);i++)
         AddValue(values[i],currency_filter,country_filter,min_importance);

      m_cache_from=from;
      m_cache_to=to;
      m_currency_filter=currency_filter;
      m_country_filter=country_filter;
      m_min_importance=min_importance;

      return true;
     }

   bool              LoadToday(const string currency_filter="",
                               const string country_filter="",
                               const ENUM_CALENDAR_EVENT_IMPORTANCE min_importance=CALENDAR_IMPORTANCE_HIGH)
     {
      datetime now=TimeTradeServer();

      MqlDateTime parts;
      TimeToStruct(now,parts);
      parts.hour=0;
      parts.min=0;
      parts.sec=0;

      datetime from=StructToTime(parts);
      datetime to=from+86400-1;

      return Cache(from,to,currency_filter,country_filter,min_importance);
     }

   bool              GetUpcoming(const int hours_ahead=24,
                                 const string currency_filter="",
                                 const string country_filter="",
                                 const ENUM_CALENDAR_EVENT_IMPORTANCE min_importance=CALENDAR_IMPORTANCE_HIGH)
     {
      datetime from=TimeTradeServer();
      datetime to=from+(datetime)(hours_ahead*3600);

      return Cache(from,to,currency_filter,country_filter,min_importance);
     }

   int               FilterCountry(const string country_code)
     {
      SNewsEvent filtered[];

      for(int i=0;i<ArraySize(m_cache);i++)
        {
         if(m_cache[i].country!=country_code)
            continue;

         int size=ArraySize(filtered);
         ArrayResize(filtered,size+1);
         filtered[size]=m_cache[i];
        }

      ArrayResize(m_cache,ArraySize(filtered));
      for(int i=0;i<ArraySize(filtered);i++)
         m_cache[i]=filtered[i];

      m_country_filter=country_code;
      return ArraySize(m_cache);
     }

   int               FilterImpact(const ENUM_CALENDAR_EVENT_IMPORTANCE min_importance)
     {
      SNewsEvent filtered[];

      for(int i=0;i<ArraySize(m_cache);i++)
        {
         if(m_cache[i].importance<min_importance)
            continue;

         int size=ArraySize(filtered);
         ArrayResize(filtered,size+1);
         filtered[size]=m_cache[i];
        }

      ArrayResize(m_cache,ArraySize(filtered));
      for(int i=0;i<ArraySize(filtered);i++)
         m_cache[i]=filtered[i];

      m_min_importance=min_importance;
      return ArraySize(m_cache);
     }

   double            MinutesToEvent(void) const
     {
      datetime now=TimeTradeServer();
      bool found=false;
      double best_minutes=EMPTY_VALUE;

      for(int i=0;i<ArraySize(m_cache);i++)
        {
         if(m_cache[i].time<now)
            continue;

         double minutes=(double)(m_cache[i].time-now)/60.0;
         if(!found || minutes<best_minutes)
           {
            best_minutes=minutes;
            found=true;
           }
        }

      return best_minutes;
     }

   bool              IsQuietPeriod(const int minutes_before=30,
                                   const int minutes_after=15) const
     {
      datetime now=TimeTradeServer();

      for(int i=0;i<ArraySize(m_cache);i++)
        {
         datetime start=m_cache[i].time-(datetime)(minutes_before*60);
         datetime end=m_cache[i].time+(datetime)(minutes_after*60);

         if(now>=start && now<=end)
            return false;
        }

      return true;
     }

   bool              IsRedNewsNow(const int minutes_before=5,
                                  const int minutes_after=5) const
     {
      datetime now=TimeTradeServer();

      for(int i=0;i<ArraySize(m_cache);i++)
        {
         if(m_cache[i].importance<CALENDAR_IMPORTANCE_HIGH)
            continue;

         datetime start=m_cache[i].time-(datetime)(minutes_before*60);
         datetime end=m_cache[i].time+(datetime)(minutes_after*60);

         if(now>=start && now<=end)
            return true;
        }

      return false;
     }

   bool              RedNewsWithin(const int minutes_ahead) const
     {
      datetime now=TimeTradeServer();
      datetime limit=now+(datetime)(minutes_ahead*60);

      for(int i=0;i<ArraySize(m_cache);i++)
        {
         if(m_cache[i].importance<CALENDAR_IMPORTANCE_HIGH)
            continue;

         if(m_cache[i].time>=now && m_cache[i].time<=limit)
            return true;
        }

      return false;
     }

   bool              NextNews(SNewsEvent &event) const
     {
      datetime now=TimeTradeServer();
      bool found=false;
      datetime best_time=0;

      for(int i=0;i<ArraySize(m_cache);i++)
        {
         if(m_cache[i].time<now)
            continue;

         if(!found || m_cache[i].time<best_time)
           {
            event=m_cache[i];
            best_time=m_cache[i].time;
            found=true;
           }
        }

      return found;
     }

   void              PrintCache(void) const
     {
      for(int i=0;i<ArraySize(m_cache);i++)
        {
         PrintFormat("[NEWS] %s | %s | %s | %s | %s",
                     TimeToString(m_cache[i].time,TIME_DATE|TIME_MINUTES),
                     m_cache[i].currency,
                     m_cache[i].country,
                     EnumToString(m_cache[i].importance),
                     m_cache[i].name);
        }
     }
  };
