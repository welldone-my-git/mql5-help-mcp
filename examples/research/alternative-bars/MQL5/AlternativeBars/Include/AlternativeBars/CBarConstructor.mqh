//+------------------------------------------------------------------+
//|                                             CBarConstructor.mqh  |
//|                                              Patrick M. Njoroge  |
//|                 https://www.mql5.com/en/users/patricknjoroge743  |
//+------------------------------------------------------------------+
//|  Abstract base class for tick-driven alternative bar constructors|
//|  Mirrors afml.data_structures.bars on the Python side.           |
//+------------------------------------------------------------------+
#property copyright "Patrick M. Njoroge"
#property link      "https://www.mql5.com/en/users/patricknjoroge743"
#property strict

#ifndef __CBAR_CONSTRUCTOR_MQH__
#define __CBAR_CONSTRUCTOR_MQH__

//+------------------------------------------------------------------+
//| Emitted bar record. Fields mirror the columns produced by the    |
//| Python make_bars() function exactly.                             |
//+------------------------------------------------------------------+
struct SBar
  {
   datetime          time;           // Bar close time (right edge for time bars,
   // last-tick time for all other bar types)
   double            open;           // Open price (bid of the first tick in bar)
   double            high;           // High price (max bid observed in bar)
   double            low;            // Low price  (min bid observed in bar)
   double            close;          // Close price (bid of the last tick in bar)
   double            mid_open;       // Mid-price at bar open
   double            mid_close;      // Mid-price at bar close
   long              tick_volume;    // Number of ticks in the bar
   double            volume;         // Sum of tick.volume (tick-volume proxy on FX)
   double            spread;         // Mean (ask - bid) over the bar
   long              tick_num;       // 1-based global tick index at bar close
   string            bar_type;       // "time" | "tick" | "volume" | "dollar"
   //  | "tick_imbalance" | "volume_imbalance"
   //  | "dollar_imbalance"
  };

//+------------------------------------------------------------------+
//| Abstract base class. Owns the OHLC accumulator and emission      |
//| plumbing. Each derived class implements ProcessTick() with the   |
//| close semantics for its bar type.                                |
//+------------------------------------------------------------------+
class CBarConstructor
  {
protected:
   //--- Bar accumulator state
   bool              m_initialized;
   double            m_open, m_high, m_low, m_close;
   double            m_mid_open, m_mid_close;
   long              m_tick_volume;
   double            m_volume;
   double            m_spread_sum;
   datetime          m_last_tick_time;
   long              m_last_tick_num;
   long              m_bar_start_tick_num;
   string            m_bar_type;

   //--- Seed the accumulator with the first tick of a new bar
   void              SeedBar(const MqlTick &tick, const long tick_num);

   //--- Fold a subsequent tick into the running OHLC/volume/spread
   void              UpdateAccumulator(const MqlTick &tick, const long tick_num);

   //--- Copy closed-bar state into the caller's SBar
   void              FillBar(SBar &bar);

public:
                     CBarConstructor(const string bar_type);
   virtual          ~CBarConstructor(void) {}

   //--- Feed one tick. Returns true iff a bar closed on this call.
   //--- When true, the closed bar is written into out_bar by reference.
   virtual bool      ProcessTick(const MqlTick &tick,
                                 const long tick_num,
                                 SBar &out_bar) = 0;

   //--- State persistence for EA restart recovery. Derived classes
   //--- with additional state (e.g. CImbalanceBar) override to chain.
   virtual bool      SaveState(const int file_handle);
   virtual bool      LoadState(const int file_handle);

   //--- Accessors
   string            BarType(void) const { return m_bar_type; }
   bool              IsInitialized(void) const { return m_initialized; }
  };

//+------------------------------------------------------------------+
//| Constructor — initialize all accumulator state to sentinel values|
//+------------------------------------------------------------------+
CBarConstructor::CBarConstructor(const string bar_type)
  {
   m_initialized        = false;
   m_open               = 0.0;
   m_high               = 0.0;
   m_low                = 0.0;
   m_close              = 0.0;
   m_mid_open           = 0.0;
   m_mid_close          = 0.0;
   m_tick_volume        = 0;
   m_volume             = 0.0;
   m_spread_sum         = 0.0;
   m_last_tick_time     = 0;
   m_last_tick_num      = 0;
   m_bar_start_tick_num = 0;
   m_bar_type           = bar_type;
  }

//+------------------------------------------------------------------+
//| SeedBar — initialize accumulator from the first tick of a new bar|
//| Uses bid for OHLC (matches Python reference); stores mid for     |
//| mid_open/mid_close; spread_sum starts at one tick's (ask - bid). |
//+------------------------------------------------------------------+
void CBarConstructor::SeedBar(const MqlTick &tick, const long tick_num)
  {
   double mid           = 0.5 * (tick.bid + tick.ask);
   m_open               = tick.bid;
   m_high               = tick.bid;
   m_low                = tick.bid;
   m_close              = tick.bid;
   m_mid_open           = mid;
   m_mid_close          = mid;
   m_tick_volume        = 1;
   m_volume             = (double)tick.volume;
   m_spread_sum         = tick.ask - tick.bid;
   m_last_tick_time     = tick.time;
   m_last_tick_num      = tick_num;
   m_bar_start_tick_num = tick_num;
   m_initialized        = true;
  }

//+------------------------------------------------------------------+
//| UpdateAccumulator — fold a non-seed tick into the running bar    |
//+------------------------------------------------------------------+
void CBarConstructor::UpdateAccumulator(const MqlTick &tick, const long tick_num)
  {
   if(tick.bid > m_high)
      m_high = tick.bid;
   if(tick.bid < m_low)
      m_low  = tick.bid;
   m_close              = tick.bid;
   m_mid_close          = 0.5 * (tick.bid + tick.ask);
   m_tick_volume       += 1;
   m_volume            += (double)tick.volume;
   m_spread_sum        += (tick.ask - tick.bid);
   m_last_tick_time     = tick.time;
   m_last_tick_num      = tick_num;
  }

//+------------------------------------------------------------------+
//| FillBar — copy closed state into caller's SBar                   |
//+------------------------------------------------------------------+
void CBarConstructor::FillBar(SBar &bar)
  {
   bar.time        = m_last_tick_time;
   bar.open        = m_open;
   bar.high        = m_high;
   bar.low         = m_low;
   bar.close       = m_close;
   bar.mid_open    = m_mid_open;
   bar.mid_close   = m_mid_close;
   bar.tick_volume = m_tick_volume;
   bar.volume      = m_volume;
   bar.spread      = (m_tick_volume > 0) ? m_spread_sum / (double)m_tick_volume : 0.0;
   bar.tick_num    = m_last_tick_num;
   bar.bar_type    = m_bar_type;
  }

//+------------------------------------------------------------------+
//| SaveState — serialize the base-class accumulator                 |
//| Derived classes override and call the base first, then write     |
//| their own additional state.                                      |
//+------------------------------------------------------------------+
bool CBarConstructor::SaveState(const int fh)
  {
   if(fh == INVALID_HANDLE)
      return false;
   FileWriteInteger(fh, (int)m_initialized);
   FileWriteDouble(fh, m_open);
   FileWriteDouble(fh, m_high);
   FileWriteDouble(fh, m_low);
   FileWriteDouble(fh, m_close);
   FileWriteDouble(fh, m_mid_open);
   FileWriteDouble(fh, m_mid_close);
   FileWriteLong(fh, m_tick_volume);
   FileWriteDouble(fh, m_volume);
   FileWriteDouble(fh, m_spread_sum);
   FileWriteLong(fh, (long)m_last_tick_time);
   FileWriteLong(fh, m_last_tick_num);
   FileWriteLong(fh, m_bar_start_tick_num);
   return true;
  }

//+------------------------------------------------------------------+
//| LoadState — deserialize the base-class accumulator               |
//+------------------------------------------------------------------+
bool CBarConstructor::LoadState(const int fh)
  {
   if(fh == INVALID_HANDLE)
      return false;
   m_initialized        = (bool)FileReadInteger(fh);
   m_open               = FileReadDouble(fh);
   m_high               = FileReadDouble(fh);
   m_low                = FileReadDouble(fh);
   m_close              = FileReadDouble(fh);
   m_mid_open           = FileReadDouble(fh);
   m_mid_close          = FileReadDouble(fh);
   m_tick_volume        = FileReadLong(fh);
   m_volume             = FileReadDouble(fh);
   m_spread_sum         = FileReadDouble(fh);
   m_last_tick_time     = (datetime)FileReadLong(fh);
   m_last_tick_num      = FileReadLong(fh);
   m_bar_start_tick_num = FileReadLong(fh);
   return true;
  }
//+------------------------------------------------------------------+

#endif // __CBAR_CONSTRUCTOR_MQH__

