//+------------------------------------------------------------------+
//|                                             CRQA_Indicator.mq5   |
//|                          Cross-RQA Indicator using RQA Library   |
//|     Plots CRR, CDET, CLAM, CENTR as buffers in separate window   | 
//|                 Compares current chart symbol with InpSymbolY.   |
//+------------------------------------------------------------------+
#property copyright   "Hammad Dilber"
#property version     "1.01"
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   4

#property indicator_label1  "CRR"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2

#property indicator_label2  "CDET"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLimeGreen
#property indicator_width2  2

#property indicator_label3  "CLAM"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrange
#property indicator_width3  2

#property indicator_label4  "CENTR"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrViolet
#property indicator_width4  1

#include <RQA\RQA.mqh>

enum ENUM_CRQA_NORMALIZE
  {
   CRQA_NORM_NONE    = 0,   // None (raw prices)
   CRQA_NORM_ZSCORE  = 1,   // Z-Score (recommended for cross-symbol)
   CRQA_NORM_RETURNS = 2    // Log Returns
  };

//--- Inputs
input string InpSymbolY      = "GBPUSD";            // Second symbol to compare with
input int    InpWindowSize   = 50;                  // Rolling window size
input int    InpStep         = 1;                   // Step between windows
input int    InpEmbDim       = 1;                   // Embedding dimension
input int    InpDelay        = 1;                   // Time delay (tau)
input double InpEpsilon      = 0.5;                 // Epsilon threshold (in normalized units if normalization enabled)
input ENUM_RQA_NORM InpNorm  = RQA_NORM_EUCLIDEAN;  // Distance norm
input int    InpMinDiag      = 2;                   // Min diagonal line length
input int    InpMinVert      = 2;                   // Min vertical line length
input ENUM_CRQA_NORMALIZE InpNormalize = CRQA_NORM_RETURNS; // Series normalization

//--- Buffers
double BufferCRR[];
double BufferCDET[];
double BufferCLAM[];
double BufferCENTR[];

//--- Cached aligned data
double g_pricesX[];
double g_pricesY[];
int    g_barMap[];
int    g_validCount;
int    g_lastAligned;
bool   g_warnedAlign;

//+------------------------------------------------------------------+
//| Initialize indicator buffers and validate second symbol          |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferCRR,   INDICATOR_DATA);
   SetIndexBuffer(1, BufferCDET,  INDICATOR_DATA);
   SetIndexBuffer(2, BufferCLAM,  INDICATOR_DATA);
   SetIndexBuffer(3, BufferCENTR, INDICATOR_DATA);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   IndicatorSetString(INDICATOR_SHORTNAME,
                      StringFormat("CRQA(%s vs %s, W=%d)",
                                   _Symbol, InpSymbolY, InpWindowSize));

   g_validCount = 0;
   g_lastAligned = 0;
   g_warnedAlign = false;

   if(InpSymbolY != _Symbol)
     {
      bool selected = SymbolSelect(InpSymbolY, true);
      if(!selected)
        {
         PrintFormat("CRQA_Indicator: symbol %s not found in Market Watch", InpSymbolY);
         return INIT_FAILED;
        }
     }

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Bulk-align second symbol's close prices to chart bars            |
//| Uses CopyTime + CopyClose in bulk, then merge-joins by datetime  |
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
//| Normalize an array in-place using z-score                        |
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
      arr[i] = (arr[i + 1] > 0 && arr[i] > 0) ? MathLog(arr[i + 1] / arr[i]) : 0.0;
   int newLen = len - 1;
   ArrayResize(arr, newLen);
   return newLen;
  }

//+------------------------------------------------------------------+
//| Main calculation: align series, normalize, run CRQA windows      |
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
         PrintFormat("CRQA_Indicator: alignment failed for %s (need %d aligned)",
                     InpSymbolY, InpWindowSize);
         return 0;
        }
      if(InpNormalize == CRQA_NORM_ZSCORE)
        {
         NormalizeZScore(g_pricesX, g_validCount);
         NormalizeZScore(g_pricesY, g_validCount);
        }
      else if(InpNormalize == CRQA_NORM_RETURNS)
        {
         int newLenX = ToLogReturns(g_pricesX, g_validCount);
         int newLenY = ToLogReturns(g_pricesY, g_validCount);
         // Shift barMap forward by 1 (returns[i] corresponds to bar[i+1])
         for(int i = 0; i < newLenX; i++)
            g_barMap[i] = g_barMap[i + 1];
         g_validCount = MathMin(newLenX, newLenY);
         ArrayResize(g_pricesX, g_validCount);
         ArrayResize(g_pricesY, g_validCount);
         ArrayResize(g_barMap,  g_validCount);
         // Z-score the returns too for scale-invariant epsilon
         NormalizeZScore(g_pricesX, g_validCount);
         NormalizeZScore(g_pricesY, g_validCount);
        }

      ArrayInitialize(BufferCRR,   EMPTY_VALUE);
      ArrayInitialize(BufferCDET,  EMPTY_VALUE);
      ArrayInitialize(BufferCLAM,  EMPTY_VALUE);
      ArrayInitialize(BufferCENTR, EMPTY_VALUE);

      CCRQAWindow win;
      win.SetWindow(InpWindowSize, InpStep);
      win.SetEpsilon(InpEpsilon);
      win.SetEmbedding(InpEmbDim, InpDelay);
      win.SetNorm(InpNorm);
      win.SetMinLines(InpMinDiag, InpMinVert);

      SCRQAWindowResult results[];
      if(!win.Run(g_pricesX, g_validCount, g_pricesY, g_validCount, results))
        {
         Print("CRQA_Indicator: Run() failed");
         return 0;
        }

      int nRes = ArraySize(results);
      for(int k = 0; k < nRes; k++)
        {
         int lastValid = results[k].barIndex + InpWindowSize - 1;
         if(lastValid < g_validCount)
           {
            int bar = g_barMap[lastValid];
            BufferCRR[bar]   = results[k].metrics.CRR;
            BufferCDET[bar]  = results[k].metrics.CDET;
            BufferCLAM[bar]  = results[k].metrics.CLAM;
            BufferCENTR[bar] = results[k].metrics.CENTR;
           }
        }
     }
   else
     {
      if(!AlignPrices(time, close, rates_total))
        {
         Print("CRQA_Indicator: cannot align data for ", InpSymbolY);
         return prev_calculated;
        }

      if(InpNormalize == CRQA_NORM_ZSCORE)
        {
         NormalizeZScore(g_pricesX, g_validCount);
         NormalizeZScore(g_pricesY, g_validCount);
        }
      else if(InpNormalize == CRQA_NORM_RETURNS)
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

      int newWindows = (rates_total - prev_calculated) / InpStep + InpWindowSize / InpStep + 1;
      int startWindow = MathMax(0, g_validCount - InpWindowSize - newWindows * InpStep);

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

      CCRQAWindow win;
      win.SetWindow(InpWindowSize, InpStep);
      win.SetEpsilon(InpEpsilon);
      win.SetEmbedding(InpEmbDim, InpDelay);
      win.SetNorm(InpNorm);
      win.SetMinLines(InpMinDiag, InpMinVert);

      SCRQAWindowResult results[];
      if(!win.Run(tailX, tailLen, tailY, tailLen, results))
         return rates_total;

      int nRes = ArraySize(results);
      for(int k = 0; k < nRes; k++)
        {
         int lastValid = results[k].barIndex + InpWindowSize - 1 + startWindow;
         if(lastValid < g_validCount)
           {
            int bar = g_barMap[lastValid];
            BufferCRR[bar]   = results[k].metrics.CRR;
            BufferCDET[bar]  = results[k].metrics.CDET;
            BufferCLAM[bar]  = results[k].metrics.CLAM;
            BufferCENTR[bar] = results[k].metrics.CENTR;
           }
        }
     }

   return rates_total;
  }
