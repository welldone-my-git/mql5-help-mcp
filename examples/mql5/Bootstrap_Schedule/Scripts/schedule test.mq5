//+------------------------------------------------------------------+
//|                                                schedule test.mq5 |
//|                                          Copyright 2023, Omegafx |
//|                 https://www.mql5.com/en/users/omegajoctan/seller |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Omegafx"
#property link      "https://www.mql5.com/en/users/omegajoctan/seller"
#property version   "1.00"

#include <schedule.mqh>
CSchedule schedule(TIME_SOURCE_GMT);
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//---
   
   schedule.every().minute().at(0).dO(Greet, "EveryMin Greetings"); //Job is set at index 0
   schedule.every().hour().at(20,10).dO(Greet, "Hourly Greetings"); //Job is set at index 1
   schedule.every().day().at(13,20,10).dO(Greet, "Daily Greetings"); //JOb is set at index 2
   schedule.every().week().at(MONDAY, 13, 56).dO(Greet, "Weekly Greetings"); //Job is set at index 3
   
   while (true)
    {
      schedule.run_pending();
      Sleep(1000);
    }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Greet()
 {
   Print("Hello there!");
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
