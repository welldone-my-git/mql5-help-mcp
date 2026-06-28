//+------------------------------------------------------------------+
//|                                                TDistribution.mqh |
//| Student's t critical value approximation for arbitrary df.       |
//+------------------------------------------------------------------+
#ifndef __T_DISTRIBUTION_MQH__
#define __T_DISTRIBUTION_MQH__

//+------------------------------------------------------------------+
//| Class: CTDistribution                                            |
//| Provides two-tailed t critical values via rational approximation.|
//| All public results signal failure through a negative return so   |
//| that callers can detect invalid input rather than receiving a    |
//| silently substituted value.                                      |
//+------------------------------------------------------------------+
class CTDistribution
  {
public:
                     CTDistribution(void);
                    ~CTDistribution(void);

   //--- Returns t_{alpha/2, df}; returns -1.0 on invalid input.
   double            CriticalValue(int degrees_of_freedom, double alpha);

private:
   double            InverseNormalApprox(double p);
   double            TQuantileApprox(double p, int df);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTDistribution::CTDistribution(void)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTDistribution::~CTDistribution(void)
  {
  }

//+------------------------------------------------------------------+
//| CTDistribution::CriticalValue                                    |
//| Returns t_{alpha/2, df} — the upper tail critical value for a    |
//| two-tailed interval at significance level alpha.                 |
//| Example: alpha=0.05, df=48 returns approximately 2.0106.         |
//| Returns -1.0 if df < 1 or alpha is outside (0, 1), so the caller |
//| can treat the result as invalid instead of proceeding with a     |
//| substituted constant.                                            |
//+------------------------------------------------------------------+
double CTDistribution::CriticalValue(int degrees_of_freedom, double alpha)
  {
//--- Reject invalid degrees of freedom and significance levels.
   if(degrees_of_freedom < 1)
      return(-1.0);
   if(alpha <= 0.0 || alpha >= 1.0)
      return(-1.0);

   double p = 1.0 - alpha * 0.5;
   return(TQuantileApprox(p, degrees_of_freedom));
  }

//+------------------------------------------------------------------+
//| CTDistribution::InverseNormalApprox                              |
//| Rational approximation to the inverse standard normal CDF.       |
//| Accuracy: absolute error < 4.5e-4 for 0 < p < 1.                 |
//| Source: Abramowitz and Stegun 26.2.17                            |
//+------------------------------------------------------------------+
double CTDistribution::InverseNormalApprox(double p)
  {
   if(p <= 0.0)
      return(-1e15);
   if(p >= 1.0)
      return(1e15);

   double sign = 1.0;
   double q    = p;

   if(q < 0.5)
     {
      sign = -1.0;
      q    = 1.0 - q;
     }

   double t = MathSqrt(-2.0 * MathLog(1.0 - q));

   double c0 = 2.515517;
   double c1 = 0.802853;
   double c2 = 0.010328;
   double d1 = 1.432788;
   double d2 = 0.189269;
   double d3 = 0.001308;

   double numerator   = c0 + c1 * t + c2 * t * t;
   double denominator = 1.0 + d1 * t + d2 * t * t + d3 * t * t * t;

   double z = t - numerator / denominator;

   return(sign * z);
  }

//+------------------------------------------------------------------+
//| CTDistribution::TQuantileApprox                                  |
//| Approximates the t-distribution quantile at probability p        |
//| with the given degrees of freedom.                               |
//| Uses the Cornish-Fisher expansion for moderate-to-large df,      |
//| and a direct closed-form for df=1 and df=2.                      |
//+------------------------------------------------------------------+
double CTDistribution::TQuantileApprox(double p, int df)
  {
//--- Handle special cases with exact closed-form results
   if(df == 1)
     {
      //--- Cauchy distribution: t = tan(π·(p − 0.5))
      return(MathTan(M_PI * (p - 0.5)));
     }

   if(df == 2)
     {
      //--- t₂ quantile: t = (2p−1)/√(2p(1−p))
      double q = 2.0 * p - 1.0;
      double r = 2.0 * p * (1.0 - p);
      if(r < 1e-15)
         return(1e15);
      return(q / MathSqrt(r));
     }

//--- For df >= 3 use the Cornish-Fisher expansion
//--- t ≈ z + (z³+z)/(4·df) + (5z⁵+16z³+3z)/(96·df²) + ...
//--- where z is the corresponding normal quantile

   double z  = InverseNormalApprox(p);
   double z2 = z * z;
   double z3 = z2 * z;
   double z5 = z3 * z2;

   double v  = (double)df;
   double v2 = v * v;

   double t = z
              + (z3 + z) / (4.0 * v)
              + (5.0 * z5 + 16.0 * z3 + 3.0 * z) / (96.0 * v2)
              + (3.0 * z5 * z2 + 19.0 * z5 + 17.0 * z3 - 15.0 * z) / (384.0 * v2 * v);

   return(t);
  }

#endif
//+------------------------------------------------------------------+