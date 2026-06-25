//+------------------------------------------------------------------+
//| Ind_ZScore_Template.mq5                                          |
//| Indicator template using same ZScore engine as EA                 |
//+------------------------------------------------------------------+
#property strict
#property version "1.00"
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1

#property indicator_label1  "Z-Score"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2

#include "ZScoreEngine_Essence.mqh"

input int InpPeriod = 50;

double ZBuffer[];
CZScoreEngine *g_signal = NULL;

int OnInit()
  {
   SetIndexBuffer(0, ZBuffer, INDICATOR_DATA);
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   IndicatorSetInteger(INDICATOR_LEVELS, 3);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0,  2.5);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1,  0.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, -2.5);

   g_signal = new CZScoreEngine(_Symbol, PERIOD_CURRENT, InpPeriod);
   if(CheckPointer(g_signal) == POINTER_INVALID)
      return INIT_FAILED;

   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(CheckPointer(g_signal) == POINTER_DYNAMIC)
      delete g_signal;
  }

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(rates_total < InpPeriod + 2) return 0;

   const int start = (prev_calculated > 0) ? prev_calculated - 1 : InpPeriod;

   for(int i=start; i<rates_total && !IsStopped(); i++)
     {
      const int shift = rates_total - 1 - i;
      ZBuffer[i] = g_signal.Value(shift);
     }

   return rates_total;
  }
