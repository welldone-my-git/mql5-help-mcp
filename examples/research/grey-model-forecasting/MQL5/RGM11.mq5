//+------------------------------------------------------------------+
//|                                                        RGM11.mq5 |
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
#property indicator_label1 "RGM"
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

int period,size,coeff[];
double buffer[],forecast[],price[],sump[],sumf[];
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
   ArrayResize(sump,period);
   ArrayResize(sumf,Forecast);

   ArrayResize(coeff,period);
   ArrayInitialize(coeff,0);
   size=period-3;
   for(int i=0;i<size;i++)
      for(int j=i+3;j>=0;j--)
         coeff[j]++;
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
      ArrayInitialize(sump,0);
      ArrayInitialize(sumf,0);

      for(int i=0;i<period;i++)
         price[i]=open[i+Shift];

      for(int i=0;i<size;i++)
         CalcGM(i+4);

      for(int i=period-1;i>=0;i--)
         buffer[i]=sump[i]/coeff[i];

      for(int i=Forecast-1;i>=0;i--)
         forecast[i]=sumf[i]/size;

     }
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CalcGM(int z)
  {
//---
   double grey[];
   ArrayResize(grey,z);

   grey[z-1]=price[z-1];
   for(int i=z-2;i>=0;i--)
      grey[i]=grey[i+1]+price[i];

   double x=0,x2=0,p=0,px=0;
   for(int i=0;i<z;i++)
     {
      x=x+grey[i];
      x2=x2+grey[i]*grey[i];
      p=p+price[i];
      px=px+price[i]*grey[i];
     }

   double d=z*x2-x*x,a=(p*x-z*px)/d,b=(x2*p-x*px)/d,k=(1-MathExp(a))*(price[z-1]-b/a);

   for(int i=z-1,t=1;i>=0;i--,t++)
      sump[i]=sump[i]+k*MathExp(-a*t);

   for(int i=Forecast-1,t=z+1;i>=0;i--,t++)
      sumf[i]=sumf[i]+k*MathExp(-a*t);
//---
  }
//+------------------------------------------------------------------+
