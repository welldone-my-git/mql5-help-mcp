//+------------------------------------------------------------------+
//|                                                  RQAMetrics.mqh  |
//|                          RQA Library for MQL5                    |
//|             All RQA quantification metrics                       |
//+------------------------------------------------------------------+
#ifndef RQAMETRICS_MQH
#define RQAMETRICS_MQH

#include "RQAMatrix.mqh"

//+------------------------------------------------------------------+
//| Struct to hold all computed RQA results                          |
//+------------------------------------------------------------------+
struct SRQAResult
  {
   // --- Basic ---
   double   RR;          // Recurrence Rate
   double   DET;         // Determinism
   double   LAM;         // Laminarity
   double   TT;          // Trapping Time (avg vertical line)
   double   L;           // Average diagonal line length
   double   Lmax;        // Max diagonal line length
   double   Vmax;        // Max vertical line length
   double   ENTR;        // Shannon entropy of diagonal lines
   double   DIV;         // Divergence = 1 / Lmax
   double   RATIO;       // DET / RR

   // --- Trend ---
   double   TREND;       // Trend of recurrence density

   // --- Complexity ---
   double   COMPLEXITY;  // RR * DET (composite)

   void     Reset()
     {
      RR=0; DET=0; LAM=0; TT=0; L=0;
      Lmax=0; Vmax=0; ENTR=0; DIV=0;
      RATIO=0; TREND=0; COMPLEXITY=0;
     }
  };

//+------------------------------------------------------------------+
//| CRQAMetrics — computes all RQA measures from a CRQAMatrix        |
//+------------------------------------------------------------------+
class CRQAMetrics
  {
private:
   int               m_minDiagLine;   // minimum diagonal line length (lmin)
   int               m_minVertLine;   // minimum vertical line length (vmin)

   //--- internal helpers
   void              CountDiagonals(const CRQAMatrix &mat,
                                    int &lineLengths[]) const;
   void              CountVerticals(const CRQAMatrix &mat,
                                    int &lineLengths[]) const;
   double            ShannonEntropy(const int &lengths[], int total) const;
   double            ComputeTrend(const CRQAMatrix &mat) const;

public:
                     CRQAMetrics(int minDiagLine = 2, int minVertLine = 2);

   bool              Compute(const CRQAMatrix &mat, SRQAResult &result) const;

   void              SetMinDiagLine(int v) { m_minDiagLine = v; }
   void              SetMinVertLine(int v) { m_minVertLine = v; }
   int               MinDiagLine()    const { return m_minDiagLine; }
   int               MinVertLine()    const { return m_minVertLine; }
  };

//+------------------------------------------------------------------+
//| Constructor with configurable minimum line lengths               |
//+------------------------------------------------------------------+
CRQAMetrics::CRQAMetrics(int minDiagLine, int minVertLine)
   : m_minDiagLine(minDiagLine), m_minVertLine(minVertLine)
  {
  }

//+------------------------------------------------------------------+
//| Count diagonal line lengths (excluding main diagonal)            |
//+------------------------------------------------------------------+
void CRQAMetrics::CountDiagonals(const CRQAMatrix &mat,
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
           {
            len++;
           }
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
void CRQAMetrics::CountVerticals(const CRQAMatrix &mat,
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
           {
            len++;
           }
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
double CRQAMetrics::ShannonEntropy(const int &lengths[], int total) const
  {
   if(total == 0)
      return 0.0;
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
double CRQAMetrics::ComputeTrend(const CRQAMatrix &mat) const
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
      double x = (double)(d - numDiag / 2); // center
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
//| Main computation — fills SRQAResult                              |
//+------------------------------------------------------------------+
bool CRQAMetrics::Compute(const CRQAMatrix &mat, SRQAResult &result) const
  {
   result.Reset();
   int N = mat.Size();
   if(N < 2)
     {
      Print("RQAMetrics::Compute — matrix too small");
      return false;
     }

   long recCount = 0;
   long total    = (long)N * N - N;

   for(int i = 0; i < N; i++)
      for(int j = 0; j < N; j++)
         if(i != j && mat.Get(i, j))
            recCount++;
   result.RR = (total > 0) ? (double)recCount / total : 0.0;

   int diagLengths[];
   CountDiagonals(mat, diagLengths);

   long  diagPoints = 0, totalDiagLines = 0;
   int   lmax       = 0;
   long  diagInQual = 0; // points in lines >= lmin
   int   sz         = ArraySize(diagLengths);

   for(int l = m_minDiagLine; l < sz; l++)
     {
      if(diagLengths[l] > 0)
        {
         diagPoints    += (long)l * diagLengths[l];
         totalDiagLines += diagLengths[l];
         if(l > lmax)
            lmax = l;
        }
     }
   diagInQual = diagPoints;

   result.Lmax = (double)lmax;
   result.DIV  = (lmax > 0) ? 1.0 / lmax : 0.0;
   result.DET  = (recCount > 0) ? (double)diagInQual / recCount : 0.0;
   result.L    = (totalDiagLines > 0) ? (double)diagPoints / totalDiagLines : 0.0;
   result.ENTR = ShannonEntropy(diagLengths, (int)totalDiagLines);

   int vertLengths[];
   CountVerticals(mat, vertLengths);

   long vertPoints = 0, totalVertLines = 0;
   int  vmax       = 0;
   int  vsz        = ArraySize(vertLengths);

   for(int l = m_minVertLine; l < vsz; l++)
     {
      if(vertLengths[l] > 0)
        {
         vertPoints    += (long)l * vertLengths[l];
         totalVertLines += vertLengths[l];
         if(l > vmax)
            vmax = l;
        }
     }

   result.Vmax = (double)vmax;
   result.LAM  = (recCount > 0) ? (double)vertPoints / recCount : 0.0;
   result.TT   = (totalVertLines > 0) ? (double)vertPoints / totalVertLines : 0.0;

   result.RATIO      = (result.RR > 1e-12) ? result.DET / result.RR : 0.0;
   result.COMPLEXITY = result.RR * result.DET;
   result.TREND      = ComputeTrend(mat);

   return true;
  }

#endif // RQAMETRICS_MQH
