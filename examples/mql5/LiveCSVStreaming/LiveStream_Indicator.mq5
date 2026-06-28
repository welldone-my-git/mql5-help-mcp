//+------------------------------------------------------------------+
//|                                         LiveStream_Indicator.mq5 |
//|        Live streaming indicator using LiveCSVStreamer.mqh        |
//+------------------------------------------------------------------+

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot attributes
#property indicator_label1  "Filter"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2

//--- Include dependencies
#include <CSV_Data_Analysis_Part_5/LiveCSVStreamer.mqh>

//--- Indicator input parameters
input int InpFilterPeriod = 14; // EMA lookback period

//--- Indicator buffer allocation
double g_filter_buf[];

//--- Signal quality metrics trackers
int      g_current_slope   = 0;
int      g_false_flips     = 0;
long     g_sum_lag_bars    = 0;
int      g_slope_changes   = 0;
int      g_bars_since_flip = 0;

//--- Native handles and tracking metrics
int      g_ema_handle        = INVALID_HANDLE;
double   g_last_filter_value = 0.0;
datetime g_last_bar_time     = 0;
bool     g_live_confirmed    = false;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Bind linear output buffer mappings
   SetIndexBuffer(0, g_filter_buf, INDICATOR_DATA);
   ArraySetAsSeries(g_filter_buf, true);

//--- Instantiate exponential moving average system handler
   g_ema_handle = iMA(_Symbol, _Period, InpFilterPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(g_ema_handle == INVALID_HANDLE)
      return(INIT_FAILED);

//--- Parse cleanly formatted period label strings for path targets
   string tf_str = EnumToString(_Period);
   StringReplace(tf_str, "PERIOD_", "");
   InitStreamer(_Symbol, tf_str);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Flush underlying in-memory streamer segments down to file layers
   ShutdownStreamer();

   if(g_ema_handle != INVALID_HANDLE)
      IndicatorRelease(g_ema_handle);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int      rates_total,
                const int      prev_calculated,
                const datetime &time[],
                const double   &open[],
                const double   &high[],
                const double   &low[],
                const double   &close[],
                const long     &tick_volume[],
                const long     &volume[],
                const int      &spread[])
  {
//--- Verify minimum operational lookback threshold bounds
   if(rates_total < InpFilterPeriod + 2)
      return(0);

//--- Explicitly set system array indexing as reverse chronological series
   ArraySetAsSeries(time,        true);
   ArraySetAsSeries(open,        true);
   ArraySetAsSeries(high,        true);
   ArraySetAsSeries(low,         true);
   ArraySetAsSeries(close,       true);
   ArraySetAsSeries(tick_volume, true);

//--- Pull indicator array segments out of internal buffer registers
   double ema_vals[3];
   if(CopyBuffer(g_ema_handle, 0, 0, 3, ema_vals) < 3)
      return(prev_calculated);

   g_filter_buf[0]     = ema_vals[2];
   g_last_filter_value = ema_vals[2];

//--- Skip computational routines during historical parsing iterations
   if(prev_calculated == 0)
      return(rates_total);

//--- Tick-level streaming (if enabled)
   if(InpStreamTicks)
     {
      SLiveTickRecord tick_rec;
      tick_rec.tick_time     = TimeCurrent();
      tick_rec.symbol        = _Symbol;
      tick_rec.bid           = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      tick_rec.ask           = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      tick_rec.spread_points = (tick_rec.ask - tick_rec.bid) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      tick_rec.filter_value  = g_last_filter_value;
      StreamTickRecord(tick_rec);
     }

//--- Bar-level logic: execute only once per newly closed bar.
//--- time[0] is the current forming bar; a change in time[0]
//--- means a new bar has opened and time[1] just closed.
   datetime current_bar_time = time[0];
   if(current_bar_time <= g_last_bar_time)
      return(rates_total);

   g_last_bar_time = current_bar_time;

//--- Confirm the first live bar close in the Experts log
   if(!g_live_confirmed)
     {
      PrintFormat("[LiveCSVStreamer] First live bar close detected: %s",
                  TimeToString(time[1], TIME_DATE | TIME_MINUTES));
      g_live_confirmed = true;
     }

//--- Slope detection and signal quality accumulation
   int new_slope = (ema_vals[2] > ema_vals[1]) ?  1
                   : (ema_vals[2] < ema_vals[1]) ? -1
                   : 0;

   g_bars_since_flip++;

//--- Accumulate metrics testing noise versus meaningful momentum swings
   if(new_slope != 0 && new_slope != g_current_slope && g_current_slope != 0)
     {
      g_slope_changes++;
      g_sum_lag_bars += g_bars_since_flip;

      if(g_bars_since_flip <= 3)
         g_false_flips++;

      g_bars_since_flip = 0;
     }

   g_current_slope = (new_slope != 0) ? new_slope : g_current_slope;

//--- Populate and stream the bar-close record (time[1] = last closed bar)
   SLiveBarRecord bar_rec;
   bar_rec.bar_time = time[1];
   bar_rec.symbol   = _Symbol;

   string tf_str = EnumToString(_Period);
   StringReplace(tf_str, "PERIOD_", "");
   bar_rec.timeframe = tf_str;

   bar_rec.open           = open[1];
   bar_rec.high           = high[1];
   bar_rec.low            = low[1];
   bar_rec.close          = close[1];
   bar_rec.volume         = (double)tick_volume[1];
   bar_rec.filter_value   = ema_vals[1];
   bar_rec.filter_slope   = g_current_slope;
   bar_rec.false_flips    = g_false_flips;
   bar_rec.avg_lag_bars   = (g_slope_changes > 0) ? (double)g_sum_lag_bars / g_slope_changes : 0.0;
   bar_rec.session_equity = AccountInfoDouble(ACCOUNT_EQUITY);

   StreamBarRecord(bar_rec);

   return(rates_total);
  }
//+------------------------------------------------------------------+