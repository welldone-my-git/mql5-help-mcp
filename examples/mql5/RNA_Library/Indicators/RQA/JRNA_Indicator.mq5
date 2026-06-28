//+------------------------------------------------------------------+
//|                                            JRNA_Indicator.mq5    |
//|              Joint Recurrence Network Analysis Indicator         |
//|                                                                  |
//|  Builds joint recurrence matrices from two symbols and computes  |
//|  network metrics on the resulting graph.  Shows how two markets' |
//|  shared dynamical structure organizes as a complex network.      |
//|                                                                  |
//|  Buffers: ACC, Transitivity, NormAPL, Assortativity,             |
//|           AvgBetweenness                                         |
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

enum ENUM_JRNA_NORMALIZE
  {
   JRNA_NORM_NONE    = 0,   // None (raw prices)
   JRNA_NORM_ZSCORE  = 1,   // Z-Score (recommended for cross-symbol)
   JRNA_NORM_RETURNS = 2    // Log Returns
  };

//--- Inputs
input string InpSymbolY      = "GBPUSD";            // Second symbol
input int    InpWindowSize   = 50;                  // Rolling window size
input int    InpStep         = 1;                   // Step between windows
input int    InpEmbDim       = 1;                   // Embedding dimension
input int    InpDelay        = 1;                   // Time delay (tau)
input double InpEpsilon      = 0.5;                 // Epsilon threshold (shared)
input ENUM_RQA_NORM InpNorm  = RQA_NORM_EUCLIDEAN;  // Distance norm
input ENUM_JRNA_NORMALIZE InpNormalize = JRNA_NORM_RETURNS; // Series normalization

//--- Buffers
double BufferACC[];
double BufferTrans[];
double BufferNormAPL[];
double BufferAssort[];
double BufferBetween[];

//--- Cached aligned data
double g_pricesX[];
double g_pricesY[];
int    g_barMap[];
int    g_validCount;
int    g_lastAligned;

//+------------------------------------------------------------------+
//| Initialize indicator buffers and validate second symbol          |
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
                      StringFormat("JRNA(%s & %s, W=%d)",
                                   _Symbol, InpSymbolY, InpWindowSize));

   g_validCount  = 0;
   g_lastAligned = 0;

   if(InpSymbolY != _Symbol)
     {
      bool selected = SymbolSelect(InpSymbolY, true);
      if(!selected)
        {
         PrintFormat("JRNA_Indicator: symbol %s not found", InpSymbolY);
         return INIT_FAILED;
        }
     }

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Bulk-align second symbol's close prices to chart bars            |
//+------------------------------------------------------------------+
bool AlignPrices(const datetime &timeX[], const double &closeX[],
                 int rates_total)
  {
   datetime timeY[];
   double   closeY[];

   int copiedT = CopyTime(InpSymbolY, _Period, 0, rates_total, timeY);
   if(copiedT <= 0)
      return false;
   int copiedC = CopyClose(InpSymbolY, _Period, 0, rates_total, closeY);
   if(copiedC != copiedT)
      return false;

   ArrayResize(g_pricesX, rates_total);
   ArrayResize(g_pricesY, rates_total);
   ArrayResize(g_barMap,  rates_total);

   int jj = 0;
   g_validCount = 0;
   for(int ix = 0; ix < rates_total; ix++)
     {
      while(jj < copiedT && timeY[jj] < timeX[ix])
         jj++;
      if(jj < copiedT && timeY[jj] == timeX[ix])
        {
         g_pricesX[g_validCount] = closeX[ix];
         g_pricesY[g_validCount] = closeY[jj];
         g_barMap[g_validCount]  = ix;
         g_validCount++;
        }
     }

   if(g_validCount > 0)
     {
      ArrayResize(g_pricesX, g_validCount);
      ArrayResize(g_pricesY, g_validCount);
      ArrayResize(g_barMap,  g_validCount);
     }

   g_lastAligned = rates_total;
   return g_validCount >= InpWindowSize;
  }

//+------------------------------------------------------------------+
//| Normalize array in-place: z-score                                |
//+------------------------------------------------------------------+
void NormalizeZScore(double &arr[], int len)
  {
   if(len < 2) return;
   double sum = 0, sumSq = 0;
   for(int i = 0; i < len; i++)
     { sum += arr[i]; sumSq += arr[i] * arr[i]; }
   double mean = sum / len;
   double var  = sumSq / len - mean * mean;
   double sd   = (var > 1e-20) ? MathSqrt(var) : 1.0;
   for(int i = 0; i < len; i++)
      arr[i] = (arr[i] - mean) / sd;
  }

//+------------------------------------------------------------------+
//| Convert to log returns in-place, shrinks array by 1              |
//+------------------------------------------------------------------+
int ToLogReturns(double &arr[], int len)
  {
   if(len < 2) return 0;
   for(int i = 0; i < len - 1; i++)
      arr[i] = (arr[i + 1] > 0 && arr[i] > 0)
               ? MathLog(arr[i + 1] / arr[i]) : 0.0;
   int newLen = len - 1;
   ArrayResize(arr, newLen);
   return newLen;
  }

//+------------------------------------------------------------------+
//| Apply normalization to aligned price arrays                      |
//+------------------------------------------------------------------+
void ApplyNormalization()
  {
   if(InpNormalize == JRNA_NORM_ZSCORE)
     {
      NormalizeZScore(g_pricesX, g_validCount);
      NormalizeZScore(g_pricesY, g_validCount);
     }
   else if(InpNormalize == JRNA_NORM_RETURNS)
     {
      int newLenX = ToLogReturns(g_pricesX, g_validCount);
      int newLenY = ToLogReturns(g_pricesY, g_validCount);
      for(int i = 0; i < newLenX; i++)
         g_barMap[i] = g_barMap[i + 1];
      g_validCount = MathMin(newLenX, newLenY);
      ArrayResize(g_pricesX, g_validCount);
      ArrayResize(g_pricesY, g_validCount);
      ArrayResize(g_barMap,  g_validCount);
      NormalizeZScore(g_pricesX, g_validCount);
      NormalizeZScore(g_pricesY, g_validCount);
     }
  }

//+------------------------------------------------------------------+
//| Setup a CJRNAWindow with current input parameters                |
//+------------------------------------------------------------------+
void SetupWindow(CJRNAWindow &win)
  {
   win.SetWindow(InpWindowSize, InpStep);
   win.SetEpsilon(InpEpsilon);
   win.SetEmbedding(InpEmbDim, InpDelay);
   win.SetNorm(InpNorm);
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

   bool fullRecalc = (prev_calculated == 0 || g_lastAligned != prev_calculated);

   if(fullRecalc)
     {
      if(!AlignPrices(time, close, rates_total))
        {
         PrintFormat("JRNA_Indicator: alignment failed for %s", InpSymbolY);
         return 0;
        }
      ApplyNormalization();

      ArrayInitialize(BufferACC,     EMPTY_VALUE);
      ArrayInitialize(BufferTrans,   EMPTY_VALUE);
      ArrayInitialize(BufferNormAPL, EMPTY_VALUE);
      ArrayInitialize(BufferAssort,  EMPTY_VALUE);
      ArrayInitialize(BufferBetween, EMPTY_VALUE);

      CJRNAWindow win;
      SetupWindow(win);

      SRNAWindowResult results[];
      if(!win.Run(g_pricesX, g_validCount,
                  g_pricesY, g_validCount, results))
        {
         Print("JRNA_Indicator: Run() failed");
         return 0;
        }

      int    embN       = InpWindowSize - (InpEmbDim - 1) * InpDelay;
      double normFactor = (embN > 1) ? 1.0 / (embN - 1) : 1.0;

      int nRes = ArraySize(results);
      for(int k = 0; k < nRes; k++)
        {
         int lastValid = results[k].barIndex + InpWindowSize - 1;
         if(lastValid < g_validCount)
           {
            int bar = g_barMap[lastValid];
            BufferACC[bar]     = results[k].metrics.AvgClustering;
            BufferTrans[bar]   = results[k].metrics.Transitivity;
            BufferNormAPL[bar] = results[k].metrics.AvgPathLength * normFactor;
            BufferAssort[bar]  = results[k].metrics.Assortativity;
            BufferBetween[bar] = results[k].metrics.AvgBetweenness;
           }
        }
     }
   else
     {
      if(!AlignPrices(time, close, rates_total))
        {
         Print("JRNA_Indicator: cannot align data for ", InpSymbolY);
         return prev_calculated;
        }
      ApplyNormalization();

      int newWindows  = (rates_total - prev_calculated) / InpStep
                        + InpWindowSize / InpStep + 1;
      int startWindow = MathMax(0, g_validCount - InpWindowSize
                                   - newWindows * InpStep);

      int tailLen = g_validCount - startWindow;
      if(tailLen < InpWindowSize)
         return rates_total;

      double tailX[], tailY[];
      ArrayResize(tailX, tailLen);
      ArrayResize(tailY, tailLen);
      for(int i = 0; i < tailLen; i++)
        {
         tailX[i] = g_pricesX[startWindow + i];
         tailY[i] = g_pricesY[startWindow + i];
        }

      CJRNAWindow win;
      SetupWindow(win);

      SRNAWindowResult results[];
      if(!win.Run(tailX, tailLen, tailY, tailLen, results))
         return rates_total;

      int    embN       = InpWindowSize - (InpEmbDim - 1) * InpDelay;
      double normFactor = (embN > 1) ? 1.0 / (embN - 1) : 1.0;

      int nRes = ArraySize(results);
      for(int k = 0; k < nRes; k++)
        {
         int lastValid = results[k].barIndex + InpWindowSize - 1
                         + startWindow;
         if(lastValid < g_validCount)
           {
            int bar = g_barMap[lastValid];
            BufferACC[bar]     = results[k].metrics.AvgClustering;
            BufferTrans[bar]   = results[k].metrics.Transitivity;
            BufferNormAPL[bar] = results[k].metrics.AvgPathLength * normFactor;
            BufferAssort[bar]  = results[k].metrics.Assortativity;
            BufferBetween[bar] = results[k].metrics.AvgBetweenness;
           }
        }
     }

   return rates_total;
  }
