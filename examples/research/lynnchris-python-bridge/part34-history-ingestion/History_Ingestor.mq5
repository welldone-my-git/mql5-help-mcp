//+------------------------------------------------------------------+
//|                                                  History Ingestor|
//|                                   Copyright 2025, MetaQuotes Ltd.|
//|                           https://www.mql5.com/en/users/lynnchris|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com/en/users/lynnchris"
#property strict
#property script_show_inputs
#property version   "1.0"

input int              DaysBack        = 120;             // days of data
input ENUM_TIMEFRAMES  Timeframe       = PERIOD_M1;       // timeframe
input int              StartChunkBars  = 5000;            // FIRST slice
input int              Timeout_ms      = 120000;          // per-POST
input int              MaxRetry        = 3;
input int              PauseBetween_ms = 200;             // gap btw posts
input string           PythonURL       = "http://127.0.0.1:5000/upload_history";

#define MAX_BYTES  14000000   // keep well below MT5 16 MiB limit
#define MIN_CHUNK  1000

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
inline string L2S(long v) {   return StringFormat("%I64d",v); }
inline string D2S(double v) { return StringFormat("%.5f",v);  }
void add(string& s,const string v,bool comma) { s+=v; if(comma) s+=","; }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string BuildJSON(const string& sym,
                 const long& T[],const double& C[],
                 const double& H[],const double& L[],
                 int from,int to)
  {
   string j="{\"symbol\":\""+sym+"\",\"time\":[";
   for(int i=from;i<to;i++)
      add(j,L2S(T[i]),i<to-1);
   j+="],\"close\":[";
   for(int i=from;i<to;i++)
      add(j,D2S(C[i]),i<to-1);
   j+="],\"high\":[";
   for(int i=from;i<to;i++)
      add(j,D2S(H[i]),i<to-1);
   j+="],\"low\":[";
   for(int i=from;i<to;i++)
      add(j,D2S(L[i]),i<to-1);
   j+="]}";
   return j;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool PostChunk(const string& json,int from,int to)
  {
   char body[];
   StringToCharArray(json,body,0,StringLen(json),CP_UTF8);
   char reply[];
   string hdr="Content-Type: application/json\r\n",rep_hdr;

   for(int r=1;r<=MaxRetry;r++)
     {
      int http = WebRequest("POST",PythonURL,hdr,Timeout_ms,
                            body,reply,rep_hdr);
      if(http!=-1 && http<400)
        {
         PrintFormat("Chunk %d-%d  HTTP %d  %s",from,to,http,
                     CharArrayToString(reply,0,WHOLE_ARRAY,CP_UTF8));
         return true;
        }
      PrintFormat("Chunk %d-%d  retry %d failed (http=%d err=%d)",
                  from,to,r,http,GetLastError());
      Sleep(500);
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnStart()
  {
   Print("HistoryUploader v3.20  (timeout=",Timeout_ms," ms) ready");
   datetime t2=TimeCurrent(), t1=t2-(datetime)DaysBack*24*60*60;

   MqlRates r[];
   int total=CopyRates(_Symbol,Timeframe,t1,t2,r);
   if(total<=0)
     {
      Print("CopyRates error ",GetLastError());
      return INIT_FAILED;
     }
   ArraySetAsSeries(r,false);

   long T[];
   double Cl[],Hi[],Lo[];
   ArrayResize(T,total);
   ArrayResize(Cl,total);
   ArrayResize(Hi,total);
   ArrayResize(Lo,total);
   for(int i=0;i<total;i++)
     {
      T[i]=r[i].time;
      Cl[i]=r[i].close;
      Hi[i]=r[i].high;
      Lo[i]=r[i].low;
     }

   for(int i=0;i<total;)
     {
      int step=StartChunkBars;
      bool sent=false;
      while(step>=MIN_CHUNK)
        {
         int to=MathMin(total,i+step);
         string js=BuildJSON(_Symbol,T,Cl,Hi,Lo,i,to);
         PrintFormat("Test %d-%d  size=%.2f MB",i,to,double(StringLen(js))/1e6);

         if(StringLen(js)<MAX_BYTES)
           {
            if(!PostChunk(js,i,to))
               return INIT_FAILED;
            i=to;
            sent=true;
            Sleep(PauseBetween_ms);
            break;
           }
         step/=2;
        }
      if(!sent)
        {
         Print("Unable to fit minimum chunk – abort");
         return INIT_FAILED;
        }
     }
   Print("Upload finished: ",total," bars.");
   return INIT_SUCCEEDED;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
