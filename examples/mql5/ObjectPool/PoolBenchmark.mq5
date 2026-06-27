//+------------------------------------------------------------------+
//|                                                PoolBenchmark.mq5 |
//| Custom indicator: dual-path benchmark measuring per-tick         |
//| execution time difference between heap-allocated and             |
//| pool-acquired CSignalEvent objects.                              |
//|                                                                  |
//| Buffer 0: Unpooled path microsecond timing per tick              |
//| Buffer 1: Pooled path microsecond timing per tick                |
//| Buffer 2: Running average ratio (unpooled / pooled)              |
//|                                                                  |
//| Requires: SignalEvent.mqh and ObjectPool.mqh                     |
//+------------------------------------------------------------------+
#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   3

#property indicator_label1  "Unpooled Time (us)"
#property indicator_type1   DRAW_SECTION
#property indicator_color1  clrCrimson
#property indicator_width1  1

#property indicator_label2  "Pooled Time (us)"
#property indicator_type2   DRAW_SECTION
#property indicator_color2  clrDodgerBlue
#property indicator_width2  1

#property indicator_label3  "Overhead Ratio"
#property indicator_type3   DRAW_SECTION
#property indicator_color3  clrDarkOrange
#property indicator_width3  1

#include <Generic_Object_Pool_in_MQL5/SignalEvent.mqh>
#include <Generic_Object_Pool_in_MQL5/ObjectPool.mqh>

//--- Input parameters
input int   inp_pool_capacity   = 64;    // Pre-Allocated Pool Capacity (Objects)
input int   inp_log_interval    = 500;   // Journal Log Interval (Ticks)
input int   inp_iterations      = 10;    // Allocation Iterations Per Timing Sample

//--- Indicator buffers
//--- NOTE: Do NOT call ArraySetAsSeries() on INDICATOR_DATA buffers.
//--- The terminal manages their indexing internally. Calling ArraySetAsSeries
//--- on them desyncs the buffer from the chart engine and causes blank plots.
double      g_unpooled_buffer[];
double      g_pooled_buffer[];
double      g_ratio_buffer[];

//--- Pool instance
CObjectPool<CSignalEvent> *g_pool = NULL;

//--- Telemetry accumulators
long        g_total_unpooled_us = 0;
long        g_total_pooled_us   = 0;
long        g_sample_count      = 0;
long        g_tick_count        = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit(void)
  {
//--- Validate input parameter boundaries
   if(inp_pool_capacity <= 0)
     {
      Print("[PoolBenchmark] Configuration error: pool capacity must be greater than zero.");
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(inp_iterations <= 0)
     {
      Print("[PoolBenchmark] Configuration error: iterations must be greater than zero.");
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(inp_pool_capacity < inp_iterations)
     {
      PrintFormat("[PoolBenchmark] Warning: pool capacity (%d) is less than iterations (%d). "
                  "Set capacity >= iterations for a fair comparison.",
                  inp_pool_capacity, inp_iterations);
     }

//--- Bind buffers to indicator slots
   SetIndexBuffer(0, g_unpooled_buffer, INDICATOR_DATA);
   SetIndexBuffer(1, g_pooled_buffer,   INDICATOR_DATA);
   SetIndexBuffer(2, g_ratio_buffer,    INDICATOR_DATA);

//--- Use EMPTY_VALUE (DBL_MAX) as the sentinel, NOT 0.0.
//--- Setting PLOT_EMPTY_VALUE to 0.0 caused the chart engine to treat every
//--- zero-valued measurement as "no data" and skip drawing it entirely,
//--- resulting in a permanently blank subwindow.
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);

//--- Initialize all buffer slots to EMPTY_VALUE so history is blank
   ArrayInitialize(g_unpooled_buffer, EMPTY_VALUE);
   ArrayInitialize(g_pooled_buffer,   EMPTY_VALUE);
   ArrayInitialize(g_ratio_buffer,    EMPTY_VALUE);

//--- Allocate pool
   g_pool = new CObjectPool<CSignalEvent>(inp_pool_capacity);
   if(CheckPointer(g_pool) != POINTER_DYNAMIC)
     {
      Print("[PoolBenchmark] Failed to allocate CObjectPool.");
      return(INIT_FAILED);
     }

   PrintFormat("[PoolBenchmark] Initialized. Pool capacity: %d | Iterations: %d",
               inp_pool_capacity,
               inp_iterations);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_pool) == POINTER_DYNAMIC)
     {
      if(g_sample_count > 0)
        {
         double avg_unpooled = g_total_unpooled_us / (double)g_sample_count;
         double avg_pooled   = g_total_pooled_us   / (double)g_sample_count;
         double avg_ratio    = (avg_pooled > 0.0) ? avg_unpooled / avg_pooled : 0.0;

         PrintFormat("[PoolBenchmark] Session summary over %s samples:",
                     IntegerToString(g_sample_count));
         PrintFormat("  Avg unpooled: %.2f us | Avg pooled: %.2f us | Avg ratio: %.3f",
                     avg_unpooled, avg_pooled, avg_ratio);
         PrintFormat("  Final pool utilization: %.1f%%",
                     g_pool.Utilization());
        }

      delete g_pool;
      g_pool = NULL;
     }

   PrintFormat("[PoolBenchmark] Deinitialized. Reason code: %d.", reason);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(CheckPointer(g_pool) != POINTER_DYNAMIC)
      return(prev_calculated);

   if(rates_total < 1)
      return(0);

//--- On first pass, leave history blank (EMPTY_VALUE already set in OnInit)
//--- and tell the engine only the current bar needs live calculation.
   if(prev_calculated == 0)
      return(rates_total - 1);

   g_tick_count++;

//--- Current bar is always index rates_total-1 in non-series buffers.
//--- Do NOT use ArraySetAsSeries; use this formula instead.
   int bar = rates_total - 1;

//+---------------------------------------------------------------+
//| PATH 1: Heap-allocated path                                   |
//+---------------------------------------------------------------+
   long t_start_unpooled = GetMicrosecondCount();

   for(int i = 0; i < inp_iterations; i++)
     {
      CSignalEvent *ev = new CSignalEvent();
      ev.SetDirection((close[bar] > open[bar]) ? 1 : -1);
      ev.SetPrice(close[bar]);
      ev.SetStrength(MathAbs(close[bar] - open[bar]) / _Point);
      ev.SetTimestamp(time[bar]);

      int      dir   = ev.GetDirection();
      double   price = ev.GetPrice();
      double   str   = ev.GetStrength();
      datetime ts    = ev.GetTimestamp();

      delete ev;
     }

   long elapsed_unpooled = GetMicrosecondCount() - t_start_unpooled;

   if(elapsed_unpooled < 0 || elapsed_unpooled > 1000000)
      return(rates_total);

//+---------------------------------------------------------------+
//| PATH 2: Pool-allocated path                                   |
//+---------------------------------------------------------------+
   long t_start_pooled = GetMicrosecondCount();

   for(int i = 0; i < inp_iterations; i++)
     {
      CSignalEvent *ev = g_pool.Acquire();
      if(ev == NULL)
         continue;

      ev.SetDirection((close[bar] > open[bar]) ? 1 : -1);
      ev.SetPrice(close[bar]);
      ev.SetStrength(MathAbs(close[bar] - open[bar]) / _Point);
      ev.SetTimestamp(time[bar]);

      int      dir   = ev.GetDirection();
      double   price = ev.GetPrice();
      double   str   = ev.GetStrength();
      datetime ts    = ev.GetTimestamp();

      g_pool.Release(ev);
     }

   long elapsed_pooled = GetMicrosecondCount() - t_start_pooled;

   if(elapsed_pooled < 0 || elapsed_pooled > 1000000)
      return(rates_total);

//--- Write to buffers
   g_unpooled_buffer[bar] = (double)elapsed_unpooled;
   g_pooled_buffer[bar]   = (double)elapsed_pooled;
   g_ratio_buffer[bar]    = (elapsed_pooled > 0)
                            ? (double)elapsed_unpooled / (double)elapsed_pooled
                            : 0.0;

   g_total_unpooled_us += elapsed_unpooled;
   g_total_pooled_us   += elapsed_pooled;
   g_sample_count++;

//--- Periodic journal log
   if(g_tick_count % inp_log_interval == 0)
     {
      double avg_unpooled = g_total_unpooled_us / (double)g_sample_count;
      double avg_pooled   = g_total_pooled_us   / (double)g_sample_count;
      double avg_ratio    = (avg_pooled > 0.0) ? avg_unpooled / avg_pooled : 0.0;

      PrintFormat("[PoolBenchmark] Tick %d | Unpooled: %d us | Pooled: %d us | "
                  "Ratio: %.3f | Pool free: %d/%d",
                  g_tick_count, elapsed_unpooled, elapsed_pooled,
                  g_ratio_buffer[bar],
                  g_pool.FreeCount(), g_pool.Capacity());

      PrintFormat("[PoolBenchmark] Session avg | Unpooled: %.2f us | Pooled: %.2f us | Ratio: %.3f",
                  avg_unpooled, avg_pooled, avg_ratio);
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+