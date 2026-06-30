//+------------------------------------------------------------------+
//|                                                         GM1N.mq5 |
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
input ENUM_MA_METHOD MA_Method=MODE_SMA;

int period,handle;
double buffer[],forecast[],price[],grey[];
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
   ArrayResize(price,period);
   ArrayResize(grey,period);

   handle=iMA(_Symbol,PERIOD_CURRENT,period,0,MA_Method,PRICE_OPEN);
   if(handle==INVALID_HANDLE)
     {
      Print("Error # ",GetLastError());
      return(INIT_FAILED);
     }
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

      if(CopyBuffer(handle,0,Shift,period,price)<period)
         return(0);

      ArrayReverse(price);

      grey[period-1]=price[period-1];
      for(int i=period-2;i>=0;i--)
         grey[i]=grey[i+1]+price[i];

      double x=0,x2=0,p=0,px=0;
      for(int i=0;i<period;i++)
        {
         x=x+grey[i];
         x2=x2+grey[i]*grey[i];
         p=p+price[i];
         px=px+price[i]*grey[i];
        }

      double denom=period*x2-x*x,
             a=(p*x-period*px)/denom,
             b=(x2*p-x*px)/denom,
             k=(1-MathExp(a))*(price[period-1]-b/a);

      for(int i=period-1,t=1;i>=0;i--,t++)
         buffer[i]=k*MathExp(-a*t);

      for(int i=Forecast-1,t=period+1;i>=0;i--,t++)
         forecast[i]=k*MathExp(-a*t);
     }
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
