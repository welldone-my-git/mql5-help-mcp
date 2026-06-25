//+------------------------------------------------------------------+
//| MSNR Clean Collector                                             |
//| 用途：收藏版框架模板，不是原策略，不建议直接实盘                 |
//+------------------------------------------------------------------+
#property strict
#property version "1.00"

#include <MSNR_Clean/SignalCore.mqh>
#include <MSNR_Clean/RiskCore.mqh>
#include <MSNR_Clean/TradeCore.mqh>
#include <MSNR_Clean/LoggerCore.mqh>
#include <MSNR_Clean/DashboardCore.mqh>

input string InpSymbol       = "";
input double InpRiskPercent  = 1.0;
input double InpFixedLot     = 0.0;
input double InpMaxLot       = 0.01;
input int    InpMagic        = 26053102;
input int    InpDeviation    = 50;
input double InpMaxSpreadPts = 350;
input double InpClusterZone  = 0.50;
input int    InpMinLayers    = 2;
input double InpMinScore     = 2.0;
input bool   InpUseSession   = false;
input int    InpSessionStart = 6;
input int    InpSessionEnd   = 23;
input int    InpOffsetHours  = 0;

CConfluenceEngine g_engine;
CSpreadFilter     g_spread;
CSessionFilter    g_session;
CDrawdownGuard    g_guard;
CTradeExecutorClean g_executor;
CCSVLoggerClean   g_logger;
CDashboardClean   g_dashboard;

string TradeSymbol()
{
   return (InpSymbol == "" ? _Symbol : InpSymbol);
}

// 示例：这里用非常简单的占位信号，真实项目应替换为自己的 Detector。
int CollectSignals(SSignal &signals[])
{
   ArrayResize(signals, 0);

   string symbol = TradeSymbol();
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick)) return 0;

   // 示例信号1：价格在当前 bid 附近形成 SNR 层
   int n = ArraySize(signals);
   ArrayResize(signals, n+1);
   signals[n] = EmptySignal();
   signals[n].dir = SIG_BUY;
   signals[n].layer = LAYER_SNR;
   signals[n].price = tick.bid;
   signals[n].strength = 1.0;
   signals[n].reason = "Example SNR layer";

   // 示例信号2：Sweep 层，用于演示 confluence，不代表真实策略
   n = ArraySize(signals);
   ArrayResize(signals, n+1);
   signals[n] = EmptySignal();
   signals[n].dir = SIG_BUY;
   signals[n].layer = LAYER_SWEEP;
   signals[n].price = tick.bid + 0.10;
   signals[n].strength = 1.0;
   signals[n].reason = "Example sweep layer";

   return ArraySize(signals);
}

int OnInit()
{
   g_engine.Configure(InpClusterZone, InpMinLayers, InpMinScore);
   g_spread.Configure(InpMaxSpreadPts);
   g_session.Configure(InpUseSession, InpSessionStart, InpSessionEnd, InpOffsetHours);
   g_guard.Configure(5.0, 3);
   g_executor.Configure(InpMagic, InpDeviation);
   g_logger.Configure("MSNR_Clean_Clusters.csv");
   g_dashboard.Configure("MSNR_CLEAN", 14, 18);
   EventSetTimer(5);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   g_dashboard.Clear();
}

void OnTimer()
{
   g_dashboard.Text("title", "MSNR Clean Collector", 0, clrAqua);
   g_dashboard.Text("symbol", "Symbol: " + TradeSymbol(), 1);
   g_dashboard.Text("mode", "Mode: framework / study template", 2);
}

void OnTick()
{
   string error;
   string symbol = TradeSymbol();

   if(!g_session.Allow()) return;
   if(!g_spread.Allow(symbol, error)) return;
   if(!g_guard.Allow(error)) return;

   SSignal signals[];
   int signal_count = CollectSignals(signals);

   SCluster clusters[];
   int cluster_count = g_engine.BuildClusters(signals, signal_count, clusters);

   for(int i=0; i<cluster_count; i++)
   {
      if(!g_engine.IsTradableCluster(clusters[i]))
         continue;

      g_logger.AppendCluster(symbol, clusters[i]);

      // 收藏版默认不自动交易。真正使用时再打开并接入自己的 SL/TP 计算。
      // double sl = clusters[i].center_price - 1.0;
      // double tp = clusters[i].center_price + 5.0;
      // g_executor.PlaceClusterTrade(symbol, clusters[i], InpRiskPercent, sl, tp,
      //                              InpFixedLot, InpMaxLot, error);
   }
}
