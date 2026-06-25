//+------------------------------------------------------------------+
//| MSNR Clean Edition - RiskCore.mqh                                |
//| 收藏内容：SpreadFilter + RiskPercent LotSizer + DrawdownGuard    |
//+------------------------------------------------------------------+
#property strict

#ifndef __MSNR_CLEAN_RISK_CORE_MQH__
#define __MSNR_CLEAN_RISK_CORE_MQH__

class CSpreadFilter
{
private:
   double m_max_spread_points;

public:
   void Configure(const double max_spread_points)
   {
      m_max_spread_points = max_spread_points;
   }

   bool Allow(const string symbol, string &error) const
   {
      MqlTick tick;
      if(!SymbolInfoTick(symbol, tick))
      {
         error = "No tick for symbol: " + symbol;
         return false;
      }

      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double spread_points = (tick.ask - tick.bid) / point;

      if(m_max_spread_points > 0 && spread_points > m_max_spread_points)
      {
         error = "Spread too high: " + DoubleToString(spread_points, 1);
         return false;
      }
      return true;
   }
};

class CLotSizer
{
public:
   double NormalizeVolume(const string symbol, double volume) const
   {
      double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double step    = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

      volume = MathMax(min_lot, MathMin(max_lot, volume));
      volume = MathFloor(volume / step) * step;
      return NormalizeDouble(volume, 2);
   }

   double RiskPercentLot(const string symbol,
                         const double risk_percent,
                         const double entry,
                         const double stop_loss,
                         const double max_lot = 0.0) const
   {
      if(risk_percent <= 0 || entry <= 0 || stop_loss <= 0)
         return 0.0;

      double risk_money = AccountInfoDouble(ACCOUNT_BALANCE) * risk_percent / 100.0;
      double tick_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double distance   = MathAbs(entry - stop_loss);

      if(tick_size <= 0 || tick_value <= 0 || distance <= 0)
         return 0.0;

      double loss_per_lot = distance / tick_size * tick_value;
      if(loss_per_lot <= 0)
         return 0.0;

      double lot = risk_money / loss_per_lot;
      if(max_lot > 0.0)
         lot = MathMin(lot, max_lot);

      return NormalizeVolume(symbol, lot);
   }
};

class CDrawdownGuard
{
private:
   double m_equity_peak;
   double m_max_dd_percent;
   int    m_max_loss_streak;
   int    m_loss_streak;
   bool   m_paused;

public:
   void Configure(const double max_dd_percent, const int max_loss_streak)
   {
      m_equity_peak      = AccountInfoDouble(ACCOUNT_EQUITY);
      m_max_dd_percent   = max_dd_percent;
      m_max_loss_streak  = max_loss_streak;
      m_loss_streak      = 0;
      m_paused           = false;
   }

   void UpdateEquityPeak()
   {
      m_equity_peak = MathMax(m_equity_peak, AccountInfoDouble(ACCOUNT_EQUITY));
   }

   void RecordClosedProfit(const double profit)
   {
      if(profit < 0) m_loss_streak++;
      else           m_loss_streak = 0;

      if(m_max_loss_streak > 0 && m_loss_streak >= m_max_loss_streak)
         m_paused = true;
   }

   bool Allow(string &error)
   {
      UpdateEquityPeak();
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double dd = 0.0;
      if(m_equity_peak > 0)
         dd = (m_equity_peak - equity) / m_equity_peak * 100.0;

      if(m_paused)
      {
         error = "Trading paused by loss streak guard.";
         return false;
      }

      if(m_max_dd_percent > 0 && dd >= m_max_dd_percent)
      {
         error = "Trading paused by drawdown guard: " + DoubleToString(dd, 2) + "%";
         m_paused = true;
         return false;
      }
      return true;
   }

   void Resume()
   {
      m_loss_streak = 0;
      m_paused = false;
      m_equity_peak = AccountInfoDouble(ACCOUNT_EQUITY);
   }
};

class CSessionFilter
{
private:
   bool m_enabled;
   int  m_start_hour;
   int  m_end_hour;
   int  m_server_to_session_offset;

public:
   void Configure(const bool enabled, const int start_hour, const int end_hour,
                  const int server_to_session_offset)
   {
      m_enabled = enabled;
      m_start_hour = start_hour;
      m_end_hour = end_hour;
      m_server_to_session_offset = server_to_session_offset;
   }

   bool Allow() const
   {
      if(!m_enabled) return true;

      MqlDateTime dt;
      TimeToStruct(TimeCurrent() + m_server_to_session_offset * 3600, dt);
      int h = dt.hour;

      if(m_start_hour <= m_end_hour)
         return (h >= m_start_hour && h < m_end_hour);

      return (h >= m_start_hour || h < m_end_hour);
   }
};

#endif
