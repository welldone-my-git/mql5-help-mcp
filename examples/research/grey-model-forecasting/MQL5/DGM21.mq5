//+------------------------------------------------------------------+
//|                                                        DGM21.mq5 |
//|                                                        AIS Forex |
//|                        https://www.mql5.com/en/users/aleksej1966 |
//+------------------------------------------------------------------+
#property copyright "AIS Forex"
#property link      "https://www.mql5.com/en/users/aleksej1966"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

#property indicator_type1  DRAW_ARROW
#property indicator_label1 "GM21"
#property indicator_color1 clrBlue
#property indicator_width1 5
#property indicator_style1 STYLE_SOLID

input int iPeriod=24;

int period;
double buffer[],grey[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,buffer,INDICATOR_DATA);
   PlotIndexSetInteger(0,PLOT_SHIFT,1);
   ArraySetAsSeries(buffer,true);

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

      int bars=prev_calculated>0? rates_total-prev_calculated-1:rates_total-period-1;

      for(int i=bars;i>=0;i--)
        {
         int p=period-1;
         grey[p]=open[i+p];
         for(int j=period-2;j>=0;j--)
            grey[j]=grey[j+1]+open[i+j];

         int n=period-3;
         double x1=0,x12=0,x1x2=0,x2=0,x22=0,y=0,yx1=0,yx2=0;
         for(int j=n;j>=0;j--)
           {
            x1=x1+grey[j+1];
            x12=x12+grey[j+1]*grey[j+1];
            x1x2=x1x2+grey[j+1]*grey[j+2];
            x2=x2+grey[j+2];
            x22=x22+grey[j+2]*grey[j+2];
            y=y+grey[j];
            yx1=yx1+grey[j]*grey[j+1];
            yx2=yx2+grey[j]*grey[j+2];
           }

         double denom=n*(x12*x22-x1x2*x1x2)-x1*x1*x22+2*x1*x1x2*x2-x12*x2*x2,
                a1=(n*(x22*yx1-x1x2*yx2)+x1*x2*yx2-x1*x22*y+x1x2*x2*y-x2*x2*yx1)/denom,
                a2=(n*(x12*yx2-x1x2*yx1)-x1*x1*yx2+x1*x1x2*y+x1*x2*yx1-x12*x2*y)/denom,
                b=(x1*x1x2*yx2-x1*x22*yx1-x12*x2*yx2+x12*x22*y-x1x2*x1x2*y+x1x2*x2*yx1)/denom;

         buffer[i]=(a1-1)*grey[0]+a2*grey[1]+b;
        }
     }
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
