//+------------------------------------------------------------------+
//| OncePerBar.mqh                                                   |
//| Small helper to run EA logic only once when a new bar appears     |
//+------------------------------------------------------------------+
#pragma once

class COncePerBar
  {
private:
   string          m_symbol;
   ENUM_TIMEFRAMES m_tf;
   datetime        m_last_bar_time;

public:
   COncePerBar(const string symbol="", const ENUM_TIMEFRAMES tf=PERIOD_CURRENT)
     {
      m_symbol = (symbol == "") ? _Symbol : symbol;
      m_tf = tf;
      m_last_bar_time = 0;
     }

   bool IsNewBar(void)
     {
      const datetime t = iTime(m_symbol, m_tf, 0);
      if(t <= 0) return false;

      if(t != m_last_bar_time)
        {
         m_last_bar_time = t;
         return true;
        }

      return false;
     }
  };
