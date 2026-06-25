//+------------------------------------------------------------------+
//| MSNR Clean Edition - SignalCore.mqh                              |
//| 收藏内容：Layer bitmask + Signal + Cluster + Confluence Engine   |
//+------------------------------------------------------------------+
#property strict

#ifndef __MSNR_CLEAN_SIGNAL_CORE_MQH__
#define __MSNR_CLEAN_SIGNAL_CORE_MQH__

enum ENUM_SIGNAL_DIRECTION
{
   SIG_NONE = 0,
   SIG_BUY  = 1,
   SIG_SELL = -1
};

enum ENUM_SIGNAL_LAYER
{
   LAYER_SNR       = 0,
   LAYER_SWEEP     = 1,
   LAYER_ENGULFING = 2,
   LAYER_MSS_MISS  = 3,
   LAYER_TRENDLINE = 4,
   LAYER_QML       = 5,
   LAYER_CRT       = 6,
   LAYER_PD_ZONE   = 7,
   LAYER_HTF_BIAS  = 8,
   LAYER_DOL       = 9
};

int LayerBit(const ENUM_SIGNAL_LAYER layer)
{
   return (1 << (int)layer);
}

int CountBits(int mask)
{
   int n = 0;
   while(mask > 0)
   {
      if((mask & 1) == 1) n++;
      mask >>= 1;
   }
   return n;
}

string LayerCode(const ENUM_SIGNAL_LAYER layer)
{
   switch(layer)
   {
      case LAYER_SNR:       return "L1:SNR";
      case LAYER_SWEEP:     return "L2:Sweep";
      case LAYER_ENGULFING: return "L3:Engulf";
      case LAYER_MSS_MISS:  return "L4:MSS/MISS";
      case LAYER_TRENDLINE: return "L5:TL";
      case LAYER_QML:       return "L6:QML";
      case LAYER_CRT:       return "L7:CRT";
      case LAYER_PD_ZONE:   return "L8:PD";
      case LAYER_HTF_BIAS:  return "L9:HTF";
      case LAYER_DOL:       return "L10:DOL";
   }
   return "L?";
}

string MaskToText(int mask)
{
   string out = "";
   for(int i=0; i<=9; i++)
   {
      int bit = (1 << i);
      if((mask & bit) == bit)
      {
         if(out != "") out += "+";
         out += "L" + IntegerToString(i+1);
      }
   }
   return out;
}

struct SSignal
{
   ENUM_SIGNAL_DIRECTION dir;
   ENUM_SIGNAL_LAYER     layer;
   double                price;
   double                strength;
   string                reason;
};

struct SCluster
{
   ENUM_SIGNAL_DIRECTION dir;
   double                center_price;
   double                low;
   double                high;
   int                   mask;
   double                score;
   int                   count;
   string                reason;
};

SSignal EmptySignal()
{
   SSignal s;
   s.dir      = SIG_NONE;
   s.layer    = LAYER_SNR;
   s.price    = 0.0;
   s.strength = 0.0;
   s.reason   = "";
   return s;
}

SCluster EmptyCluster()
{
   SCluster c;
   c.dir          = SIG_NONE;
   c.center_price = 0.0;
   c.low          = 0.0;
   c.high         = 0.0;
   c.mask         = 0;
   c.score        = 0.0;
   c.count        = 0;
   c.reason       = "";
   return c;
}

bool SameCluster(const SCluster &c, const SSignal &s, const double zone_price)
{
   if(c.dir != s.dir) return false;
   return MathAbs(c.center_price - s.price) <= zone_price;
}

void AddSignalToCluster(SCluster &c, const SSignal &s)
{
   if(c.count == 0)
   {
      c.dir          = s.dir;
      c.center_price = s.price;
      c.low          = s.price;
      c.high         = s.price;
      c.mask         = LayerBit(s.layer);
      c.score        = s.strength;
      c.count        = 1;
      c.reason       = s.reason;
      return;
   }

   c.low  = MathMin(c.low, s.price);
   c.high = MathMax(c.high, s.price);
   c.center_price = (c.center_price * c.count + s.price) / (c.count + 1);
   c.mask  |= LayerBit(s.layer);
   c.score += s.strength;
   c.count++;
   if(s.reason != "") c.reason += " | " + s.reason;
}

class CConfluenceEngine
{
private:
   double m_cluster_zone;
   int    m_min_layers;
   double m_min_score;

public:
   void Configure(const double cluster_zone_price,
                  const int min_layers,
                  const double min_score)
   {
      m_cluster_zone = cluster_zone_price;
      m_min_layers   = min_layers;
      m_min_score    = min_score;
   }

   int BuildClusters(const SSignal &signals[], const int signal_count,
                     SCluster &clusters[])
   {
      ArrayResize(clusters, 0);

      for(int i=0; i<signal_count; i++)
      {
         if(signals[i].dir == SIG_NONE || signals[i].price <= 0.0)
            continue;

         bool merged = false;
         for(int j=0; j<ArraySize(clusters); j++)
         {
            if(SameCluster(clusters[j], signals[i], m_cluster_zone))
            {
               AddSignalToCluster(clusters[j], signals[i]);
               merged = true;
               break;
            }
         }

         if(!merged)
         {
            int n = ArraySize(clusters);
            ArrayResize(clusters, n+1);
            clusters[n] = EmptyCluster();
            AddSignalToCluster(clusters[n], signals[i]);
         }
      }

      return ArraySize(clusters);
   }

   bool IsTradableCluster(const SCluster &c) const
   {
      return (CountBits(c.mask) >= m_min_layers && c.score >= m_min_score);
   }
};

#endif
