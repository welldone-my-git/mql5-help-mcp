//+------------------------------------------------------------------+
//|                                              PersistenceDemo.mq5 |
//+------------------------------------------------------------------+
#property strict
#include "PersistenceManager.mqh"
#include <Trade\Trade.mqh>

//--- Input parameters
input int      InpMaxDailyTrades = 3;
input double   InpBaseLots       = 0.1;
input double   InpLotMultiplier  = 1.5;
input bool     InpResetState     = false;

//--- Global variables
EAState  g_state;
CTrade   g_trade;
datetime g_lastBarTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpResetState)
      DeleteStateFile();

//--- Load historical data into memory state
   LoadState(g_state);

//--- Validate daytime logic only if a historical state exists
   if(g_state.lastSaveTime > 0)
     {
      MqlDateTime sdt, tdt;
      TimeToStruct(g_state.lastSaveTime, sdt);
      TimeToStruct(TimeCurrent(), tdt);

      if(sdt.day != tdt.day || sdt.mon != tdt.mon)
        {
         g_state.dailyTradeCount = 0;
         Print("New trading day detected - daily counter reset.");
         SaveState(g_state);
        }
     }
   else
     {
      //--- For fresh profiles, ensure structural sizing begins at baseline
      g_state.currentLotMult = 1.0;
     }

   Print("=== STATE ON LOAD ===");
   PrintFormat("Daily trades so far : %d", g_state.dailyTradeCount);
   PrintFormat("Loss streak         : %d", g_state.lossStreak);
   PrintFormat("Current lot mult    : %.2f", g_state.currentLotMult);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Serialize active data footprint on parameter tweaks or extraction
   SaveState(g_state);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBar == g_lastBarTime)
      return;
   g_lastBarTime = currentBar;

   if(g_state.dailyTradeCount >= InpMaxDailyTrades)
     {
      PrintFormat("Daily trade limit reached (%d/%d).", g_state.dailyTradeCount, InpMaxDailyTrades);
      return;
     }

   if(PositionsTotal() > 0)
      return;

   double lots = NormalizeDouble(InpBaseLots * g_state.currentLotMult, 2);
   lots = MathMax(lots, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));

   bool buySignal = (g_state.lastSignal <= 0);
   double sl, tp;
   double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
   if(atr == 0)
      return;

   if(buySignal)
     {
      sl = SymbolInfoDouble(_Symbol, SYMBOL_BID) - atr * 1.5;
      tp = SymbolInfoDouble(_Symbol, SYMBOL_BID) + atr * 2.0;
      if(g_trade.Buy(lots, _Symbol, 0, sl, tp, "PersistDemo"))
        {
         g_state.lastSignal = 1;
         PrintFormat("BUY signal sent to server. Lots: %.2f", lots);
        }
     }
   else
     {
      sl = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + atr * 1.5;
      tp = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - atr * 2.0;
      if(g_trade.Sell(lots, _Symbol, 0, sl, tp, "PersistDemo"))
        {
         g_state.dailyTradeCount++;
         g_state.lastSignal = -1;
         SaveState(g_state);
         PrintFormat("SELL opened. Daily count: %d | Lots: %.2f", g_state.dailyTradeCount, lots);
        }
     }
  }

//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest      &req,
                        const MqlTradeResult       &res)
  {
//--- Isolate processing strictly to confirmed deal additions
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   ulong dealTicket = trans.deal;
   if(!HistoryDealSelect(dealTicket))
      return;

//--- Restrict validation context exclusively to this specific ticker
   if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol)
      return;

   long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);

//--- 1. TRACK NEWLY OPENED TRADES (Daily Counter)
   if(dealEntry == DEAL_ENTRY_IN)
     {
      g_state.dailyTradeCount++;
      PrintFormat("New trade detected on account. Daily count updated to: %d", g_state.dailyTradeCount);
      SaveState(g_state);
      return;
     }

//--- 2. TRACK CLOSED TRADES (Win/Loss Streaks)
   if(dealEntry == DEAL_ENTRY_OUT)
     {
      double profit     = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      double swap       = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
      double commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
      double netProfit  = profit + swap + commission;

      if(netProfit < 0)
        {
         g_state.lossStreak++;
         g_state.winStreak       = 0;
         g_state.currentLotMult *= InpLotMultiplier;
         PrintFormat("Loss recorded. Streak: %d | Next lot mult: %.2f", g_state.lossStreak, g_state.currentLotMult);
        }
      else
         if(netProfit > 0)
           {
            g_state.winStreak++;
            g_state.lossStreak      = 0;
            g_state.currentLotMult  = 1.0;
            PrintFormat("Win recorded. Streak: %d | Lot mult reset to 1.0", g_state.winStreak);
           }

      SaveState(g_state);
     }
  }
//+------------------------------------------------------------------+