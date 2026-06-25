//+------------------------------------------------------------------+
//| SignalEngineBase.mqh                                             |
//| Minimal reusable signal engine interface for MQL5 EA/Indicator    |
//+------------------------------------------------------------------+
#pragma once

class ISignalEngine
  {
public:
   virtual ~ISignalEngine(void) {}

   // Always use closed bar by default: shift=1
   virtual double Value(const int shift=1) = 0;
   virtual bool   IsReady(void) const = 0;
  };
