//+------------------------------------------------------------------+
//|                                                 TradeExecutor.mqh|
//|                                 Copyright 2026, Clemence Benjamin|
//|                                              https://www.mql5.com|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Clemence Benjamin"
#property link      "https://www.mql5.com"

#include <Trade/Trade.mqh>
#include "InteractionDetector.mqh"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CTradeExecutor
  {
private:
   CTrade            m_trade;            // Standard Library trade object
   bool              m_busy;             // busy flag to avoid duplicate orders
   datetime          m_lastOrderTime;    // timestamp of last order
   int               m_intervalSec;      // minimum seconds between orders

   double            ComputeStopLoss(const SInteraction &inter, double entryPrice, ENUM_ORDER_TYPE orderType);
   double            ComputeTakeProfit(double entryPrice, double slPrice, ENUM_ORDER_TYPE orderType);

public:
                     CTradeExecutor(int minIntervalSec=2);
   bool              PlaceOrder(const SInteraction &inter, double lotSize, uint magic=0);
   void              ResetBusyFlag() { m_busy=false; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradeExecutor::CTradeExecutor(int minIntervalSec)
   : m_busy(false),
     m_lastOrderTime(0),
     m_intervalSec(minIntervalSec)
  {
   if(m_intervalSec<1)
      m_intervalSec=1;
   m_trade.SetExpertMagicNumber(0);
  }

//+------------------------------------------------------------------+
//| Place order based on interaction                                  |
//+------------------------------------------------------------------+
bool CTradeExecutor::PlaceOrder(const SInteraction &inter, double lotSize, uint magic=0)
  {
//--- Guard: busy flag and minimum interval
   if(m_busy)
      return(false);
   if(TimeCurrent()-m_lastOrderTime<m_intervalSec)
      return(false);

   ENUM_ORDER_TYPE orderType;
   bool isMarket=false;
   double pendingPrice=0.0;

//--- Determine order type and direction from interaction
   switch(inter.action)
     {
      case INTERACTION_CROSS_UP:
      case INTERACTION_BREAKOUT_ABOVE:
         orderType=ORDER_TYPE_BUY;
         isMarket=true;
         break;

      case INTERACTION_CROSS_DOWN:
      case INTERACTION_BREAKOUT_BELOW:
         orderType=ORDER_TYPE_SELL;
         isMarket=true;
         break;

      case INTERACTION_TOUCH:
         //--- Buy if touched from above (support), sell if from below (resistance)
         if(inter.side=="above")
           {
            orderType=ORDER_TYPE_BUY;
            double ask=SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            if(ask<=inter.levelPrice+SymbolInfoDouble(_Symbol, SYMBOL_POINT)*5)
               isMarket=true;
            else
               pendingPrice=inter.levelPrice;
           }
         else
            if(inter.side=="below")
              {
               orderType=ORDER_TYPE_SELL;
               double bid=SymbolInfoDouble(_Symbol, SYMBOL_BID);
               if(bid>=inter.levelPrice-SymbolInfoDouble(_Symbol, SYMBOL_POINT)*5)
                  isMarket=true;
               else
                  pendingPrice=inter.levelPrice;
              }
            else
               return(false);
         break;

      default:
         return(false);
     }

//--- Entry price
   double entryPrice;
   if(isMarket)
      entryPrice=(orderType==ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                 : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   else
      entryPrice=pendingPrice;

//--- Compute SL and TP
   double sl=ComputeStopLoss(inter, entryPrice, orderType);
   double tp=(sl>0) ? ComputeTakeProfit(entryPrice, sl, orderType) : 0.0;

//--- Validate SL/TP ordering
   if(sl>0 && tp>0)
     {
      if(orderType==ORDER_TYPE_BUY || orderType==ORDER_TYPE_BUY_STOP || orderType==ORDER_TYPE_BUY_LIMIT)
        {
         if(sl>=entryPrice)
            sl=entryPrice-SymbolInfoDouble(_Symbol, SYMBOL_POINT)*10;
         if(tp<=entryPrice)
            tp=0;
        }
      else
        {
         if(sl<=entryPrice)
            sl=entryPrice+SymbolInfoDouble(_Symbol, SYMBOL_POINT)*10;
         if(tp>=entryPrice)
            tp=0;
        }
     }

//--- Send order
   m_trade.SetExpertMagicNumber(magic);
   bool result=false;

   if(isMarket)
      result=m_trade.PositionOpen(_Symbol, orderType, lotSize, entryPrice, sl, tp, "Interaction");
   else
     {
      if(orderType==ORDER_TYPE_BUY)
         result=m_trade.BuyLimit(lotSize, pendingPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0);
      else
         result=m_trade.SellLimit(lotSize, pendingPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0);
     }

//--- Log result and set busy flag
   if(result)
     {
      m_busy=true;
      m_lastOrderTime=TimeCurrent();
      Print("Order placed: ", EnumToString(orderType), " Entry=", entryPrice, " SL=", sl, " TP=", tp);
     }
   else
      Print("Order failed: ", m_trade.ResultRetcodeDescription());

   return(result);
  }

//+------------------------------------------------------------------+
//| Compute stop-loss relative to object geometry                     |
//+------------------------------------------------------------------+
double CTradeExecutor::ComputeStopLoss(const SInteraction &inter, double entryPrice, ENUM_ORDER_TYPE orderType)
  {
   double buffer=5.0*SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   bool isBuy=(orderType==ORDER_TYPE_BUY || orderType==ORDER_TYPE_BUY_LIMIT || orderType==ORDER_TYPE_BUY_STOP);

//--- Place SL just beyond the touched level
   if(isBuy)
      return(inter.levelPrice-buffer);    // SL just below the support
   else
      return(inter.levelPrice+buffer);    // SL just above the resistance
  }

//+------------------------------------------------------------------+
//| Compute take-profit (default risk-reward 2:1)                    |
//+------------------------------------------------------------------+
double CTradeExecutor::ComputeTakeProfit(double entryPrice, double slPrice, ENUM_ORDER_TYPE orderType)
  {
   double risk=MathAbs(entryPrice-slPrice);
   if(risk<=0)
      return(0.0);
   bool isBuy=(orderType==ORDER_TYPE_BUY || orderType==ORDER_TYPE_BUY_LIMIT || orderType==ORDER_TYPE_BUY_STOP);
   return(isBuy ? entryPrice+2.0*risk : entryPrice-2.0*risk);
  }
//+------------------------------------------------------------------+
