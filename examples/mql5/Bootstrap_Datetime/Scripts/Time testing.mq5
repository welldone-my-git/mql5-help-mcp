//+------------------------------------------------------------------+
//|                                                 Time testing.mq5 |
//|                                          Copyright 2023, Omegafx |
//|                 https://www.mql5.com/en/users/omegajoctan/seller |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Omegafx"
#property link      "https://www.mql5.com/en/users/omegajoctan/seller"
#property version   "1.00"

#include <PyMQL5\datetime.mqh>
#include <PyMQL5\time.mqh>

CDate date_m;
CDatetime py_datetime;
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//---
   
   Print("10 minutes datetime: ",CTimedelta::minutes<datetime>(10));
   Print("10 minutes seconds: ",CTimedelta::minutes<int>(10));
   
   datetime now_t = TimeLocal();
   printf("Current time: %s 10 minutes ahead: %s",(string)now_t, string(now_t + CTimedelta::minutes<datetime>(10)));
   printf("Current time: %s 1 week, 2 days, 10 hours, and 5 minutes ahead: %s",string(now_t), string(now_t + CTimedelta::timedelta<datetime>(2,10,5,0,1)));
   
   
   CTZInfo tzinfo("Africa/Nairobi");
   CTime t(14, 30, 55, &tzinfo, 120);   // 14:30:55.120

   Print(t.isoformat());                       // AUTO -> "14:30:55.120"
   Print(t.isoformat("hours"));                // "14"
   Print(t.isoformat("minutes"));              // "14:30"
   Print(t.isoformat("seconds"));              // "14:30:55"
   Print(t.isoformat("milliseconds"));         // "14:30:55.120"
   
   CTime t2(TimeLocal());
   Print("New time format: ",t2.strftime("%H,%M,%S"));
   
   //Print("local time: ",time.local());
   
   CTime time;
   Print("Time: ",time.fromisoformat("04:23:01").__str__());
   Print("Time: ",time.fromisoformat("T04:23:01").__str__());
   Print("Time: ",time.fromisoformat("T042301").__str__());
   Print("Time: ",time.fromisoformat("04:23:01.000384").__str__());
   Print("Time: ",time.fromisoformat("04:23:01,000384").__str__());
   Print("Time: ",time.fromisoformat("04:23:01+04:00").__str__());
   Print("Time: ",time.fromisoformat("04:23:01Z").__str__());
   Print("Time: ",time.fromisoformat("04:23:01+00:00").__datetime__());
   
   //Print("Replaced time: ",time.replace()
   
   /*
   CTime t2 = CTime::fromisoformat("T04:23:01");
   CTime t3 = CTime::fromisoformat("T042301");
   CTime t4 = CTime::fromisoformat("04:23:01.000384");
   CTime t5 = CTime::fromisoformat("04:23:01,000384");
   CTime t6 = CTime::fromisoformat("04:23:01+04:00");
   CTime t7 = CTime::fromisoformat("04:23:01Z");
   CTime t8 = CTime::fromisoformat("04:23:01+00:00");
   */
   
   CDate date = py_datetime.date(D'29.02.2024');
     
   Print("date: ", date.isoformat());               
   Print("Weekday: ", date.weekday());            
   Print("ISO Weekday: ", date.isoweekday());     
   Print("Ordinal: ", date.toordinal());          
   Print("Leap year 2024? ", date.IsLeapYear(2024));
   Print("__str__: ",date.__str__());
   
   CDate d2 = py_datetime.date().today();
   Print("Today: ", d2.isoformat());            
   Print("From ISO: ", d2.isoformat());         

   d2 = d2.replace(-1, -1, 30);
   Print("Replaced: ", d2.isoformat());   
      
//--- from timestamps

   CDate date3 = date.fromtimestamp(1672531199);
   Print("Date From timestamps: ",date3.isoformat());
   
   Print("time timestamps: ",py_datetime.fromtimestamp(1672531199).__datetime__());

//---

   Print(date_m.fromisoformat("2019-12-04").__str__());
   Print(date_m.fromisoformat("20191204").__str__());
   
//--- Datetime module testing
   
   //Print("datetime: ",py_datetime.datetime_(2025, 01, 01, 10, 00, 00).__str__());

   CDatetime now = py_datetime.now(&tzinfo);
   string format = "%Y/%m/%d %H:%M:%S";

   string formatted_time = now.strftime(format);
   
   Print("formatted time: ", formatted_time);
   Print("Original time: ", now.strptime(formatted_time, format).__datetime__());
   
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

