//+------------------------------------------------------------------+
//|                                                 sqlite3 test.mq5 |
//|                                         Copyright 2024, Omegafx. |
//|                 https://www.mql5.com/en/users/omegajoctan/seller |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Omegafx."
#property link      "https://www.mql5.com/en/users/omegajoctan/seller"
#property version   "1.00"

#include <sqlite3.mqh>
CSqlite3 sqlite3;
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//---
   
    sqlite3.connect("Trades_database.db");
    
//--- auxiliary variables

    ulong    deal_ticket;         // deal ticket
    long     order_ticket;        // a ticket of an order a deal was executed by
    long     position_ticket;     // ID of a position a deal belongs to
    datetime time;                // deal execution time
    long     type ;               // deal type
    long     entry ;              // deal direction
    string   symbol;              // a symbol a deal was executed for
    double   volume;              // operation volume
    double   price;               // price
    double   profit;              // financial result
    double   swap;                // swap
    double   commission;          // commission
    long     magic;               // Magic number (Expert Advisor ID)
    long     reason;              // deal execution reason or source
    
//--- go through all deals and add them to the database
   
   HistorySelect(0, TimeCurrent());
   int deals=HistoryDealsTotal();
   
   sqlite3.execute("CREATE TABLE IF NOT EXISTS DEALS ("
                     "ID          INT KEY NOT NULL,"
                     "ORDER_ID    INT     NOT NULL,"
                     "POSITION_ID INT     NOT NULL,"
                     "TIME        INT     NOT NULL,"
                     "TYPE        INT     NOT NULL,"
                     "ENTRY       INT     NOT NULL,"
                     "SYMBOL      CHAR(10),"
                     "VOLUME      REAL,"
                     "PRICE       REAL,"
                     "PROFIT      REAL,"
                     "SWAP        REAL,"
                     "COMMISSION  REAL,"
                     "MAGIC       INT,"
                     "REASON      INT );"
   ); //Create a table
   
   sqlite3.begin(); //Start the transaction
   
// --- lock the database before executing transactions

   for(int i=0; i<deals; i++)
     {
      deal_ticket=    HistoryDealGetTicket(i);
      order_ticket=   HistoryDealGetInteger(deal_ticket, DEAL_ORDER);
      position_ticket=HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
      time= (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      type=           HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
      entry=          HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      symbol=         HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
      volume=         HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
      price=          HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
      profit=         HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
      swap=           HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
      commission=     HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
      magic=          HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
      reason=         HistoryDealGetInteger(deal_ticket, DEAL_REASON);
      
      //--- add each deal to the table using the following query
      string request_text=StringFormat("INSERT INTO DEALS (ID,ORDER_ID,POSITION_ID,TIME,TYPE,ENTRY,SYMBOL,VOLUME,PRICE,PROFIT,SWAP,COMMISSION,MAGIC,REASON)"
                                       "VALUES (%d, %d, %d, %d, %d, %d, '%s', %G, %G, %G, %G, %G, %d, %d)",
                                       deal_ticket, order_ticket, position_ticket, time, type, entry, symbol, volume, price, profit, swap, commission, magic, reason);
      
      sqlite3.execute(request_text);
     }
    
    sqlite3.commit(); //Commit all deals to the database at once
    sqlite3.close(); //close the database
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

