//+------------------------------------------------------------------+
//|                                                  RNAMetrics.mqh  |
//|                          RQA Library for MQL5                    |
//|       Recurrence Network Analysis — Graph Metrics Module         |
//|                                                                  |
//|  Reinterprets an NxN recurrence matrix R(i,j) as the adjacency   |
//|  matrix A(i,j) of an undirected complex network (no self-loops). |
//|  Each time point is a node; an edge exists iff R(i,j)=1, i!=j.   |
//|                                                                  |
//|  Works with any square recurrence matrix via ComputeFromAdj():   |
//|    — Standard RP  (CRQAMatrix)  → single-series RNA              |
//|    — Joint RP     (CJRQAMatrix) → two-series JRN                 |
//|                                                                  |
//|  Metrics computed:                                               |
//|    AvgDegree      — Mean node degree <k>                         |
//|    MaxDegree      — Maximum degree in the network                |
//|    DegreeStd      — Standard deviation of degree distribution    |
//|    AvgClustering  — Average local clustering coefficient (ACC)   |
//|    Transitivity   — Global clustering coefficient (triangles)    |
//|    AvgPathLength  — Average shortest path length (APL)           |
//|    Diameter       — Network diameter (longest shortest path)     |
//|    AvgBetweenness — Mean betweenness centrality (normalized)     |
//|    MaxBetweenness — Maximum betweenness centrality (normalized)  |
//|    AvgCloseness   — Mean closeness centrality                    |
//|    Assortativity  — Degree assortativity coefficient             |
//|    Density        — Network density = 2|E| / (N*(N-1))           |
//+------------------------------------------------------------------+
#ifndef RNAMETRICS_MQH
#define RNAMETRICS_MQH

#include "RQAMatrix.mqh"

//+------------------------------------------------------------------+
//| Struct to hold all computed RNA results                          |
//+------------------------------------------------------------------+
struct SRNAResult
  {
   double   AvgDegree;
   double   MaxDegree;
   double   DegreeStd;
   double   AvgClustering;
   double   Transitivity;
   double   AvgPathLength;
   double   Diameter;
   double   AvgBetweenness;
   double   MaxBetweenness;
   double   AvgCloseness;
   double   Assortativity;
   double   Density;

   void     Reset()
     {
      AvgDegree=0; MaxDegree=0; DegreeStd=0;
      AvgClustering=0; Transitivity=0;
      AvgPathLength=0; Diameter=0;
      AvgBetweenness=0; MaxBetweenness=0;
      AvgCloseness=0; Assortativity=0; Density=0;
     }
  };

//+------------------------------------------------------------------+
//| CRNAMetrics — computes network measures from adjacency data      |
//|                                                                  |
//|  Two entry points:                                               |
//|    Compute()        — from CRQAMatrix (single-series RNA)        |
//|    ComputeFromAdj() — from flat char[] adjacency (generic)       |
//+------------------------------------------------------------------+
class CRNAMetrics
  {
private:
   void              ComputeDeg(const char &A[], int N,
                                int &degrees[]) const;
   void              ComputeClust(const char &A[], int N,
                                   const int &degrees[],
                                   double &cc[]) const;
   double            ComputeTrans(const char &A[], int N,
                                   const int &degrees[]) const;
   void              BFSArr(const char &A[], int start, int N,
                            int &dist[]) const;
   void              ComputePaths(const char &A[], int N,
                                   double &avgPath, double &diam,
                                   double &closeness[]) const;
   void              ComputeBC(const char &A[], int N,
                                double &bc[]) const;
   double            ComputeAssort(const char &A[], int N,
                                    const int &degrees[]) const;

public:
   bool              Compute(const CRQAMatrix &mat,
                             SRNAResult &result) const;

   bool              ComputeFromAdj(const char &adj[], int N,
                                     SRNAResult &result) const;
  };

//+------------------------------------------------------------------+
//| Convenience wrapper — extract CRQAMatrix into flat adjacency     |
//+------------------------------------------------------------------+
bool CRNAMetrics::Compute(const CRQAMatrix &mat,
                           SRNAResult &result) const
  {
   int N = mat.Size();
   if(N < 3)
     {
      Print("CRNAMetrics::Compute — network too small (min 3 nodes)");
      return false;
     }

   char adj[];
   ArrayResize(adj, N * N);
   for(int i = 0; i < N; i++)
      for(int j = 0; j < N; j++)
         adj[i * N + j] = (char)((i != j && mat.Get(i, j)) ? 1 : 0);

   return ComputeFromAdj(adj, N, result);
  }

//+------------------------------------------------------------------+
//| Compute node degrees (row sums; self-loops already excluded)     |
//+------------------------------------------------------------------+
void CRNAMetrics::ComputeDeg(const char &A[], int N,
                              int &degrees[]) const
  {
   ArrayResize(degrees, N);
   ArrayInitialize(degrees, 0);
   for(int i = 0; i < N; i++)
     {
      int off = i * N;
      for(int j = 0; j < N; j++)
         if(A[off + j] != 0)
            degrees[i]++;
     }
  }

//+------------------------------------------------------------------+
//| Local clustering coefficient per node                            |
//|  C(i) = 2 * links_among_neighbors / (k * (k-1))                  |
//+------------------------------------------------------------------+
void CRNAMetrics::ComputeClust(const char &A[], int N,
                                const int &degrees[],
                                double &cc[]) const
  {
   ArrayResize(cc, N);
   ArrayInitialize(cc, 0.0);

   int neighbors[];
   ArrayResize(neighbors, N);

   for(int i = 0; i < N; i++)
     {
      int k = degrees[i];
      if(k < 2) continue;

      int nCnt = 0;
      int off  = i * N;
      for(int j = 0; j < N; j++)
         if(A[off + j] != 0)
            neighbors[nCnt++] = j;

      int links = 0;
      for(int a = 0; a < nCnt; a++)
         for(int b = a + 1; b < nCnt; b++)
            if(A[neighbors[a] * N + neighbors[b]] != 0)
               links++;

      cc[i] = (2.0 * links) / ((double)k * (k - 1));
     }
  }

//+------------------------------------------------------------------+
//| Transitivity (global clustering coefficient)                     |
//|  T = 3 * triangles / connected_triples                           |
//+------------------------------------------------------------------+
double CRNAMetrics::ComputeTrans(const char &A[], int N,
                                  const int &degrees[]) const
  {
   long triangles = 0;
   for(int i = 0; i < N; i++)
      for(int j = i + 1; j < N; j++)
         if(A[i * N + j] != 0)
            for(int k = j + 1; k < N; k++)
               if(A[i * N + k] != 0 && A[j * N + k] != 0)
                  triangles++;

   long triples = 0;
   for(int i = 0; i < N; i++)
      triples += (long)degrees[i] * (degrees[i] - 1) / 2;

   if(triples == 0) return 0.0;
   return (double)(3 * triangles) / triples;
  }

//+------------------------------------------------------------------+
//| BFS from a single source node on flat adjacency                  |
//+------------------------------------------------------------------+
void CRNAMetrics::BFSArr(const char &A[], int start, int N,
                          int &dist[]) const
  {
   ArrayInitialize(dist, -1);
   dist[start] = 0;

   int queue[];
   ArrayResize(queue, N);
   int qF = 0, qB = 0;
   queue[qB++] = start;

   while(qF < qB)
     {
      int u   = queue[qF++];
      int off = u * N;
      for(int v = 0; v < N; v++)
        {
         if(dist[v] != -1 || A[off + v] == 0) continue;
         dist[v] = dist[u] + 1;
         queue[qB++] = v;
        }
     }
  }

//+------------------------------------------------------------------+
//| Average path length, diameter, closeness centrality              |
//|  Handles disconnected graphs: only counts reachable pairs.       |
//|  Closeness uses Wasserman-Faust normalization.                   |
//+------------------------------------------------------------------+
void CRNAMetrics::ComputePaths(const char &A[], int N,
                                double &avgPath, double &diam,
                                double &closeness[]) const
  {
   ArrayResize(closeness, N);
   ArrayInitialize(closeness, 0.0);

   int dist[];
   ArrayResize(dist, N);

   double totalDist  = 0;
   long   totalPairs = 0;
   int    maxDist    = 0;

   for(int s = 0; s < N; s++)
     {
      BFSArr(A, s, N, dist);

      int  reachable = 0;
      long sumDist   = 0;

      for(int t = 0; t < N; t++)
        {
         if(t == s) continue;
         if(dist[t] > 0)
           {
            sumDist += dist[t];
            reachable++;
            if(dist[t] > maxDist)
               maxDist = dist[t];
           }
        }

      totalDist  += (double)sumDist;
      totalPairs += reachable;

      if(reachable > 0 && sumDist > 0)
         closeness[s] = ((double)reachable * reachable)
                        / ((double)(N - 1) * sumDist);
     }

   avgPath = (totalPairs > 0) ? totalDist / totalPairs : 0.0;
   diam    = (double)maxDist;
  }

//+------------------------------------------------------------------+
//| Betweenness centrality — Brandes algorithm (unweighted)          |
//+------------------------------------------------------------------+
void CRNAMetrics::ComputeBC(const char &A[], int N,
                              double &bc[]) const
  {
   ArrayResize(bc, N);
   ArrayInitialize(bc, 0.0);

   int    sigma[];
   int    dist[];
   double delta[];
   int    stack[];
   int    queue[];
   int    predStore[];
   int    predCnt[];

   ArrayResize(sigma,     N);
   ArrayResize(dist,      N);
   ArrayResize(delta,     N);
   ArrayResize(stack,     N);
   ArrayResize(queue,     N);
   ArrayResize(predStore, N * N);
   ArrayResize(predCnt,   N);

   for(int s = 0; s < N; s++)
     {
      ArrayInitialize(sigma, 0);    sigma[s] = 1;
      ArrayInitialize(dist, -1);    dist[s]  = 0;
      ArrayInitialize(delta, 0.0);
      ArrayInitialize(predCnt, 0);

      int sTop = 0, qF = 0, qB = 0;
      queue[qB++] = s;

      while(qF < qB)
        {
         int v   = queue[qF++];
         int off = v * N;
         stack[sTop++] = v;

         for(int w = 0; w < N; w++)
           {
            if(A[off + w] == 0) continue;

            if(dist[w] == -1)
              {
               dist[w] = dist[v] + 1;
               queue[qB++] = w;
              }
            if(dist[w] == dist[v] + 1)
              {
               sigma[w] += sigma[v];
               predStore[w * N + predCnt[w]] = v;
               predCnt[w]++;
              }
           }
        }

      while(sTop > 0)
        {
         int w = stack[--sTop];
         for(int p = 0; p < predCnt[w]; p++)
           {
            int v = predStore[w * N + p];
            delta[v] += ((double)sigma[v] / sigma[w])
                        * (1.0 + delta[w]);
           }
         if(w != s)
            bc[w] += delta[w];
        }
     }

   for(int i = 0; i < N; i++)
      bc[i] /= 2.0;
  }

//+------------------------------------------------------------------+
//| Degree assortativity coefficient (Newman 2002)                   |
//|  Pearson correlation of degrees at both ends of each edge.       |
//+------------------------------------------------------------------+
double CRNAMetrics::ComputeAssort(const char &A[], int N,
                                   const int &degrees[]) const
  {
   double sumProd  = 0;
   double sumSum   = 0;
   double sumSqSum = 0;
   long   M        = 0;

   for(int i = 0; i < N; i++)
      for(int j = i + 1; j < N; j++)
         if(A[i * N + j] != 0)
           {
            double ki = (double)degrees[i];
            double kj = (double)degrees[j];
            sumProd  += ki * kj;
            sumSum   += ki + kj;
            sumSqSum += ki * ki + kj * kj;
            M++;
           }

   if(M == 0) return 0.0;

   double invM  = 1.0 / M;
   double term1 = sumProd * invM;
   double half  = sumSum * 0.5 * invM;
   double term2 = half * half;
   double term3 = sumSqSum * 0.5 * invM;

   double denom = term3 - term2;
   if(MathAbs(denom) < 1e-12) return 0.0;
   return (term1 - term2) / denom;
  }

//+------------------------------------------------------------------+
//| Core computation from flat adjacency char[N*N]                   |
//|  A[i*N+j] != 0 means edge (i,j) exists; A[i*N+i] must be 0.      |
//+------------------------------------------------------------------+
bool CRNAMetrics::ComputeFromAdj(const char &adj[], int N,
                                   SRNAResult &result) const
  {
   result.Reset();
   if(N < 3)
     {
      Print("CRNAMetrics::ComputeFromAdj — network too small");
      return false;
     }

   //--- Degrees
   int degrees[];
   ComputeDeg(adj, N, degrees);

   double sumDeg = 0, sumDeg2 = 0;
   int    maxDeg = 0;
   for(int i = 0; i < N; i++)
     {
      sumDeg  += degrees[i];
      sumDeg2 += (double)degrees[i] * degrees[i];
      if(degrees[i] > maxDeg)
         maxDeg = degrees[i];
     }

   result.AvgDegree = sumDeg / N;
   result.MaxDegree = (double)maxDeg;
   result.DegreeStd = MathSqrt(MathMax(0.0,
                         sumDeg2 / N - result.AvgDegree * result.AvgDegree));
   result.Density   = sumDeg / ((double)N * (N - 1));

   //--- Clustering
   double cc[];
   ComputeClust(adj, N, degrees, cc);

   double sumClust = 0;
   for(int i = 0; i < N; i++) sumClust += cc[i];
   result.AvgClustering = sumClust / N;

   //--- Transitivity
   result.Transitivity = ComputeTrans(adj, N, degrees);

   //--- Path metrics + Closeness
   double closeness[];
   ComputePaths(adj, N,
                result.AvgPathLength, result.Diameter, closeness);

   double sumClose = 0;
   for(int i = 0; i < N; i++) sumClose += closeness[i];
   result.AvgCloseness = sumClose / N;

   //--- Betweenness (Brandes, then normalize to [0,1])
   double betweenness[];
   ComputeBC(adj, N, betweenness);

   double bcNorm = (N > 2)
                   ? 2.0 / ((double)(N - 1) * (N - 2))
                   : 1.0;
   double sumBC = 0, maxBC = 0;
   for(int i = 0; i < N; i++)
     {
      double nbc = betweenness[i] * bcNorm;
      sumBC += nbc;
      if(nbc > maxBC) maxBC = nbc;
     }
   result.AvgBetweenness = sumBC / N;
   result.MaxBetweenness = maxBC;

   //--- Assortativity
   result.Assortativity = ComputeAssort(adj, N, degrees);

   return true;
  }

#endif // RNAMETRICS_MQH
