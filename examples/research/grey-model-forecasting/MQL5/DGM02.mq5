//+------------------------------------------------------------------+
//|                                                         GM02.mq5 |
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
#property indicator_label1 "GM02"
#property indicator_color1 clrBlue
#property indicator_width1 5
#property indicator_style1 STYLE_SOLID

input int iPeriod=24;

int period;
double buffer[],grey[],grey1[];
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
   ArrayResize(grey1,period);
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

      int bars=prev_calculated>0? rates_total-prev_calculated-1:rates_total-period-2;

      for(int i=bars;i>=0;i--)
        {
         int p=period-1;
         grey[p]=open[i+p];
         grey1[p]=open[i+p+1];

         for(int j=period-2;j>=0;j--)
           {
            p=i+j;
            grey[j]=grey[j+1]+open[p];
            grey1[j]=grey1[j+1]+open[p+1];
           }

         double x=0,xy=0,y=0,y2=0;
         for(int j=0;j<period;j++)
           {
            x=x+grey[j];
            xy=xy+grey[j]*grey1[j];
            y=y+grey1[j];
            y2=y2+grey1[j]*grey1[j];
           }
         double denom=period*y2-y*y,
                a=(period*xy-x*y)/denom,
                b=(x*y2-xy*y)/denom;

         buffer[i]=a*(grey1[0]+open[i])+b-grey[0];
        }
     }
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
