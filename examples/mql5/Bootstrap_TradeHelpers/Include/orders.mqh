//+------------------------------------------------------------------+
//|                                                       orders.mqh |
//|                                     Copyright 2026, Omega Joctan |
//|                 https://www.mql5.com/en/users/omegajoctan/seller |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Omega Joctan"
#property link      "https://www.mql5.com/en/users/omegajoctan/seller"
//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
#include <Trade\OrderInfo.mqh>
#include <Trade\Trade.mqh>0
//+------------------------------------------------------------------+
//|  Returns true if an order exists filtered by                     |
//|  symbol, magic, type, or ticket                                  |
//+------------------------------------------------------------------+
bool OrderExists(const string symbol="",
                 const long magic=LONG_MAX,
                 const int type=-1,
                 const long ticket=-1)
  {
   bool use_symbol = (symbol != "");
   bool use_magic  = (magic  != LONG_MAX);
   bool use_type   = (type   != -1);
   bool use_ticket = (ticket != -1);
   
   COrderInfo order;
   
   for(int i = OrdersTotal()-1; i >= 0; --i)
     {
      if(!order.SelectByIndex(i))
         continue;

      if(use_symbol && order.Symbol() != symbol)
         continue;
      if(use_magic  && order.Magic()  != magic)
         continue;
      if(use_type   && (int)order.OrderType() != type)
         continue;
      if(use_ticket && order.Ticket() != ticket)
         continue;

      //--- passed all active filters
      return true;
     }
   return false;
  }
//+------------------------------------------------------------------+
//|  Returns true if an order exists with a specified magic number   |
//+------------------------------------------------------------------+
bool OrderExistsByMagic(int magic)
  {
   return OrderExists(NULL, magic);
  }
//+------------------------------------------------------------------+
//|  Returns true if an order exists with a specified symbol         |
//+------------------------------------------------------------------+
bool OrderExistsBySymbol(string symbol)
  {
   return OrderExists(symbol);
  }
//+------------------------------------------------------------------+
//|  Returns true if an order exists with a specified type           |
//+------------------------------------------------------------------+
bool OrderExistsByType(int type)
  {
   return OrderExists(NULL, LONG_MAX, type);
  }
//+------------------------------------------------------------------+
//|  Returns true if an order exists with a specified ticket number  |
//+------------------------------------------------------------------+
bool OrderExistsByTicket(int ticket)
  {
   return OrderExists(NULL, LONG_MAX, -1, ticket);
  }
//+------------------------------------------------------------------+
//|  Counts orders filtered by symbol, magic, type, or ticket        |
//+------------------------------------------------------------------+
int OrderCount(const string symbol="",
                  const long magic=LONG_MAX,
                  const int type=-1,
                  const long ticket=-1)
  {
   
   COrderInfo order;
     
//---

   bool use_symbol = (symbol != "");
   bool use_magic  = (magic  != LONG_MAX);
   bool use_type   = (type   != -1);
   bool use_ticket = (ticket != -1);

   int count = 0;
   for(int i = OrdersTotal()-1; i >= 0; --i)
     {
      if(!order.SelectByIndex(i))
         continue;

      if(use_symbol && order.Symbol() != symbol)
         continue;
      if(use_magic  && order.Magic()  != magic)
         continue;
      if(use_type   && (int)order.OrderType() != type)
         continue;
      if(use_ticket && order.Ticket() != ticket)
         continue;

      //--- passed all active filters
      count++;
     }

   return count;
  }
//+------------------------------------------------------------------+
//|  Counts orders with a specified magic number                     |
//+------------------------------------------------------------------+
int OrderCountByMagic(int magic)
  {
   return OrderCount(NULL, magic);
  }
//+------------------------------------------------------------------+
//|  Counts orders with a specified symbol                           |
//+------------------------------------------------------------------+
int OrderCountBySymbol(string symbol)
  {
   return OrderCount(symbol);
  }
//+------------------------------------------------------------------+
//|  Counts orders with a specified type                             |
//+------------------------------------------------------------------+
int OrderCountByType(int type)
  {
   return OrderCount(NULL, LONG_MAX, type);
  }
//+------------------------------------------------------------------+
//|  Counts orders with a specified ticket number                    |
//+------------------------------------------------------------------+
int OrderCountByTicket(long ticket)
  {
   return OrderCount(NULL, LONG_MAX, -1, ticket);
  }
//+------------------------------------------------------------------+
//|  Cancels orders filtered by symbol, magic, type, or ticket       |
//+------------------------------------------------------------------+
bool CancelOrders(const string symbol="",
                  const long magic=LONG_MAX,
                  const int type=-1,
                  const long ticket=-1)
  {
   
   COrderInfo order;
   CTrade trade;
   
   bool use_symbol = (symbol != "");
   bool use_magic  = (magic  != LONG_MAX);
   bool use_type   = (type   != -1);
   bool use_ticket = (ticket != -1);

   for(int i = OrdersTotal()-1; i >= 0; --i)
     {
      if(!order.SelectByIndex(i))
         continue;

      if(use_symbol && order.Symbol() != symbol)
         continue;
      if(use_magic  && order.Magic()  != magic)
         continue;
      if(use_type   && (int)order.OrderType() != type)
         continue;
      if(use_ticket && order.Ticket() != (ulong)ticket)
         continue;
      
      //---
      
      trade.SetExpertMagicNumber(magic);
      trade.SetTypeFillingBySymbol(order.Symbol());
      
      ulong ticket = order.Ticket();
      
      if (!trade.OrderDelete(ticket))
          printf("Failed to delete an order #%I64u", ticket);
     }
     
   return true;
  }
//+------------------------------------------------------------------+
//|  Cancels all orders with a specified symbol                      |
//+------------------------------------------------------------------+
bool CancelOrdersBySymbol(string symbol)
  {
   return CancelOrders(symbol);
  }
//+------------------------------------------------------------------+
//|  Cancels all orders with a specified magic number                |
//+------------------------------------------------------------------+
bool CancelOrdersByMagic(int magic)
  {
   return CancelOrders("", magic);
  }
//+------------------------------------------------------------------+
//|  Cancels all orders with a specified type                        |
//+------------------------------------------------------------------+
bool CancelOrdersByType(ENUM_POSITION_TYPE type)
  {
   return CancelOrders("", INT_MAX, type);
  }
//+------------------------------------------------------------------+
//|  Cancels an order with a specified ticket number                 |
//+------------------------------------------------------------------+
bool CancelOrdersByTicket(long ticket)
  {
   return CancelOrders("", INT_MAX, -1, ticket);
  }
//+------------------------------------------------------------------+
//|  Returns the most recently placed order filtered by              |
//|  symbol, magic, or type                                          |
//+------------------------------------------------------------------+
bool RecentOrder(COrderInfo &info,
                 const string symbol="",
                 const long magic=LONG_MAX,
                 const int type=-1)
  {
   bool use_symbol = (symbol != "");
   bool use_magic  = (magic  != LONG_MAX);
   bool use_type   = (type   != -1);
   
   ulong recent_ticket = 0;
   ulong last_time_msc = 0;
   
   COrderInfo order;
   
   for(int i = OrdersTotal()-1; i >= 0; --i)
     {
      if(!order.SelectByIndex(i))
         continue;

      if(use_symbol && order.Symbol() != symbol)
         continue;
      if(use_magic  && order.Magic()  != magic)
         continue;
      if(use_type   && (int)order.OrderType() != type)
         continue;

      //--- passed all active filters
      
      ulong t = order.TimeSetupMsc();
      if (t > last_time_msc)
         {
            last_time_msc = t;
            recent_ticket = order.Ticket();
         }
     }
   
   if(recent_ticket == 0)
      return false;
      
   return info.Select(recent_ticket); //--- select the latest orderition using it's ticket
  }
//+---------------------------------------------------------------------+
//|  Returns the oldest placed order filtered by symbol, magic, or type |
//+---------------------------------------------------------------------+
bool OldestOrder(COrderInfo &info,
                 const string symbol="",
                 const long magic=LONG_MAX,
                 const int type=-1)
  {
   bool use_symbol = (symbol != "");
   bool use_magic  = (magic  != LONG_MAX);
   bool use_type   = (type   != -1);
   
   ulong oldest_ticket = 0;
   ulong oldest_time_msc = 0;
   
   COrderInfo order;
   
   for(int i = OrdersTotal()-1; i >= 0; --i)
     {
      if(!order.SelectByIndex(i))
         continue;

      if(use_symbol && order.Symbol() != symbol)
         continue;
      if(use_magic  && order.Magic()  != magic)
         continue;
      if(use_type   && (int)order.OrderType() != type)
         continue;

      //--- passed all active filters
      
      ulong t = order.TimeSetupMsc();
      if (t < oldest_time_msc)
         {
            oldest_time_msc = t;
            oldest_ticket = order.Ticket();
         }
     }
   
   if(oldest_ticket == 0)
      return false;
      
   return info.Select(oldest_ticket); //--- select the latest orderition using it's ticket
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
