//+------------------------------------------------------------------+
//|                                              RQA_Indicator.mq5   |
//|                     Example Indicator using RQA Library          |
//|  Plots DET, RR, LAM, ENTR as indicator buffers on chart          |
//+------------------------------------------------------------------+
#property copyright   "Hammad Dilber"
#property version     "1.00"
#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   5

// Plots
#property indicator_label1  "RR"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2

#property indicator_label2  "DET"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLimeGreen
#property indicator_width2  2

#property indicator_label3  "LAM"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrange
#property indicator_width3  2

#property indicator_label4  "ENTR"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrViolet
#property indicator_width4  2

#property indicator_label5  "TREND"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrRed
#property indicator_width5  1

// Include the full RQA library
#include <RQA\RQA.mqh>

//--- Input parameters
input int    InpWindowSize   = 50;          // Rolling window size
input int    InpStep         = 1;           // Step between windows
input int    InpEmbDim       = 1;           // Embedding dimension
input int    InpDelay        = 1;           // Time delay (tau)
input double InpEpsilon      = 0.0;         // Epsilon (0 = auto by RR target)
input double InpEpsilonParam = 0.05;        // Auto-epsilon param (target RR or fraction)
input ENUM_EPSILON_METHOD InpEpsMethod = EPSILON_RR_TARGET; // Epsilon method
input ENUM_RQA_NORM InpNorm  = RQA_NORM_EUCLIDEAN; // Distance norm
input int    InpMinDiag      = 2;           // Min diagonal line length
input int    InpMinVert      = 2;           // Min vertical line length

//--- Buffers
double BufferRR[];
double BufferDET[];
double BufferLAM[];
double BufferENTR[];
double BufferTREND[];

//+------------------------------------------------------------------+
//| OnInit — register buffers and set indicator short name           |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BufferRR,    INDICATOR_DATA);
   SetIndexBuffer(1, BufferDET,   INDICATOR_DATA);
   SetIndexBuffer(2, BufferLAM,   INDICATOR_DATA);
   SetIndexBuffer(3, BufferENTR,  INDICATOR_DATA);
   SetIndexBuffer(4, BufferTREND, INDICATOR_DATA);

   IndicatorSetString(INDICATOR_SHORTNAME,
                      StringFormat("RQA(W=%d,m=%d,τ=%d)",
                                   InpWindowSize, InpEmbDim, InpDelay));
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| OnCalculate — run rolling RQA and fill indicator buffers         |
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

   //--- Only recalculate on new bars
   int startBar = (prev_calculated > InpWindowSize) ? prev_calculated - 1 : InpWindowSize;

   //--- Setup rolling window analysis
   CRQAWindow win;
   win.SetWindow(InpWindowSize, InpStep);
   win.SetEmbedding(InpEmbDim, InpDelay);
   win.SetNorm(InpNorm);
   win.SetMinLines(InpMinDiag, InpMinVert);

   //--- Set epsilon
   if(InpEpsilon > 0.0)
      win.SetEpsilon(InpEpsilon);
   else
     {
      //--- Use auto-epsilon on full series
      double fullSeries[];
      ArrayResize(fullSeries, rates_total);
      for(int i = 0; i < rates_total; i++)
         fullSeries[i] = close[i];
      double autoEps = CRQAEpsilon::Select(fullSeries, rates_total,
                                            InpEpsMethod, InpEpsilonParam);
      win.SetEpsilon(autoEps);
     }

   //--- Build the close price array
   double prices[];
   ArrayResize(prices, rates_total);
   for(int i = 0; i < rates_total; i++)
      prices[i] = close[i];

   //--- Run rolling RQA
   SRQAWindowResult results[];
   if(!win.Run(prices, rates_total, results))
      return prev_calculated;

   int nRes = ArraySize(results);

   //--- Fill buffers (results[k].barIndex = starting bar of window)
   for(int k = 0; k < nRes; k++)
     {
      int bar = results[k].barIndex + InpWindowSize - 1;
      if(bar < rates_total)
        {
         BufferRR[bar]    = results[k].metrics.RR;
         BufferDET[bar]   = results[k].metrics.DET;
         BufferLAM[bar]   = results[k].metrics.LAM;
         BufferENTR[bar]  = results[k].metrics.ENTR;
         BufferTREND[bar] = results[k].metrics.TREND;
        }
     }

   return rates_total;
  }
