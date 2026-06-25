//+------------------------------------------------------------------+
//| MSNR Clean Edition - Single File 收藏版                          |
//| 说明：这是从 MSNR 大型 EA 中抽出的可复用思想骨架。                |
//| 保留：Layer、Mask、Cluster、Risk、Session、Logger、Dashboard。    |
//| 删除：Whitelist Hell、大量过拟合 input、具体交易补丁逻辑。        |
//+------------------------------------------------------------------+
#property strict
#property version "1.00"

#include <Trade/Trade.mqh>

// ========================= Signal Core =============================
enum ENUM_SIGNAL_DIRECTION { SIG_NONE=0, SIG_BUY=1, SIG_SELL=-1 };
enum ENUM_SIGNAL_LAYER
{
   LAYER_SNR=0, LAYER_SWEEP=1, LAYER_ENGULFING=2, LAYER_MSS_MISS=3,
   LAYER_TRENDLINE=4, LAYER_QML=5, LAYER_CRT=6, LAYER_PD_ZONE=7,
   LAYER_HTF_BIAS=8, LAYER_DOL=9
};

int LayerBit(const ENUM_SIGNAL_LAYER layer){ return (1 << (int)layer); }
int CountBits(int mask){ int n=0; while(mask>0){ if((mask&1)==1)n++; mask>>=1; } return n; }
string MaskToText(int mask)
{
   string out="";
   for(int i=0;i<=9;i++) if((mask & (1<<i)) == (1<<i))
   { if(out!="") out+="+"; out += "L"+IntegerToString(i+1); }
   return out;
}

struct SSignal
{
   ENUM_SIGNAL_DIRECTION dir;
   ENUM_SIGNAL_LAYER layer;
   double price;
   double strength;
   string reason;
};

struct SCluster
{
   ENUM_SIGNAL_DIRECTION dir;
   double center_price, low, high;
   int mask;
   double score;
   int count;
   string reason;
};

SSignal EmptySignal(){ SSignal s; s.dir=SIG_NONE; s.layer=LAYER_SNR; s.price=0; s.strength=0; s.reason=""; return s; }
SCluster EmptyCluster(){ SCluster c; c.dir=SIG_NONE; c.center_price=0; c.low=0; c.high=0; c.mask=0; c.score=0; c.count=0; c.reason=""; return c; }

bool SameCluster(const SCluster &c,const SSignal &s,const double zone_price)
{ return (c.dir==s.dir && MathAbs(c.center_price-s.price)<=zone_price); }

void AddSignalToCluster(SCluster &c,const SSignal &s)
{
   if(c.count==0)
   {
      c.dir=s.dir; c.center_price=s.price; c.low=s.price; c.high=s.price;
      c.mask=LayerBit(s.layer); c.score=s.strength; c.count=1; c.reason=s.reason; return;
   }
   c.low=MathMin(c.low,s.price); c.high=MathMax(c.high,s.price);
   c.center_price=(c.center_price*c.count+s.price)/(c.count+1);
   c.mask |= LayerBit(s.layer); c.score += s.strength; c.count++;
   if(s.reason!="") c.reason += " | "+s.reason;
}

class CConfluenceEngine
{
private:
   double m_cluster_zone; int m_min_layers; double m_min_score;
public:
   void Configure(double zone,int min_layers,double min_score){ m_cluster_zone=zone; m_min_layers=min_layers; m_min_score=min_score; }
   int BuildClusters(const SSignal &signals[],const int signal_count,SCluster &clusters[])
   {
      ArrayResize(clusters,0);
      for(int i=0;i<signal_count;i++)
      {
         if(signals[i].dir==SIG_NONE || signals[i].price<=0) continue;
         bool merged=false;
         for(int j=0;j<ArraySize(clusters);j++)
            if(SameCluster(clusters[j],signals[i],m_cluster_zone))
            { AddSignalToCluster(clusters[j],signals[i]); merged=true; break; }
         if(!merged){ int n=ArraySize(clusters); ArrayResize(clusters,n+1); clusters[n]=EmptyCluster(); AddSignalToCluster(clusters[n],signals[i]); }
      }
      return ArraySize(clusters);
   }
   bool IsTradableCluster(const SCluster &c) const { return CountBits(c.mask)>=m_min_layers && c.score>=m_min_score; }
};

// =========================== Risk Core =============================
class CSpreadFilter
{
private: double m_max_spread_points;
public:
   void Configure(double max_spread_points){ m_max_spread_points=max_spread_points; }
   bool Allow(string symbol,string &error) const
   {
      MqlTick tick; if(!SymbolInfoTick(symbol,tick)){ error="No tick"; return false; }
      double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      double spread=(tick.ask-tick.bid)/point;
      if(m_max_spread_points>0 && spread>m_max_spread_points){ error="Spread too high"; return false; }
      return true;
   }
};

class CLotSizer
{
public:
   double NormalizeVolume(string symbol,double volume) const
   {
      double min_lot=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
      double max_lot=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
      double step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
      volume=MathMax(min_lot,MathMin(max_lot,volume));
      volume=MathFloor(volume/step)*step;
      return NormalizeDouble(volume,2);
   }
   double RiskPercentLot(string symbol,double risk_percent,double entry,double sl,double max_lot=0.0) const
   {
      double risk_money=AccountInfoDouble(ACCOUNT_BALANCE)*risk_percent/100.0;
      double tick_size=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
      double tick_value=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);
      double dist=MathAbs(entry-sl);
      if(risk_money<=0 || tick_size<=0 || tick_value<=0 || dist<=0) return 0;
      double lot=risk_money/(dist/tick_size*tick_value);
      if(max_lot>0) lot=MathMin(lot,max_lot);
      return NormalizeVolume(symbol,lot);
   }
};

class CSessionFilter
{
private: bool m_enabled; int m_start,m_end,m_offset;
public:
   void Configure(bool enabled,int start,int end,int offset){ m_enabled=enabled; m_start=start; m_end=end; m_offset=offset; }
   bool Allow() const
   {
      if(!m_enabled) return true;
      MqlDateTime dt; TimeToStruct(TimeCurrent()+m_offset*3600,dt); int h=dt.hour;
      if(m_start<=m_end) return h>=m_start && h<m_end;
      return h>=m_start || h<m_end;
   }
};

// ========================= Logger Core =============================
class CCSVLoggerClean
{
private: string m_file;
public:
   void Configure(string file_name){ m_file=file_name; }
   void AppendCluster(string symbol,const SCluster &c)
   {
      int h=FileOpen(m_file,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON,','); if(h==INVALID_HANDLE) return;
      if(FileSize(h)==0) FileWrite(h,"time","symbol","dir","price","layers","score","count","reason");
      FileSeek(h,0,SEEK_END);
      FileWrite(h,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),symbol,(c.dir==SIG_BUY?"BUY":"SELL"),DoubleToString(c.center_price,_Digits),MaskToText(c.mask),DoubleToString(c.score,2),c.count,c.reason);
      FileClose(h);
   }
};

// ====================== Example Collector EA =======================
input string InpSymbol="";
input double InpMaxSpreadPts=350;
input double InpClusterZone=0.50;
input int    InpMinLayers=2;
input double InpMinScore=2.0;
input bool   InpUseSession=false;
input int    InpSessionStart=6;
input int    InpSessionEnd=23;
input int    InpOffsetHours=0;

CConfluenceEngine g_engine;
CSpreadFilter g_spread;
CSessionFilter g_session;
CCSVLoggerClean g_logger;

string TradeSymbol(){ return InpSymbol=="" ? _Symbol : InpSymbol; }

int CollectSignals(SSignal &signals[])
{
   ArrayResize(signals,0);
   MqlTick tick; if(!SymbolInfoTick(TradeSymbol(),tick)) return 0;
   int n=ArraySize(signals); ArrayResize(signals,n+1); signals[n]=EmptySignal(); signals[n].dir=SIG_BUY; signals[n].layer=LAYER_SNR; signals[n].price=tick.bid; signals[n].strength=1.0; signals[n].reason="Example SNR";
   n=ArraySize(signals); ArrayResize(signals,n+1); signals[n]=EmptySignal(); signals[n].dir=SIG_BUY; signals[n].layer=LAYER_SWEEP; signals[n].price=tick.bid+0.10; signals[n].strength=1.0; signals[n].reason="Example Sweep";
   return ArraySize(signals);
}

int OnInit()
{
   g_engine.Configure(InpClusterZone,InpMinLayers,InpMinScore);
   g_spread.Configure(InpMaxSpreadPts);
   g_session.Configure(InpUseSession,InpSessionStart,InpSessionEnd,InpOffsetHours);
   g_logger.Configure("MSNR_Clean_Clusters.csv");
   return INIT_SUCCEEDED;
}

void OnTick()
{
   string error; if(!g_session.Allow()) return; if(!g_spread.Allow(TradeSymbol(),error)) return;
   SSignal signals[]; int n=CollectSignals(signals);
   SCluster clusters[]; int c=g_engine.BuildClusters(signals,n,clusters);
   for(int i=0;i<c;i++) if(g_engine.IsTradableCluster(clusters[i])) g_logger.AppendCluster(TradeSymbol(),clusters[i]);
}
