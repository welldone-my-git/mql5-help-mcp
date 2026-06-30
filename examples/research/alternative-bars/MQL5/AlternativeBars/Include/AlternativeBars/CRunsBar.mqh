//+------------------------------------------------------------------+
//|                                                     CRunsBar.mqh |
//|  Run bar constructor — tick, volume, and dollar variants.        |
//|  Derives from CBarConstructor; shares ENUM_IMBALANCE_METRIC and  |
//|  the updated CTickRule (with SetPrevPrice/SetPrevSign) from      |
//|  CImbalanceBars.mqh.                                             |
//|                                                                  |
//|  Runs bars sample when the sequence of buy or sell volumes       |
//|  (runs) exceeds dynamic expectations tracked via EWMA.           |
//+------------------------------------------------------------------+
#include "CImbalanceBars.mqh"

//+------------------------------------------------------------------+
//| Class CRunsBar                                                   |
//| Generates bars based on the occurrence of long runs of trades    |
//| happening on the same side (buy or sell).                        |
//+------------------------------------------------------------------+
class CRunsBar : public CBarConstructor
  {
private:
   CTickRule             m_tick_rule;        // Classifies ticks as buy (+1) or sell (-1)
   ENUM_IMBALANCE_METRIC m_metric_type;      // Defines whether we track ticks, volume, or dollars

   //--- Accumulators
   double                m_theta_buy;        // Cumulative metric for buy-side runs
   double                m_theta_sell;       // Cumulative metric for sell-side runs

   //--- EWM (Exponentially Weighted Moving Average) state
   double                m_ewm_T;            // EWMA of the number of ticks per bar
   double                m_ewm_run_buy;      // EWMA of the buy-side theta per bar
   double                m_ewm_run_sell;     // EWMA of the sell-side theta per bar
   double                m_exp_T;            // Current expectation of ticks per bar E[T]
   double                m_exp_buy;          // Current expectation of buy run proportions E[theta+/T]
   double                m_exp_sell;         // Current expectation of sell run proportions E[theta-/T]
   double                m_ewm_alpha;        // Smoothing/decay factor = 2 / (span + 1)
   long                  m_bar_tick_count;   // Counter for the total ticks in the current forming bar

   //--- Calculates the value of the current tick based on the chosen metric
   double                TickMetric(const MqlTick &tick, const double sign) const;

public:
   //--- Constructor setting initial estimates and EWM span
                         CRunsBar(ENUM_IMBALANCE_METRIC metric_type,
                                 double exp_ticks_init,
                                 double exp_run_buy_init,
                                 double exp_run_sell_init,
                                 int    ewm_span = 20);

   //--- Core tick processing logic. Returns true if a new bar was formed.
   virtual bool          ProcessTick(const MqlTick &tick,
                                     const long     tick_num,
                                     SBar          &out_bar) override;

   //--- State persistence for uninterrupted operation across restarts
   virtual bool          SaveState(const int file_handle) override;
   virtual bool          LoadState(const int file_handle) override;

   //--- Diagnostic accessors
   double                ThetaBuy(void)         const { return m_theta_buy;  }
   double                ThetaSell(void)        const { return m_theta_sell; }
   
   //--- Calculates the dynamic threshold that must be breached to form a bar
   double                CurrentThreshold(void) const
                           { return m_exp_T * MathMax(m_exp_buy, m_exp_sell); }
                           
   double                ExpT(void)             const { return m_exp_T;      }
   double                ExpBuy(void)           const { return m_exp_buy;    }
   double                ExpSell(void)          const { return m_exp_sell;   }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//| Initializes variables and sets up the base EWMA values ensuring  |
//| they do not start at zero to avoid division/threshold errors.    |
//+------------------------------------------------------------------+
CRunsBar::CRunsBar(ENUM_IMBALANCE_METRIC metric_type,
                 double exp_ticks_init,
                 double exp_run_buy_init,
                 double exp_run_sell_init,
                 int    ewm_span)
   : CBarConstructor(EnumToString(metric_type) == "IMBALANCE_TICK"   ? "tick_run"
                   : EnumToString(metric_type) == "IMBALANCE_VOLUME" ? "volume_run"
                                                                      : "dollar_run"),
     m_metric_type(metric_type),
     m_theta_buy(0.0),
     m_theta_sell(0.0),
     m_bar_tick_count(0)
  {
   // Compute standard EWMA alpha from the specified span
   m_ewm_alpha      = 2.0 / (ewm_span + 1);
   
   //--- Initialize expectations with minimum bounds
   m_ewm_T          = MathMax(exp_ticks_init, 1.0);
   m_ewm_run_buy    = MathMax(exp_run_buy_init,  1e-10) * m_ewm_T;
   m_ewm_run_sell   = MathMax(exp_run_sell_init, 1e-10) * m_ewm_T;
   
   m_exp_T          = m_ewm_T;
   m_exp_buy        = MathMax(exp_run_buy_init,  1e-10);
   m_exp_sell       = MathMax(exp_run_sell_init, 1e-10);
  }

//+------------------------------------------------------------------+
//| Signed metric for the current tick                               |
//| Returns the raw value that will be added to the run accumulators |
//| depending on whether we are forming Tick, Volume, or Dollar bar. |
//|                                                                  |
//| For dollar bars, mid-price ((bid+ask)/2) is used instead of bid  |
//| to obtain a fairer valuation and reduce the impact of bid-ask    |
//| bounce on run detection.                                         |
//+------------------------------------------------------------------+
double CRunsBar::TickMetric(const MqlTick &tick, const double sign) const
  {
   switch(m_metric_type)
     {
      case IMBALANCE_TICK:   return sign;                                      // +1 or -1
      case IMBALANCE_VOLUME: return sign * tick.volume;                        // Signed volume
      case IMBALANCE_DOLLAR:
        {
         double mid = (tick.bid + tick.ask) / 2.0;
         return sign * mid * tick.volume;                                      // Signed monetary value (mid‑price)
        }
      default:               return sign;
     }
  }

//+------------------------------------------------------------------+
//| ProcessTick — core bar construction loop                         |
//|                                                                  |
//| Boundary semantic matches Python _detect_run_boundaries():       |
//|   UpdateAccumulator() folds the boundary tick into the closing   |
//|   bar's OHLC; SeedBar() then starts a new bar at that same tick. |
//+------------------------------------------------------------------+
bool CRunsBar::ProcessTick(const MqlTick &tick,
                          const long     tick_num,
                          SBar          &out_bar)
  {
   //--- If this is the very first tick, initialize the bar and skip accumulation
   if(!m_initialized)
     { SeedBar(tick, tick_num); return false; }

   //--- Expand current bar's High/Low/Close and add tick volume
   UpdateAccumulator(tick, tick_num);
   m_bar_tick_count++;

   //--- Determine trade direction (+1 for buy, -1 for sell)
   double sign   = m_tick_rule.Classify(tick.bid);
   //--- Get the absolute run metric (ticks, volume, or dollars)
   double metric = TickMetric(tick, sign);

   //--- Route to buy or sell accumulator (>= 0 matches Python's "if v >= 0.0")
   //--- Notice that sell runs are accumulated as positive values (-metric when metric is negative)
   if(metric >= 0.0)
      m_theta_buy  += metric;
   else
      m_theta_sell += -metric;

   //--- Dynamic threshold: Expected Ticks * Max Expected Run Proportion
   double threshold = m_exp_T * MathMax(m_exp_buy, m_exp_sell);

   // Check if either buy run or sell run has exceeded the threshold
   if(MathMax(m_theta_buy, m_theta_sell) >= threshold)
     {
      //--- Finalize the bar data into the output structure
      FillBar(out_bar);

      //--- EWM update
      //--- Update our expectations based on the bar that just closed
      double bar_len     = (double)m_bar_tick_count;
      double one_minus_a = 1.0 - m_ewm_alpha;

      //--- Update EWMA for Ticks, Buy Run, and Sell Run
      m_ewm_T        = m_ewm_alpha * bar_len      + one_minus_a * m_ewm_T;
      m_ewm_run_buy  = m_ewm_alpha * m_theta_buy  + one_minus_a * m_ewm_run_buy;
      m_ewm_run_sell = m_ewm_alpha * m_theta_sell + one_minus_a * m_ewm_run_sell;

      //--- Re-calculate the expected values for the next bar
      m_exp_T    = m_ewm_T;
      m_exp_buy  = m_ewm_run_buy  / MathMax(m_exp_T, 1.0);
      m_exp_sell = m_ewm_run_sell / MathMax(m_exp_T, 1.0);

      //--- Reset for next bar
      //--- Clear accumulators for the new run
      m_theta_buy      = 0.0;
      m_theta_sell     = 0.0;
      m_bar_tick_count = 0;

      //--- The tick that triggered the bar closure is also the seed for the new bar
      SeedBar(tick, tick_num);
      return true; // Indicate a new bar has been minted
     }

   return false; // No bar minted yet
  }

//+------------------------------------------------------------------+
//| Persist full run-bar state                                       |
//| Used for saving the object's memory state to disk to survive     |
//| terminal restarts or data feeds drops.                           |
//+------------------------------------------------------------------+
bool CRunsBar::SaveState(const int fh)
  {
   if(!CBarConstructor::SaveState(fh)) return false;
   FileWriteDouble(fh, m_theta_buy);
   FileWriteDouble(fh, m_theta_sell);
   FileWriteDouble(fh, m_ewm_T);
   FileWriteDouble(fh, m_ewm_run_buy);
   FileWriteDouble(fh, m_ewm_run_sell);
   FileWriteDouble(fh, m_exp_T);
   FileWriteDouble(fh, m_exp_buy);
   FileWriteDouble(fh, m_exp_sell);
   FileWriteLong  (fh, m_bar_tick_count);
   FileWriteDouble(fh, m_tick_rule.PrevPrice());
   FileWriteDouble(fh, m_tick_rule.PrevSign());
   return true;
  }

//+------------------------------------------------------------------+
//| Restore full run-bar state                                       |
//| Used for resuming the EWMA and accumulators from disk.           |
//+------------------------------------------------------------------+
bool CRunsBar::LoadState(const int fh)
  {
   if(!CBarConstructor::LoadState(fh)) return false;
   m_theta_buy      = FileReadDouble(fh);
   m_theta_sell     = FileReadDouble(fh);
   m_ewm_T          = FileReadDouble(fh);
   m_ewm_run_buy    = FileReadDouble(fh);
   m_ewm_run_sell   = FileReadDouble(fh);
   m_exp_T          = FileReadDouble(fh);
   m_exp_buy        = FileReadDouble(fh);
   m_exp_sell       = FileReadDouble(fh);
   m_bar_tick_count = FileReadLong  (fh);
   m_tick_rule.SetPrevPrice(FileReadDouble(fh));
   m_tick_rule.SetPrevSign (FileReadDouble(fh));
   return true;
  }
//+------------------------------------------------------------------+