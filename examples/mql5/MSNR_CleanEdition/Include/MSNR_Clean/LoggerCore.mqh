//+------------------------------------------------------------------+
//| MSNR Clean Edition - LoggerCore.mqh                              |
//| 收藏内容：CSV Logger 骨架                                        |
//+------------------------------------------------------------------+
#property strict

#ifndef __MSNR_CLEAN_LOGGER_CORE_MQH__
#define __MSNR_CLEAN_LOGGER_CORE_MQH__

#include "SignalCore.mqh"

class CCSVLoggerClean
{
private:
   string m_file_name;

public:
   void Configure(const string file_name)
   {
      m_file_name = file_name;
   }

   void AppendCluster(const string symbol, const SCluster &cluster)
   {
      int h = FileOpen(m_file_name, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON, ',');
      if(h == INVALID_HANDLE)
         return;

      if(FileSize(h) == 0)
         FileWrite(h, "time", "symbol", "dir", "price", "mask", "layers", "score", "count", "reason");

      FileSeek(h, 0, SEEK_END);
      FileWrite(h,
                TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
                symbol,
                (cluster.dir == SIG_BUY ? "BUY" : "SELL"),
                DoubleToString(cluster.center_price, _Digits),
                cluster.mask,
                MaskToText(cluster.mask),
                DoubleToString(cluster.score, 2),
                cluster.count,
                cluster.reason);

      FileClose(h);
   }
};

#endif
