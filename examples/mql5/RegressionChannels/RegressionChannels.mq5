//+------------------------------------------------------------------+
//|                                           RegressionChannels.mq5 |
//| Rolling OLS regression channels with confidence and prediction   |
//| intervals computed using Student's t-distribution.               |
//| Line-only rendering: regression line plus four boundary lines.   |
//+------------------------------------------------------------------+

#property description "Linear Regression Channels: OLS + Student's t"
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   5

//--- Plot 1: Regression line
#property indicator_label1  "Regression Line"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Prediction interval upper boundary
#property indicator_label2  "PI Upper"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrCrimson
#property indicator_style2  STYLE_DASH
#property indicator_width2  1

//--- Plot 3: Prediction interval lower boundary
#property indicator_label3  "PI Lower"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrCrimson
#property indicator_style3  STYLE_DASH
#property indicator_width3  1

//--- Plot 4: Confidence interval upper boundary
#property indicator_label4  "CI Upper"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrForestGreen
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

//--- Plot 5: Confidence interval lower boundary
#property indicator_label5  "CI Lower"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrForestGreen
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1

//--- Includes
#include <Linear_Regression_Prediction_Channels/OLSStatistics.mqh>
#include <Linear_Regression_Prediction_Channels/ResidualAnalysis.mqh>
#include <Linear_Regression_Prediction_Channels/TDistribution.mqh>
#include <Linear_Regression_Prediction_Channels/ConfidenceInterval.mqh>
#include <Linear_Regression_Prediction_Channels/PredictionInterval.mqh>

//+------------------------------------------------------------------+
//| Evaluation mode for the interval bands.                          |
//| CURRENT_EDGE: evaluate at x = window-1, the last observed bar    |
//|               inside the window. This is an in-sample edge band. |
//| NEXT_BAR:     evaluate at x = window, a genuine one-step-ahead   |
//|               forecast point one bar beyond the window.          |
//+------------------------------------------------------------------+
enum ENUM_EVAL_MODE
  {
   EVAL_CURRENT_EDGE = 0, // In-Sample Edge (x = n-1)
   EVAL_NEXT_BAR     = 1  // One-Step-Ahead Forecast (x = n)
  };

//--- Input parameters
input int            inp_regression_window = 50;              // Regression Window (Bars)
input double         inp_confidence_level  = 0.95;            // Confidence Level (0.90 to 0.99)
input ENUM_EVAL_MODE inp_eval_mode         = EVAL_CURRENT_EDGE;// Interval Evaluation Mode
input bool           inp_show_ci           = true;            // Show Confidence Interval Lines
input bool           inp_show_pi           = true;            // Show Prediction Interval Lines
input bool           inp_print_diagnostics = true;            // Print Diagnostics To Experts Log

//--- Indicator buffers
double g_buffer_regression[];
double g_buffer_pi_upper[];
double g_buffer_pi_lower[];
double g_buffer_ci_upper[];
double g_buffer_ci_lower[];

//--- Module instances (global)
COLSStatistics      g_ols_engine;
CResidualAnalysis   g_residual_engine;
CTDistribution      g_t_distribution;
CConfidenceInterval g_ci_engine;
CPredictionInterval g_pi_engine;

//--- Precomputed x-domain constants (fixed for a given window size)
double g_x_mean = 0.0;   // x̄ = (n-1)/2
double g_sxx    = 0.0;   // Σ(xᵢ − x̄)² = n(n²−1)/12
int    g_x_eval = 0;     // evaluation position (n-1 or n)

//--- Reusable working buffer for the price window (allocated once)
double g_prices[];

//--- Diagnostics state
bool g_diagnostics_printed = false;

//+------------------------------------------------------------------+
//| Self-check: verify x-domain constants for a known window.        |
//| Returns true when the closed-form constants match the expected   |
//| values for the active window, providing a lightweight unit test  |
//| that runs once at initialization.                                |
//+------------------------------------------------------------------+
bool SelfCheckXConstants(int window)
  {
   double expect_mean = (double)(window - 1) / 2.0;
   double expect_sxx  = (double)window * ((double)window * window - 1.0) / 12.0;

   if(MathAbs(g_x_mean - expect_mean) > 1e-9)
      return(false);
   if(MathAbs(g_sxx - expect_sxx) > 1e-6)
      return(false);

   return(true);
  }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit(void)
  {
//--- Validate inputs
   if(inp_regression_window < 5)
     {
      Print("RegressionChannels: inp_regression_window must be >= 5. Received: " +
            IntegerToString(inp_regression_window));
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(inp_confidence_level <= 0.50 || inp_confidence_level >= 1.00)
     {
      Print("RegressionChannels: inp_confidence_level must be in (0.50, 1.00). Received: " +
            DoubleToString(inp_confidence_level, 4));
      return(INIT_PARAMETERS_INCORRECT);
     }

//--- Precompute x-domain constants for the fixed window. Because bar
//--- indices are always 0..window-1, these never change between bars,
//--- so they are computed once here rather than on every bar.
   int n = inp_regression_window;
   g_x_mean = (double)(n - 1) / 2.0;
   g_sxx    = (double)n * ((double)n * n - 1.0) / 12.0;

//--- Choose the evaluation position from the selected mode.
   g_x_eval = (inp_eval_mode == EVAL_NEXT_BAR) ? n : (n - 1);

//--- Run the lightweight self-check on the x-domain constants.
   if(!SelfCheckXConstants(n))
     {
      Print("RegressionChannels: x-domain self-check failed. "
            "x_mean=" + DoubleToString(g_x_mean, 4) +
            " sxx=" + DoubleToString(g_sxx, 4));
      return(INIT_FAILED);
     }

//--- Allocate the reusable price working buffer once.
   if(ArrayResize(g_prices, n) != n)
     {
      Print("RegressionChannels: failed to allocate price buffer.");
      return(INIT_FAILED);
     }

//--- Bind buffers
   SetIndexBuffer(0, g_buffer_regression, INDICATOR_DATA);
   SetIndexBuffer(1, g_buffer_pi_upper,   INDICATOR_DATA);
   SetIndexBuffer(2, g_buffer_pi_lower,   INDICATOR_DATA);
   SetIndexBuffer(3, g_buffer_ci_upper,   INDICATOR_DATA);
   SetIndexBuffer(4, g_buffer_ci_lower,   INDICATOR_DATA);

//--- Set empty value per plot (5 plots, indices 0..4)
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);

//--- Apply current visibility from inputs. Using DRAW_LINE / DRAW_NONE
//--- here (rather than only in OnInit on first load) means the plots
//--- track input changes when the indicator is re-initialized.
   int pi_type = inp_show_pi ? DRAW_LINE : DRAW_NONE;
   int ci_type = inp_show_ci ? DRAW_LINE : DRAW_NONE;
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, pi_type);
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, pi_type);
   PlotIndexSetInteger(3, PLOT_DRAW_TYPE, ci_type);
   PlotIndexSetInteger(4, PLOT_DRAW_TYPE, ci_type);

//--- Require enough historical bars
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   string mode_tag   = (inp_eval_mode == EVAL_NEXT_BAR) ? "fwd" : "edge";
   string short_name = "RegCh(" +
                       IntegerToString(inp_regression_window) + "," +
                       DoubleToString(inp_confidence_level * 100.0, 0) + "%," +
                       mode_tag + ")";
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);

   g_diagnostics_printed = false;

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }

//+------------------------------------------------------------------+
//| Helper: write EMPTY_VALUE into every buffer at one bar           |
//+------------------------------------------------------------------+
void ClearBar(int bar)
  {
   g_buffer_regression[bar] = EMPTY_VALUE;
   g_buffer_pi_upper[bar]   = EMPTY_VALUE;
   g_buffer_pi_lower[bar]   = EMPTY_VALUE;
   g_buffer_ci_upper[bar]   = EMPTY_VALUE;
   g_buffer_ci_lower[bar]   = EMPTY_VALUE;
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
   int window = inp_regression_window;

//--- Need at least one full window before drawing
   if(rates_total < window)
      return(0);

//--- Determine starting bar for this pass
   int start_bar = prev_calculated - 1;
   if(start_bar < window - 1)
      start_bar = window - 1;

//--- Fill leading bars with EMPTY_VALUE
   if(prev_calculated == 0)
     {
      for(int i = 0; i < window - 1; i++)
         ClearBar(i);
     }

//--- Compute alpha from confidence level
   double alpha = 1.0 - inp_confidence_level;

//--- Process each bar from start_bar to the most recent
   for(int bar = start_bar; bar < rates_total; bar++)
     {
      //--- Copy this window's closing prices into the reusable buffer.
      //--- prices[0] = oldest bar in window, prices[window-1] = bar itself.
      for(int k = 0; k < window; k++)
         g_prices[k] = close[bar - (window - 1) + k];

      //--- Step 1: Fit OLS regression (passing the precomputed x stats)
      SOLSResult ols = g_ols_engine.Compute(g_prices, window, g_x_mean, g_sxx);

      if(!ols.valid)
        {
         ClearBar(bar);
         continue;
        }

      //--- Step 2: Compute residual variance
      SResidualStatistics res = g_residual_engine.Compute(ols);

      if(!res.valid)
        {
         ClearBar(bar);
         continue;
        }

      //--- Step 3: Get t critical value; skip the bar if it is invalid
      double t_crit = g_t_distribution.CriticalValue(res.degrees_of_freedom, alpha);

      if(t_crit < 0.0)
        {
         ClearBar(bar);
         continue;
        }

      //--- Step 4: Evaluate intervals at the configured position.
      //--- g_x_eval is window-1 for the in-sample edge, or window for a
      //--- one-step-ahead forecast one bar beyond the window.
      SIntervalBand ci = g_ci_engine.Evaluate(ols, res, t_crit, g_x_eval);
      SIntervalBand pi = g_pi_engine.Evaluate(ols, res, t_crit, g_x_eval);

      //--- Default this bar to empty, then fill in whatever is valid/enabled
      ClearBar(bar);

      //--- Regression line
      if(ci.valid)
         g_buffer_regression[bar] = ci.fitted;

      //--- Prediction interval boundary lines
      if(inp_show_pi && pi.valid)
        {
         g_buffer_pi_upper[bar] = pi.upper;
         g_buffer_pi_lower[bar] = pi.lower;
        }

      //--- Confidence interval boundary lines
      if(inp_show_ci && ci.valid)
        {
         g_buffer_ci_upper[bar] = ci.upper;
         g_buffer_ci_lower[bar] = ci.lower;
        }

      //--- Step 5: Print diagnostics on first valid bar only
      if(inp_print_diagnostics && !g_diagnostics_printed && ci.valid && pi.valid)
        {
         PrintDiagnostics(ols, res, t_crit, ci, pi, bar);
         g_diagnostics_printed = true;
        }
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| PrintDiagnostics                                                 |
//| Outputs regression statistics to the MetaTrader Experts log.     |
//+------------------------------------------------------------------+
void PrintDiagnostics(const SOLSResult          &ols,
                      const SResidualStatistics  &res,
                      double                     t_crit,
                      const SIntervalBand        &ci,
                      const SIntervalBand        &pi,
                      int                        bar_index)
  {
   string mode_text = (inp_eval_mode == EVAL_NEXT_BAR)
                      ? "One-Step-Ahead Forecast (x = n)"
                      : "In-Sample Edge (x = n-1)";

   Print("=== RegressionChannels Diagnostics ===");
   Print("Evaluation Mode     = " + mode_text);
   Print("Evaluation x        = " + IntegerToString(g_x_eval));
   Print("Bar Index           = " + IntegerToString(bar_index));
   Print("Regression Window   = " + IntegerToString(ols.n));
   Print("Degrees Of Freedom  = " + IntegerToString(res.degrees_of_freedom));
   Print("Regression Slope    = " + DoubleToString(ols.slope, 8));
   Print("Regression Intercept= " + DoubleToString(ols.intercept, 8));
   Print("SSE                 = " + DoubleToString(ols.sse, 8));
   Print("Residual Variance   = " + DoubleToString(res.variance, 8));
   Print("Residual Std Error  = " + DoubleToString(res.std_error, 8));
   Print("t Critical Value    = " + DoubleToString(t_crit, 6));
   Print("x Mean              = " + DoubleToString(ols.x_mean, 4));
   Print("Sxx                 = " + DoubleToString(ols.sxx, 4));
   Print("--- Confidence Interval ---");
   Print("CI Fitted           = " + DoubleToString(ci.fitted, _Digits));
   Print("CI Upper            = " + DoubleToString(ci.upper,  _Digits));
   Print("CI Lower            = " + DoubleToString(ci.lower,  _Digits));
   Print("CI Half Width       = " + DoubleToString(ci.upper - ci.fitted, _Digits));
   Print("--- Prediction Interval ---");
   Print("PI Fitted           = " + DoubleToString(pi.fitted, _Digits));
   Print("PI Upper            = " + DoubleToString(pi.upper,  _Digits));
   Print("PI Lower            = " + DoubleToString(pi.lower,  _Digits));
   Print("PI Half Width       = " + DoubleToString(pi.upper - pi.fitted, _Digits));
   Print("--- Width Ratio PI/CI ---");
   double ci_hw = ci.upper - ci.fitted;
   double pi_hw = pi.upper - pi.fitted;
   if(ci_hw > 1e-15)
      Print("Width Ratio         = " + DoubleToString(pi_hw / ci_hw, 6));
   Print("======================================");
  }
//+------------------------------------------------------------------+