//+------------------------------------------------------------------+
//|                                              LiveCSVStreamer.mqh |
//|     Event-Driven Live Streaming Export Engine for MQL5 Terminals |
//+------------------------------------------------------------------+

#ifndef LIVE_CSV_STREAMER_MQH
#define LIVE_CSV_STREAMER_MQH

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "--- Live CSV Streaming Settings ---"
input bool  InpStreamingEnabled = true;  // Enable live CSV streaming
input int   InpFlushThreshold   = 20;    // Rows to buffer before flushing
input bool  InpStreamTicks      = false; // Stream tick-level records
input bool  InpStreamBars       = true;  // Stream bar-close-level records
input bool  InpUseCommonFolder  = true;  // Write to MetaTrader 5 common files directory

//--- Buffer allocation boundary constraints
#define STREAMER_MAX_BUFFER 500

//+------------------------------------------------------------------+
//| Bar-level metric record written at each bar close                |
//+------------------------------------------------------------------+
struct SLiveBarRecord
  {
   datetime          bar_time;         // Open time of the closed bar (UTC)
   string            symbol;           // Chart symbol
   string            timeframe;        // Chart timeframe label
   double            open;             // Bar open price
   double            high;             // Bar high price
   double            low;              // Bar low price
   double            close;            // Bar close price
   double            volume;           // Tick volume for the closed bar
   double            filter_value;     // Indicator value at bar close
   int               filter_slope;     // 1 = rising, -1 = falling, 0 = flat
   int               false_flips;      // Cumulative whipsaw count since session start
   double            avg_lag_bars;     // Rolling average lag since session start
   double            session_equity;   // Terminal equity at bar close
  };

//+------------------------------------------------------------------+
//| Tick-level record written on every new tick                      |
//+------------------------------------------------------------------+
struct SLiveTickRecord
  {
   datetime          tick_time;        // Tick timestamp (UTC)
   string            symbol;           // Chart symbol
   double            bid;              // Bid price
   double            ask;              // Ask price
   double            spread_points;    // Spread in points
   double            filter_value;     // Indicator value at this tick
  };

//+------------------------------------------------------------------+
//| Managed in-memory data accumulation and file pipeline structure  |
//+------------------------------------------------------------------+
class CStreamBuffer
  {
private:
   string            m_rows[];           // In-memory row buffer
   int               m_count;            // Current buffered row count
   int               m_flush_threshold;  // Row count that triggers a flush
   string            m_active_file;      // Currently active output file name
   string            m_symbol;           // Host symbol for file naming
   string            m_tf_str;           // Timeframe string for file naming
   datetime          m_active_date;      // UTC date of the active file
   bool              m_use_common;       // Common folder flag

   //--- Internal pipeline utility methods
   string            BuildFileName(datetime utc_date);
   void              CheckRotation();
   bool              WriteFileHeader(const string file_name, const bool bar_mode);
   bool              FlushToFile();

public:
                     CStreamBuffer();
                    ~CStreamBuffer();

   //--- Control and configuration interface
   void              Initialize(const string symbol,
                                const string tf_str,
                                const int    flush_threshold,
                                const bool   use_common);
   void              Push(const string row);
   void              ForceFlush();
   string            ActiveFile() const;
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStreamBuffer::CStreamBuffer()
  {
   m_count           = 0;
   m_flush_threshold = 20;
   m_active_file     = "";
   m_symbol          = "";
   m_tf_str          = "";
   m_active_date     = 0;
   m_use_common      = true;

   ::ArrayResize(m_rows, STREAMER_MAX_BUFFER);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStreamBuffer::~CStreamBuffer()
  {
   if(m_count > 0)
      FlushToFile();
  }

//+------------------------------------------------------------------+
//| Initialize buffer parameters and active date structures          |
//+------------------------------------------------------------------+
void CStreamBuffer::Initialize(const string symbol,
                               const string tf_str,
                               const int    flush_threshold,
                               const bool   use_common)
  {
   m_symbol          = symbol;
   m_tf_str          = tf_str;
   m_flush_threshold = flush_threshold;
   m_use_common      = use_common;
   m_active_date     = (datetime)((long)::TimeCurrent() / 86400 * 86400);
   m_active_file     = BuildFileName(m_active_date);
  }

//+------------------------------------------------------------------+
//| Build date-qualified system output file name                     |
//+------------------------------------------------------------------+
string CStreamBuffer::BuildFileName(datetime utc_date)
  {
   MqlDateTime dt;
   ::TimeToStruct(utc_date, dt);

   return(::StringFormat("LiveStream_%s_%s_%04d%02d%02d.csv",
                         m_symbol, m_tf_str,
                         dt.year, dt.mon, dt.day));
  }

//+------------------------------------------------------------------+
//| Monitor temporal bounds and execute file rotations when required |
//+------------------------------------------------------------------+
void CStreamBuffer::CheckRotation()
  {
   datetime today_utc = (datetime)((long)::TimeCurrent() / 86400 * 86400);

   if(today_utc > m_active_date)
     {
      if(m_count > 0)
         FlushToFile();

      m_active_date = today_utc;
      m_active_file = BuildFileName(m_active_date);

      ::PrintFormat("[LiveCSVStreamer] File rotated to: %s", m_active_file);
     }
  }

//+------------------------------------------------------------------+
//| Populate structural schema headers into newly initialized files  |
//+------------------------------------------------------------------+
bool CStreamBuffer::WriteFileHeader(const string file_name,
                                    const bool   bar_mode)
  {
   int flags = FILE_WRITE | FILE_CSV | FILE_ANSI;
   if(m_use_common)
      flags |= FILE_COMMON;

   int handle = ::FileOpen(file_name, flags, ',');
   if(handle == INVALID_HANDLE)
     {
      ::PrintFormat("[LiveCSVStreamer] Header write failed for [%s]. Error: %d",
                    file_name, ::GetLastError());
      return(false);
     }

   if(bar_mode)
     {
      ::FileWriteString(handle,
                        "Bar_Time,Symbol,Timeframe,Open,High,Low,Close,Volume,"
                        "Filter_Value,Filter_Slope,False_Flips_Cumulative,"
                        "Avg_Lag_Bars_Rolling,Session_Equity\n");
     }
   else
     {
      ::FileWriteString(handle,
                        "Tick_Time,Symbol,Bid,Ask,Spread_Points,Filter_Value\n");
     }

   ::FileClose(handle);
   return(true);
  }

//+------------------------------------------------------------------+
//| Flush block buffer contents down to local physical media disk    |
//+------------------------------------------------------------------+
bool CStreamBuffer::FlushToFile()
  {
   if(m_count == 0 || m_active_file == "")
      return(true);

   int flags = FILE_WRITE | FILE_READ | FILE_CSV | FILE_ANSI;
   if(m_use_common)
      flags |= FILE_COMMON;

//--- Construct file verification matrix mapping
   bool file_exists = ::FileIsExist(m_active_file, m_use_common ? FILE_COMMON : 0);
   if(!file_exists)
      WriteFileHeader(m_active_file, InpStreamBars);

   int handle = ::FileOpen(m_active_file, flags, ',');
   if(handle == INVALID_HANDLE)
     {
      ::PrintFormat("[LiveCSVStreamer] Flush failed for [%s]. Error: %d",
                    m_active_file, ::GetLastError());
      return(false);
     }

   ::FileSeek(handle, 0, SEEK_END);

//--- Stream sequential buffer entries to active physical handle
   for(int i = 0; i < m_count; i++)
     {
      ::FileWriteString(handle, m_rows[i] + "\n");
     }

   ::FileClose(handle);
   m_count = 0;
   return(true);
  }

//+------------------------------------------------------------------+
//| Push incoming matrix rows onto stack arrays or trigger a flush   |
//+------------------------------------------------------------------+
void CStreamBuffer::Push(const string row)
  {
   CheckRotation();

   if(m_count >= ::MathMin(m_flush_threshold, STREAMER_MAX_BUFFER - 1))
      FlushToFile();

   if(m_count < STREAMER_MAX_BUFFER)
     {
      m_rows[m_count] = row;
      m_count++;
     }
  }

//+------------------------------------------------------------------+
//| Expose public wrapper interface to force instant data commits    |
//+------------------------------------------------------------------+
void CStreamBuffer::ForceFlush()
  {
   FlushToFile();
  }

//+------------------------------------------------------------------+
//| Track name metrics of current active rotation file targets       |
//+------------------------------------------------------------------+
string CStreamBuffer::ActiveFile() const
  {
   return(m_active_file);
  }

//--- Global buffer instance allocation
CStreamBuffer g_stream_buffer;

//+------------------------------------------------------------------+
//| Transform and pass structured bar records to operational frames  |
//+------------------------------------------------------------------+
void StreamBarRecord(const SLiveBarRecord &rec)
  {
   if(!InpStreamingEnabled || !InpStreamBars)
      return;

   string row = ::StringFormat("%s,%s,%s,%.5f,%.5f,%.5f,%.5f,%.0f,%.5f,%d,%d,%.2f,%.2f",
                               ::TimeToString(rec.bar_time, TIME_DATE | TIME_MINUTES),
                               rec.symbol,
                               rec.timeframe,
                               rec.open, rec.high, rec.low, rec.close,
                               rec.volume,
                               rec.filter_value,
                               rec.filter_slope,
                               rec.false_flips,
                               rec.avg_lag_bars,
                               rec.session_equity);

   g_stream_buffer.Push(row);
  }

//+------------------------------------------------------------------+
//| Transform and pass structured tick records to operational frames |
//+------------------------------------------------------------------+
void StreamTickRecord(const SLiveTickRecord &rec)
  {
   if(!InpStreamingEnabled || !InpStreamTicks)
      return;

   string row = ::StringFormat("%s,%s,%.5f,%.5f,%.1f,%.5f",
                               ::TimeToString(rec.tick_time, TIME_DATE | TIME_SECONDS),
                               rec.symbol,
                               rec.bid,
                               rec.ask,
                               rec.spread_points,
                               rec.filter_value);

   g_stream_buffer.Push(row);
  }

//+------------------------------------------------------------------+
//| Global operational initialization gateway framework mapping      |
//+------------------------------------------------------------------+
void InitStreamer(const string symbol, const string tf_str)
  {
   g_stream_buffer.Initialize(symbol, tf_str,
                              InpFlushThreshold,
                              InpUseCommonFolder);

   ::PrintFormat("[LiveCSVStreamer] Initialized. Active file: %s",
                 g_stream_buffer.ActiveFile());
  }

//+------------------------------------------------------------------+
//| Global operational teardown gateway framework mapping            |
//+------------------------------------------------------------------+
void ShutdownStreamer()
  {
   g_stream_buffer.ForceFlush();
   ::Print("[LiveCSVStreamer] Shutdown flush complete.");
  }

#endif // LIVE_CSV_STREAMER_MQH
//+------------------------------------------------------------------+