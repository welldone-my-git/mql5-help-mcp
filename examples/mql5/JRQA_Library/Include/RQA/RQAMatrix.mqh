//+------------------------------------------------------------------+
//|                                                    RQAMatrix.mqh |
//|                          RQA Library for MQL5                    |
//|                    Recurrence Matrix Core Module                 |
//+------------------------------------------------------------------+
#ifndef RQAMATRIX_MQH
#define RQAMATRIX_MQH

//+------------------------------------------------------------------+
//| Distance norms                                                   |
//+------------------------------------------------------------------+
enum ENUM_RQA_NORM
  {
   RQA_NORM_MAX       = 0,   // Maximum norm (Chebyshev)
   RQA_NORM_EUCLIDEAN = 1,   // Euclidean norm
   RQA_NORM_MANHATTAN = 2    // Manhattan (L1) norm
  };

//+------------------------------------------------------------------+
//| CRQAMatrix — builds & stores the recurrence matrix               |
//+------------------------------------------------------------------+
class CRQAMatrix
  {
private:
   int               m_N;           // number of embedded vectors
   int               m_embDim;      // embedding dimension
   int               m_delay;       // time delay (tau)
   double            m_epsilon;     // threshold
   ENUM_RQA_NORM     m_norm;        // distance norm

   bool              m_R[];         // flattened NxN boolean matrix
   double            m_embedded[];  // flattened embedded vectors [N x embDim]

   //--- helpers
   void              Embed(const double &series[], int seriesLen);
   double            Distance(int i, int j) const;
   bool              RIdx(int i, int j) const { return m_R[i * m_N + j]; }

public:
                     CRQAMatrix();
                    ~CRQAMatrix() {}

   //--- build matrix
   bool              Build(const double &series[], int seriesLen,
                           double epsilon,
                           int embDim      = 1,
                           int delay       = 1,
                           ENUM_RQA_NORM norm = RQA_NORM_EUCLIDEAN);

   //--- accessors
   bool              Get(int i, int j)  const;
   int               Size()             const { return m_N; }
   double            Epsilon()          const { return m_epsilon; }
   int               EmbDim()           const { return m_embDim; }
   int               Delay()            const { return m_delay; }
   ENUM_RQA_NORM     Norm()             const { return m_norm; }
  };

//+------------------------------------------------------------------+
//| Default constructor                                              |
//+------------------------------------------------------------------+
CRQAMatrix::CRQAMatrix()
   : m_N(0), m_embDim(1), m_delay(1), m_epsilon(0.0), m_norm(RQA_NORM_EUCLIDEAN)
  {
  }

//+------------------------------------------------------------------+
//| Time-delay embedding                                             |
//+------------------------------------------------------------------+
void CRQAMatrix::Embed(const double &series[], int seriesLen)
  {
   m_N = seriesLen - (m_embDim - 1) * m_delay;
   if(m_N <= 0)
     {
      m_N = 0;
      return;
     }
   ArrayResize(m_embedded, m_N * m_embDim);
   for(int i = 0; i < m_N; i++)
      for(int d = 0; d < m_embDim; d++)
         m_embedded[i * m_embDim + d] = series[i + d * m_delay];
  }

//+------------------------------------------------------------------+
//| Distance between embedded vectors i and j                        |
//+------------------------------------------------------------------+
double CRQAMatrix::Distance(int i, int j) const
  {
   double dist = 0.0;
   for(int d = 0; d < m_embDim; d++)
     {
      double diff = m_embedded[i * m_embDim + d] - m_embedded[j * m_embDim + d];
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
//| Build the full NxN recurrence matrix                             |
//+------------------------------------------------------------------+
bool CRQAMatrix::Build(const double &series[], int seriesLen,
                        double epsilon,
                        int embDim,
                        int delay,
                        ENUM_RQA_NORM norm)
  {
   if(seriesLen < 2 || epsilon <= 0.0 || embDim < 1 || delay < 1)
     {
      Print("RQAMatrix::Build — invalid parameters");
      return false;
     }

   m_epsilon = epsilon;
   m_embDim  = embDim;
   m_delay   = delay;
   m_norm    = norm;

   Embed(series, seriesLen);
   if(m_N <= 0)
     {
      Print("RQAMatrix::Build — series too short for given embedding");
      return false;
     }

   ArrayResize(m_R, m_N * m_N);
   for(int i = 0; i < m_N; i++)
      for(int j = 0; j < m_N; j++)
         m_R[i * m_N + j] = (Distance(i, j) <= m_epsilon);

   return true;
  }

//+------------------------------------------------------------------+
//| Bounds-checked access to recurrence matrix element R(i,j)        |
//+------------------------------------------------------------------+
bool CRQAMatrix::Get(int i, int j) const
  {
   if(i < 0 || i >= m_N || j < 0 || j >= m_N)
      return false;
   return m_R[i * m_N + j];
  }

#endif // RQAMATRIX_MQH
