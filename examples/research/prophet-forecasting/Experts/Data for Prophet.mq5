//+------------------------------------------------------------------+
//|                                             Data for Prophet.mq5 |
//|                                          Copyright 2023, Omegafx |
//|                 https://www.mql5.com/en/users/omegajoctan/seller |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Omegafx"
#property link      "https://www.mql5.com/en/users/omegajoctan/seller"
#property version   "1.00"

input uint collect_news_interval_seconds = 60;
input uint training_bars = 1000;

input ENUM_TIMEFRAMES timeframe = PERIOD_H1;

MqlRates rates[];
struct news_data_struct
  {   
    datetime time[]; //News release time
    double open[]; //Candle opening price
    double high[]; //Candle high price
    double low[]; //Candle low price
    double close[]; //Candle close price
    string name[]; //Name of the news
    ENUM_CALENDAR_EVENT_SECTOR sector[]; //The sector a news is related to
    ENUM_CALENDAR_EVENT_IMPORTANCE importance[]; //Event importance
    double actual[]; //actual value
    double forecast[]; //forecast value
    double previous[]; //previous value
    
    void Resize(uint size)
      {
          ArrayResize(time, size);
          ArrayResize(open, size);
          ArrayResize(high, size);
          ArrayResize(low, size);
          ArrayResize(close, size);
          ArrayResize(name, size);
          ArrayResize(sector, size);
          ArrayResize(importance, size);
          ArrayResize(actual, size);
          ArrayResize(forecast, size);
          ArrayResize(previous, size);
      }
    
  } news_data;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {  
//--- create timer

   EventSetTimer(collect_news_interval_seconds);
   
   if (!ChartSetSymbolPeriod(0, Symbol(), timeframe))
      return INIT_FAILED;
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
   MqlDateTime time_struct;
   TimeToStruct(TimeGMT(), time_struct);
   
   SaveNews(StringFormat("%s.%s.OHLC.date=%s.hour=%d + News.csv",Symbol(),EnumToString(timeframe), TimeToString(TimeGMT(), TIME_DATE), time_struct.hour));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SaveNews(string csv_name)
 {
//--- get OHLC values first
   
   ResetLastError();
   if (CopyRates(Symbol(), timeframe, 0, training_bars, rates)<=0)
     {
       printf("%s failed to get price infromation from %d to %d. Error = %d",__FUNCTION__,0,training_bars,GetLastError());
       return;
     }
      
   uint size = rates.Size();   
   news_data.Resize(size-1);

//---

   FileDelete(csv_name); //Delete an existing csv file of a given name
   int csv_handle = FileOpen(csv_name,FILE_WRITE|FILE_SHARE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,",",CP_UTF8); //csv handle
   
   if(csv_handle == INVALID_HANDLE)
     {
       printf("Invalid %s handle Error %d ",csv_name,GetLastError());
       return; //stop the process
     }
     
   FileSeek(csv_handle,0,SEEK_SET); //go to file begining
   FileWrite(csv_handle,"Time,Open,High,Low,Close,Name,Sector,Importance,Actual,Forecast,Previous"); //write csv header
   
   MqlCalendarValue values[]; //https://www.mql5.com/en/docs/constants/structures/mqlcalendar#mqlcalendarvalue
   for (uint i=0; i<size-1; i++)
      {
         news_data.time[i] = rates[i].time;
         news_data.open[i] = rates[i].open;
         news_data.high[i] = rates[i].high;
         news_data.low[i] = rates[i].low;
         news_data.close[i] = rates[i].close;
         
         int all_news = CalendarValueHistory(values, rates[i].time, rates[i+1].time, NULL, NULL); //we obtain all the news with their values https://www.mql5.com/en/docs/calendar/calendarvaluehistory
         
         for (int n=0; n<all_news; n++)
            {
              MqlCalendarEvent event;
              CalendarEventById(values[n].event_id, event); //Here among all the news we select one after the other by its id https://www.mql5.com/en/docs/calendar/calendareventbyid
                   
              MqlCalendarCountry country; //The couhtry where the currency pair originates
              CalendarCountryById(event.country_id, country); //https://www.mql5.com/en/docs/calendar/calendarcountrybyid
                 
              if (StringFind(Symbol(), country.currency)>-1) //We want to ensure that we filter news that has nothing to do with the base and the quote currency for the current symbol pair
                { 
                     news_data.name[i] = event.name;  
                     news_data.sector[i] = event.sector;
                     news_data.importance[i] = event.importance;
                       
                     news_data.actual[i] = !MathIsValidNumber(values[n].GetActualValue()) ? 0 : values[n].GetActualValue();
                     news_data.forecast[i] = !MathIsValidNumber(values[n].GetForecastValue()) ? 0 : values[n].GetForecastValue();
                     news_data.previous[i] = !MathIsValidNumber(values[n].GetPreviousValue()) ? 0 : values[n].GetPreviousValue();
                }
            }
          
          FileWrite(csv_handle,StringFormat("%s,%f,%f,%f,%f,%s,%s,%s,%f,%f,%f",
                                 (string)news_data.time[i],
                                 news_data.open[i],
                                 news_data.high[i],
                                 news_data.low[i],
                                 news_data.close[i],
                                 news_data.name[i],
                                 EnumToString(news_data.sector[i]),
                                 EnumToString(news_data.importance[i]),
                                 news_data.actual[i],
                                 news_data.forecast[i],
                                 news_data.previous[i]
                               ));
       }  
//---

   FileClose(csv_handle);
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

