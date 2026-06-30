//+------------------------------------------------------------------+
//|                                             CImbalanceBars.mqh   |
//|  Tick direction classifier and imbalance bar constructor.        |
//|                                                                  |
//|  Purpose:                                                        |
//|    Constructs "information-driven" bars (imbalance bars) that    |
//|    close when the accumulated signed metric reaches a dynamic    |
//|    threshold. The threshold adapts online via exponential        |
//|    weighted moving averages (EWM) of the bar length and the      |
//|    absolute imbalance per bar, as described in de Prado (2018).  |
//|                                                                  |
//|  Dependencies:  CBarConstructor.mqh                              |
//|                                                                  |
//|  Classes:                                                        |
//|    CTickRule          –  Tick-direction classifier               |
//|    CImbalanceBar      –  Imbalance bar constructor               |
//|                                                                  |
//|  Usage:                                                          |
//|    After instantiation, call ProcessTick() for every incoming    |
//|    tick. When the bar is ready, the method returns true and      |
//|    fills the SBar structure. Use SaveState()/LoadState() to      |
//|    persist/restore the internal EWM state.                       |
//+------------------------------------------------------------------+
#include "CBarConstructor.mqh"

//+------------------------------------------------------------------+
//| Metric selector — shared by CImbalanceBar and CRunsBar           |
//+------------------------------------------------------------------+
enum ENUM_IMBALANCE_METRIC
  {
   IMBALANCE_TICK   = 0,  // Signed tick count:  +1/-1 per tick
   IMBALANCE_VOLUME = 1,  // Signed tick volume (volume * sign)
   IMBALANCE_DOLLAR = 2,  // Signed dollar volume (mid-price * volume * sign)
  };

//+------------------------------------------------------------------+
//| CTickRule — tick-direction classifier                            |
//|                                                                  |
//| Classifies price movement into +1 (up), -1 (down) or carries     |
//| forward the previous sign when the price is unchanged. This      |
//| matches the Python reference implementation’s b[0] = 1.0 start.  |
//|                                                                  |
//| The default state is +1, so a flat sequence is considered an     |
//| up-tick until the first directional move occurs.                 |
//+------------------------------------------------------------------+
class CTickRule
  {
private:
   double m_prev_price;      // Last seen price (bid)
   double m_prev_sign;       // Most recent direction (±1.0)

public:
                     CTickRule(void) : m_prev_price(0.0), m_prev_sign(1.0) {}

   //+----------------------------------------------------------------+
   //| Classify the next price. Returns +1.0 or -1.0.                 |
   //+----------------------------------------------------------------+
   double            Classify(const double price)
     {
      if(m_prev_price == 0.0)   // first tick – return default
        { m_prev_price = price; return m_prev_sign; }
      if(price > m_prev_price)        m_prev_sign =  1.0;
      else if(price < m_prev_price)   m_prev_sign = -1.0;
      // else unchanged → carry forward the existing sign
      m_prev_price = price;
      return m_prev_sign;
     }

   //--- Read-only accessors
   double            PrevPrice(void) const { return m_prev_price; }
   double            PrevSign (void) const { return m_prev_sign;  }

   //--- Write accessors (required for state restoration)
   void              SetPrevPrice(const double p) { m_prev_price = p; }
   void              SetPrevSign (const double s) { m_prev_sign  = s; }
  };

//+------------------------------------------------------------------+
//| CImbalanceBar                                                    |
//|                                                                  |
//| Constructs a bar that closes when |θ| ≥ E[T] · E[|imb|].         |
//| Both expectations are tracked via exponential weighted           |
//| averages and updated only at bar completion.                     |
//|                                                                  |
//| The constructor accepts initial guesses for the expected number  |
//| of ticks per bar (exp_ticks_init) and the expected absolute      |
//| imbalance per bar (exp_imbalance_init). These seeds avoid cold-  |
//| start instability.                                               |
//+------------------------------------------------------------------+
class CImbalanceBar : public CBarConstructor
  {
private:
   CTickRule            m_tick_rule;         // Price direction classifier
   ENUM_IMBALANCE_METRIC m_metric_type;      // Which metric to accumulate

   double               m_theta;             // Running signed imbalance
   double               m_ewm_T;             // EWM of bar length (ticks)
   double               m_ewm_abs_theta;     // EWM of |θ| at bar close
   double               m_exp_T;             // E[T]  – used as threshold factor
   double               m_exp_abs_imb;       // E[|imb|] – per-bar average abs imb
   double               m_ewm_alpha;         // Smoothing factor α = 2/(span+1)
   long                 m_bar_tick_count;    // Tick counter for current bar

   //+----------------------------------------------------------------+
   //| Compute the implicit contribution of a single tick.            |
   //+----------------------------------------------------------------+
   double               TickMetric(const MqlTick &tick, const double sign) const;

public:
                           CImbalanceBar(ENUM_IMBALANCE_METRIC metric_type,
                                         double exp_ticks_init,
                                         double exp_imbalance_init,
                                         int    ewm_span = 20);

   //--- Inherited interface
   virtual bool            ProcessTick(const MqlTick &tick,
                                       const long     tick_num,
                                       SBar          &out_bar) override;
   virtual bool            SaveState(const int file_handle) override;
   virtual bool            LoadState(const int file_handle) override;

   //--- Diagnostic accessors (for monitoring / logging)
   double                  CurrentTheta(void)     const { return m_theta;            }
   double                  CurrentThreshold(void) const
                              { return m_exp_T * m_exp_abs_imb; }
   double                  ExpT(void)             const { return m_exp_T;            }
   double                  ExpAbsImb(void)        const { return m_exp_abs_imb;      }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//|                                                                  |
//| Initializes the EWM accumulators using the user-supplied seeds.  |
//| The initial E[|imb|] is derived from the absolute seed, and      |
//| m_ewm_abs_theta is set to E[T]·E[|imb|] to keep the ratio        |
//| consistent from the start.                                       |
//+------------------------------------------------------------------+
CImbalanceBar::CImbalanceBar(ENUM_IMBALANCE_METRIC metric_type,
                             double exp_ticks_init,
                             double exp_imbalance_init,
                             int    ewm_span)
   : CBarConstructor(EnumToString(metric_type) == "IMBALANCE_TICK"   ? "tick_imbalance"
                   : EnumToString(metric_type) == "IMBALANCE_VOLUME" ? "volume_imbalance"
                                                                      : "dollar_imbalance"),
     m_metric_type(metric_type),
     m_theta(0.0),
     m_bar_tick_count(0)
  {
   m_ewm_alpha      = 2.0 / (ewm_span + 1);
   m_ewm_T          = MathMax(exp_ticks_init, 1.0);
   m_ewm_abs_theta  = MathMax(MathAbs(exp_imbalance_init), 1e-10) * m_ewm_T;
   m_exp_T          = m_ewm_T;
   m_exp_abs_imb    = MathMax(MathAbs(exp_imbalance_init), 1e-10);
  }

//+------------------------------------------------------------------+
//| TickMetric – convert a tick into its signed contribution.        |
//| Uses mid-price for dollar bars to reduce bid-ask bounce.         |
//+------------------------------------------------------------------+
double CImbalanceBar::TickMetric(const MqlTick &tick, const double sign) const
  {
   switch(m_metric_type)
     {
      case IMBALANCE_TICK:   return sign;
      case IMBALANCE_VOLUME: return sign * tick.volume;
      case IMBALANCE_DOLLAR:
        {
         double mid = (tick.bid + tick.ask) / 2.0;
         return sign * mid * tick.volume;
        }
      default:               return sign;
     }
  }

//+------------------------------------------------------------------+
//| ProcessTick – core bar construction logic.                       |
//|                                                                  |
//| 1. Updates OHLCV accumulator.                                    |
//| 2. Classifies tick direction and accumulates the signed metric.  |
//| 3. Checks if |θ| exceeds the dynamic threshold.                  |
//| 4. If yes: closes the bar, updates EWM expectations, and resets  |
//|    the internal accumulators for the next bar.                   |
//+------------------------------------------------------------------+
bool CImbalanceBar::ProcessTick(const MqlTick &tick,
                                const long     tick_num,
                                SBar          &out_bar)
  {
   if(!m_initialized)
     { SeedBar(tick, tick_num); return false; }

   UpdateAccumulator(tick, tick_num);
   m_bar_tick_count++;

   double sign   = m_tick_rule.Classify(tick.bid);
   m_theta      += TickMetric(tick, sign);

   if(MathAbs(m_theta) >= m_exp_T * m_exp_abs_imb)
     {
      FillBar(out_bar);

      double bar_len     = (double)m_bar_tick_count;
      double one_minus_a = 1.0 - m_ewm_alpha;

      //--- Update EWM of bar length and absolute imbalance
      m_ewm_T         = m_ewm_alpha * bar_len           + one_minus_a * m_ewm_T;
      m_ewm_abs_theta = m_ewm_alpha * MathAbs(m_theta)  + one_minus_a * m_ewm_abs_theta;

      //--- Propagate into the threshold factors
      m_exp_T       = m_ewm_T;
      m_exp_abs_imb = m_ewm_abs_theta / MathMax(m_exp_T, 1.0);

      //--- Reset for next bar
      m_theta          = 0.0;
      m_bar_tick_count = 0;

      SeedBar(tick, tick_num);
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//| SaveState – persist internal EWM and tick-rule state.            |
//+------------------------------------------------------------------+
bool CImbalanceBar::SaveState(const int fh)
  {
   if(!CBarConstructor::SaveState(fh)) return false;
   FileWriteDouble(fh, m_theta);
   FileWriteDouble(fh, m_ewm_T);
   FileWriteDouble(fh, m_ewm_abs_theta);
   FileWriteDouble(fh, m_exp_T);
   FileWriteDouble(fh, m_exp_abs_imb);
   FileWriteLong  (fh, m_bar_tick_count);
   FileWriteDouble(fh, m_tick_rule.PrevPrice());
   FileWriteDouble(fh, m_tick_rule.PrevSign());
   return true;
  }

//+------------------------------------------------------------------+
//| LoadState – restore internal EWM and tick-rule state.            |
//| Uses SetPrevPrice/SetPrevSign to correctly re-initialize the     |
//| tick classifier.                                                 |
//+------------------------------------------------------------------+
bool CImbalanceBar::LoadState(const int fh)
  {
   if(!CBarConstructor::LoadState(fh)) return false;
   m_theta          = FileReadDouble(fh);
   m_ewm_T          = FileReadDouble(fh);
   m_ewm_abs_theta  = FileReadDouble(fh);
   m_exp_T          = FileReadDouble(fh);
   m_exp_abs_imb    = FileReadDouble(fh);
   m_bar_tick_count = FileReadLong  (fh);
   m_tick_rule.SetPrevPrice(FileReadDouble(fh));
   m_tick_rule.SetPrevSign (FileReadDouble(fh));
   return true;
  }
//+------------------------------------------------------------------+