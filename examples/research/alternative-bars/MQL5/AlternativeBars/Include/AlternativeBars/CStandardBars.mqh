//+------------------------------------------------------------------+  
//|                                               CStandardBars.mqh  |  
//|                                              Patrick M. Njoroge  |  
//|                 https://www.mql5.com/en/users/patricknjoroge743  |  
//+------------------------------------------------------------------+  
//|  Standard bar constructors: time, tick, volume, dollar.          |  
//|  Mirror the four non-imbalance branches of _make_bar_type_grouper|  
//|  on the Python side.                                             |  
//+------------------------------------------------------------------+  
#property copyright "Patrick M. Njoroge"  
#property strict  

#ifndef __CSTANDARD_BARS_MQH__  
#define __CSTANDARD_BARS_MQH__  

#include "CBarConstructor.mqh"  

//+------------------------------------------------------------------+  
//| CTimeBar — closes when the tick's floor(time/bar_seconds)        |  
//| differs from the current window. Label is the right edge of the  |  
//| window, matching Python's resample(closed='left', label='right').|  
//+------------------------------------------------------------------+  
class CTimeBar : public CBarConstructor  
  {  
private:  
   int               m_bar_seconds;  
   datetime          m_current_window_start;  

   datetime          BarFloor(const datetime t) const  
     {  
      return (datetime)((long)t - ((long)t % m_bar_seconds));  
     }  

public:  
                     CTimeBar(const int bar_seconds) : CBarConstructor("time")  
     {  
      m_bar_seconds          = bar_seconds;  
      m_current_window_start = 0;  
     }  

   virtual bool      ProcessTick(const MqlTick &tick,  
                            const long tick_num,  
                            SBar &out_bar) override  
     {  
      datetime window = BarFloor(tick.time);  

      if(!m_initialized)  
        {  
         SeedBar(tick, tick_num);  
         m_current_window_start = window;  
         return false;  
        }  

      if(window != m_current_window_start)  
        {  
         FillBar(out_bar);  
         //--- Override bar.time with the right-edge label  
         out_bar.time = m_current_window_start + m_bar_seconds;  
         SeedBar(tick, tick_num);  
         m_current_window_start = window;  
         return true;  
        }  

      UpdateAccumulator(tick, tick_num);  
      return false;  
     }  

   virtual bool      SaveState(const int fh) override  
     {  
      if(!CBarConstructor::SaveState(fh))  
         return false;  
      FileWriteLong(fh, (long)m_current_window_start);  
      return true;  
     }  

   virtual bool      LoadState(const int fh) override  
     {  
      if(!CBarConstructor::LoadState(fh))  
         return false;  
      m_current_window_start = (datetime)FileReadLong(fh);  
      return true;  
     }  
  };  

//+------------------------------------------------------------------+  
//| CTickBar — closes when tick count in the current bar reaches     |  
//| bar_size. The (bar_size+1)-th tick is the first of the new bar,  |  
//| matching Python's np.arange(len(df)) // bar_size semantics.      |  
//+------------------------------------------------------------------+  
class CTickBar : public CBarConstructor  
  {  
private:  
   int               m_bar_size;  

public:  
                     CTickBar(const int bar_size) : CBarConstructor("tick")  
     {  
      m_bar_size = bar_size;  
     }  

   virtual bool      ProcessTick(const MqlTick &tick,  
                            const long tick_num,  
                            SBar &out_bar) override  
     {  
      if(!m_initialized)  
        {  
         SeedBar(tick, tick_num);  
         return false;  
        }  

      if(m_tick_volume >= m_bar_size)  
        {  
         FillBar(out_bar);  
         SeedBar(tick, tick_num);  
         return true;  
        }  

      UpdateAccumulator(tick, tick_num);  
      return false;  
     }  
  };  

//+------------------------------------------------------------------+  
//| CCumSumBar — shared parent for volume and dollar bars. Maintains |  
//| a global cumulative metric and a derived bar_id that increments  |  
//| when cum crosses a multiple of bar_size. The crossing tick is    |  
//| the first of the new bar, matching Python's cumsum // bar_size.  |  
//+------------------------------------------------------------------+  
class CCumSumBar : public CBarConstructor  
  {  
protected:  
   double            m_bar_size;  
   double            m_cum_global;  
   long              m_prev_bar_id;  

   //--- Per-tick metric. Overridden by concrete derived classes.  
   virtual double    TickMetric(const MqlTick &tick) = 0;  

public:  
                     CCumSumBar(const string bar_type, const double bar_size)  
      :              CBarConstructor(bar_type)  
     {  
      m_bar_size    = bar_size;  
      m_cum_global  = 0.0;  
      m_prev_bar_id = -1;  
     }  

   virtual bool      ProcessTick(const MqlTick &tick,  
                            const long tick_num,  
                            SBar &out_bar) override  
     {  
      double x = TickMetric(tick);  
      m_cum_global += x;  
      long bar_id = (long)MathFloor(m_cum_global / m_bar_size);  

      if(!m_initialized)  
        {  
         SeedBar(tick, tick_num);  
         m_prev_bar_id = bar_id;  
         return false;  
        }  

      if(bar_id != m_prev_bar_id)  
        {  
         FillBar(out_bar);  
         SeedBar(tick, tick_num);  
         m_prev_bar_id = bar_id;  
         return true;  
        }  

      UpdateAccumulator(tick, tick_num);  
      return false;  
     }  

   virtual bool      SaveState(const int fh) override  
     {  
      if(!CBarConstructor::SaveState(fh))  
         return false;  
      FileWriteDouble(fh, m_cum_global);  
      FileWriteLong(fh, m_prev_bar_id);  
      return true;  
     }  

   virtual bool      LoadState(const int fh) override  
     {  
      if(!CBarConstructor::LoadState(fh))  
         return false;  
      m_cum_global  = FileReadDouble(fh);  
      m_prev_bar_id = FileReadLong(fh);  
      return true;  
     }  
  };  

//+------------------------------------------------------------------+  
//| CVolumeBar — metric is tick.volume (tick‑count proxy on FX).     |  
//+------------------------------------------------------------------+  
class CVolumeBar : public CCumSumBar  
  {  
protected:  
   virtual double    TickMetric(const MqlTick &tick) override  
     {  
      return (double)tick.volume;  
     }  

public:  
                     CVolumeBar(const double volume_per_bar)  
      :              CCumSumBar("volume", volume_per_bar) {}  
  };  

//+------------------------------------------------------------------+  
//| CDollarBar — metric is tick volume multiplied by the mid-price.  |  
//|                                                                  |  
//| Using (bid+ask)/2 instead of bid gives a more representative     |  
//| valuation of each tick’s economic size and reduces noise from    |  
//| the bid-ask bounce. This enhances signal stability in dollar-    |  
//| based sampling.                                                  |  
//+------------------------------------------------------------------+  
class CDollarBar : public CCumSumBar  
  {  
protected:  
   virtual double    TickMetric(const MqlTick &tick) override  
     {  
      // Mid‑price gives a balanced value between bid and ask,  
      // avoiding the one‑sided bias that using bid alone would introduce.  
      double mid = (tick.bid + tick.ask) / 2.0;  
      return mid * (double)tick.volume;  
     }  

public:  
                     CDollarBar(const double dollar_per_bar)  
      :              CCumSumBar("dollar", dollar_per_bar) {}  
  };  
//+------------------------------------------------------------------+  

#endif // __CSTANDARD_BARS_MQH__  