//+------------------------------------------------------------------+
//|                                                   Example EA.mq5 |
//|                                     Copyright 2025, Omega Joctan |
//|                 https://www.mql5.com/en/users/omegajoctan/seller |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Omega Joctan"
#property link      "https://www.mql5.com/en/users/omegajoctan/seller"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>

CTrade m_trade;
CSymbolInfo m_symbol;
CPositionInfo m_position;

input int magic_number = 10012026;
input int stoploss = 1000;
input int takeprofit = 100;
input int slippage = 100;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
   m_symbol.Name(Symbol());
   m_trade.SetExpertMagicNumber(magic_number);
   m_trade.SetDeviationInPoints(slippage);
   m_trade.SetTypeFillingBySymbol(Symbol());
   
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
    
    if (!m_symbol.RefreshRates())
      return;
    
    double ask = m_symbol.Ask(),
           bid = m_symbol.Bid(),
           pts = m_symbol.Point();
    
    double volume = 0.01;
    
    if (!PosExists(magic_number, POSITION_TYPE_BUY))
      m_trade.Buy(volume, Symbol(), ask, ask-stoploss*pts, ask+takeprofit*pts);
    
    if (!PosExists(magic_number, POSITION_TYPE_SELL))
      m_trade.Sell(volume, Symbol(), bid, bid+stoploss*pts, bid-takeprofit*pts);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool PosExists(int magic, ENUM_POSITION_TYPE type)
 {
   for (int i=PositionsTotal()-1; i>=0; i--)
     if (m_position.SelectByIndex(i))
        if (m_position.Magic() == magic && m_position.PositionType() == type)
           return true;
           
   return false;
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

