//+------------------------------------------------------------------+
//|                                                   Index1MTF.mq5 |
//| Reads indicator values from bar index 1 (last closed bar).      |
//| Demonstrates stable, confirmed signal timing.                    |
//| Run on the same symbol, period and dates as Index0MTF.mq5.       |
//+------------------------------------------------------------------+
#property strict
#property description "Index 1 EA — reads from closed bar (correct)"

//--- Global variables
int      g_h_fast     = INVALID_HANDLE;
int      g_h_slow     = INVALID_HANDLE;
int      g_bar_count  = 0;
int      g_sig_count  = 0;
datetime g_last_bar   = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_h_fast = iMA(_Symbol,PERIOD_CURRENT,20,0,MODE_EMA,PRICE_CLOSE);
   g_h_slow = iMA(_Symbol,PERIOD_CURRENT,50,0,MODE_EMA,PRICE_CLOSE);

   if(g_h_fast == INVALID_HANDLE || g_h_slow == INVALID_HANDLE)
     {
      Print("Index1MTF: Handle creation failed.");
      return(INIT_FAILED);
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(g_h_fast);
   IndicatorRelease(g_h_slow);

   PrintFormat("Index1MTF: Complete. Bars: %d | Crossover signals: %d",
               g_bar_count,g_sig_count);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- New bar gate
   datetime current_bar = iTime(_Symbol,PERIOD_CURRENT,0);
   if(current_bar == g_last_bar)
     {
      return;
     }
   g_last_bar = current_bar;
   g_bar_count++;

   double fast_buf[1];
   double slow_buf[1];

//--- INDEX 1: reads from the last fully closed bar.
//--- Value is final and stable for the entire duration of the current bar.
   if(CopyBuffer(g_h_fast,0,1,1,fast_buf) < 1)
     {
      return;
     }
   if(CopyBuffer(g_h_slow,0,1,1,slow_buf) < 1)
     {
      return;
     }

   static double prev_fast = 0.0;
   static double prev_slow = 0.0;

   if(prev_fast != 0.0)
     {
      bool cross_up   = (prev_fast <= prev_slow && fast_buf[0] > slow_buf[0]);
      bool cross_down = (prev_fast >= prev_slow && fast_buf[0] < slow_buf[0]);

      if(cross_up || cross_down)
        {
         g_sig_count++;
         PrintFormat("Index1MTF: Signal #%d on bar %d | Fast=%.5f Slow=%.5f",
                     g_sig_count,g_bar_count,fast_buf[0],slow_buf[0]);
        }
     }

   prev_fast = fast_buf[0];
   prev_slow = slow_buf[0];
  }
//+------------------------------------------------------------------+