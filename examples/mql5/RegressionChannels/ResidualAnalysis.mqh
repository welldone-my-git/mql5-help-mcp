//+------------------------------------------------------------------+
//|                                             ResidualAnalysis.mqh |
//| Residual variance and degrees of freedom from OLS output.        |
//+------------------------------------------------------------------+
#ifndef __RESIDUAL_ANALYSIS_MQH__
#define __RESIDUAL_ANALYSIS_MQH__

#include "OLSStatistics.mqh"

//+------------------------------------------------------------------+
//| Structure: SResidualStatistics                                   |
//| Holds residual analysis outputs.                                 |
//+------------------------------------------------------------------+
struct SResidualStatistics
  {
   double            variance;            // s² = SSE / (n−2)
   double            std_error;           // s  = √s²
   int               degrees_of_freedom;  // n − 2
   bool              valid;
  };

//+------------------------------------------------------------------+
//| Class: CResidualAnalysis                                         |
//| Derives residual statistics from a completed OLS result.         |
//+------------------------------------------------------------------+
class CResidualAnalysis
  {
public:
                     CResidualAnalysis(void);
                    ~CResidualAnalysis(void);

   SResidualStatistics Compute(const SOLSResult &ols);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CResidualAnalysis::CResidualAnalysis(void)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CResidualAnalysis::~CResidualAnalysis(void)
  {
  }

//+------------------------------------------------------------------+
//| CResidualAnalysis::Compute                                       |
//| Receives a validated SOLSResult and returns residual statistics. |
//+------------------------------------------------------------------+
SResidualStatistics CResidualAnalysis::Compute(const SOLSResult &ols)
  {
   SResidualStatistics res;
   res.valid = false;

   if(!ols.valid || ols.n < 3)
      return(res);

   int df = ols.n - 2;

   if(df < 1)
      return(res);

   double variance  = ols.sse / (double)df;
   double std_error = MathSqrt(variance);

   res.variance           = variance;
   res.std_error          = std_error;
   res.degrees_of_freedom = df;
   res.valid              = true;

   return(res);
  }

#endif
//+------------------------------------------------------------------+