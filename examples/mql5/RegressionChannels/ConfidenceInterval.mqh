//+------------------------------------------------------------------+
//|                                       ConfidenceInterval.mqh     |
//| Computes OLS confidence intervals for the mean response.         |
//+------------------------------------------------------------------+
#ifndef __CONFIDENCE_INTERVAL_MQH__
#define __CONFIDENCE_INTERVAL_MQH__

#include "OLSStatistics.mqh"
#include "ResidualAnalysis.mqh"
#include "TDistribution.mqh"

//+------------------------------------------------------------------+
//| Structure: SIntervalBand                                         |
//| Holds the upper and lower band values at a single x position.    |
//+------------------------------------------------------------------+
struct SIntervalBand
  {
   double            upper;
   double            lower;
   double            fitted;
   bool              valid;
  };

//+------------------------------------------------------------------+
//| Class: CConfidenceInterval                                       |
//| Calculates mean confidence interval bands over a regression.     |
//+------------------------------------------------------------------+
class CConfidenceInterval
  {
public:
                     CConfidenceInterval(void);
                    ~CConfidenceInterval(void);

   SIntervalBand     Evaluate(const SOLSResult           &ols,
                              const SResidualStatistics  &res,
                              double                     t_critical,
                              int                        x_position);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CConfidenceInterval::CConfidenceInterval(void)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CConfidenceInterval::~CConfidenceInterval(void)
  {
  }

//+------------------------------------------------------------------+
//| CConfidenceInterval::Evaluate                                    |
//| Computes the confidence interval at position x_position.         |
//|                                                                  |
//| Formula:                                                         |
//|    ŷ ± t · s · √(1/n + (x − x̄)² / Sxx)                           |
//+------------------------------------------------------------------+
SIntervalBand CConfidenceInterval::Evaluate(const SOLSResult           &ols,
      const SResidualStatistics  &res,
      double                     t_critical,
      int                        x_position)
  {
   SIntervalBand band;
   band.valid = false;

   if(!ols.valid || !res.valid)
      return(band);

   double x      = (double)x_position;
   double fitted = ols.intercept + ols.slope * x;

   double deviation = x - ols.x_mean;
   double leverage  = (1.0 / (double)ols.n) + (deviation * deviation) / ols.sxx;

   double half_width = t_critical * res.std_error * MathSqrt(leverage);

   band.fitted = fitted;
   band.upper  = fitted + half_width;
   band.lower  = fitted - half_width;
   band.valid  = true;

   return(band);
  }

#endif
//+------------------------------------------------------------------+