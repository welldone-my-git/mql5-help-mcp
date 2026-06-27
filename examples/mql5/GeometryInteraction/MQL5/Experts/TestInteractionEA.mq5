//+------------------------------------------------------------------+
//|                                             TestInteractionEA.mq5|
//|                                 Copyright 2026, Clemence Benjamin|
//|                                              https://www.mql5.com|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Clemence Benjamin"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <ChartObjectsAlgorithms/InteractionDetector.mqh>
#include <ChartObjectsAlgorithms/AlertManager.mqh>
#include <ChartObjectsAlgorithms/TradeExecutor.mqh>

//--- Input parameters
input bool   EnableAlerts     =true;   // enable visual/log alerts
input bool   EnableTrading    =false;  // enable auto trade entry
input double TradeLotSize     =0.01;   // lot size for trades
input int    TimerIntervalSec =2;      // seconds between scans
input string ExcludeNameSubstring="autotrade,#"; // comma-separated substrings to skip

//--- Global objects
CInteractionDetector detector;
CAlertManager        alertManager;
CTradeExecutor       tradeExecutor(2);
SInteraction         interactions[];
int                  interactionCount=0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   detector.Init(0);
   alertManager.SetAlertUse(EnableAlerts);
   alertManager.SetNotificationUse(false);
   alertManager.SetSoundUse(false);

   Print("Test Interaction EA Initialized – monitoring all analytical objects");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Helper: check if object name should be excluded                  |
//+------------------------------------------------------------------+
bool ShouldExclude(const string &name)
  {
   if(ExcludeNameSubstring=="")
      return(false);
   string excludeList[];
   StringSplit(ExcludeNameSubstring, ',', excludeList);
   for(int i=0; i<ArraySize(excludeList); i++)
     {
      if(StringFind(name, excludeList[i])>=0)
         return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   static datetime lastRun=0;
//--- Throttle detection to the configured interval
   if(TimeCurrent()-lastRun<TimerIntervalSec)
      return;
   lastRun=TimeCurrent();

   double bid=SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask=SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   datetime now=TimeCurrent();

//--- Run interaction detection
   int rawCount=detector.DetectInteractions(bid, ask, now);

//--- Filter out unwanted objects
   ArrayResize(interactions, rawCount);
   interactionCount=0;

   for(int i=0; i<rawCount; i++)
     {
      SInteraction inter;
      if(detector.GetInteraction(i, inter) && !ShouldExclude(inter.objName))
         interactions[interactionCount++]=inter;
     }

//--- Print, alert, and optionally trade
   if(interactionCount>0)
     {
      Print("------ INTERACTIONS DETECTED: ", interactionCount, " ------");
      for(int i=0; i<interactionCount; i++)
        {
         PrintFormat("  %s [%s] Action: %d Price: %.5f Dir: %d Side: %s Level: %s",
                     interactions[i].objName, ObjectTypeToString(interactions[i].objType),
                     interactions[i].action, interactions[i].levelPrice,
                     interactions[i].direction, interactions[i].side,
                     interactions[i].levelText);
        }

      //--- Send alerts if enabled
      if(EnableAlerts)
         alertManager.ProcessInteractions(interactions, interactionCount);

      //--- Execute trades (includes touches) if enabled
      if(EnableTrading)
        {
         for(int i=0; i<interactionCount; i++)
           {
            if(interactions[i].action==INTERACTION_CROSS_UP || interactions[i].action==INTERACTION_CROSS_DOWN ||
               interactions[i].action==INTERACTION_BREAKOUT_ABOVE || interactions[i].action==INTERACTION_BREAKOUT_BELOW ||
               interactions[i].action==INTERACTION_TOUCH)
               tradeExecutor.PlaceOrder(interactions[i], TradeLotSize);
           }
        }
     }
  }
//+------------------------------------------------------------------+

