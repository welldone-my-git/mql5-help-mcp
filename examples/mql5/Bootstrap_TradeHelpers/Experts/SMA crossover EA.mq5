//+------------------------------------------------------------------+
//|                                             SMA crossover EA.mq5 |
//|                                     Copyright 2026, Omega Joctan |
//|                 https://www.mql5.com/en/users/omegajoctan/seller |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Omega Joctan"
#property link      "https://www.mql5.com/en/users/omegajoctan/seller"
#property version   "1.00"
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

#include <Bootstrap\positions.mqh>
#include <Bootstrap\orders.mqh>

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

CTrade m_trade;
CSymbolInfo m_symbol;

//+------------------------------------------------------------------+

input int magic_number = 14022026;
input uint slippage = 100;

input uint short_sma_period = 10;
input uint long_sma_period = 20;

//+------------------------------------------------------------------+

int short_handle, long_handle;
double long_sma_buff[], short_sma_buff[];
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   if(!m_symbol.Name(Symbol()))
     {
      printf("Failed to get symbolinfo, error = %d", GetLastError());
      return INIT_FAILED;
     }
//---
   m_trade.SetExpertMagicNumber(magic_number);
   m_trade.SetDeviationInPoints(slippage);
   m_trade.SetTypeFillingBySymbol(Symbol());
//---
   short_handle = iMA(Symbol(), Period(), short_sma_period, 0, MODE_SMA, PRICE_CLOSE);
   long_handle = iMA(Symbol(), Period(), long_sma_period, 0, MODE_SMA, PRICE_CLOSE);
   TesterHideIndicators(false);
//ChartIndicatorAdd(0, 0, short_handle);
//ChartIndicatorAdd(0, 0, long_handle);
//---
   ArraySetAsSeries(long_sma_buff, true);
   ArraySetAsSeries(short_sma_buff, true);
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
   if(!m_symbol.RefreshRates())
     {
      printf("Failed to fetch latest tick information, error = %d", GetLastError());
      return;
     }
   if(CopyBuffer(long_handle, 0, 0, 2, long_sma_buff) < 0)
      return;
   if(CopyBuffer(short_handle, 0, 0, 2, short_sma_buff) < 0)
      return;
   double curr_long_sma = long_sma_buff[0], prev_long_sma = long_sma_buff[1],
          curr_short_sma = short_sma_buff[0], prev_short_sma = short_sma_buff[1];
//--- long signal
   if(curr_short_sma > curr_long_sma && prev_short_sma < prev_long_sma)
      if(!PositionExists(Symbol(), magic_number, POSITION_TYPE_BUY))
        {
         PositionClose(slippage, Symbol(), magic_number, POSITION_TYPE_SELL); //close an opposite trade
         m_trade.Buy(m_symbol.LotsMin(), Symbol(), m_symbol.Ask());
        }
//--- short signal
   if(curr_short_sma < curr_long_sma && prev_short_sma > prev_long_sma)
      if(!PositionExists(Symbol(), magic_number, POSITION_TYPE_SELL))
        {
         PositionClose(slippage, Symbol(), magic_number, POSITION_TYPE_BUY); //close an opposite trade
         m_trade.Sell(m_symbol.LotsMin(), Symbol(), m_symbol.Bid());
        }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
