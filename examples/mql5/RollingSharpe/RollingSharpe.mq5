//+------------------------------------------------------------------+
//|                                                RollingSharpe.mq5 |
//| Rolling Annualized Sharpe Ratio with Lo Significance Bands       |
//| Requires: CReturnBuffer.mqh, CSharpeCalculator.mqh               |
//+------------------------------------------------------------------+

#property description "Rolling Sharpe Ratio with +/-z*SE significance bands"
#property strict

//--- Indicator window configurations
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   4

//--- Plot 1: Sharpe Ratio line
#property indicator_label1  "Sharpe Ratio"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrCyan
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Upper Standard Error Band
#property indicator_label2  "Upper Band (+1.96*SE)"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrCrimson
#property indicator_style2  STYLE_DASH
#property indicator_width2  1

//--- Plot 3: Lower Standard Error Band
#property indicator_label3  "Lower Band (-1.96*SE)"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrCrimson
#property indicator_style3  STYLE_DASH
#property indicator_width3  1

//--- Plot 4: Static Baseline Anchor
#property indicator_label4  "Zero Line"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrDimGray
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

//--- Include dependencies
#include <RollingSharpe/CReturnBuffer.mqh>
#include <RollingSharpe/CSharpeCalculator.mqh>

//--- Input parameters
input int    inp_Window         = 60;  // Lookback Rolling Window Size
input int    inp_PeriodsPerYear = 252; // Annualization Periodicity (e.g. Daily = 252)
input double inp_ZScore         = 1.96;// Statistical Confidence Interval z-score
input bool   inp_UseLogReturns  = true;// Calculate Logarithmic Returns instead of Simple

//--- Global indicator data arrays
double g_BufSharpe[];
double g_BufUpper[];
double g_BufLower[];
double g_BufZero[];

//--- Shared analytical cached values
double g_AnnFactor = 1.0;

//+------------------------------------------------------------------+
//| ComputeBar                                                       |
//| Purpose: Evaluates rolling Sharpe statistics and standard errors |
//|          for an isolated bar position using multi-pass analysis. |
//+------------------------------------------------------------------+
void ComputeBar(const int      i,
                const double   &close[],
                const int      window,
                const double   annFactor,
                const double   zScore,
                const bool     useLog,
                double         &outSharpe,
                double         &outUpper,
                double         &outLower)
  {
   outSharpe = EMPTY_VALUE;
   outUpper  = EMPTY_VALUE;
   outLower  = EMPTY_VALUE;

//--- Verify that enough historical data points exist prior to the index
   if(i < window)
      return;

   double sum = 0.0;

//--- Pass 1: Compute empirical mean of returns over the sliding window
   for(int k = i - window + 1; k <= i; k++)
     {
      double prevClose = close[k - 1];
      if(prevClose < 1e-10)
         return; // Abort structural processing if an invalid price point is hit

      double ret = useLog ? MathLog(close[k] / prevClose) : (close[k] - prevClose) / prevClose;
      sum += ret;
     }
   double mean = sum / (double)window;

   double ssq = 0.0;

//--- Pass 2: Compute unbiased sample variance across the window
   for(int k = i - window + 1; k <= i; k++)
     {
      double prevClose = close[k - 1];
      double ret = useLog ? MathLog(close[k] / prevClose) : (close[k] - prevClose) / prevClose;
      double dev = ret - mean;
      ssq += dev * dev;
     }
   double variance = ssq / (double)(window - 1);

//--- Handle edge cases with zero/degenerate market variance
   if(variance < 1e-24)
      return;

   double stdDev = MathSqrt(variance);
   double sr_raw = mean / stdDev;
   double sr_ann = sr_raw * annFactor;

//--- Apply asymptotic standard error framework using Lo (2002) model equations
   double se_raw = MathSqrt((1.0 + 0.5 * sr_raw * sr_raw) / (double)window);
   double se_ann = annFactor * se_raw;

//--- Map analytical values onto output destination reference parameters
   outSharpe = sr_ann;
   outUpper  = sr_ann + zScore * se_ann;
   outLower  = sr_ann - zScore * se_ann;
  }

//+------------------------------------------------------------------+
//| Custom Indicator Initialization Function                         |
//+------------------------------------------------------------------+
int OnInit(void)
  {
//--- Perform input verification checks
   if(inp_Window < 2)
     {
      Alert("RollingSharpe: inp_Window must be >= 2. Aborting.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(inp_PeriodsPerYear < 1)
     {
      Alert("RollingSharpe: inp_PeriodsPerYear must be >= 1. Aborting.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(inp_ZScore <= 0.0)
     {
      Alert("RollingSharpe: inp_ZScore must be > 0. Aborting.");
      return(INIT_PARAMETERS_INCORRECT);
     }

//--- Derive annualization multiplier coefficients
   g_AnnFactor = MathSqrt((double)inp_PeriodsPerYear);

//--- Bind dynamic global array vectors to structural indicator tracks
   SetIndexBuffer(0, g_BufSharpe, INDICATOR_DATA);
   SetIndexBuffer(1, g_BufUpper,  INDICATOR_DATA);
   SetIndexBuffer(2, g_BufLower,  INDICATOR_DATA);
   SetIndexBuffer(3, g_BufZero,   INDICATOR_DATA);

//--- Explicitly assign systemic out-of-bounds rendering targets
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);

//--- Offset rendering boundaries to match lookback window data constraints
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, inp_Window);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, inp_Window);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, inp_Window);
   PlotIndexSetInteger(3, PLOT_DRAW_BEGIN, 0);

//--- Set visual tracking float precision limits
   IndicatorSetInteger(INDICATOR_DIGITS, 4);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom Indicator Deinitialization Function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }

//+------------------------------------------------------------------+
//| Custom Indicator Iteration Function                              |
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
//--- Ensure dataset sizes exceed minimum parsing window depths
   if(rates_total < inp_Window + 1)
      return(0);

//--- Assert system security against reverse index array formatting flags
   if(ArrayGetAsSeries(close))
     {
      Print("RollingSharpe: time-series array ordering detected. Aborting.");
      return(0);
     }

//--- Establish processing ranges depending on complete or incremental calculations
   int startBar = (prev_calculated == 0) ? 1 : prev_calculated - 1;

//--- Flush baseline data elements if handling a complete data recalculation pass
   if(prev_calculated == 0)
     {
      for(int i = 0; i < MathMin(inp_Window, rates_total); i++)
        {
         g_BufSharpe[i] = EMPTY_VALUE;
         g_BufUpper[i]  = EMPTY_VALUE;
         g_BufLower[i]  = EMPTY_VALUE;
         g_BufZero[i]   = 0.0;
        }
      //--- Advance initialization pointer past uncomputable warmup bar frames
      startBar = inp_Window;
     }

//--- Primary analytical calculation execution loop
   for(int i = startBar; i < rates_total; i++)
     {
      g_BufZero[i] = 0.0;

      double sharpe, upper, lower;
      ComputeBar(i, close, inp_Window, g_AnnFactor, inp_ZScore, inp_UseLogReturns, sharpe, upper, lower);

      g_BufSharpe[i] = sharpe;
      g_BufUpper[i]  = upper;
      g_BufLower[i]  = lower;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+