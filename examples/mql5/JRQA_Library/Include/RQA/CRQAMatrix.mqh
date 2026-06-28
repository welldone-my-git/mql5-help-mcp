//+------------------------------------------------------------------+
//|                                                   CRQAMatrix.mqh |
//|                          RQA Library for MQL5                    |
//|              Cross Recurrence Matrix Core Module                 |
//|                                                                  |
//|  CRQA: builds an NxM cross-recurrence matrix between two         |
//|  different time series (or two segments of the same series).     |
//+------------------------------------------------------------------+
#ifndef CRQAMATRIX_MQH
#define CRQAMATRIX_MQH

#include "RQAMatrix.mqh"   // reuse ENUM_RQA_NORM

//+------------------------------------------------------------------+
//| CCRQAMatrix — NxM cross-recurrence matrix for two series         |
//|                                                                  |
//|  R[i,j] = 1  iff  ||x_i - y_j|| <= epsilon                       |
//|  where x_i = embedded vector from series X at time i             |
//|        y_j = embedded vector from series Y at time j             |
//+------------------------------------------------------------------+
class CCRQAMatrix
  {
private:
   int               m_N;          // embedded vectors from series X
   int               m_M;          // embedded vectors from series Y
   int               m_embDim;     // shared embedding dimension
   int               m_delay;      // shared time delay (tau)
   double            m_epsilon;    // threshold
   ENUM_RQA_NORM     m_norm;       // distance norm

   bool              m_R[];        // flattened N x M boolean matrix
   double            m_embX[];     // embedded X  [N x embDim]
   double            m_embY[];     // embedded Y  [M x embDim]

   //--- helpers
   void              Embed(const double &series[], int seriesLen,
                           double &embedded[], int &numVec);
   double            Distance(int i, int j) const;

public:
                     CCRQAMatrix();
                    ~CCRQAMatrix() {}

   //--- Build N x M cross-recurrence matrix
   bool              Build(const double &seriesX[], int lenX,
                           const double &seriesY[], int lenY,
                           double epsilon,
                           int embDim         = 1,
                           int delay          = 1,
                           ENUM_RQA_NORM norm = RQA_NORM_EUCLIDEAN);

   //--- Accessors
   bool              Get(int i, int j) const;
   int               SizeN()   const { return m_N; }      // rows (X)
   int               SizeM()   const { return m_M; }      // cols (Y)
   double            Epsilon() const { return m_epsilon; }
   int               EmbDim()  const { return m_embDim; }
   int               Delay()   const { return m_delay; }
   ENUM_RQA_NORM     Norm()    const { return m_norm; }
  };

//+------------------------------------------------------------------+
//| Default constructor                                              |
//+------------------------------------------------------------------+
CCRQAMatrix::CCRQAMatrix()
   : m_N(0), m_M(0), m_embDim(1), m_delay(1),
     m_epsilon(0.0), m_norm(RQA_NORM_EUCLIDEAN)
  {
  }

//+------------------------------------------------------------------+
//| Embed a single series into delay-coordinate vectors              |
//+------------------------------------------------------------------+
void CCRQAMatrix::Embed(const double &series[], int seriesLen,
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
//| Distance between x_i and y_j                                     |
//+------------------------------------------------------------------+
double CCRQAMatrix::Distance(int i, int j) const
  {
   double dist = 0.0;
   for(int d = 0; d < m_embDim; d++)
     {
      double diff = m_embX[i * m_embDim + d] - m_embY[j * m_embDim + d];
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
//| Build the full N x M cross-recurrence matrix                     |
//+------------------------------------------------------------------+
bool CCRQAMatrix::Build(const double &seriesX[], int lenX,
                         const double &seriesY[], int lenY,
                         double epsilon,
                         int embDim,
                         int delay,
                         ENUM_RQA_NORM norm)
  {
   if(lenX < 2 || lenY < 2 || epsilon <= 0.0 || embDim < 1 || delay < 1)
     {
      Print("CCRQAMatrix::Build — invalid parameters");
      return false;
     }

   m_epsilon = epsilon;
   m_embDim  = embDim;
   m_delay   = delay;
   m_norm    = norm;

   Embed(seriesX, lenX, m_embX, m_N);
   Embed(seriesY, lenY, m_embY, m_M);

   if(m_N <= 0 || m_M <= 0)
     {
      Print("CCRQAMatrix::Build — series too short for given embedding");
      return false;
     }

   ArrayResize(m_R, m_N * m_M);
   for(int i = 0; i < m_N; i++)
      for(int j = 0; j < m_M; j++)
         m_R[i * m_M + j] = (Distance(i, j) <= m_epsilon);

   return true;
  }

//+------------------------------------------------------------------+
//| Bounds-checked access to cross-recurrence element R(i,j)         |
//+------------------------------------------------------------------+
bool CCRQAMatrix::Get(int i, int j) const
  {
   if(i < 0 || i >= m_N || j < 0 || j >= m_M)
      return false;
   return m_R[i * m_M + j];
  }

#endif // CRQAMATRIX_MQH
