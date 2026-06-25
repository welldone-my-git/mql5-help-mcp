//+------------------------------------------------------------------+
//| MSNR Clean Edition - TradeCore.mqh                               |
//| 收藏内容：TradeExecutor 骨架，建议后续接 Builder/Validator 分层   |
//+------------------------------------------------------------------+
#property strict

#ifndef __MSNR_CLEAN_TRADE_CORE_MQH__
#define __MSNR_CLEAN_TRADE_CORE_MQH__

#include <Trade/Trade.mqh>
#include "SignalCore.mqh"
#include "RiskCore.mqh"

class CTradeExecutorClean
{
private:
   CTrade        m_trade;
   CLotSizer     m_lot_sizer;

public:
   void Configure(const int magic, const int deviation_points)
   {
      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetDeviationInPoints(deviation_points);
   }

   bool PlaceClusterTrade(const string symbol,
                          const SCluster &cluster,
                          const double risk_percent,
                          const double sl,
                          const double tp,
                          const double fixed_lot,
                          const double max_lot,
                          string &error)
   {
      MqlTick tick;
      if(!SymbolInfoTick(symbol, tick))
      {
         error = "No tick.";
         return false;
      }

      double entry = (cluster.dir == SIG_BUY ? tick.ask : tick.bid);
      double lot = fixed_lot;
      if(lot <= 0.0)
         lot = m_lot_sizer.RiskPercentLot(symbol, risk_percent, entry, sl, max_lot);
      else
         lot = m_lot_sizer.NormalizeVolume(symbol, lot);

      if(lot <= 0.0)
      {
         error = "Invalid lot size.";
         return false;
      }

      string comment = "CleanCluster " + MaskToText(cluster.mask);
      bool ok = false;

      if(cluster.dir == SIG_BUY)
         ok = m_trade.Buy(lot, symbol, 0.0, sl, tp, comment);
      else if(cluster.dir == SIG_SELL)
         ok = m_trade.Sell(lot, symbol, 0.0, sl, tp, comment);
      else
      {
         error = "Invalid direction.";
         return false;
      }

      if(!ok)
      {
         error = "Trade failed. Retcode=" + IntegerToString(m_trade.ResultRetcode()) +
                 " " + m_trade.ResultRetcodeDescription();
         return false;
      }

      return true;
   }
};

#endif
