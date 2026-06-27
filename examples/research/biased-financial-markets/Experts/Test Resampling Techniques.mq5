//+------------------------------------------------------------------+
//|                                   Test Resampling Techniques.mq5 |
//|                                         Copyright 2024, Omegafx. |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Omegafx."
#property link      "https://www.mql5.com/en/users/omegajoctan/seller"
#property version   "1.00"

#include <Random Forest.mqh> 
CRandomForestClassifier random_forest; //A class for loading the RFC in ONNX format

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

CTrade m_trade;
CPositionInfo m_position;

input string symbol_ = "USDJPY";
input int magic_number= 14042025;
input int slippage = 100;
input ENUM_TIMEFRAMES timeframe_ = PERIOD_D1;
input string technique_name = "randomoversampling";

int lookahead = 1;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---

   if (!random_forest.Init(StringFormat("%s.%s.%s.onnx", symbol_, EnumToString(timeframe_), technique_name), ONNX_COMMON_FOLDER)) //Initializing the RFC in ONNX format from a commmon folder
     return INIT_FAILED;
     
//--- Setting up the CTrade module
   
   m_trade.SetExpertMagicNumber(magic_number);
   m_trade.SetDeviationInPoints(slippage);
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(symbol_);
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
      
   vector x = {
      iOpen(symbol_, timeframe_, 1),
      iHigh(symbol_, timeframe_, 1),
      iLow(symbol_, timeframe_, 1),
      iClose(symbol_, timeframe_, 1)
   };
   
   long signal = random_forest.predict_bin(x); //Predicted class
   double proba = random_forest.predict_proba(x).Max(); //Maximum predicted probability

   MqlTick ticks;
   if (!SymbolInfoTick(symbol_, ticks))
      {
         printf("Failed to obtain ticks information, Error = %d",GetLastError());
         return;
      }
      
   double volume_ = SymbolInfoDouble(symbol_, SYMBOL_VOLUME_MIN);
   
   
   if (signal == 1) 
     {        
        if (!PosExists(POSITION_TYPE_BUY) && !PosExists(POSITION_TYPE_SELL))  
            m_trade.Buy(volume_, symbol_, ticks.ask,0,0);
     }
     
   if (signal == 0)
     {        
        if (!PosExists(POSITION_TYPE_SELL) && !PosExists(POSITION_TYPE_BUY))  
            m_trade.Sell(volume_, symbol_, ticks.bid,0,0);
     } 

//---
   
   CloseTradeAfterTime((Timeframe2Minutes(timeframe_)*lookahead)*60); //Close the trade after a certain lookahead and according the the trained timeframe
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool PosExists(ENUM_POSITION_TYPE type)
 {
    for (int i=PositionsTotal()-1; i>=0; i--)
      if (m_position.SelectByIndex(i))
         if (m_position.Symbol()==symbol_ && m_position.Magic() == magic_number && m_position.PositionType()==type)
            return (true);
            
    return (false);
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ClosePos(ENUM_POSITION_TYPE type)
 {
    for (int i=PositionsTotal()-1; i>=0; i--)
      if (m_position.SelectByIndex(i))
         if (m_position.Symbol() == symbol_ && m_position.Magic() == magic_number && m_position.PositionType()==type)
            {
              if (m_trade.PositionClose(m_position.Ticket()))
                return true;
            }
            
    return (false);
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseTradeAfterTime(int period_seconds)
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
      if (m_position.SelectByIndex(i))
         if (m_position.Magic() == magic_number)
            if (TimeCurrent() - m_position.Time() >= period_seconds)
               m_trade.PositionClose(m_position.Ticket(), slippage);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

int Timeframe2Minutes(ENUM_TIMEFRAMES tf)
{
    switch(tf)
    {
        case PERIOD_M1:  return 1;
        case PERIOD_M2:  return 2;
        case PERIOD_M3:  return 3;
        case PERIOD_M4:  return 4;
        case PERIOD_M5:  return 5;
        case PERIOD_M6:  return 6;
        case PERIOD_M10: return 10;
        case PERIOD_M12: return 12;
        case PERIOD_M15: return 15;
        case PERIOD_M20: return 20;
        case PERIOD_M30: return 30;
        case PERIOD_H1:  return 60;
        case PERIOD_H2:  return 120;
        case PERIOD_H3:  return 180;
        case PERIOD_H4:  return 240;
        case PERIOD_H6:  return 360;
        case PERIOD_H8:  return 480;
        case PERIOD_H12: return 720;
        case PERIOD_D1:  return 1440; // 1 day = 1440 minutes
        case PERIOD_W1:  return 10080; // 1 week = 7 * 1440 minutes
        case PERIOD_MN1: return 43200; // Approx. 1 month = 30 * 1440 minutes

        default:
            PrintFormat("Unknown timeframe: %d", tf);
            return 0;
    }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
