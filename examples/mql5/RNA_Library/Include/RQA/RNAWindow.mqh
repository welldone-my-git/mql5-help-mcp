//+------------------------------------------------------------------+
//|                                                   RNAWindow.mqh  |
//|                          RQA Library for MQL5                    |
//|     Windowed (rolling) Recurrence Network Analysis               |
//|                                                                  |
//|  Slides a window over the series, builds the recurrence matrix   |
//|  per window via CRQAMatrix, then computes graph metrics via      |
//|  CRNAMetrics.  CPU-only — network metric computation (BFS,       |
//|  clustering, betweenness) is inherently sequential.              |
//+------------------------------------------------------------------+
#ifndef RNAWINDOW_MQH
#define RNAWINDOW_MQH

#include "RQAMatrix.mqh"
#include "RNAMetrics.mqh"

//+------------------------------------------------------------------+
//| Per-window result                                                |
//+------------------------------------------------------------------+
struct SRNAWindowResult
  {
   int          barIndex;
   SRNAResult   metrics;
  };

//+------------------------------------------------------------------+
//| CRNAWindow — rolling Recurrence Network Analysis                 |
//+------------------------------------------------------------------+
class CRNAWindow
  {
private:
   int               m_windowSize;
   int               m_step;
   double            m_epsilon;
   int               m_embDim;
   int               m_delay;
   ENUM_RQA_NORM     m_norm;

public:
                     CRNAWindow();

   void              SetWindow(int windowSize, int step = 1)
                       { m_windowSize = windowSize; m_step = step; }
   void              SetEpsilon(double eps)          { m_epsilon = eps; }
   void              SetEmbedding(int dim, int delay)
                       { m_embDim = dim; m_delay = delay; }
   void              SetNorm(ENUM_RQA_NORM norm)     { m_norm = norm; }

   bool              Run(const double &series[], int seriesLen,
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
CRNAWindow::CRNAWindow()
   : m_windowSize(50), m_step(1), m_epsilon(0.0), m_embDim(1),
     m_delay(1), m_norm(RQA_NORM_EUCLIDEAN)
  {
  }

//+------------------------------------------------------------------+
//| Slide window, build recurrence matrix, compute network metrics   |
//+------------------------------------------------------------------+
bool CRNAWindow::Run(const double &series[], int seriesLen,
                      SRNAWindowResult &results[])
  {
   if(seriesLen < m_windowSize)
     {
      Print("CRNAWindow::Run — series shorter than window");
      return false;
     }

   CRQAMatrix  mat;
   CRNAMetrics metrics;

   int numWindows = (seriesLen - m_windowSize) / m_step + 1;
   ArrayResize(results, numWindows);

   double slice[];
   ArrayResize(slice, m_windowSize);

   int idx = 0;
   for(int start = 0; start + m_windowSize <= seriesLen; start += m_step)
     {
      for(int k = 0; k < m_windowSize; k++)
         slice[k] = series[start + k];

      double eps = (m_epsilon > 0.0) ? m_epsilon : 0.1;

      results[idx].barIndex = start;

      if(mat.Build(slice, m_windowSize, eps, m_embDim, m_delay, m_norm))
         metrics.Compute(mat, results[idx].metrics);
      else
         results[idx].metrics.Reset();

      idx++;
     }

   ArrayResize(results, idx);
   return true;
  }

//+------------------------------------------------------------------+
//| Extract single-metric arrays from windowed results               |
//+------------------------------------------------------------------+
void CRNAWindow::ExtractAvgClustering(const SRNAWindowResult &r[], double &out[])
  { int n = ArraySize(r); ArrayResize(out, n); for(int i = 0; i < n; i++) out[i] = r[i].metrics.AvgClustering; }
void CRNAWindow::ExtractTransitivity(const SRNAWindowResult &r[], double &out[])
  { int n = ArraySize(r); ArrayResize(out, n); for(int i = 0; i < n; i++) out[i] = r[i].metrics.Transitivity; }
void CRNAWindow::ExtractAvgPathLength(const SRNAWindowResult &r[], double &out[])
  { int n = ArraySize(r); ArrayResize(out, n); for(int i = 0; i < n; i++) out[i] = r[i].metrics.AvgPathLength; }
void CRNAWindow::ExtractAssortativity(const SRNAWindowResult &r[], double &out[])
  { int n = ArraySize(r); ArrayResize(out, n); for(int i = 0; i < n; i++) out[i] = r[i].metrics.Assortativity; }
void CRNAWindow::ExtractAvgBetweenness(const SRNAWindowResult &r[], double &out[])
  { int n = ArraySize(r); ArrayResize(out, n); for(int i = 0; i < n; i++) out[i] = r[i].metrics.AvgBetweenness; }
void CRNAWindow::ExtractDensity(const SRNAWindowResult &r[], double &out[])
  { int n = ArraySize(r); ArrayResize(out, n); for(int i = 0; i < n; i++) out[i] = r[i].metrics.Density; }

#endif // RNAWINDOW_MQH
