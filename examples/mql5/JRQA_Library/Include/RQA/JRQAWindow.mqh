//+------------------------------------------------------------------+
//|                                                  JRQAWindow.mqh  |
//|                          RQA Library for MQL5                    |
//|        Windowed (rolling) Joint-RQA for two time series          |
//|                                                                  |
//|  OpenCL-accelerated: GPU computes both self-recurrence matrices  |
//|  and their AND in a single kernel pass.                          |
//|  Falls back to CPU-only if OpenCL is unavailable.                |
//+------------------------------------------------------------------+
#ifndef JRQAWINDOW_MQH
#define JRQAWINDOW_MQH

#include "JRQAMatrix.mqh"
#include "JRQAMetrics.mqh"
#include <OpenCL/OpenCL.mqh>

//+------------------------------------------------------------------+
//| OpenCL kernel — joint recurrence in a single pass                |
//|  For each (i,j,w): compute distX = ||x_i - x_j|| and             |
//|  distY = ||y_i - y_j||, output JR = (distX<=epsX)&&(distY<=epsY) |
//+------------------------------------------------------------------+
const string cl_jrqa_source =
   "__kernel void jrqa_recurrence(                                  \r\n"
   "   __global const float *seriesX,                               \r\n"
   "   __global const float *seriesY,                               \r\n"
   "   __global int         *outR,                                  \r\n"
   "   const int             N,                                     \r\n"
   "   const int             embDim,                                \r\n"
   "   const int             tau,                                   \r\n"
   "   const int             norm,                                  \r\n"
   "   const float           epsilonX,                              \r\n"
   "   const float           epsilonY,                              \r\n"
   "   const int             step,                                  \r\n"
   "   const int             baseWin)                               \r\n"
   "{                                                               \r\n"
   "   int i = get_global_id(0);                                    \r\n"
   "   int j = get_global_id(1);                                    \r\n"
   "   int w = get_global_id(2);                                    \r\n"
   "   if(i >= N || j >= N) return;                                 \r\n"
   "   int winStart = (baseWin + w) * step;                         \r\n"
   "   float distX = 0.0f;                                          \r\n"
   "   float distY = 0.0f;                                          \r\n"
   "   if(embDim == 1) {                                            \r\n"
   "      float diffX = seriesX[winStart+i] - seriesX[winStart+j];  \r\n"
   "      float diffY = seriesY[winStart+i] - seriesY[winStart+j];  \r\n"
   "      if(norm == 1) { distX = diffX*diffX; distY = diffY*diffY;}\r\n"
   "      else          { distX = fabs(diffX); distY = fabs(diffY);}\r\n"
   "   } else {                                                     \r\n"
   "      for(int d = 0; d < embDim; d++) {                         \r\n"
   "         float diffX = seriesX[winStart + i + d*tau]             \r\n"
   "                      - seriesX[winStart + j + d*tau];           \r\n"
   "         float diffY = seriesY[winStart + i + d*tau]             \r\n"
   "                      - seriesY[winStart + j + d*tau];           \r\n"
   "         if(norm == 0) {                                        \r\n"
   "            distX = fmax(distX, fabs(diffX));                   \r\n"
   "            distY = fmax(distY, fabs(diffY));                   \r\n"
   "         } else if(norm == 1) {                                 \r\n"
   "            distX += diffX*diffX;                               \r\n"
   "            distY += diffY*diffY;                               \r\n"
   "         } else {                                               \r\n"
   "            distX += fabs(diffX);                               \r\n"
   "            distY += fabs(diffY);                               \r\n"
   "         }                                                      \r\n"
   "      }                                                         \r\n"
   "   }                                                            \r\n"
   "   float threshX = (norm==1) ? epsilonX*epsilonX : epsilonX;    \r\n"
   "   float threshY = (norm==1) ? epsilonY*epsilonY : epsilonY;    \r\n"
   "   outR[(w*N + i)*N + j] =                                      \r\n"
   "       ((distX <= threshX) && (distY <= threshY)) ? 1 : 0;     \r\n"
   "}                                                               \r\n";

//+------------------------------------------------------------------+
//| Per-window result struct                                         |
//+------------------------------------------------------------------+
struct SJRQAWindowResult
  {
   int          barIndex;
   SJRQAResult  metrics;
  };

//+------------------------------------------------------------------+
//| CJRQAWindow — rolling Joint-RQA with GPU/CPU                     |
//+------------------------------------------------------------------+
class CJRQAWindow
  {
private:
   int               m_windowSize;
   int               m_step;
   double            m_epsilonX;
   double            m_epsilonY;
   int               m_embDim;
   int               m_delay;
   ENUM_RQA_NORM     m_norm;
   int               m_minDiagLine;
   int               m_minVertLine;

   bool              RunGPU(const double &seriesX[], const double &seriesY[],
                            int seriesLen, int numWindows,
                            SJRQAWindowResult &results[]);

   void              ComputeFusedCPU(const double &sX[], int offX,
                                     const double &sY[], int offY,
                                     SJRQAResult &result);

   void              ScanMetrics(const int &R[], int N, int baseIdx,
                                 SJRQAResult &result);

public:
                     CJRQAWindow();

   void              SetWindow(int windowSize, int step = 1)   { m_windowSize = windowSize; m_step = step; }
   void              SetEpsilon(double epsX, double epsY)       { m_epsilonX = epsX; m_epsilonY = epsY; }
   void              SetEpsilon(double eps)                     { m_epsilonX = eps; m_epsilonY = eps; }
   void              SetEmbedding(int dim, int delay)           { m_embDim = dim; m_delay = delay; }
   void              SetNorm(ENUM_RQA_NORM norm)                { m_norm = norm; }
   void              SetMinLines(int diagMin, int vertMin)      { m_minDiagLine = diagMin; m_minVertLine = vertMin; }

   bool              Run(const double &seriesX[], int lenX,
                         const double &seriesY[], int lenY,
                         SJRQAWindowResult &results[]);

   static void       ExtractJRR  (const SJRQAWindowResult &r[], double &out[]);
   static void       ExtractJDET (const SJRQAWindowResult &r[], double &out[]);
   static void       ExtractJLAM (const SJRQAWindowResult &r[], double &out[]);
   static void       ExtractJTT  (const SJRQAWindowResult &r[], double &out[]);
   static void       ExtractJENTR(const SJRQAWindowResult &r[], double &out[]);
   static void       ExtractJLmax(const SJRQAWindowResult &r[], double &out[]);
  };

//+------------------------------------------------------------------+
//| Default constructor                                              |
//+------------------------------------------------------------------+
CJRQAWindow::CJRQAWindow()
   : m_windowSize(50), m_step(1), m_epsilonX(0.1), m_epsilonY(0.1),
     m_embDim(1), m_delay(1), m_norm(RQA_NORM_EUCLIDEAN),
     m_minDiagLine(2), m_minVertLine(2)
  {
  }

//+------------------------------------------------------------------+
//| Scan a flat int R[N*N] sub-array for JRQA metrics                |
//+------------------------------------------------------------------+
void CJRQAWindow::ScanMetrics(const int &R[], int N, int baseIdx,
                               SJRQAResult &result)
  {
   result.Reset();
   if(N < 2) return;

   long NsqMinusN = (long)N * N - N;

   long recCount = 0;
   for(int i = 0; i < N; i++)
      for(int j = 0; j < N; j++)
         if(i != j && R[baseIdx + i * N + j] != 0)
            recCount++;

   result.JRR = (NsqMinusN > 0) ? (double)recCount / NsqMinusN : 0.0;

   // --- Diagonal lines (excluding main diagonal) ---
   int diagHist[];
   ArrayResize(diagHist, N + 1);
   ArrayInitialize(diagHist, 0);

   for(int k = -(N - 1); k <= (N - 1); k++)
     {
      if(k == 0) continue;
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

   result.JLmax = (double)lmax;
   result.JDIV  = (lmax > 0) ? 1.0 / lmax : 0.0;
   result.JDET  = (recCount > 0) ? (double)diagPoints / recCount : 0.0;
   result.JL    = (totalDiagLines > 0) ? (double)diagPoints / totalDiagLines : 0.0;

   if(totalDiagLines > 0)
     {
      double entr = 0.0;
      for(int l = m_minDiagLine; l <= N; l++)
         if(diagHist[l] > 0)
           { double p = (double)diagHist[l] / totalDiagLines; entr -= p * MathLog(p); }
      result.JENTR = entr;
     }

   // --- Vertical lines ---
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

   result.JVmax       = (double)vmax;
   result.JLAM        = (recCount > 0) ? (double)vertPoints / recCount : 0.0;
   result.JTT         = (totalVertLines > 0) ? (double)vertPoints / totalVertLines : 0.0;
   result.JRATIO      = (result.JRR > 1e-12) ? result.JDET / result.JRR : 0.0;
   result.JCOMPLEXITY = result.JRR * result.JDET;

   // --- TREND ---
   if(N >= 4)
     {
      int numDiag = N - 1;
      double sumX = 0, sumYd = 0, sumXY = 0, sumX2 = 0;
      for(int d = 1; d < N; d++)
        {
         int cnt = 0, tot = N - d;
         for(int i = 0; i < tot; i++)
            if(R[baseIdx + i * N + (i + d)] != 0) cnt++;
         double density = (tot > 0) ? (double)cnt / tot : 0.0;
         double x = (double)(d - numDiag / 2);
         sumX  += x;
         sumYd += density;
         sumXY += x * density;
         sumX2 += x * x;
        }
      double denom = (double)numDiag * sumX2 - sumX * sumX;
      if(MathAbs(denom) > 1e-12)
         result.JTREND = ((double)numDiag * sumXY - sumX * sumYd) / denom;
     }
  }

//+------------------------------------------------------------------+
//| GPU path — using COpenCL wrapper                                 |
//+------------------------------------------------------------------+
bool CJRQAWindow::RunGPU(const double &seriesX[], const double &seriesY[],
                          int seriesLen, int numWindows,
                          SJRQAWindowResult &results[])
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
   if(!ocl.Initialize(cl_jrqa_source, true))
     {
      Print("JRQA: OpenCL init failed");
      return false;
     }

   if(!ocl.SetKernelsCount(1) || !ocl.KernelCreate(0, "jrqa_recurrence"))
     {
      Print("JRQA: kernel create failed");
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
      Print("JRQA: buffer upload failed");
      ocl.Shutdown();
      return false;
     }

   ocl.SetArgumentBuffer(0, 0, 0);   // seriesX
   ocl.SetArgumentBuffer(0, 1, 1);   // seriesY
   ocl.SetArgument(0, 3, N);
   ocl.SetArgument(0, 4, m_embDim);
   ocl.SetArgument(0, 5, m_delay);
   ocl.SetArgument(0, 6, (int)m_norm);
   ocl.SetArgument(0, 7, (float)m_epsilonX);
   ocl.SetArgument(0, 8, (float)m_epsilonY);
   ocl.SetArgument(0, 9, m_step);

   long cellsPerWin = (long)N * N;
   int  maxBatch = (int)MathMin((long)numWindows,
                                64L * 1024 * 1024 / (cellsPerWin * (long)sizeof(int)));
   if(maxBatch < 1) maxBatch = 1;

   ArrayResize(results, numWindows);

   bool ok = true;
   int processed = 0;

   while(processed < numWindows && ok)
     {
      int batchSize  = MathMin(maxBatch, numWindows - processed);
      int totalCells = batchSize * (int)cellsPerWin;

      ocl.BufferFree(2);
      if(!ocl.BufferCreate(2, totalCells * sizeof(int), CL_MEM_WRITE_ONLY))
        { ok = false; break; }

      ocl.SetArgumentBuffer(0, 2, 2);   // outR
      ocl.SetArgument(0, 10, processed);

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
//| CPU fallback — fused single-window joint recurrence compute      |
//+------------------------------------------------------------------+
void CJRQAWindow::ComputeFusedCPU(const double &sX[], int offX,
                                   const double &sY[], int offY,
                                   SJRQAResult &result)
  {
   result.Reset();

   int N = m_windowSize - (m_embDim - 1) * m_delay;
   if(N <= 1) return;

   long NsqMinusN = (long)N * N - N;
   double epsSqX = m_epsilonX * m_epsilonX;
   double epsSqY = m_epsilonY * m_epsilonY;

   int diagHist[], vertHist[];
   ArrayResize(diagHist, N + 1);
   ArrayResize(vertHist, N + 1);
   ArrayInitialize(diagHist, 0);
   ArrayInitialize(vertHist, 0);

   long recCount = 0;

   if(m_embDim == 1 && m_norm == RQA_NORM_EUCLIDEAN)
     {
      // --- Fast path: embDim=1, Euclidean ---
      // Diagonal scan
      for(int k = -(N - 1); k <= (N - 1); k++)
        {
         if(k == 0) continue;
         int iS = (k < 0) ? -k : 0;
         int iE = (k < 0) ? N - 1 : N - 1 - k;
         int len = 0;
         for(int i = iS; i <= iE; i++)
           {
            double diffX = sX[offX + i] - sX[offX + i + k];
            double diffY = sY[offY + i] - sY[offY + i + k];
            if(diffX * diffX <= epsSqX && diffY * diffY <= epsSqY)
              { len++; recCount++; }
            else
              { if(len >= m_minDiagLine) diagHist[len]++; len = 0; }
           }
         if(len >= m_minDiagLine) diagHist[len]++;
        }
      // Vertical scan
      for(int j = 0; j < N; j++)
        {
         int len = 0;
         for(int i = 0; i < N; i++)
           {
            if(i == j) { if(len >= m_minVertLine) vertHist[len]++; len = 0; continue; }
            double diffX = sX[offX + i] - sX[offX + j];
            double diffY = sY[offY + i] - sY[offY + j];
            if(diffX * diffX <= epsSqX && diffY * diffY <= epsSqY)
               len++;
            else
              { if(len >= m_minVertLine) vertHist[len]++; len = 0; }
           }
         if(len >= m_minVertLine) vertHist[len]++;
        }
     }
   else
     {
      // --- General path ---
      bool useEucSq = (m_norm == RQA_NORM_EUCLIDEAN);
      double epsCompX = useEucSq ? epsSqX : m_epsilonX;
      double epsCompY = useEucSq ? epsSqY : m_epsilonY;

      // Diagonal scan
      for(int k = -(N - 1); k <= (N - 1); k++)
        {
         if(k == 0) continue;
         int iS = (k < 0) ? -k : 0;
         int iE = (k < 0) ? N - 1 : N - 1 - k;
         int len = 0;
         for(int i = iS; i <= iE; i++)
           {
            double dstX = 0.0, dstY = 0.0;
            for(int d = 0; d < m_embDim; d++)
              {
               double diffX = sX[offX + i + d * m_delay]
                             - sX[offX + i + k + d * m_delay];
               double diffY = sY[offY + i + d * m_delay]
                             - sY[offY + i + k + d * m_delay];
               if(useEucSq)
                 { dstX += diffX * diffX; dstY += diffY * diffY; }
               else if(m_norm == RQA_NORM_MAX)
                 { dstX = MathMax(dstX, MathAbs(diffX)); dstY = MathMax(dstY, MathAbs(diffY)); }
               else
                 { dstX += MathAbs(diffX); dstY += MathAbs(diffY); }
              }
            if(dstX <= epsCompX && dstY <= epsCompY)
              { len++; recCount++; }
            else
              { if(len >= m_minDiagLine) diagHist[len]++; len = 0; }
           }
         if(len >= m_minDiagLine) diagHist[len]++;
        }
      // Vertical scan
      for(int j = 0; j < N; j++)
        {
         int len = 0;
         for(int i = 0; i < N; i++)
           {
            if(i == j) { if(len >= m_minVertLine) vertHist[len]++; len = 0; continue; }
            double dstX = 0.0, dstY = 0.0;
            for(int d = 0; d < m_embDim; d++)
              {
               double diffX = sX[offX + i + d * m_delay]
                             - sX[offX + j + d * m_delay];
               double diffY = sY[offY + i + d * m_delay]
                             - sY[offY + j + d * m_delay];
               if(useEucSq)
                 { dstX += diffX * diffX; dstY += diffY * diffY; }
               else if(m_norm == RQA_NORM_MAX)
                 { dstX = MathMax(dstX, MathAbs(diffX)); dstY = MathMax(dstY, MathAbs(diffY)); }
               else
                 { dstX += MathAbs(diffX); dstY += MathAbs(diffY); }
              }
            if(dstX <= epsCompX && dstY <= epsCompY)
               len++;
            else
              { if(len >= m_minVertLine) vertHist[len]++; len = 0; }
           }
         if(len >= m_minVertLine) vertHist[len]++;
        }
     }

   // --- Assemble metrics ---
   result.JRR = (NsqMinusN > 0) ? (double)recCount / NsqMinusN : 0.0;

   long diagPoints = 0, totalDiagLines = 0;
   int lmax = 0;
   for(int l = m_minDiagLine; l <= N; l++)
      if(diagHist[l] > 0)
        { diagPoints += (long)l * diagHist[l]; totalDiagLines += diagHist[l]; lmax = l; }

   result.JLmax = (double)lmax;
   result.JDIV  = (lmax > 0) ? 1.0 / lmax : 0.0;
   result.JDET  = (recCount > 0) ? (double)diagPoints / recCount : 0.0;
   result.JL    = (totalDiagLines > 0) ? (double)diagPoints / totalDiagLines : 0.0;

   if(totalDiagLines > 0)
     {
      double entr = 0.0;
      for(int l = m_minDiagLine; l <= N; l++)
         if(diagHist[l] > 0)
           { double p = (double)diagHist[l] / totalDiagLines; entr -= p * MathLog(p); }
      result.JENTR = entr;
     }

   long vertPoints = 0, totalVertLines = 0;
   int vmax = 0;
   for(int l = m_minVertLine; l <= N; l++)
      if(vertHist[l] > 0)
        { vertPoints += (long)l * vertHist[l]; totalVertLines += vertHist[l]; vmax = l; }

   result.JVmax       = (double)vmax;
   result.JLAM        = (recCount > 0) ? (double)vertPoints / recCount : 0.0;
   result.JTT         = (totalVertLines > 0) ? (double)vertPoints / totalVertLines : 0.0;
   result.JRATIO      = (result.JRR > 1e-12) ? result.JDET / result.JRR : 0.0;
   result.JCOMPLEXITY = result.JRR * result.JDET;

   // --- TREND ---
   if(N >= 4)
     {
      int numDiag = N - 1;
      double sumX = 0, sumYd = 0, sumXY = 0, sumX2 = 0;
      for(int dd = 1; dd < N; dd++)
        {
         int cnt = 0, tot = N - dd;
         for(int i = 0; i < tot; i++)
           {
            double diffX, diffY;
            if(m_embDim == 1)
              {
               diffX = sX[offX + i] - sX[offX + i + dd];
               diffY = sY[offY + i] - sY[offY + i + dd];
               bool recX = (m_norm == RQA_NORM_EUCLIDEAN)
                            ? (diffX * diffX <= epsSqX)
                            : (MathAbs(diffX) <= m_epsilonX);
               bool recY = (m_norm == RQA_NORM_EUCLIDEAN)
                            ? (diffY * diffY <= epsSqY)
                            : (MathAbs(diffY) <= m_epsilonY);
               if(recX && recY) cnt++;
              }
            else
              {
               bool useEucSq = (m_norm == RQA_NORM_EUCLIDEAN);
               double dstX = 0.0, dstY = 0.0;
               for(int d = 0; d < m_embDim; d++)
                 {
                  double dfX = sX[offX + i + d * m_delay] - sX[offX + i + dd + d * m_delay];
                  double dfY = sY[offY + i + d * m_delay] - sY[offY + i + dd + d * m_delay];
                  if(useEucSq)      { dstX += dfX * dfX; dstY += dfY * dfY; }
                  else if(m_norm == RQA_NORM_MAX)
                    { dstX = MathMax(dstX, MathAbs(dfX)); dstY = MathMax(dstY, MathAbs(dfY)); }
                  else              { dstX += MathAbs(dfX); dstY += MathAbs(dfY); }
                 }
               double ecX = useEucSq ? epsSqX : m_epsilonX;
               double ecY = useEucSq ? epsSqY : m_epsilonY;
               if(dstX <= ecX && dstY <= ecY) cnt++;
              }
           }
         double density = (tot > 0) ? (double)cnt / tot : 0.0;
         double x = (double)(dd - numDiag / 2);
         sumX  += x;
         sumYd += density;
         sumXY += x * density;
         sumX2 += x * x;
        }
      double denom = (double)numDiag * sumX2 - sumX * sumX;
      if(MathAbs(denom) > 1e-12)
         result.JTREND = ((double)numDiag * sumXY - sumX * sumYd) / denom;
     }
  }

//+------------------------------------------------------------------+
//| Main entry — tries GPU, falls back to CPU                        |
//+------------------------------------------------------------------+
bool CJRQAWindow::Run(const double &seriesX[], int lenX,
                       const double &seriesY[], int lenY,
                       SJRQAWindowResult &results[])
  {
   int minLen = MathMin(lenX, lenY);
   if(minLen < m_windowSize)
     {
      Print("CJRQAWindow::Run — series shorter than window");
      return false;
     }

   int numWindows = (minLen - m_windowSize) / m_step + 1;

   if(RunGPU(seriesX, seriesY, minLen, numWindows, results))
      return true;

   Print("JRQA: OpenCL unavailable, using CPU fallback");
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
//| Extract single-metric arrays from windowed JRQA results          |
//+------------------------------------------------------------------+
void CJRQAWindow::ExtractJRR(const SJRQAWindowResult &r[], double &out[])
  { int n=ArraySize(r); ArrayResize(out,n); for(int i=0;i<n;i++) out[i]=r[i].metrics.JRR; }
void CJRQAWindow::ExtractJDET(const SJRQAWindowResult &r[], double &out[])
  { int n=ArraySize(r); ArrayResize(out,n); for(int i=0;i<n;i++) out[i]=r[i].metrics.JDET; }
void CJRQAWindow::ExtractJLAM(const SJRQAWindowResult &r[], double &out[])
  { int n=ArraySize(r); ArrayResize(out,n); for(int i=0;i<n;i++) out[i]=r[i].metrics.JLAM; }
void CJRQAWindow::ExtractJTT(const SJRQAWindowResult &r[], double &out[])
  { int n=ArraySize(r); ArrayResize(out,n); for(int i=0;i<n;i++) out[i]=r[i].metrics.JTT; }
void CJRQAWindow::ExtractJENTR(const SJRQAWindowResult &r[], double &out[])
  { int n=ArraySize(r); ArrayResize(out,n); for(int i=0;i<n;i++) out[i]=r[i].metrics.JENTR; }
void CJRQAWindow::ExtractJLmax(const SJRQAWindowResult &r[], double &out[])
  { int n=ArraySize(r); ArrayResize(out,n); for(int i=0;i<n;i++) out[i]=r[i].metrics.JLmax; }

#endif // JRQAWINDOW_MQH
