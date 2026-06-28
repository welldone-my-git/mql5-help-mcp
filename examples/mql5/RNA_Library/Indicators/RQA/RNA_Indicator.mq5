//+------------------------------------------------------------------+
//|                                              RNA_Indicator.mq5   |
//|                   Recurrence Network Analysis Indicator          |
//|                                                                  |
//|  Plots rolling network metrics derived from the recurrence       |
//|  matrix treated as a complex-network adjacency matrix:           |
//|    ACC            — Average Clustering Coefficient               |
//|    Transitivity   — Global clustering (triangle ratio)           |
//|    NormAPL        — Avg Path Length normalized to [0,1]          |
//|    Assortativity  — Degree correlation at edge endpoints         |
//|    AvgBetweenness — Mean betweenness centrality (normalized)     |
//+------------------------------------------------------------------+
#property copyright   "Hammad Dilber"
#property version     "1.00"
#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   5

#property indicator_label1  "ACC"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2

#property indicator_label2  "Transitivity"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLimeGreen
#property indicator_width2  2

#property indicator_label3  "NormAPL"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrange
#property indicator_width3  2

#property indicator_label4  "Assortativity"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrViolet
#property indicator_width4  1

#property indicator_label5  "AvgBetweenness"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrRed
#property indicator_width5  1

#include <RQA\RQA.mqh>

//--- Input parameters
input int    InpWindowSize   = 50;                  // Rolling window size
input int    InpStep         = 1;                   // Step between windows
input int    InpEmbDim       = 1;                   // Embedding dimension
input int    InpDelay        = 1;                   // Time delay (tau)
input double InpEpsilon      = 0.0;                 // Epsilon (0 = auto)
input double InpEpsilonParam = 0.05;                // Auto-epsilon param
input ENUM_EPSILON_METHOD InpEpsMethod = EPSILON_RR_TARGET; // Epsilon method
input ENUM_RQA_NORM InpNorm  = RQA_NORM_EUCLIDEAN;  // Distance norm

//--- Buffers
double BufferACC[];
double BufferTrans[];
double BufferNormAPL[];
double BufferAssort[];
double BufferBetween[];

//+------------------------------------------------------------------+
//| Initialize indicator buffers                                     |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferACC,     INDICATOR_DATA);
   SetIndexBuffer(1, BufferTrans,   INDICATOR_DATA);
   SetIndexBuffer(2, BufferNormAPL, INDICATOR_DATA);
   SetIndexBuffer(3, BufferAssort,  INDICATOR_DATA);
   SetIndexBuffer(4, BufferBetween, INDICATOR_DATA);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   IndicatorSetString(INDICATOR_SHORTNAME,
                      StringFormat("RNA(W=%d,m=%d,τ=%d)",
                                   InpWindowSize, InpEmbDim, InpDelay));

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Main calculation                                                 |
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
   if(rates_total < InpWindowSize + 10)
      return 0;

   if(prev_calculated == rates_total)
      return rates_total;

   //--- Determine computation range
   bool fullRecalc = (prev_calculated == 0);
   int  computeFrom;

   if(fullRecalc)
     {
      computeFrom = 0;
      ArrayInitialize(BufferACC,     EMPTY_VALUE);
      ArrayInitialize(BufferTrans,   EMPTY_VALUE);
      ArrayInitialize(BufferNormAPL, EMPTY_VALUE);
      ArrayInitialize(BufferAssort,  EMPTY_VALUE);
      ArrayInitialize(BufferBetween, EMPTY_VALUE);
     }
   else
      computeFrom = MathMax(0, prev_calculated - InpWindowSize);

   int computeLen = rates_total - computeFrom;
   if(computeLen < InpWindowSize)
      return rates_total;

   //--- Setup rolling window
   CRNAWindow win;
   win.SetWindow(InpWindowSize, InpStep);
   win.SetEmbedding(InpEmbDim, InpDelay);
   win.SetNorm(InpNorm);

   //--- Set epsilon
   if(InpEpsilon > 0.0)
      win.SetEpsilon(InpEpsilon);
   else
     {
      double fullSeries[];
      ArrayResize(fullSeries, rates_total);
      for(int i = 0; i < rates_total; i++)
         fullSeries[i] = close[i];
      double autoEps = CRQAEpsilon::Select(fullSeries, rates_total,
                                            InpEpsMethod, InpEpsilonParam);
      win.SetEpsilon(autoEps);
     }

   //--- Extract prices for computation range
   double prices[];
   ArrayResize(prices, computeLen);
   for(int i = 0; i < computeLen; i++)
      prices[i] = close[computeFrom + i];

   //--- Run rolling RNA
   SRNAWindowResult results[];
   if(!win.Run(prices, computeLen, results))
      return prev_calculated;

   //--- Normalization factor for APL: divide by (embeddedN - 1)
   int    embN       = InpWindowSize - (InpEmbDim - 1) * InpDelay;
   double normFactor = (embN > 1) ? 1.0 / (embN - 1) : 1.0;

   //--- Map results to chart bars
   int nRes = ArraySize(results);
   for(int k = 0; k < nRes; k++)
     {
      int bar = results[k].barIndex + computeFrom + InpWindowSize - 1;
      if(bar >= 0 && bar < rates_total)
        {
         BufferACC[bar]     = results[k].metrics.AvgClustering;
         BufferTrans[bar]   = results[k].metrics.Transitivity;
         BufferNormAPL[bar] = results[k].metrics.AvgPathLength * normFactor;
         BufferAssort[bar]  = results[k].metrics.Assortativity;
         BufferBetween[bar] = results[k].metrics.AvgBetweenness;
        }
     }

   return rates_total;
  }
