//+------------------------------------------------------------------+
//|                                                          RQA.mqh |
//|                          RQA Library for MQL5                    |
//|                                                                  |
//|  FULL LIBRARY — Main include file                                |
//|                                                                  |
//|  Usage:                                                          |
//|    #include <RQA\RQA.mqh>                                        |
//|                                                                  |
//|  ── Standard RQA classes (single series) ──────────────────────  |
//|    CRQAMatrix   — builds the NxN recurrence matrix               |
//|    CRQAMetrics  — computes all RQA measures                      |
//|    CRQAEpsilon  — automatic epsilon selection                    |
//|    CRQAWindow   — rolling/windowed RQA analysis                  |
//|    CRQA          — high-level all-in-one RQA facade              |
//|                                                                  |
//|  ── Cross-RQA classes (two series) ────────────────────────────  |
//|    CCRQAMatrix  — builds the NxM cross-recurrence matrix         |
//|    CCRQAMetrics — computes all CRQA measures                     |
//|    CCRQAWindow  — rolling/windowed CRQA analysis                 |
//|    CCRQA        — high-level all-in-one CRQA facade              |
//|                                                                  |
//|  ── Joint-RQA classes (two series, joint recurrence) ──────────  |
//|    CJRQAMatrix  — builds NxN joint recurrence matrix (AND of RPs)|
//|    CJRQAMetrics — computes all JRQA measures                     |
//|    CJRQAWindow  — rolling/windowed JRQA analysis                 |
//|    CJRQA        — high-level all-in-one JRQA facade              |
//|                                                                  |
//|  ── Structs ──────────────────────────────────────────────────── |
//|    SRQAResult        — holds all RQA metric values               |
//|    SRQAWindowResult  — per-window RQA metric values              |
//|    SCRQAResult       — holds all CRQA metric values              |
//|    SCRQAWindowResult — per-window CRQA metric values             |
//|    SJRQAResult       — holds all JRQA metric values              |
//|    SJRQAWindowResult — per-window JRQA metric values             |
//|                                                                  |
//|  ── Enums ────────────────────────────────────────────────────── |
//|    ENUM_RQA_NORM       — distance norm choice                    |
//|    ENUM_EPSILON_METHOD — epsilon auto-selection                  |
//+------------------------------------------------------------------+
#ifndef RQA_MQH
#define RQA_MQH

// --- Standard RQA modules ---
#include "RQAMatrix.mqh"
#include "RQAMetrics.mqh"
#include "RQAEpsilon.mqh"
#include "RQAWindow.mqh"

// --- Cross-RQA modules ---
#include "CRQAMatrix.mqh"
#include "CRQAMetrics.mqh"
#include "CRQAWindow.mqh"

// --- Joint-RQA modules ---
#include "JRQAMatrix.mqh"
#include "JRQAMetrics.mqh"
#include "JRQAWindow.mqh"

//+------------------------------------------------------------------+
//| CRQA — high-level facade for single-series RQA                   |
//+------------------------------------------------------------------+
class CRQA
  {
private:
   CRQAMatrix        m_matrix;
   CRQAMetrics       m_metrics;
   SRQAResult        m_result;
   bool              m_computed;

   double            m_epsilon;
   int               m_embDim;
   int               m_delay;
   ENUM_RQA_NORM     m_norm;
   ENUM_EPSILON_METHOD m_epsilonMethod;
   double            m_epsilonParam;

public:
                     CRQA();

   void              SetEpsilon(double eps)
     { m_epsilon = eps; m_epsilonMethod = EPSILON_FIXED; }

   void              SetEpsilonAuto(ENUM_EPSILON_METHOD method, double param = 0.05)
     { m_epsilonMethod = method; m_epsilonParam = param; }

   void              SetEmbedding(int dim, int delay)
     { m_embDim = dim; m_delay = delay; }

   void              SetNorm(ENUM_RQA_NORM norm)    { m_norm = norm; }
   void              SetMinDiagLine(int v)          { m_metrics.SetMinDiagLine(v); }
   void              SetMinVertLine(int v)          { m_metrics.SetMinVertLine(v); }

   bool              Compute(const double &series[], int N);

   void              GetResult(SRQAResult &out) const { out = m_result; }

   double            RR()          const { return m_result.RR; }
   double            DET()         const { return m_result.DET; }
   double            LAM()         const { return m_result.LAM; }
   double            TT()          const { return m_result.TT; }
   double            L()           const { return m_result.L; }
   double            Lmax()        const { return m_result.Lmax; }
   double            Vmax()        const { return m_result.Vmax; }
   double            ENTR()        const { return m_result.ENTR; }
   double            DIV()         const { return m_result.DIV; }
   double            RATIO()       const { return m_result.RATIO; }
   double            TREND()       const { return m_result.TREND; }
   double            COMPLEXITY()  const { return m_result.COMPLEXITY; }

   void              PrintSummary() const;

   int               MatrixSize() const { return m_matrix.Size(); }
   double            Epsilon()    const { return m_epsilon; }
  };

//+------------------------------------------------------------------+
//| Default constructor                                              |
//+------------------------------------------------------------------+
CRQA::CRQA()
   : m_computed(false),
     m_epsilon(0.1),
     m_embDim(1),
     m_delay(1),
     m_norm(RQA_NORM_EUCLIDEAN),
     m_epsilonMethod(EPSILON_FIXED),
     m_epsilonParam(0.05)
  {
  }

//+------------------------------------------------------------------+
//| Build recurrence matrix and compute all RQA metrics              |
//+------------------------------------------------------------------+
bool CRQA::Compute(const double &series[], int N)
  {
   m_computed = false;
   m_result.Reset();

   if(N < 4)
     {
      Print("CRQA::Compute — series too short (min 4 bars)");
      return false;
     }

   double eps = m_epsilon;
   if(m_epsilonMethod != EPSILON_FIXED)
      eps = CRQAEpsilon::Select(series, N, m_epsilonMethod, m_epsilonParam);

   m_epsilon = eps;

   if(!m_matrix.Build(series, N, eps, m_embDim, m_delay, m_norm))
      return false;

   if(!m_metrics.Compute(m_matrix, m_result))
      return false;

   m_computed = true;
   return true;
  }

//+------------------------------------------------------------------+
//| Print all RQA metrics to the Experts log                         |
//+------------------------------------------------------------------+
void CRQA::PrintSummary() const
  {
   if(!m_computed)
     {
      Print("CRQA: Not computed yet — call Compute() first");
      return;
     }
   PrintFormat("===== RQA Summary =====");
   PrintFormat("Epsilon     : %.6f  (embDim=%d, delay=%d)",
               m_epsilon, m_embDim, m_delay);
   PrintFormat("RR          : %.4f  (%.2f%%)", m_result.RR, m_result.RR * 100.0);
   PrintFormat("DET         : %.4f", m_result.DET);
   PrintFormat("LAM         : %.4f", m_result.LAM);
   PrintFormat("TT          : %.4f", m_result.TT);
   PrintFormat("L (avg diag): %.4f", m_result.L);
   PrintFormat("Lmax        : %.0f", m_result.Lmax);
   PrintFormat("Vmax        : %.0f", m_result.Vmax);
   PrintFormat("ENTR        : %.4f", m_result.ENTR);
   PrintFormat("DIV         : %.4f", m_result.DIV);
   PrintFormat("RATIO       : %.4f", m_result.RATIO);
   PrintFormat("TREND       : %.6f", m_result.TREND);
   PrintFormat("COMPLEXITY  : %.6f", m_result.COMPLEXITY);
   PrintFormat("=======================");
  }

//+------------------------------------------------------------------+
//| CCRQA — high-level facade for Cross-RQA (two series)             |
//|                                                                  |
//|  Measures shared dynamic structure between two time series,      |
//|  e.g. two instruments, price vs indicator, or two timeframes.    |
//|                                                                  |
//|  Quick usage:                                                    |
//|    CCRQA crqa;                                                   |
//|    crqa.SetEpsilon(0.05);                                        |
//|    crqa.SetEmbedding(2, 1);                                      |
//|    if(crqa.Compute(closeX, lenX, closeY, lenY))                  |
//|      crqa.PrintSummary();                                        |
//|    double sync = crqa.CRR();   // cross recurrence rate          |
//|    double det  = crqa.CDET();  // cross determinism              |
//+------------------------------------------------------------------+
class CCRQA
  {
private:
   CCRQAMatrix       m_matrix;
   CCRQAMetrics      m_metrics;
   SCRQAResult       m_result;
   bool              m_computed;

   double            m_epsilon;
   int               m_embDim;
   int               m_delay;
   ENUM_RQA_NORM     m_norm;

public:
                     CCRQA();

   //--- Configuration
   void              SetEpsilon(double eps)           { m_epsilon = eps; }
   void              SetEmbedding(int dim, int delay)  { m_embDim = dim; m_delay = delay; }
   void              SetNorm(ENUM_RQA_NORM norm)        { m_norm = norm; }
   void              SetMinDiagLine(int v)              { m_metrics.SetMinDiagLine(v); }
   void              SetMinVertLine(int v)              { m_metrics.SetMinVertLine(v); }

   //--- Main compute — two series (can differ in length)
   bool              Compute(const double &seriesX[], int lenX,
                             const double &seriesY[], int lenY);

   //--- Results access
   void              GetResult(SCRQAResult &out) const { out = m_result; }

   double            CRR()    const { return m_result.CRR;    }
   double            CDET()   const { return m_result.CDET;   }
   double            CL()     const { return m_result.CL;     }
   double            CLmax()  const { return m_result.CLmax;  }
   double            CENTR()  const { return m_result.CENTR;  }
   double            CDIV()   const { return m_result.CDIV;   }
   double            CLAM()   const { return m_result.CLAM;   }
   double            CTT()    const { return m_result.CTT;    }
   double            CVmax()  const { return m_result.CVmax;  }
   double            CRATIO() const { return m_result.CRATIO; }

   //--- Print summary
   void              PrintSummary() const;

   //--- Underlying objects
   int               MatrixRows() const { return m_matrix.SizeN(); }
   int               MatrixCols() const { return m_matrix.SizeM(); }
   double            Epsilon()    const { return m_epsilon; }
  };

//+------------------------------------------------------------------+
//| Default constructor                                              |
//+------------------------------------------------------------------+
CCRQA::CCRQA()
   : m_computed(false),
     m_epsilon(0.1),
     m_embDim(1),
     m_delay(1),
     m_norm(RQA_NORM_EUCLIDEAN)
  {
  }

//+------------------------------------------------------------------+
//| Build cross-recurrence matrix and compute all CRQA metrics       |
//+------------------------------------------------------------------+
bool CCRQA::Compute(const double &seriesX[], int lenX,
                     const double &seriesY[], int lenY)
  {
   m_computed = false;
   m_result.Reset();

   if(lenX < 4 || lenY < 4)
     {
      Print("CCRQA::Compute — series too short (min 4 bars each)");
      return false;
     }

   if(!m_matrix.Build(seriesX, lenX, seriesY, lenY,
                      m_epsilon, m_embDim, m_delay, m_norm))
      return false;

   if(!m_metrics.Compute(m_matrix, m_result))
      return false;

   m_computed = true;
   return true;
  }

//+------------------------------------------------------------------+
//| Print all CRQA metrics to the Experts log                        |
//+------------------------------------------------------------------+
void CCRQA::PrintSummary() const
  {
   if(!m_computed)
     {
      Print("CCRQA: Not computed yet — call Compute() first");
      return;
     }
   PrintFormat("===== Cross-RQA Summary =====");
   PrintFormat("Epsilon      : %.6f  (embDim=%d, delay=%d)",
               m_epsilon, m_embDim, m_delay);
   PrintFormat("Matrix       : %d x %d", m_matrix.SizeN(), m_matrix.SizeM());
   PrintFormat("CRR          : %.4f  (%.2f%%)", m_result.CRR, m_result.CRR * 100.0);
   PrintFormat("CDET         : %.4f", m_result.CDET);
   PrintFormat("CLAM         : %.4f", m_result.CLAM);
   PrintFormat("CTT          : %.4f", m_result.CTT);
   PrintFormat("CL (avg diag): %.4f", m_result.CL);
   PrintFormat("CLmax        : %.0f",  m_result.CLmax);
   PrintFormat("CVmax        : %.0f",  m_result.CVmax);
   PrintFormat("CENTR        : %.4f",  m_result.CENTR);
   PrintFormat("CDIV         : %.4f",  m_result.CDIV);
   PrintFormat("CRATIO       : %.4f",  m_result.CRATIO);
   PrintFormat("=============================");
  }

//+------------------------------------------------------------------+
//| CJRQA — high-level facade for Joint-RQA (two series)             |
//|                                                                  |
//|  Measures simultaneous recurrence in two dynamical systems.      |
//|  JR(i,j) = 1 only when BOTH systems recur at (i,j).             |
//|                                                                  |
//|  Quick usage:                                                    |
//|    CJRQA jrqa;                                                   |
//|    jrqa.SetEpsilon(0.05);         // shared epsilon              |
//|    jrqa.SetEmbedding(2, 1);                                      |
//|    if(jrqa.Compute(closeX, closeY, len))                         |
//|      jrqa.PrintSummary();                                        |
//|    double jrr = jrqa.JRR();                                      |
//+------------------------------------------------------------------+
class CJRQA
  {
private:
   CJRQAMatrix       m_matrix;
   CJRQAMetrics      m_metrics;
   SJRQAResult       m_result;
   bool              m_computed;

   double            m_epsilonX;
   double            m_epsilonY;
   int               m_embDim;
   int               m_delay;
   ENUM_RQA_NORM     m_norm;

public:
                     CJRQA();

   //--- Configuration
   void              SetEpsilon(double eps)              { m_epsilonX = eps; m_epsilonY = eps; }
   void              SetEpsilon(double epsX, double epsY){ m_epsilonX = epsX; m_epsilonY = epsY; }
   void              SetEmbedding(int dim, int delay)    { m_embDim = dim; m_delay = delay; }
   void              SetNorm(ENUM_RQA_NORM norm)         { m_norm = norm; }
   void              SetMinDiagLine(int v)               { m_metrics.SetMinDiagLine(v); }
   void              SetMinVertLine(int v)               { m_metrics.SetMinVertLine(v); }

   //--- Main compute — two series of equal length
   bool              Compute(const double &seriesX[], const double &seriesY[],
                             int seriesLen);

   //--- Results access
   void              GetResult(SJRQAResult &out) const { out = m_result; }

   double            JRR()         const { return m_result.JRR; }
   double            JDET()        const { return m_result.JDET; }
   double            JLAM()        const { return m_result.JLAM; }
   double            JTT()         const { return m_result.JTT; }
   double            JL()          const { return m_result.JL; }
   double            JLmax()       const { return m_result.JLmax; }
   double            JVmax()       const { return m_result.JVmax; }
   double            JENTR()       const { return m_result.JENTR; }
   double            JDIV()        const { return m_result.JDIV; }
   double            JRATIO()      const { return m_result.JRATIO; }
   double            JTREND()      const { return m_result.JTREND; }
   double            JCOMPLEXITY() const { return m_result.JCOMPLEXITY; }

   void              PrintSummary() const;

   int               MatrixSize()  const { return m_matrix.Size(); }
   double            EpsilonX()    const { return m_epsilonX; }
   double            EpsilonY()    const { return m_epsilonY; }
  };

//+------------------------------------------------------------------+
//| Default constructor                                              |
//+------------------------------------------------------------------+
CJRQA::CJRQA()
   : m_computed(false),
     m_epsilonX(0.1),
     m_epsilonY(0.1),
     m_embDim(1),
     m_delay(1),
     m_norm(RQA_NORM_EUCLIDEAN)
  {
  }

//+------------------------------------------------------------------+
//| Build joint recurrence matrix and compute all JRQA metrics       |
//+------------------------------------------------------------------+
bool CJRQA::Compute(const double &seriesX[], const double &seriesY[],
                     int seriesLen)
  {
   m_computed = false;
   m_result.Reset();

   if(seriesLen < 4)
     {
      Print("CJRQA::Compute — series too short (min 4 bars)");
      return false;
     }

   if(!m_matrix.Build(seriesX, seriesY, seriesLen,
                      m_epsilonX, m_epsilonY,
                      m_embDim, m_delay, m_norm))
      return false;

   if(!m_metrics.Compute(m_matrix, m_result))
      return false;

   m_computed = true;
   return true;
  }

//+------------------------------------------------------------------+
//| Print all JRQA metrics to the Experts log                        |
//+------------------------------------------------------------------+
void CJRQA::PrintSummary() const
  {
   if(!m_computed)
     {
      Print("CJRQA: Not computed yet — call Compute() first");
      return;
     }
   PrintFormat("===== Joint-RQA Summary =====");
   PrintFormat("EpsilonX     : %.6f  EpsilonY: %.6f  (embDim=%d, delay=%d)",
               m_epsilonX, m_epsilonY, m_embDim, m_delay);
   PrintFormat("Matrix       : %d x %d", m_matrix.Size(), m_matrix.Size());
   PrintFormat("JRR          : %.4f  (%.2f%%)", m_result.JRR, m_result.JRR * 100.0);
   PrintFormat("JDET         : %.4f", m_result.JDET);
   PrintFormat("JLAM         : %.4f", m_result.JLAM);
   PrintFormat("JTT          : %.4f", m_result.JTT);
   PrintFormat("JL (avg diag): %.4f", m_result.JL);
   PrintFormat("JLmax        : %.0f",  m_result.JLmax);
   PrintFormat("JVmax        : %.0f",  m_result.JVmax);
   PrintFormat("JENTR        : %.4f",  m_result.JENTR);
   PrintFormat("JDIV         : %.4f",  m_result.JDIV);
   PrintFormat("JRATIO       : %.4f",  m_result.JRATIO);
   PrintFormat("JTREND       : %.6f",  m_result.JTREND);
   PrintFormat("JCOMPLEXITY  : %.6f",  m_result.JCOMPLEXITY);
   PrintFormat("=============================");
  }

#endif // RQA_MQH
