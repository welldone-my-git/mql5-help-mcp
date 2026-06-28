//+------------------------------------------------------------------+
//|                                                   JRQAMatrix.mqh |
//|                          RQA Library for MQL5                    |
//|              Joint Recurrence Matrix Core Module                 |
//|                                                                  |
//|  JRQA: builds an NxN joint recurrence matrix from two series.    |
//|  JR(i,j) = R_X(i,j) AND R_Y(i,j)                                 |
//|  where R_X(i,j) = 1 iff ||x_i - x_j|| <= epsilonX                |
//|        R_Y(i,j) = 1 iff ||y_i - y_j|| <= epsilonY                |
//|                                                                  |
//|  Both series must have the same length. Each can have its own    |
//|  epsilon for scale-independent analysis.                         |
//+------------------------------------------------------------------+
#ifndef JRQAMATRIX_MQH
#define JRQAMATRIX_MQH

#include "RQAMatrix.mqh"   // reuse ENUM_RQA_NORM

//+------------------------------------------------------------------+
//| CJRQAMatrix — NxN joint recurrence matrix for two series         |
//+------------------------------------------------------------------+
class CJRQAMatrix
  {
private:
   int               m_N;          // number of embedded vectors
   int               m_embDim;
   int               m_delay;
   double            m_epsilonX;
   double            m_epsilonY;
   ENUM_RQA_NORM     m_norm;

   bool              m_R[];        // flattened NxN joint boolean matrix
   double            m_embX[];     // embedded X  [N x embDim]
   double            m_embY[];     // embedded Y  [N x embDim]

   void              Embed(const double &series[], int seriesLen,
                           double &embedded[], int &numVec);
   double            Distance(const double &emb[], int i, int j) const;

public:
                     CJRQAMatrix();
                    ~CJRQAMatrix() {}

   bool              Build(const double &seriesX[], const double &seriesY[],
                           int seriesLen,
                           double epsilonX, double epsilonY,
                           int embDim         = 1,
                           int delay          = 1,
                           ENUM_RQA_NORM norm = RQA_NORM_EUCLIDEAN);

   bool              Get(int i, int j) const;
   int               Size()      const { return m_N; }
   double            EpsilonX()  const { return m_epsilonX; }
   double            EpsilonY()  const { return m_epsilonY; }
   int               EmbDim()    const { return m_embDim; }
   int               Delay()     const { return m_delay; }
   ENUM_RQA_NORM     Norm()      const { return m_norm; }
  };

//+------------------------------------------------------------------+
//| Default constructor                                              |
//+------------------------------------------------------------------+
CJRQAMatrix::CJRQAMatrix()
   : m_N(0), m_embDim(1), m_delay(1),
     m_epsilonX(0.0), m_epsilonY(0.0), m_norm(RQA_NORM_EUCLIDEAN)
  {
  }

//+------------------------------------------------------------------+
//| Embed a single series into delay-coordinate vectors              |
//+------------------------------------------------------------------+
void CJRQAMatrix::Embed(const double &series[], int seriesLen,
                         double &embedded[], int &numVec)
  {
   numVec = seriesLen - (m_embDim - 1) * m_delay;
   if(numVec <= 0) { numVec = 0; return; }

   ArrayResize(embedded, numVec * m_embDim);
   for(int i = 0; i < numVec; i++)
      for(int d = 0; d < m_embDim; d++)
         embedded[i * m_embDim + d] = series[i + d * m_delay];
  }

//+------------------------------------------------------------------+
//| Distance between embedded vectors i and j in a given embedding   |
//+------------------------------------------------------------------+
double CJRQAMatrix::Distance(const double &emb[], int i, int j) const
  {
   double dist = 0.0;
   for(int d = 0; d < m_embDim; d++)
     {
      double diff = emb[i * m_embDim + d] - emb[j * m_embDim + d];
      switch(m_norm)
        {
         case RQA_NORM_MAX:
            dist = MathMax(dist, MathAbs(diff));
            break;
         case RQA_NORM_MANHATTAN:
            dist += MathAbs(diff);
            break;
         case RQA_NORM_EUCLIDEAN:
         default:
            dist += diff * diff;
            break;
        }
     }
   if(m_norm == RQA_NORM_EUCLIDEAN)
      dist = MathSqrt(dist);
   return dist;
  }

//+------------------------------------------------------------------+
//| Build the NxN joint recurrence matrix                            |
//|  JR(i,j) = (||x_i - x_j|| <= epsX) AND (||y_i - y_j|| <= epsY)   |
//+------------------------------------------------------------------+
bool CJRQAMatrix::Build(const double &seriesX[], const double &seriesY[],
                         int seriesLen,
                         double epsilonX, double epsilonY,
                         int embDim,
                         int delay,
                         ENUM_RQA_NORM norm)
  {
   if(seriesLen < 2 || epsilonX <= 0.0 || epsilonY <= 0.0 ||
      embDim < 1 || delay < 1)
     {
      Print("JRQAMatrix::Build — invalid parameters");
      return false;
     }

   m_epsilonX = epsilonX;
   m_epsilonY = epsilonY;
   m_embDim   = embDim;
   m_delay    = delay;
   m_norm     = norm;

   int nX = 0, nY = 0;
   Embed(seriesX, seriesLen, m_embX, nX);
   Embed(seriesY, seriesLen, m_embY, nY);

   m_N = MathMin(nX, nY);

   if(m_N <= 0)
     {
      Print("JRQAMatrix::Build — series too short for given embedding");
      return false;
     }

   ArrayResize(m_R, m_N * m_N);
   for(int i = 0; i < m_N; i++)
      for(int j = 0; j < m_N; j++)
         m_R[i * m_N + j] = (Distance(m_embX, i, j) <= m_epsilonX) &&
                             (Distance(m_embY, i, j) <= m_epsilonY);

   return true;
  }

//+------------------------------------------------------------------+
//| Bounds-checked access to joint recurrence element JR(i,j)        |
//+------------------------------------------------------------------+
bool CJRQAMatrix::Get(int i, int j) const
  {
   if(i < 0 || i >= m_N || j < 0 || j >= m_N)
      return false;
   return m_R[i * m_N + j];
  }

#endif // JRQAMATRIX_MQH
