//+------------------------------------------------------------------+
//|                                                        DGM11.mq5 |
//|                                                        AIS Forex |
//|                        https://www.mql5.com/en/users/aleksej1966 |
//+------------------------------------------------------------------+
#property copyright "AIS Forex"
#property link      "https://www.mql5.com/en/users/aleksej1966"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_type1  DRAW_ARROW
#property indicator_label1 "GM"
#property indicator_color1 clrBlue
#property indicator_width1 5
#property indicator_style1 STYLE_SOLID

#property indicator_type2  DRAW_ARROW
#property indicator_label2 "Forecast"
#property indicator_color2 clrRed
#property indicator_width2 5
#property indicator_style2 STYLE_SOLID

input int iPeriod=24,
          Forecast=5,
          Shift=0;

int period;
double buffer[],forecast[],grey[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,buffer,INDICATOR_DATA);
   PlotIndexSetInteger(0,PLOT_SHIFT,-Shift);
   ArraySetAsSeries(buffer,true);

   SetIndexBuffer(1,forecast,INDICATOR_DATA);
   PlotIndexSetInteger(1,PLOT_SHIFT,Forecast-Shift);
   ArraySetAsSeries(forecast,true);

   period=MathMax(4,iPeriod);
   ArrayResize(grey,period);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int32_t rates_total,
                const int32_t prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int32_t &spread[])
  {
//---
   if(rates_total>prev_calculated)
     {
      ArraySetAsSeries(open,true);
      ArrayInitialize(buffer,EMPTY_VALUE);
      ArrayInitialize(forecast,EMPTY_VALUE);

      int bar=Shift+period-1;
      grey[period-1]=open[bar];
      for(int i=period-2;i>=0;i--)
        {
         bar--;
         grey[i]=grey[i+1]+open[bar];
        }

      double g=0,gg=0,g1=0,g12=0;
      for(int i=period-2;i>=0;i--)
        {
         g=g+grey[i];
         gg=gg+grey[i]*grey[i+1];
         g1=g1+grey[i+1];
         g12=g12+grey[i+1]*grey[i+1];
        }

      double denom=(period-1)*g12-g1*g1,
             a=((period-1)*gg-g1*g)/denom,
             b=(g12*g-gg*g1)/denom,
             k=grey[period-1]-b/(1-a);

      for(int i=period-1,t=1;i>=0;i--,t++)
         buffer[i]=(MathPow(a,t)-MathPow(a,t-1))*k;

      for(int i=Forecast-1,t=period+1;i>=0;i--,t++)
         forecast[i]=(MathPow(a,t)-MathPow(a,t-1))*k;
     }
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
