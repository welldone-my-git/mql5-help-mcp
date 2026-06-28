//+------------------------------------------------------------------+
//|                                                  JRNAWindow.mqh  |
//|                          RQA Library for MQL5                    |
//|   Windowed (rolling) Joint Recurrence Network Analysis           |
//|                                                                  |
//|  Builds a CJRQAMatrix per window from two time series, then      |
//|  extracts the adjacency matrix and computes network metrics      |
//|  via CRNAMetrics::ComputeFromAdj().                              |
//|                                                                  |
//|  Reuses SRNAResult / SRNAWindowResult — the graph metrics are    |
//|  identical regardless of whether the adjacency came from a       |
//|  standard RP or a joint RP.                                      |
//+------------------------------------------------------------------+
#ifndef JRNAWINDOW_MQH
#define JRNAWINDOW_MQH

#include "JRQAMatrix.mqh"
#include "RNAMetrics.mqh"

//+------------------------------------------------------------------+
//| CJRNAWindow — rolling Joint Recurrence Network Analysis          |
//+------------------------------------------------------------------+
class CJRNAWindow
  {
private:
   int               m_windowSize;
   int               m_step;
   double            m_epsilonX;
   double            m_epsilonY;
   int               m_embDim;
   int               m_delay;
   ENUM_RQA_NORM     m_norm;

public:
                     CJRNAWindow();

   void              SetWindow(int windowSize, int step = 1)
                       { m_windowSize = windowSize; m_step = step; }
   void              SetEpsilon(double eps)
                       { m_epsilonX = eps; m_epsilonY = eps; }
   void              SetEpsilon(double epsX, double epsY)
                       { m_epsilonX = epsX; m_epsilonY = epsY; }
   void              SetEmbedding(int dim, int delay)
                       { m_embDim = dim; m_delay = delay; }
   void              SetNorm(ENUM_RQA_NORM norm) { m_norm = norm; }

   bool              Run(const double &seriesX[], int lenX,
                         const double &seriesY[], int lenY,
                         SRNAWindowResult &results[]);

   static void       ExtractAvgClustering (const SRNAWindowResult &r[], double &out[]);
   static void       ExtractTransitivity  (const SRNAWindowResult &r[], double &out[]);
   static void       ExtractAvgPathLength (const SRNAWindowResult &r[], double &out[]);
   static void       ExtractAssortativity (const SRNAWindowResult &r[], double &out[]);
   static void       ExtractAvgBetweenness(const SRNAWindowResult &r[], double &out[]);
   static void       ExtractDensity       (const SRNAWindowResult &r[], double &out[]);
  };

//+------------------------------------------------------------------+
//| Default constructor                                              |
//+------------------------------------------------------------------+
CJRNAWindow::CJRNAWindow()
   : m_windowSize(50), m_step(1),
     m_epsilonX(0.1), m_epsilonY(0.1),
     m_embDim(1), m_delay(1), m_norm(RQA_NORM_EUCLIDEAN)
  {
  }

//+------------------------------------------------------------------+
//| Slide window, build joint RP, extract adjacency, compute metrics |
//+------------------------------------------------------------------+
bool CJRNAWindow::Run(const double &seriesX[], int lenX,
                       const double &seriesY[], int lenY,
                       SRNAWindowResult &results[])
  {
   int minLen = MathMin(lenX, lenY);
   if(minLen < m_windowSize)
     {
      Print("CJRNAWindow::Run — series shorter than window");
      return false;
     }

   CJRQAMatrix mat;
   CRNAMetrics metrics;

   int numWindows = (minLen - m_windowSize) / m_step + 1;
   ArrayResize(results, numWindows);

   double sliceX[], sliceY[];
   ArrayResize(sliceX, m_windowSize);
   ArrayResize(sliceY, m_windowSize);

   int idx = 0;
   for(int start = 0; start + m_windowSize <= minLen; start += m_step)
     {
      for(int k = 0; k < m_windowSize; k++)
        {
         sliceX[k] = seriesX[start + k];
         sliceY[k] = seriesY[start + k];
        }

      results[idx].barIndex = start;

      if(!mat.Build(sliceX, sliceY, m_windowSize,
                    m_epsilonX, m_epsilonY,
                    m_embDim, m_delay, m_norm))
        {
         results[idx].metrics.Reset();
         idx++;
         continue;
        }

      //--- Extract adjacency matrix (no self-loops)
      int N = mat.Size();
      char adj[];
      ArrayResize(adj, N * N);
      for(int i = 0; i < N; i++)
         for(int j = 0; j < N; j++)
            adj[i * N + j] = (char)((i != j && mat.Get(i, j)) ? 1 : 0);

      metrics.ComputeFromAdj(adj, N, results[idx].metrics);
      idx++;
     }

   ArrayResize(results, idx);
   return true;
  }

//+------------------------------------------------------------------+
//| Extract single-metric arrays from windowed results               |
//+------------------------------------------------------------------+
void CJRNAWindow::ExtractAvgClustering(const SRNAWindowResult &r[], double &out[])
  { int n = ArraySize(r); ArrayResize(out, n); for(int i = 0; i < n; i++) out[i] = r[i].metrics.AvgClustering; }
void CJRNAWindow::ExtractTransitivity(const SRNAWindowResult &r[], double &out[])
  { int n = ArraySize(r); ArrayResize(out, n); for(int i = 0; i < n; i++) out[i] = r[i].metrics.Transitivity; }
void CJRNAWindow::ExtractAvgPathLength(const SRNAWindowResult &r[], double &out[])
  { int n = ArraySize(r); ArrayResize(out, n); for(int i = 0; i < n; i++) out[i] = r[i].metrics.AvgPathLength; }
void CJRNAWindow::ExtractAssortativity(const SRNAWindowResult &r[], double &out[])
  { int n = ArraySize(r); ArrayResize(out, n); for(int i = 0; i < n; i++) out[i] = r[i].metrics.Assortativity; }
void CJRNAWindow::ExtractAvgBetweenness(const SRNAWindowResult &r[], double &out[])
  { int n = ArraySize(r); ArrayResize(out, n); for(int i = 0; i < n; i++) out[i] = r[i].metrics.AvgBetweenness; }
void CJRNAWindow::ExtractDensity(const SRNAWindowResult &r[], double &out[])
  { int n = ArraySize(r); ArrayResize(out, n); for(int i = 0; i < n; i++) out[i] = r[i].metrics.Density; }

#endif // JRNAWINDOW_MQH
