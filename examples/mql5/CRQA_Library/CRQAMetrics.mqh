//+------------------------------------------------------------------+
//|                                                  CRQAMetrics.mqh |
//|                          RQA Library for MQL5                    |
//|          Cross-RQA quantification metrics from CCRQAMatrix       |
//|                                                                  |
//|  Metrics defined for an N x M (non-square) cross-recurrence      |
//|  matrix:                                                         |
//|    CRR    — Cross Recurrence Rate                                |
//|    CDET   — Cross Determinism (diagonal lines in CR matrix)      |
//|    CL     — Average cross diagonal line length                   |
//|    CLmax  — Longest cross diagonal line                          |
//|    CENTR  — Shannon entropy of cross diagonal lines              |
//|    CDIV   — Cross Divergence = 1 / CLmax                         |
//|    CLAM   — Cross Laminarity (vertical lines)                    |
//|    CTT    — Cross Trapping Time (avg vertical line)              |
//|    CVmax  — Longest vertical line                                |
//|    CRATIO — CDET / CRR                                           |
//+------------------------------------------------------------------+
#ifndef CRQAMETRICS_MQH
#define CRQAMETRICS_MQH

#include "CRQAMatrix.mqh"

//+------------------------------------------------------------------+
//| Struct — all CRQA results                                        |
//+------------------------------------------------------------------+
struct SCRQAResult
  {
   double   CRR;     // Cross Recurrence Rate
   double   CDET;    // Cross Determinism
   double   CL;      // Average cross-diagonal line length
   double   CLmax;   // Max cross-diagonal line length
   double   CENTR;   // Shannon entropy of cross-diagonal lines
   double   CDIV;    // Divergence = 1 / CLmax
   double   CLAM;    // Cross Laminarity
   double   CTT;     // Cross Trapping Time
   double   CVmax;   // Max vertical line length
   double   CRATIO;  // CDET / CRR

   void     Reset()
     {
      CRR=0; CDET=0; CL=0; CLmax=0;
      CENTR=0; CDIV=0; CLAM=0;
      CTT=0; CVmax=0; CRATIO=0;
     }
  };

//+------------------------------------------------------------------+
//| CCRQAMetrics — computes all CRQA measures from CCRQAMatrix       |
//+------------------------------------------------------------------+
class CCRQAMetrics
  {
private:
   int               m_minDiagLine;
   int               m_minVertLine;

   //--- internal helpers
   void              CountDiagonals(const CCRQAMatrix &mat,
                                    int &lineLengths[]) const;
   void              CountVerticals(const CCRQAMatrix &mat,
                                    int &lineLengths[]) const;
   double            ShannonEntropy(const int &lengths[], int total) const;

public:
                     CCRQAMetrics(int minDiagLine = 2, int minVertLine = 2);

   bool              Compute(const CCRQAMatrix &mat, SCRQAResult &result) const;

   void              SetMinDiagLine(int v) { m_minDiagLine = v; }
   void              SetMinVertLine(int v) { m_minVertLine = v; }
   int               MinDiagLine()   const { return m_minDiagLine; }
   int               MinVertLine()   const { return m_minVertLine; }
  };

//+------------------------------------------------------------------+
//| Constructor with configurable minimum line lengths               |
//+------------------------------------------------------------------+
CCRQAMetrics::CCRQAMetrics(int minDiagLine, int minVertLine)
   : m_minDiagLine(minDiagLine), m_minVertLine(minVertLine)
  {
  }

//+------------------------------------------------------------------+
//| Count diagonal lines in an NxM (possibly non-square) matrix      |
//|  Diagonals run parallel to the main anti-diagonal (j - i = k)    |
//|  k ranges from -(N-1) to +(M-1)                                  |
//+------------------------------------------------------------------+
void CCRQAMetrics::CountDiagonals(const CCRQAMatrix &mat,
                                   int &lineLengths[]) const
  {
   int N = mat.SizeN();   // rows
   int M = mat.SizeM();   // cols
   int maxLen = MathMax(N, M);

   ArrayResize(lineLengths, maxLen + 1);
   ArrayInitialize(lineLengths, 0);

   for(int k = -(N - 1); k <= (M - 1); k++)
     {
      int len = 0;
      // i ranges where both i and j=i+k are valid
      int iStart = MathMax(0, -k);
      int iEnd   = MathMin(N - 1, M - 1 - k);

      for(int i = iStart; i <= iEnd; i++)
        {
         int j = i + k;
         if(mat.Get(i, j))
           {
            len++;
           }
         else
           {
            if(len >= m_minDiagLine)
               lineLengths[MathMin(len, maxLen)]++;
            len = 0;
           }
        }
      if(len >= m_minDiagLine)
         lineLengths[MathMin(len, maxLen)]++;
     }
  }

//+------------------------------------------------------------------+
//| Count vertical lines (fixed column j, vary row i)                |
//+------------------------------------------------------------------+
void CCRQAMetrics::CountVerticals(const CCRQAMatrix &mat,
                                   int &lineLengths[]) const
  {
   int N = mat.SizeN();
   int M = mat.SizeM();

   ArrayResize(lineLengths, N + 1);
   ArrayInitialize(lineLengths, 0);

   for(int j = 0; j < M; j++)
     {
      int len = 0;
      for(int i = 0; i < N; i++)
        {
         if(mat.Get(i, j))
           {
            len++;
           }
         else
           {
            if(len >= m_minVertLine)
               lineLengths[MathMin(len, N)]++;
            len = 0;
           }
        }
      if(len >= m_minVertLine)
         lineLengths[MathMin(len, N)]++;
     }
  }

//+------------------------------------------------------------------+
//| Shannon entropy of line length distribution                      |
//+------------------------------------------------------------------+
double CCRQAMetrics::ShannonEntropy(const int &lengths[], int total) const
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
//| Main computation — fills SCRQAResult                             |
//+------------------------------------------------------------------+
bool CCRQAMetrics::Compute(const CCRQAMatrix &mat, SCRQAResult &result) const
  {
   result.Reset();
   int N = mat.SizeN();
   int M = mat.SizeM();

   if(N < 2 || M < 2)
     {
      Print("CCRQAMetrics::Compute — matrix too small");
      return false;
     }

   long recCount = 0;
   long total    = (long)N * M;
   for(int i = 0; i < N; i++)
      for(int j = 0; j < M; j++)
         if(mat.Get(i, j))
            recCount++;
   result.CRR = (total > 0) ? (double)recCount / total : 0.0;

   int diagLengths[];
   CountDiagonals(mat, diagLengths);

   long diagPoints     = 0;
   long totalDiagLines = 0;
   int  lmax           = 0;
   int  sz             = ArraySize(diagLengths);

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

   result.CLmax  = (double)lmax;
   result.CDIV   = (lmax > 0) ? 1.0 / lmax : 0.0;
   result.CDET   = (recCount > 0) ? (double)diagPoints / recCount : 0.0;
   result.CL     = (totalDiagLines > 0) ? (double)diagPoints / totalDiagLines : 0.0;
   result.CENTR  = ShannonEntropy(diagLengths, (int)totalDiagLines);

   int vertLengths[];
   CountVerticals(mat, vertLengths);

   long vertPoints     = 0;
   long totalVertLines = 0;
   int  vmax           = 0;
   int  vsz            = ArraySize(vertLengths);

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

   result.CVmax  = (double)vmax;
   result.CLAM   = (recCount > 0) ? (double)vertPoints / recCount : 0.0;
   result.CTT    = (totalVertLines > 0) ? (double)vertPoints / totalVertLines : 0.0;

   result.CRATIO = (result.CRR > 1e-12) ? result.CDET / result.CRR : 0.0;

   return true;
  }

#endif // CRQAMETRICS_MQH
