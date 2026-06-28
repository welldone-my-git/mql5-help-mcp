//+------------------------------------------------------------------+
//|                                           PredictionInterval.mqh |
//| Computes OLS prediction intervals for individual observations.   |
//+------------------------------------------------------------------+
#ifndef __PREDICTION_INTERVAL_MQH__
#define __PREDICTION_INTERVAL_MQH__

#include "OLSStatistics.mqh"
#include "ResidualAnalysis.mqh"
#include "TDistribution.mqh"
#include "ConfidenceInterval.mqh"   // Provides SIntervalBand

//+------------------------------------------------------------------+
//| Class: CPredictionInterval                                       |
//| Calculates prediction interval bands over a regression.          |
//+------------------------------------------------------------------+
class CPredictionInterval
  {
public:
                     CPredictionInterval(void);
                    ~CPredictionInterval(void);

   SIntervalBand     Evaluate(const SOLSResult           &ols,
                              const SResidualStatistics  &res,
                              double                     t_critical,
                              int                        x_position);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPredictionInterval::CPredictionInterval(void)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CPredictionInterval::~CPredictionInterval(void)
  {
  }

//+------------------------------------------------------------------+
//| CPredictionInterval::Evaluate                                    |
//| Computes the prediction interval at position x_position.         |
//|                                                                  |
//| Formula:                                                         |
//|    ŷ ± t · s · √(1 + 1/n + (x − x̄)² / Sxx)                       |
//|                                                                  |
//| The additional 1 under the square root represents the variance   |
//| of a new individual observation around the regression line.      |
//+------------------------------------------------------------------+
SIntervalBand CPredictionInterval::Evaluate(const SOLSResult           &ols,
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

   double deviation     = x - ols.x_mean;
   double pred_variance = 1.0
                          + (1.0 / (double)ols.n)
                          + (deviation * deviation) / ols.sxx;

   double half_width = t_critical * res.std_error * MathSqrt(pred_variance);

   band.fitted = fitted;
   band.upper  = fitted + half_width;
   band.lower  = fitted - half_width;
   band.valid  = true;

   return(band);
  }

#endif
//+------------------------------------------------------------------+