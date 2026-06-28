//+------------------------------------------------------------------+
//|                                          Schedule testing EA.mq5 |
//|                                          Copyright 2023, Omegafx |
//|                 https://www.mql5.com/en/users/omegajoctan/seller |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Omegafx"
#property link      "https://www.mql5.com/en/users/omegajoctan/seller"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\AccountInfo.mqh>

CTrade m_trade;
CSymbolInfo m_symbol;
CPositionInfo m_position;
CDealInfo m_deal;
CAccountInfo m_account;

//---

#include <schedule.mqh>
CSchedule schedule(TIME_SOURCE_CURRENT); //Use the current broker's time
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input int magic_number = 22072025;
input uint slippage = 100;
input uint stoploss = 500;
input uint takeprofit = 700;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
   m_trade.SetExpertMagicNumber(magic_number);
   m_trade.SetTypeFillingBySymbol(Symbol());
   m_trade.SetDeviationInPoints(slippage);
   
   if (!m_symbol.Name(Symbol()))
      {
         printf("%s -> Failed to select a symbol '%s'. Error = %d", __FUNCTION__,Symbol(),GetLastError());
         return INIT_FAILED;
      }
   
//--- Schedule
   
   schedule.every().hour().at(0,0).dO(MainTradingFunction);
   schedule.every().day().at(23, 55).dO(SendDailyTradingReport); //every day 5 minutes before market closing

//--- Ontimer
   
   EventSetTimer(1); //Run the Ontimer function after every 1 second (always)

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    EventKillTimer(); //Delete the timer
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
    
    schedule.run_pending();
    
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool PosExists(ENUM_POSITION_TYPE type)
 {
    for (int i=PositionsTotal()-1; i>=0; i--)
      if (m_position.SelectByIndex(i))
         if (m_position.Symbol()==Symbol() && m_position.Magic() == magic_number && m_position.PositionType()==type)
            return (true);
            
    return (false);
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseAllTrades()
 {
   for (int i = PositionsTotal() - 1; i >= 0; i--)
      if (m_position.SelectByIndex(i))
         if (m_position.Magic() == magic_number && m_position.Symbol() == Symbol())
             m_trade.PositionClose(m_position.Ticket(), slippage);
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void MainTradingFunction()
 {
   printf("New bar detected!"); 
//---
   
   if (!m_symbol.RefreshRates())
      return;
      
    if (!PosExists(POSITION_TYPE_BUY))
      m_trade.Buy(m_symbol.LotsMin(), 
                  Symbol(), 
                  m_symbol.Ask(), 
                  m_symbol.Ask()-stoploss*m_symbol.Point(),
                  m_symbol.Ask()+takeprofit*m_symbol.Point()
                 );
                  
    if (!PosExists(POSITION_TYPE_SELL))
      m_trade.Sell(m_symbol.LotsMin(), 
                   Symbol(), 
                   m_symbol.Bid(),
                   m_symbol.Bid()+stoploss*m_symbol.Point(),
                   m_symbol.Bid()-takeprofit*m_symbol.Point()
                   ); 
//---
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SendDailyTradingReport()
 {
   string sdate = TimeToString (TimeCurrent(), TIME_DATE);
   datetime start = StringToTime(sdate);

   if (!HistorySelect(start, TimeCurrent()))
     {
       printf("%s, line %d failed to obtain closed deals from history error =%d",__FUNCTION__,__LINE__,GetLastError());
       return;
     }
   
   Comment("");
   
//---
   
   double pl = 0.0;
   
   int trades_count=0;
   string report_body = "";
   for(int i = 0; i < HistoryDealsTotal(); i++)
     {
      if (m_deal.SelectByIndex(i))   
        if (m_deal.Entry() == DEAL_ENTRY_OUT && m_deal.Magic() == magic_number)
          {
            pl += m_deal.Profit();
            trades_count++;
            
            report_body += StringFormat("Trade[%d] -> | ticket: %I64u | type: %s | entry: %.5f | volume: %.3f | commision: %.3f\n",
                                          trades_count, 
                                          m_deal.Ticket(),
                                          EnumToString(m_deal.DealType()),
                                          m_deal.Entry(),
                                          m_deal.Volume(),
                                          m_deal.Commission()
                                        ); 
          }
     }
    string report_header = StringFormat("<<< Daily Trading Report >>> \r\n\r\nAC Balance: %.3f\r\nAC Equity: %.3f\r\nPL: %.3f\r\nTotal Trades: %d \r\n\r\n",
                                          m_account.Balance(),
                                          m_account.Equity(),
                                          pl,
                                          trades_count
                                        );   
   
//--- You might choose to send the reports instead of printing

   Comment(report_header+report_body); 
   Print(report_header+report_body);
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer(void)
  {
    schedule.run_pending();    
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
