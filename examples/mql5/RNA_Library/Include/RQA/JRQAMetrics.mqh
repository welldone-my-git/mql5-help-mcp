//+------------------------------------------------------------------+
//|                                                  JRQAMetrics.mqh |
//|                          RQA Library for MQL5                    |
//|          Joint-RQA quantification metrics from CJRQAMatrix       |
//|                                                                  |
//|  Metrics computed on the NxN joint recurrence matrix:            |
//|    JRR    — Joint Recurrence Rate                                |
//|    JDET   — Joint Determinism (diagonal lines)                   |
//|    JL     — Average joint diagonal line length                   |
//|    JLmax  — Longest joint diagonal line                          |
//|    JENTR  — Shannon entropy of joint diagonal lines              |
//|    JDIV   — Joint Divergence = 1 / JLmax                         |
//|    JLAM   — Joint Laminarity (vertical lines)                    |
//|    JTT    — Joint Trapping Time (avg vertical line)              |
//|    JVmax  — Longest vertical line                                |
//|    JRATIO — JDET / JRR                                           |
//|    JTREND — Trend of joint recurrence density                    |
//|    JCOMPLEXITY — JRR * JDET                                      |
//+------------------------------------------------------------------+
#ifndef JRQAMETRICS_MQH
#define JRQAMETRICS_MQH

#include "JRQAMatrix.mqh"

//+------------------------------------------------------------------+
//| Struct — all JRQA results                                        |
//+------------------------------------------------------------------+
struct SJRQAResult
  {
   double   JRR;          // Joint Recurrence Rate
   double   JDET;         // Joint Determinism
   double   JLAM;         // Joint Laminarity
   double   JTT;          // Joint Trapping Time
   double   JL;           // Average joint diagonal line length
   double   JLmax;        // Max joint diagonal line length
   double   JVmax;        // Max vertical line length
   double   JENTR;        // Shannon entropy of joint diagonal lines
   double   JDIV;         // Divergence = 1 / JLmax
   double   JRATIO;       // JDET / JRR
   double   JTREND;       // Trend of joint recurrence density
   double   JCOMPLEXITY;  // JRR * JDET

   void     Reset()
     {
      JRR=0; JDET=0; JLAM=0; JTT=0; JL=0;
      JLmax=0; JVmax=0; JENTR=0; JDIV=0;
      JRATIO=0; JTREND=0; JCOMPLEXITY=0;
     }
  };

//+------------------------------------------------------------------+
//| CJRQAMetrics — computes all JRQA measures from CJRQAMatrix       |
//+------------------------------------------------------------------+
class CJRQAMetrics
  {
private:
   int               m_minDiagLine;
   int               m_minVertLine;

   void              CountDiagonals(const CJRQAMatrix &mat,
                                    int &lineLengths[]) const;
   void              CountVerticals(const CJRQAMatrix &mat,
                                    int &lineLengths[]) const;
   double            ShannonEntropy(const int &lengths[], int total) const;
   double            ComputeTrend(const CJRQAMatrix &mat) const;

public:
                     CJRQAMetrics(int minDiagLine = 2, int minVertLine = 2);

   bool              Compute(const CJRQAMatrix &mat, SJRQAResult &result) const;

   void              SetMinDiagLine(int v) { m_minDiagLine = v; }
   void              SetMinVertLine(int v) { m_minVertLine = v; }
   int               MinDiagLine()   const { return m_minDiagLine; }
   int               MinVertLine()   const { return m_minVertLine; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CJRQAMetrics::CJRQAMetrics(int minDiagLine, int minVertLine)
   : m_minDiagLine(minDiagLine), m_minVertLine(minVertLine)
  {
  }

//+------------------------------------------------------------------+
//| Count diagonal line lengths (excluding main diagonal)            |
//+------------------------------------------------------------------+
void CJRQAMetrics::CountDiagonals(const CJRQAMatrix &mat,
                                   int &lineLengths[]) const
  {
   int N = mat.Size();
   ArrayResize(lineLengths, N + 1);
   ArrayInitialize(lineLengths, 0);

   for(int diag = -(N - 1); diag <= (N - 1); diag++)
     {
      if(diag == 0)
         continue;

      int len = 0;
      int iStart = MathMax(0, -diag);
      int iEnd   = MathMin(N - 1, N - 1 - diag);

      for(int i = iStart; i <= iEnd; i++)
        {
         int j = i + diag;
         if(mat.Get(i, j))
            len++;
         else
           {
            if(len >= m_minDiagLine && len < N)
               lineLengths[len]++;
            len = 0;
           }
        }
      if(len >= m_minDiagLine && len < N)
         lineLengths[len]++;
     }
  }

//+------------------------------------------------------------------+
//| Count vertical line lengths                                      |
//+------------------------------------------------------------------+
void CJRQAMetrics::CountVerticals(const CJRQAMatrix &mat,
                                   int &lineLengths[]) const
  {
   int N = mat.Size();
   ArrayResize(lineLengths, N + 1);
   ArrayInitialize(lineLengths, 0);

   for(int j = 0; j < N; j++)
     {
      int len = 0;
      for(int i = 0; i < N; i++)
        {
         if(mat.Get(i, j))
            len++;
         else
           {
            if(len >= m_minVertLine)
               lineLengths[len]++;
            len = 0;
           }
        }
      if(len >= m_minVertLine)
         lineLengths[len]++;
     }
  }

//+------------------------------------------------------------------+
//| Shannon entropy of line length distribution                      |
//+------------------------------------------------------------------+
double CJRQAMetrics::ShannonEntropy(const int &lengths[], int total) const
  {
   if(total == 0) return 0.0;
   double entr = 0.0;
   int    sz   = ArraySize(lengths);
   for(int l = 0; l < sz; l++)
     {
      if(lengths[l] > 0)
        {
         double p = (double)lengths[l] / total;
         entr -= p * MathLog(p);
        }
     }
   return entr;
  }

//+------------------------------------------------------------------+
//| TREND: linear regression slope of diagonal density per strip     |
//+------------------------------------------------------------------+
double CJRQAMetrics::ComputeTrend(const CJRQAMatrix &mat) const
  {
   int N = mat.Size();
   if(N < 4)
      return 0.0;

   int numDiag = N - 1;
   double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
   for(int d = 1; d < N; d++)
     {
      int count = 0, total = N - d;
      for(int i = 0; i < total; i++)
         if(mat.Get(i, i + d))
            count++;
      double density = (total > 0) ? (double)count / total : 0.0;
      double x = (double)(d - numDiag / 2);
      sumX  += x;
      sumY  += density;
      sumXY += x * density;
      sumX2 += x * x;
     }
   double denom = (double)numDiag * sumX2 - sumX * sumX;
   if(MathAbs(denom) < 1e-12)
      return 0.0;
   return ((double)numDiag * sumXY - sumX * sumY) / denom;
  }

//+------------------------------------------------------------------+
//| Main computation — fills SJRQAResult                             |
//+------------------------------------------------------------------+
bool CJRQAMetrics::Compute(const CJRQAMatrix &mat, SJRQAResult &result) const
  {
   result.Reset();
   int N = mat.Size();
   if(N < 2)
     {
      Print("JRQAMetrics::Compute — matrix too small");
      return false;
     }

   long recCount = 0;
   long total    = (long)N * N - N;

   for(int i = 0; i < N; i++)
      for(int j = 0; j < N; j++)
         if(i != j && mat.Get(i, j))
            recCount++;
   result.JRR = (total > 0) ? (double)recCount / total : 0.0;

   int diagLengths[];
   CountDiagonals(mat, diagLengths);

   long  diagPoints = 0, totalDiagLines = 0;
   int   lmax       = 0;
   long  diagInQual = 0;
   int   sz         = ArraySize(diagLengths);

   for(int l = m_minDiagLine; l < sz; l++)
     {
      if(diagLengths[l] > 0)
        {
         diagPoints     += (long)l * diagLengths[l];
         totalDiagLines += diagLengths[l];
         if(l > lmax)
            lmax = l;
        }
     }
   diagInQual = diagPoints;

   result.JLmax = (double)lmax;
   result.JDIV  = (lmax > 0) ? 1.0 / lmax : 0.0;
   result.JDET  = (recCount > 0) ? (double)diagInQual / recCount : 0.0;
   result.JL    = (totalDiagLines > 0) ? (double)diagPoints / totalDiagLines : 0.0;
   result.JENTR = ShannonEntropy(diagLengths, (int)totalDiagLines);

   int vertLengths[];
   CountVerticals(mat, vertLengths);

   long vertPoints = 0, totalVertLines = 0;
   int  vmax       = 0;
   int  vsz        = ArraySize(vertLengths);

   for(int l = m_minVertLine; l < vsz; l++)
     {
      if(vertLengths[l] > 0)
        {
         vertPoints     += (long)l * vertLengths[l];
         totalVertLines += vertLengths[l];
         if(l > vmax)
            vmax = l;
        }
     }

   result.JVmax       = (double)vmax;
   result.JLAM        = (recCount > 0) ? (double)vertPoints / recCount : 0.0;
   result.JTT         = (totalVertLines > 0) ? (double)vertPoints / totalVertLines : 0.0;
   result.JRATIO      = (result.JRR > 1e-12) ? result.JDET / result.JRR : 0.0;
   result.JCOMPLEXITY = result.JRR * result.JDET;
   result.JTREND      = ComputeTrend(mat);

   return true;
  }

#endif // JRQAMETRICS_MQH
