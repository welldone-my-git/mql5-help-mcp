//+------------------------------------------------------------------+
//|                                                          sGM.mq5 |
//|                                                        AIS Forex |
//|                        https://www.mql5.com/en/users/aleksej1966 |
//+------------------------------------------------------------------+
#property copyright "AIS Forex"
#property link      "https://www.mql5.com/en/users/aleksej1966"
#property version   "1.00"
#include <Graphics\Graphic.mqh>

input uchar iPeriod=24,
            Width=5;
input bool ScreenShot=true;
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//---
   int size=MathMax(4,iPeriod);
   double price[],grey[],smooth[];
   ArrayResize(price,size);
   ArrayResize(grey,size);
   ArrayResize(smooth,size);

   price[0]=iOpen(_Symbol,PERIOD_CURRENT,size-1);
   grey[0]=price[0];
   for(int i=1;i<size;i++)
     {
      price[i]=iOpen(_Symbol,PERIOD_CURRENT,size-i-1);
      grey[i]=grey[i-1]+price[i];
     }

   double x=0,x2=0,p=0,px=0;
   for(int i=0;i<size;i++)
     {
      x=x+grey[i];
      x2=x2+grey[i]*grey[i];
      p=p+price[i];
      px=px+price[i]*grey[i];
     }

   double denom=size*x2-x*x,
          a=(p*x-size*px)/denom,
          b=(x2*p-x*px)/denom;

   for(int i=0;i<size;i++)
      smooth[i]=(grey[0]-b/a)*MathExp(-a*i)+b/a;
//---
   int w=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0),
       h=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);

   ChartSetInteger(0,CHART_SHOW,false);

   CGraphic graphic;
   graphic.Create(0,"GM",0,0,0,w,h);

   CCurve *hist=graphic.CurveAdd(grey,CURVE_HISTOGRAM);
   hist.Name("grey");
   hist.HistogramWidth(Width);
   CCurve *line=graphic.CurveAdd(smooth,CURVE_LINES);
   line.Name("Smooth");
   line.LinesWidth(Width);

   graphic.CurvePlotAll();
   graphic.Update();
   if(ScreenShot==true)
      ChartScreenShot(0,"GM.png",w,h);
   Sleep(5000);

   graphic.Destroy();
   ChartSetInteger(0,CHART_SHOW,true);
//---
  }
//+------------------------------------------------------------------+
