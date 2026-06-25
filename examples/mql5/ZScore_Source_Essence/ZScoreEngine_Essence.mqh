//+------------------------------------------------------------------+
//| ZScoreEngine_Essence.mqh                                         |
//| Reusable Z-Score feature engine                                  |
//| Design essence: math separated from EA/Indicator                  |
//+------------------------------------------------------------------+
#pragma once
#include "SignalEngineBase.mqh"

class CZScoreEngine : public ISignalEngine
  {
private:
   string          m_symbol;
   ENUM_TIMEFRAMES m_tf;
   int             m_period;

private:
   double Mean(const double &x[]) const
     {
      const int n = ArraySize(x);
      if(n <= 0) return 0.0;

      double sum = 0.0;
      for(int i=0; i<n; i++)
         sum += x[i];

      return sum / n;
     }

   double StdDev(const double &x[], const double mean) const
     {
      const int n = ArraySize(x);
      if(n <= 0) return 0.0;

      double ss = 0.0;
      for(int i=0; i<n; i++)
        {
         const double d = x[i] - mean;
         ss += d * d;
        }

      return MathSqrt(ss / n); // population std for fixed rolling window
     }

public:
   CZScoreEngine(const string symbol, const ENUM_TIMEFRAMES tf, const int period)
     {
      m_symbol = (symbol == "") ? _Symbol : symbol;
      m_tf     = tf;
      m_period = (period < 2) ? 20 : period;
     }

   virtual ~CZScoreEngine(void) {}

   virtual bool IsReady(void) const
     {
      return Bars(m_symbol, m_tf) >= m_period + 2;
     }

   // Closed-bar calculation by default.
   // shift=1 means previous completed candle, avoiding current-bar repaint/noise.
   virtual double Value(const int shift=1)
     {
      if(!IsReady()) return 0.0;

      double close[];
      ArraySetAsSeries(close, true);

      const int copied = CopyClose(m_symbol, m_tf, shift, m_period, close);
      if(copied < m_period) return 0.0;

      const double mean = Mean(close);
      const double sd   = StdDev(close, mean);
      if(sd <= 0.0) return 0.0;

      return (close[0] - mean) / sd;
     }
  };
