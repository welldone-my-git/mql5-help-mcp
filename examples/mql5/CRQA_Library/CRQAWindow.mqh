//+------------------------------------------------------------------+
//|                                                  CRQAWindow.mqh  |
//|                          RQA Library for MQL5                    |
//|        Windowed (rolling) Cross-RQA for two time series          |
//|                                                                  |
//|  OpenCL-accelerated: GPU computes recurrence matrices in         |
//|  batches, CPU scans boolean results for line metrics.            |
//|  Falls back to CPU-only if OpenCL is unavailable.                |
//+------------------------------------------------------------------+
#ifndef CRQAWINDOW_MQH
#define CRQAWINDOW_MQH

#include "CRQAMatrix.mqh"
#include "CRQAMetrics.mqh"
#include <OpenCL/OpenCL.mqh>

//+------------------------------------------------------------------+
//| OpenCL kernel source — embedded as string constant               |
//+------------------------------------------------------------------+
const string cl_crqa_source =
   "__kernel void crqa_recurrence(                                  \r\n"
   "   __global const float *seriesX,                               \r\n"
   "   __global const float *seriesY,                               \r\n"
   "   __global int         *outR,                                  \r\n"
   "   const int             N,                                     \r\n"
   "   const int             embDim,                                \r\n"
   "   const int             tau,                                   \r\n"
   "   const int             norm,                                  \r\n"
   "   const float           epsilon,                               \r\n"
   "   const int             step,                                  \r\n"
   "   const int             baseWin)                               \r\n"
   "{                                                               \r\n"
   "   int i = get_global_id(0);                                    \r\n"
   "   int j = get_global_id(1);                                    \r\n"
   "   int w = get_global_id(2);                                    \r\n"
   "   if(i >= N || j >= N) return;                                 \r\n"
   "   int winStart = (baseWin + w) * step;                         \r\n"
   "   float dist = 0.0f;                                           \r\n"
   "   if(embDim == 1) {                                            \r\n"
   "      float diff = seriesX[winStart + i] - seriesY[winStart + j]; \r\n"
   "      dist = (norm == 1) ? diff * diff : fabs(diff);            \r\n"
   "   } else {                                                     \r\n"
   "      for(int d = 0; d < embDim; d++) {                         \r\n"
   "         float diff = seriesX[winStart + i + d * tau]            \r\n"
   "                    - seriesY[winStart + j + d * tau];           \r\n"
   "         if(norm == 0)      dist = fmax(dist, fabs(diff));      \r\n"
   "         else if(norm == 1) dist += diff * diff;                \r\n"
   "         else               dist += fabs(diff);                 \r\n"
   "      }                                                         \r\n"
   "   }                                                            \r\n"
   "   float threshold = (norm == 1) ? epsilon * epsilon : epsilon;  \r\n"
   "   outR[(w * N + i) * N + j] = (dist <= threshold) ? 1 : 0;    \r\n"
   "}                                                               \r\n";

struct SCRQAWindowResult
  {
   int          barIndex;
   SCRQAResult  metrics;
  };

class CCRQAWindow
  {
private:
   int               m_windowSize;
   int               m_step;
   double            m_epsilon;
   int               m_embDim;
   int               m_delay;
   ENUM_RQA_NORM     m_norm;
   int               m_minDiagLine;
   int               m_minVertLine;

   //--- GPU path
   bool              RunGPU(const double &seriesX[], const double &seriesY[],
                            int seriesLen, int numWindows,
                            SCRQAWindowResult &results[]);

   //--- CPU fallback for a single window
   void              ComputeFusedCPU(const double &sX[], int offX,
                                     const double &sY[], int offY,
                                     SCRQAResult &result);

   //--- Scan boolean matrix for all CRQA metrics
   void              ScanMetrics(const int &R[], int N, int baseIdx,
                                 SCRQAResult &result);

public:
                     CCRQAWindow();

   void              SetWindow(int windowSize, int step = 1)   { m_windowSize = windowSize; m_step = step; }
   void              SetEpsilon(double eps)                     { m_epsilon = eps; }
   void              SetEmbedding(int dim, int delay)           { m_embDim = dim; m_delay = delay; }
   void              SetNorm(ENUM_RQA_NORM norm)                { m_norm = norm; }
   void              SetMinLines(int diagMin, int vertMin)      { m_minDiagLine = diagMin; m_minVertLine = vertMin; }

   bool              Run(const double &seriesX[], int lenX,
                         const double &seriesY[], int lenY,
                         SCRQAWindowResult &results[]);

   static void       ExtractCRR  (const SCRQAWindowResult &r[], double &out[]);
   static void       ExtractCDET (const SCRQAWindowResult &r[], double &out[]);
   static void       ExtractCLAM (const SCRQAWindowResult &r[], double &out[]);
   static void       ExtractCTT  (const SCRQAWindowResult &r[], double &out[]);
   static void       ExtractCENTR(const SCRQAWindowResult &r[], double &out[]);
   static void       ExtractCLmax(const SCRQAWindowResult &r[], double &out[]);
  };

//+------------------------------------------------------------------+
//| Default constructor                                              |
//+------------------------------------------------------------------+
CCRQAWindow::CCRQAWindow()
   : m_windowSize(50), m_step(1), m_epsilon(0.1), m_embDim(1),
     m_delay(1), m_norm(RQA_NORM_EUCLIDEAN),
     m_minDiagLine(2), m_minVertLine(2)
  {
  }

//+------------------------------------------------------------------+
//| Scan a flat int R[N*N] sub-array for CRQA metrics                |
//+------------------------------------------------------------------+
void CCRQAWindow::ScanMetrics(const int &R[], int N, int baseIdx,
                               SCRQAResult &result)
  {
   result.Reset();
   if(N < 2) return;

   long NM = (long)N * N;

   long recCount = 0;
   for(int idx = 0; idx < (int)NM; idx++)
      if(R[baseIdx + idx] != 0)
         recCount++;

   result.CRR = (NM > 0) ? (double)recCount / NM : 0.0;

   int diagHist[];
   ArrayResize(diagHist, N + 1);
   ArrayInitialize(diagHist, 0);

   for(int k = -(N - 1); k <= (N - 1); k++)
     {
      int iS = (k < 0) ? -k : 0;
      int iE = (k < 0) ? N - 1 : N - 1 - k;
      int len = 0;
      for(int i = iS; i <= iE; i++)
        {
         if(R[baseIdx + i * N + (i + k)] != 0)
            len++;
         else
           {
            if(len >= m_minDiagLine) diagHist[len]++;
            len = 0;
           }
        }
      if(len >= m_minDiagLine) diagHist[len]++;
     }

   long diagPoints = 0, totalDiagLines = 0;
   int  lmax = 0;
   for(int l = m_minDiagLine; l <= N; l++)
      if(diagHist[l] > 0)
        { diagPoints += (long)l * diagHist[l]; totalDiagLines += diagHist[l]; lmax = l; }

   result.CLmax = (double)lmax;
   result.CDIV  = (lmax > 0) ? 1.0 / lmax : 0.0;
   result.CDET  = (recCount > 0) ? (double)diagPoints / recCount : 0.0;
   result.CL    = (totalDiagLines > 0) ? (double)diagPoints / totalDiagLines : 0.0;

   if(totalDiagLines > 0)
     {
      double entr = 0.0;
      for(int l = m_minDiagLine; l <= N; l++)
         if(diagHist[l] > 0)
           { double p = (double)diagHist[l] / totalDiagLines; entr -= p * MathLog(p); }
      result.CENTR = entr;
     }

   int vertHist[];
   ArrayResize(vertHist, N + 1);
   ArrayInitialize(vertHist, 0);

   for(int j = 0; j < N; j++)
     {
      int len = 0;
      for(int i = 0; i < N; i++)
        {
         if(R[baseIdx + i * N + j] != 0)
            len++;
         else
           { if(len >= m_minVertLine) vertHist[len]++; len = 0; }
        }
      if(len >= m_minVertLine) vertHist[len]++;
     }

   long vertPoints = 0, totalVertLines = 0;
   int  vmax = 0;
   for(int l = m_minVertLine; l <= N; l++)
      if(vertHist[l] > 0)
        { vertPoints += (long)l * vertHist[l]; totalVertLines += vertHist[l]; vmax = l; }

   result.CVmax  = (double)vmax;
   result.CLAM   = (recCount > 0) ? (double)vertPoints / recCount : 0.0;
   result.CTT    = (totalVertLines > 0) ? (double)vertPoints / totalVertLines : 0.0;
   result.CRATIO = (result.CRR > 1e-12) ? result.CDET / result.CRR : 0.0;
  }

//+------------------------------------------------------------------+
//| GPU path — using COpenCL wrapper                                 |
//+------------------------------------------------------------------+
bool CCRQAWindow::RunGPU(const double &seriesX[], const double &seriesY[],
                          int seriesLen, int numWindows,
                          SCRQAWindowResult &results[])
  {
   int N = m_windowSize - (m_embDim - 1) * m_delay;
   if(N < 2) return false;

   float fSeriesX[], fSeriesY[];
   ArrayResize(fSeriesX, seriesLen);
   ArrayResize(fSeriesY, seriesLen);
   for(int i = 0; i < seriesLen; i++)
     {
      fSeriesX[i] = (float)seriesX[i];
      fSeriesY[i] = (float)seriesY[i];
     }

   COpenCL ocl;
   if(!ocl.Initialize(cl_crqa_source, true))
     {
      Print("CRQA: OpenCL init failed");
      return false;
     }

   if(!ocl.SetKernelsCount(1) || !ocl.KernelCreate(0, "crqa_recurrence"))
     {
      Print("CRQA: kernel create failed");
      ocl.Shutdown();
      return false;
     }

   if(!ocl.SetBuffersCount(3))
     {
      ocl.Shutdown();
      return false;
     }

   if(!ocl.BufferFromArray(0, fSeriesX, 0, seriesLen, CL_MEM_READ_ONLY) ||
      !ocl.BufferFromArray(1, fSeriesY, 0, seriesLen, CL_MEM_READ_ONLY))
     {
      Print("CRQA: buffer upload failed");
      ocl.Shutdown();
      return false;
     }

   ocl.SetArgumentBuffer(0, 0, 0);
   ocl.SetArgumentBuffer(0, 1, 1);
   ocl.SetArgument(0, 3, N);
   ocl.SetArgument(0, 4, m_embDim);
   ocl.SetArgument(0, 5, m_delay);
   ocl.SetArgument(0, 6, (int)m_norm);
   ocl.SetArgument(0, 7, (float)m_epsilon);
   ocl.SetArgument(0, 8, m_step);

   long cellsPerWin = (long)N * N;
   int  maxBatch = (int)MathMin((long)numWindows,
                                64L * 1024 * 1024 / (cellsPerWin * (long)sizeof(int)));
   if(maxBatch < 1) maxBatch = 1;

   ArrayResize(results, numWindows);

   bool ok = true;
   int processed = 0;

   while(processed < numWindows && ok)
     {
      int batchSize   = MathMin(maxBatch, numWindows - processed);
      int totalCells  = batchSize * (int)cellsPerWin;

      ocl.BufferFree(2);
      if(!ocl.BufferCreate(2, totalCells * sizeof(int), CL_MEM_WRITE_ONLY))
        { ok = false; break; }

      ocl.SetArgumentBuffer(0, 2, 2);
      ocl.SetArgument(0, 9, processed);

      uint gOff[3]  = {0, 0, 0};
      uint gWork[3] = {(uint)N, (uint)N, (uint)batchSize};

      if(!ocl.Execute(0, 3, gOff, gWork))
        { ok = false; break; }

      int rBuf[];
      ArrayResize(rBuf, totalCells);
      if(!ocl.BufferRead(2, rBuf, 0, 0, totalCells))
        { ok = false; break; }

      for(int b = 0; b < batchSize; b++)
        {
         int winIdx = processed + b;
         results[winIdx].barIndex = winIdx * m_step;
         ScanMetrics(rBuf, N, b * (int)cellsPerWin, results[winIdx].metrics);
        }

      processed += batchSize;
     }

   ocl.Shutdown();
   return ok;
  }

//+------------------------------------------------------------------+
//| CPU fallback — single window fused compute                       |
//+------------------------------------------------------------------+
void CCRQAWindow::ComputeFusedCPU(const double &sX[], int offX,
                                   const double &sY[], int offY,
                                   SCRQAResult &result)
  {
   result.Reset();

   int N = m_windowSize - (m_embDim - 1) * m_delay;
   if(N <= 1) return;

   long NM = (long)N * N;
   double epsSq = m_epsilon * m_epsilon;

   int diagHist[], vertHist[];
   ArrayResize(diagHist, N + 1);
   ArrayResize(vertHist, N + 1);
   ArrayInitialize(diagHist, 0);
   ArrayInitialize(vertHist, 0);

   long recCount = 0;

   if(m_embDim == 1 && m_norm == RQA_NORM_EUCLIDEAN)
     {
      for(int k = -(N - 1); k <= (N - 1); k++)
        {
         int iS = (k < 0) ? -k : 0;
         int iE = (k < 0) ? N - 1 : N - 1 - k;
         int len = 0;
         for(int i = iS; i <= iE; i++)
           {
            double diff = sX[offX + i] - sY[offY + i + k];
            if(diff * diff <= epsSq)
              { len++; recCount++; }
            else
              { if(len >= m_minDiagLine) diagHist[len]++; len = 0; }
           }
         if(len >= m_minDiagLine) diagHist[len]++;
        }
      for(int j = 0; j < N; j++)
        {
         int len = 0;
         double yj = sY[offY + j];
         for(int i = 0; i < N; i++)
           {
            double diff = sX[offX + i] - yj;
            if(diff * diff <= epsSq) len++;
            else { if(len >= m_minVertLine) vertHist[len]++; len = 0; }
           }
         if(len >= m_minVertLine) vertHist[len]++;
        }
     }
   else
     {
      bool useEucSq = (m_norm == RQA_NORM_EUCLIDEAN);
      double epsComp = useEucSq ? epsSq : m_epsilon;

      for(int k = -(N - 1); k <= (N - 1); k++)
        {
         int iS = (k < 0) ? -k : 0;
         int iE = (k < 0) ? N - 1 : N - 1 - k;
         int len = 0;
         for(int i = iS; i <= iE; i++)
           {
            double dist = 0.0;
            for(int d = 0; d < m_embDim; d++)
              {
               double diff = sX[offX + i + d * m_delay]
                           - sY[offY + i + k + d * m_delay];
               if(useEucSq)       dist += diff * diff;
               else if(m_norm == RQA_NORM_MAX) dist = MathMax(dist, MathAbs(diff));
               else               dist += MathAbs(diff);
              }
            if(dist <= epsComp) { len++; recCount++; }
            else { if(len >= m_minDiagLine) diagHist[len]++; len = 0; }
           }
         if(len >= m_minDiagLine) diagHist[len]++;
        }
      for(int j = 0; j < N; j++)
        {
         int len = 0;
         for(int i = 0; i < N; i++)
           {
            double dist = 0.0;
            for(int d = 0; d < m_embDim; d++)
              {
               double diff = sX[offX + i + d * m_delay]
                           - sY[offY + j + d * m_delay];
               if(useEucSq)       dist += diff * diff;
               else if(m_norm == RQA_NORM_MAX) dist = MathMax(dist, MathAbs(diff));
               else               dist += MathAbs(diff);
              }
            if(dist <= epsComp) len++;
            else { if(len >= m_minVertLine) vertHist[len]++; len = 0; }
           }
         if(len >= m_minVertLine) vertHist[len]++;
        }
     }

   result.CRR = (NM > 0) ? (double)recCount / NM : 0.0;

   long diagPoints = 0, totalDiagLines = 0;
   int lmax = 0;
   for(int l = m_minDiagLine; l <= N; l++)
      if(diagHist[l] > 0)
        { diagPoints += (long)l * diagHist[l]; totalDiagLines += diagHist[l]; lmax = l; }

   result.CLmax = (double)lmax;
   result.CDIV  = (lmax > 0) ? 1.0 / lmax : 0.0;
   result.CDET  = (recCount > 0) ? (double)diagPoints / recCount : 0.0;
   result.CL    = (totalDiagLines > 0) ? (double)diagPoints / totalDiagLines : 0.0;

   if(totalDiagLines > 0)
     {
      double entr = 0.0;
      for(int l = m_minDiagLine; l <= N; l++)
         if(diagHist[l] > 0)
           { double p = (double)diagHist[l] / totalDiagLines; entr -= p * MathLog(p); }
      result.CENTR = entr;
     }

   long vertPoints = 0, totalVertLines = 0;
   int vmax = 0;
   for(int l = m_minVertLine; l <= N; l++)
      if(vertHist[l] > 0)
        { vertPoints += (long)l * vertHist[l]; totalVertLines += vertHist[l]; vmax = l; }

   result.CVmax  = (double)vmax;
   result.CLAM   = (recCount > 0) ? (double)vertPoints / recCount : 0.0;
   result.CTT    = (totalVertLines > 0) ? (double)vertPoints / totalVertLines : 0.0;
   result.CRATIO = (result.CRR > 1e-12) ? result.CDET / result.CRR : 0.0;
  }

//+------------------------------------------------------------------+
//| Main entry — tries GPU, falls back to CPU                        |
//+------------------------------------------------------------------+
bool CCRQAWindow::Run(const double &seriesX[], int lenX,
                       const double &seriesY[], int lenY,
                       SCRQAWindowResult &results[])
  {
   int minLen = MathMin(lenX, lenY);
   if(minLen < m_windowSize)
     {
      Print("CCRQAWindow::Run — series shorter than window");
      return false;
     }

   int numWindows = (minLen - m_windowSize) / m_step + 1;

   if(RunGPU(seriesX, seriesY, minLen, numWindows, results))
      return true;

   Print("CRQA: OpenCL unavailable, using CPU fallback");
   ArrayResize(results, numWindows);
   for(int idx = 0; idx < numWindows; idx++)
     {
      int start = idx * m_step;
      results[idx].barIndex = start;
      ComputeFusedCPU(seriesX, start, seriesY, start, results[idx].metrics);
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Extract single-metric arrays from windowed CRQA results          |
//+------------------------------------------------------------------+
void CCRQAWindow::ExtractCRR(const SCRQAWindowResult &r[], double &out[])
  { int n=ArraySize(r); ArrayResize(out,n); for(int i=0;i<n;i++) out[i]=r[i].metrics.CRR; }
void CCRQAWindow::ExtractCDET(const SCRQAWindowResult &r[], double &out[])
  { int n=ArraySize(r); ArrayResize(out,n); for(int i=0;i<n;i++) out[i]=r[i].metrics.CDET; }
void CCRQAWindow::ExtractCLAM(const SCRQAWindowResult &r[], double &out[])
  { int n=ArraySize(r); ArrayResize(out,n); for(int i=0;i<n;i++) out[i]=r[i].metrics.CLAM; }
void CCRQAWindow::ExtractCTT(const SCRQAWindowResult &r[], double &out[])
  { int n=ArraySize(r); ArrayResize(out,n); for(int i=0;i<n;i++) out[i]=r[i].metrics.CTT; }
void CCRQAWindow::ExtractCENTR(const SCRQAWindowResult &r[], double &out[])
  { int n=ArraySize(r); ArrayResize(out,n); for(int i=0;i<n;i++) out[i]=r[i].metrics.CENTR; }
void CCRQAWindow::ExtractCLmax(const SCRQAWindowResult &r[], double &out[])
  { int n=ArraySize(r); ArrayResize(out,n); for(int i=0;i<n;i++) out[i]=r[i].metrics.CLmax; }

#endif // CRQAWINDOW_MQH
