//+------------------------------------------------------------------+
//|                                                  RQA_Example.mq5 |
//|              Script: demonstrates RQA Library usage              |
//+------------------------------------------------------------------+
#property script_show_inputs

#include <RQA\RQA.mqh>

input int    InpBars    = 100;    // Number of bars to analyze
input int    InpEmbDim  = 2;      // Embedding dimension
input int    InpDelay   = 1;      // Time delay
input double InpEpsilon = 0.0;    // Epsilon (0 = auto)

//+------------------------------------------------------------------+
//| OnStart — demonstrate full and windowed RQA on close prices      |
//+------------------------------------------------------------------+
void OnStart()
  {
   //--- 1. Get close prices
   double close[];
   int    copied = CopyClose(_Symbol, _Period, 0, InpBars, close);
   if(copied < InpBars)
     {
      Print("Not enough bars: got ", copied);
      return;
     }

   //--- 2. Create CRQA object and configure
   CRQA rqa;
   rqa.SetEmbedding(InpEmbDim, InpDelay);
   rqa.SetNorm(RQA_NORM_EUCLIDEAN);
   rqa.SetMinDiagLine(2);
   rqa.SetMinVertLine(2);

   if(InpEpsilon > 0.0)
      rqa.SetEpsilon(InpEpsilon);
   else
      rqa.SetEpsilonAuto(EPSILON_RR_TARGET, 0.05); // target 5% RR

   //--- 3. Compute
   if(!rqa.Compute(close, copied))
     {
      Print("RQA computation failed");
      return;
     }

   //--- 4. Print results
   rqa.PrintSummary();

   //--- 5. Use individual metrics
   double det = rqa.DET();
   double lam = rqa.LAM();

   if(det > 0.9 && lam > 0.9)
      Print("Market is highly deterministic & laminar (possible trend)");
   else if(det < 0.3)
      Print("Market is chaotic / low structure");
   else
      Print("Market is in transition zone");

   //--- 6. Windowed analysis example
   Print("\n--- Rolling Window RQA (window=30, step=5) ---");
   CRQAWindow win;
   win.SetWindow(30, 5);
   win.SetEmbedding(InpEmbDim, InpDelay);
   win.SetEpsilon(rqa.Epsilon()); // reuse computed epsilon

   SRQAWindowResult results[];
   if(win.Run(close, copied, results))
     {
      double rrSeries[], detSeries[];
      CRQAWindow::ExtractRR(results, rrSeries);
      CRQAWindow::ExtractDET(results, detSeries);

      int n = ArraySize(results);
      PrintFormat("Windows computed: %d", n);
      if(n >= 2)
        {
         PrintFormat("First window — RR=%.4f DET=%.4f",
                     rrSeries[0], detSeries[0]);
         PrintFormat("Last  window — RR=%.4f DET=%.4f",
                     rrSeries[n-1], detSeries[n-1]);
        }
     }
  }
