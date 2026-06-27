//+------------------------------------------------------------------+
//|                                        ObjectDetectionTestEA.mq5 |
//|                                 Copyright 2026, Clemence Benjamin|
//|                                               http://www.mql5.com|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Clemence Benjamin"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <ChartObjectsAlgorithms/ChartObjectDetector.mqh>

CChartObjectDetector detector;
SChartObjectInfo objects[];

//+------------------------------------------------------------------+
//| Expert Initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   detector.Init(0); // current chart
   Print("Object Detection EA Initialized");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Tick Function                                                    |
//+------------------------------------------------------------------+
void OnTick()
  {
   static datetime last_run = 0;

   //--- Run every 5 seconds (avoid spam)
   if(TimeCurrent() - last_run < 5)
      return;

   last_run = TimeCurrent();

   int total = detector.Detect(objects);

   Print("------ DETECTED OBJECTS: ", total, " ------");

   for(int i = 0; i < total; i++)
     {
      PrintFormat("Name: %s | Type: %s | Price1: %.5f | Price2: %.5f",
                  objects[i].name,
                  objects[i].type_name,
                  objects[i].price1,
                  objects[i].price2);
     }
  }
//+------------------------------------------------------------------+