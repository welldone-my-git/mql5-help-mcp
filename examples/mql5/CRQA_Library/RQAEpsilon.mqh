//+------------------------------------------------------------------+
//|                                                   RQAEpsilon.mqh |
//|                          RQA Library for MQL5                    |
//|             Automatic epsilon (threshold) selection              |
//+------------------------------------------------------------------+
#ifndef RQAEPSILON_MQH
#define RQAEPSILON_MQH

//+------------------------------------------------------------------+
//| Epsilon selection strategies                                     |
//+------------------------------------------------------------------+
enum ENUM_EPSILON_METHOD
  {
   EPSILON_FIXED         = 0,  // User-specified fixed value
   EPSILON_RR_TARGET     = 1,  // Bisection to hit a target RR (e.g. 5%)
   EPSILON_STD_FRACTION  = 2,  // Fraction of series std-deviation
   EPSILON_RANGE_FRACTION= 3   // Fraction of series range (max-min)
  };

//+------------------------------------------------------------------+
//| CRQAEpsilon — helper to auto-select epsilon                      |
//+------------------------------------------------------------------+
class CRQAEpsilon
  {
public:
   //--- Returns epsilon based on chosen strategy
   static double     Select(const double &series[], int N,
                            ENUM_EPSILON_METHOD method,
                            double param = 0.05);

private:
   static double     SeriesStdDev(const double &series[], int N);
   static double     SeriesRange(const double &series[], int N);
   static double     ApproxRR(const double &series[], int N,
                               double epsilon, int embDim, int delay);
  };

//+------------------------------------------------------------------+
//| Sample standard deviation of N elements                          |
//+------------------------------------------------------------------+
double CRQAEpsilon::SeriesStdDev(const double &series[], int N)
  {
   if(N < 2)
      return 1.0;
   double mean = 0;
   for(int i = 0; i < N; i++) mean += series[i];
   mean /= N;
   double var = 0;
   for(int i = 0; i < N; i++) var += (series[i] - mean) * (series[i] - mean);
   return MathSqrt(var / (N - 1));
  }

//+------------------------------------------------------------------+
//| Range (max - min) of N elements                                  |
//+------------------------------------------------------------------+
double CRQAEpsilon::SeriesRange(const double &series[], int N)
  {
   double mn = series[0], mx = series[0];
   for(int i = 1; i < N; i++)
     {
      if(series[i] < mn) mn = series[i];
      if(series[i] > mx) mx = series[i];
     }
   return mx - mn;
  }

//+------------------------------------------------------------------+
//| Quick approximate RR without building full matrix                |
//| Uses random sampling for speed                                   |
//+------------------------------------------------------------------+
double CRQAEpsilon::ApproxRR(const double &series[], int N,
                               double epsilon, int embDim, int delay)
  {
   int samples = MathMin(N, 200);
   int M       = N - (embDim - 1) * delay;
   if(M <= 0 || samples < 2) return 0.0;

   long rec = 0, total = 0;
   int  step = MathMax(1, M / samples);
   for(int i = 0; i < M; i += step)
     {
      for(int j = 0; j < M; j += step)
        {
         if(i == j) continue;
         double dist = 0;
         for(int d = 0; d < embDim; d++)
           {
            double diff = series[i + d * delay] - series[j + d * delay];
            dist += diff * diff;
           }
         dist = MathSqrt(dist);
         if(dist <= epsilon) rec++;
         total++;
        }
     }
   return (total > 0) ? (double)rec / total : 0.0;
  }

//+------------------------------------------------------------------+
//| Main selector                                                    |
//+------------------------------------------------------------------+
double CRQAEpsilon::Select(const double &series[], int N,
                            ENUM_EPSILON_METHOD method,
                            double param)
  {
   switch(method)
     {
      case EPSILON_FIXED:
         return param;

      case EPSILON_STD_FRACTION:
         return param * SeriesStdDev(series, N);

      case EPSILON_RANGE_FRACTION:
         return param * SeriesRange(series, N);

      case EPSILON_RR_TARGET:
        {
         double lo = 0.0, hi = SeriesRange(series, N);
         if(hi < 1e-12) return 1e-6;
         for(int iter = 0; iter < 40; iter++)
           {
            double mid = (lo + hi) * 0.5;
            double rr  = ApproxRR(series, N, mid, 1, 1);
            if(rr < param) lo = mid;
            else            hi = mid;
           }
         return (lo + hi) * 0.5;
        }
     }
   return param;
  }

#endif // RQAEPSILON_MQH
