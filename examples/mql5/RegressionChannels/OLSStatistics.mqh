//+------------------------------------------------------------------+
//|                                                OLSStatistics.mqh |
//| Ordinary Least Squares parameter estimation for rolling windows. |
//+------------------------------------------------------------------+
#ifndef __OLS_STATISTICS_MQH__
#define __OLS_STATISTICS_MQH__

//+------------------------------------------------------------------+
//| Structure: SOLSResult                                            |
//| Holds all regression outputs from a single OLS pass.             |
//+------------------------------------------------------------------+
struct SOLSResult
  {
   double            slope;          // Estimated slope β₁
   double            intercept;      // Estimated intercept β₀
   double            sse;            // Sum of squared errors
   double            x_mean;         // Mean of bar indices x̄
   double            sxx;            // Σ(xᵢ − x̄)²
   int               n;              // Number of observations used
   bool              valid;          // False if computation failed
  };

//+------------------------------------------------------------------+
//| Class: COLSStatistics                                            |
//| Fits an OLS regression line to a price array over the fixed      |
//| integer grid x = 0,1,..,count-1.                                 |
//+------------------------------------------------------------------+
class COLSStatistics
  {
public:
                     COLSStatistics(void);
                    ~COLSStatistics(void);

   //--- x_mean and sxx are precomputed by the caller because, for a
   //--- fixed window over the grid 0..count-1, they are constants:
   //---   x_mean = (count-1)/2,  sxx = count(count^2-1)/12.
   SOLSResult        Compute(const double &y[], int count,
                             double x_mean, double sxx);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
COLSStatistics::COLSStatistics(void)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
COLSStatistics::~COLSStatistics(void)
  {
  }

//+------------------------------------------------------------------+
//| COLSStatistics::Compute                                          |
//| Accepts a price array, its length, and the precomputed x-domain  |
//| constants x_mean and sxx. Only the y-dependent sums are computed |
//| here, in a single pass. Returns a populated SOLSResult.          |
//+------------------------------------------------------------------+
SOLSResult COLSStatistics::Compute(const double &y[], int count,
                                   double x_mean, double sxx)
  {
   SOLSResult result;
   result.valid = false;

   if(count < 3)
      return(result);

   if(MathAbs(sxx) < 1e-14)
      return(result);

//--- Accumulate only the y-dependent sums. The x-only sums are not
//--- needed because x_mean and sxx are supplied by the caller.
   double sum_y  = 0.0;
   double sum_xy = 0.0;
   double sum_yy = 0.0;

   for(int i = 0; i < count; i++)
     {
      double xi = (double)i;
      double yi = y[i];

      if(!MathIsValidNumber(yi))
         return(result);

      sum_y  += yi;
      sum_xy += xi * yi;
      sum_yy += yi * yi;
     }

   double n      = (double)count;
   double y_mean = sum_y / n;

//--- Sxy = Σ(xᵢ − x̄)(yᵢ − ȳ) = Σxᵢyᵢ − n·x̄·ȳ
   double sxy = sum_xy - n * x_mean * y_mean;

//--- OLS slope and intercept
   double slope     = sxy / sxx;
   double intercept = y_mean - slope * x_mean;

//--- SSE = Syy − β₁·Sxy, where Syy = Σyᵢ² − n·ȳ²
   double syy = sum_yy - n * y_mean * y_mean;
   double sse = syy - slope * sxy;

   if(sse < 0.0)
      sse = 0.0;

   result.slope     = slope;
   result.intercept = intercept;
   result.sse       = sse;
   result.x_mean    = x_mean;
   result.sxx       = sxx;
   result.n         = count;
   result.valid     = true;

   return(result);
  }

#endif
//+------------------------------------------------------------------+