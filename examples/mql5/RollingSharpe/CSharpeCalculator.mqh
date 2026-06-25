//+------------------------------------------------------------------+
//|                                            CSharpeCalculator.mqh |
//| Computes rolling annualized Sharpe ratio with Lo SE bands.       |
//+------------------------------------------------------------------+
#ifndef __CSHARPECALCULATOR_MQH__
#define __CSHARPECALCULATOR_MQH__

#include "CReturnBuffer.mqh"

//+------------------------------------------------------------------+
//| Struct SSharpeResult                                             |
//| Purpose: Structure holding annualized Sharpe evaluation details  |
//|          alongside standard asymptotic error boundary margins.   |
//+------------------------------------------------------------------+
struct SSharpeResult
  {
   double            sharpe;           // Annualized Sharpe ratio metric
   double            upperBand;        // Confidence interval upper limit (Sharpe + zScore * SE)
   double            lowerBand;        // Confidence interval lower limit (Sharpe - zScore * SE)
   double            se;               // Annualized standard error variance estimator
   bool              valid;            // Operational status flag representing dataset maturity
  };

//+------------------------------------------------------------------+
//| Class CSharpeCalculator                                          |
//| Purpose: Processes risk-adjusted metric profiles over sliding    |
//|          lookback window boundaries via single pass iterations.  |
//+------------------------------------------------------------------+
class CSharpeCalculator
  {
private:
   CReturnBuffer     m_buffer;         // Core sliding analytical circular caching array
   int               m_window;         // Minimum lookback item count window depth
   double            m_annFactor;      // Calculated annualization root factor multiplier
   double            m_zScore;         // Standard Normal score confidence coefficient

   //--- Calculates the standard error envelope over raw performance vectors
   double            ComputeSE(const double sr_raw, const int n) const;

public:
                     CSharpeCalculator(void);
                    ~CSharpeCalculator(void);

   //--- Setup tracking dimensions and statistical scaling coefficients
   bool              Init(const int window, const int periodsPerYear, const double zScore = 1.96);

   void              AddReturn(const double ret);
   SSharpeResult     Calculate(void) const;
   bool              IsReady(void) const;
   void              Reset(void);
  };

//+------------------------------------------------------------------+
//| Default Class Constructor                                        |
//+------------------------------------------------------------------+
CSharpeCalculator::CSharpeCalculator(void) : m_window(0),
   m_annFactor(1.0),
   m_zScore(1.96)
  {
  }

//+------------------------------------------------------------------+
//| Class Destructor                                                 |
//+------------------------------------------------------------------+
CSharpeCalculator::~CSharpeCalculator(void)
  {
  }

//+-----------------------------------------------------------------------+
//| Init                                                                  |
//| Purpose: Establishes sizing metrics limits and validation constraints |
//+-----------------------------------------------------------------------+
bool CSharpeCalculator::Init(const int window, const int periodsPerYear, const double zScore = 1.96)
  {
//--- Verify fundamental operational sizing ranges
   if(window < 2)
     {
      Print("CSharpeCalculator::Init - window must be >= 2");
      return(false);
     }
   if(periodsPerYear < 1)
     {
      Print("CSharpeCalculator::Init - periodsPerYear must be >= 1");
      return(false);
     }

//--- Set up global state property definitions
   m_window    = window;
   m_annFactor = MathSqrt((double)periodsPerYear);
   m_zScore    = MathAbs(zScore);

//--- Configure underlying data array storage limits
   return(m_buffer.Init(window));
  }

//+------------------------------------------------------------------+
//| ComputeSE                                                        |
//| Purpose: Estimates the standard error of the Sharpe Ratio        |
//|          utilizing standard Lo (2002) asymptotic equations.      |
//+------------------------------------------------------------------+
double CSharpeCalculator::ComputeSE(const double sr_raw, const int n) const
  {
//--- Guard against out of bounds division operations on low sample distributions
   if(n < 2)
      return(0.0);

//--- Compute standard error base tracking metrics
   double se_raw = MathSqrt((1.0 + 0.5 * sr_raw * sr_raw) / (double)n);
   return(m_annFactor * se_raw);
  }

//+------------------------------------------------------------------+
//| AddReturn                                                        |
//+------------------------------------------------------------------+
void CSharpeCalculator::AddReturn(const double ret)
  {
//--- Write newly arrived data element onto tracking data arrays
   m_buffer.Push(ret);
  }

//+------------------------------------------------------------------+
//| Calculate                                                        |
//| Purpose: Transforms runtime rolling sums into an annualized      |
//|          Sharpe profile structure report payload cleanly.        |
//+------------------------------------------------------------------+
SSharpeResult CSharpeCalculator::Calculate(void) const
  {
   SSharpeResult res;
   res.valid     = false;
   res.sharpe    = 0.0;
   res.upperBand = 0.0;
   res.lowerBand = 0.0;
   res.se        = 0.0;

//--- Extract current item counts stored within the active matrix buffer
   int n = m_buffer.Count();
   if(n < 2)
      return(res);

//--- Prevent divide-by-zero actions under zero-variance market conditions
   double stdDev = m_buffer.StdDev();
   if(stdDev < 1e-12)
      return(res);

//--- Execute mathematical tracking conversions
   double mean   = m_buffer.Mean();
   double sr_raw = mean / stdDev;
   double sr_ann = sr_raw * m_annFactor;
   double se_ann = ComputeSE(sr_raw, n);

//--- Finalize calculation result matrix mapping assignments
   res.sharpe    = sr_ann;
   res.se        = se_ann;
   res.upperBand = sr_ann + m_zScore * se_ann;
   res.lowerBand = sr_ann - m_zScore * se_ann;
   res.valid     = true;

   return(res);
  }

//+------------------------------------------------------------------+
//| IsReady                                                          |
//+------------------------------------------------------------------+
bool CSharpeCalculator::IsReady(void) const
  {
//--- Asserts whether historical sampling has fully saturated the designated window
   return(m_buffer.IsFull());
  }

//+------------------------------------------------------------------+
//| Reset                                                            |
//+------------------------------------------------------------------+
void CSharpeCalculator::Reset(void)
  {
//--- Flush underlying analytical ring buffers completely
   m_buffer.Reset();
  }

#endif // __CSHARPECALCULATOR_MQH__
//+------------------------------------------------------------------+