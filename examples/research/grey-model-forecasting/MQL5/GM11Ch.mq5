//+------------------------------------------------------------------+
//|                                                       GM11Ch.mq5 |
//|                                                        AIS Forex |
//|                        https://www.mql5.com/en/users/aleksej1966 |
//+------------------------------------------------------------------+
#property copyright "AIS Forex"
#property link      "https://www.mql5.com/en/users/aleksej1966"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

#property indicator_type1  DRAW_ARROW
#property indicator_label1 "GM Up"
#property indicator_color1 clrBlue
#property indicator_width1 5
#property indicator_style1 STYLE_SOLID

#property indicator_type2  DRAW_ARROW
#property indicator_label2 "Forecast Up"
#property indicator_color2 clrRed
#property indicator_width2 5
#property indicator_style2 STYLE_SOLID

#property indicator_type3  DRAW_ARROW
#property indicator_label3 "GM Up"
#property indicator_color3 clrBlue
#property indicator_width3 5
#property indicator_style3 STYLE_SOLID

#property indicator_type4  DRAW_ARROW
#property indicator_label4 "Forecast Up"
#property indicator_color4 clrRed
#property indicator_width4 5
#property indicator_style4 STYLE_SOLID

input int iPeriod=24,
          Forecast=5,
          Shift=0;

int period;
double bufferup[],forecastup[],bufferdn[],forecastdn[],price[],grey[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,bufferup,INDICATOR_DATA);
   PlotIndexSetInteger(0,PLOT_SHIFT,-Shift);
   ArraySetAsSeries(bufferup,true);

   SetIndexBuffer(1,forecastup,INDICATOR_DATA);
   PlotIndexSetInteger(1,PLOT_SHIFT,Forecast-Shift);
   ArraySetAsSeries(forecastup,true);

   SetIndexBuffer(2,bufferdn,INDICATOR_DATA);
   PlotIndexSetInteger(2,PLOT_SHIFT,-Shift);
   ArraySetAsSeries(bufferdn,true);

   SetIndexBuffer(3,forecastdn,INDICATOR_DATA);
   PlotIndexSetInteger(3,PLOT_SHIFT,Forecast-Shift);
   ArraySetAsSeries(forecastdn,true);

   period=MathMax(4,iPeriod);
   ArrayResize(price,period);
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
      ArrayInitialize(bufferup,EMPTY_VALUE);
      ArrayInitialize(forecastup,EMPTY_VALUE);
      ArrayInitialize(bufferdn,EMPTY_VALUE);
      ArrayInitialize(forecastdn,EMPTY_VALUE);

      int bar=Shift+period-1;
      price[period-1]=open[bar];
      grey[period-1]=open[bar];
      for(int i=period-2;i>=0;i--)
        {
         bar--;
         price[i]=open[bar];
         grey[i]=grey[i+1]+price[i];
        }

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
             bmax=b,bmin=b,k=a/(1-MathExp(a));

      for(int i=period-1,t=1;i>=0;i--,t++)
        {
         b=a*price[period-1]-k*price[i]/MathExp(-a*t);
         bmax=MathMax(bmax,b);
         bmin=MathMin(bmin,b);
        }

      double kmax=(1-MathExp(a))*(price[period-1]-bmax/a),
             kmin=(1-MathExp(a))*(price[period-1]-bmin/a);

      for(int i=period-1,t=1;i>=0;i--,t++)
        {
         bufferup[i]=kmax*MathExp(-a*t);
         bufferdn[i]=kmin*MathExp(-a*t);
        }

      for(int i=Forecast-1,t=period+1;i>=0;i--,t++)
        {
         forecastup[i]=kmax*MathExp(-a*t);
         forecastdn[i]=kmin*MathExp(-a*t);
        }
     }
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
