//+------------------------------------------------------------------+
//|                                                    positinos.mqh |
//|                                     Copyright 2026, Omega Joctan |
//|                 https://www.mql5.com/en/users/omegajoctan/seller |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Omega Joctan"
#property link      "https://www.mql5.com/en/users/omegajoctan/seller"
//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
//+------------------------------------------------------------------+
//|  Returns true if a position exists filtered by                   |
//|  symbol, magic, type, or ticket                                  |
//+------------------------------------------------------------------+
bool PositionExists(const string symbol="",
                    const long magic=LONG_MAX,
                    const int type=-1,
                    const long ticket=-1)
  {
   bool use_symbol = (symbol != "");
   bool use_magic  = (magic  != LONG_MAX);
   bool use_type   = (type   != -1);
   bool use_ticket = (ticket != -1);
   
   CPositionInfo pos;
   
   for(int i = PositionsTotal()-1; i >= 0; --i)
     {
      if(!pos.SelectByIndex(i))
         continue;

      if(use_symbol && pos.Symbol() != symbol)
         continue;
      if(use_magic  && pos.Magic()  != magic)
         continue;
      if(use_type   && (int)pos.PositionType() != type)
         continue;
      if(use_ticket && pos.Ticket() != ticket)
         continue;

      //--- passed all active filters
      return true;
     }
   return false;
  }
//+------------------------------------------------------------------+
//|  Returns true if a position exists with a specified ticket number|
//+------------------------------------------------------------------+
bool PositionExistsByMagic(int magic)
  {
   return PositionExists("", magic);
  }
//+------------------------------------------------------------------+
//|  Returns true if a position exists with a specified symbol       |
//+------------------------------------------------------------------+
bool PositionExistsBySymbol(string symbol)
  {
   return PositionExists(symbol);
  }
//+------------------------------------------------------------------+
//|  Returns true if a position exists with a specified type         |
//+------------------------------------------------------------------+
bool PositionExistsByType(ENUM_POSITION_TYPE type)
  {
   return PositionExists("", LONG_MAX, type);
  }
//+------------------------------------------------------------------+
//|  Returns true if a position exists with a specified ticket number|
//+------------------------------------------------------------------+
bool PositionExistsByTicket(int ticket)
  {
   return PositionExists("", LONG_MAX, -1, ticket);
  }
//+------------------------------------------------------------------+
//|  Counts positions filtered by symbol, magic, type, or ticket     |
//+------------------------------------------------------------------+
int PositionCount(const string symbol="",
                  const long magic=LONG_MAX,
                  const int type=-1,
                  const long ticket=-1)
  {
   bool use_symbol = (symbol != "");
   bool use_magic  = (magic  != LONG_MAX);
   bool use_type   = (type   != -1);
   bool use_ticket = (ticket != -1);
   
   CPositionInfo pos;
   
   int count = 0;
   for(int i = PositionsTotal()-1; i >= 0; --i)
     {
      if(!pos.SelectByIndex(i))
         continue;

      if(use_symbol && pos.Symbol() != symbol)
         continue;
      if(use_magic  && pos.Magic()  != magic)
         continue;
      if(use_type   && (int)pos.PositionType() != type)
         continue;
      if(use_ticket && pos.Ticket() != ticket)
         continue;

      //--- passed all active filters
      count++;
     }

   return count;
  }
//+------------------------------------------------------------------+
//|         Counts positions with a specified magic number           |
//+------------------------------------------------------------------+
int PositionCountByMagic(int magic)
  {
   return PositionCount("", magic);
  }
//+------------------------------------------------------------------+
//|         Counts positions with a specified symbol                 |
//+------------------------------------------------------------------+
int PositionCountBySymbol(string symbol)
  {
   return PositionCount(symbol);
  }
//+------------------------------------------------------------------+
//|         Counts positions with a specified type                   |
//+------------------------------------------------------------------+
int PositionCountByType(int type)
  {
   return PositionCount("", LONG_MAX, type);
  }
//+------------------------------------------------------------------+
//|         Counts positions with a specified ticket number          |
//+------------------------------------------------------------------+
int PositionCountByTicket(long ticket)
  {
   return PositionCount("", LONG_MAX, -1, ticket);
  }
//+------------------------------------------------------------------+
//|  Closes positions filtered by symbol, magic, type, or ticket     |
//+------------------------------------------------------------------+
void PositionClose(const long deviation_points=LONG_MAX,
                    const string symbol="",
                    const long magic=LONG_MAX,
                    const int type=-1,
                    const long ticket=-1)
  {
   bool use_symbol = (symbol != "");
   bool use_magic  = (magic  != LONG_MAX);
   bool use_type   = (type   != -1);
   bool use_ticket = (ticket != -1);
   
   CPositionInfo pos;
   CTrade trade;
   
   for(int i = PositionsTotal()-1; i >= 0; --i)
     {
      if(!pos.SelectByIndex(i))
         continue;

      if(use_symbol && pos.Symbol() != symbol)
         continue;
      if(use_magic  && pos.Magic()  != magic)
         continue;
      if(use_type   && (int)pos.PositionType() != type)
         continue;
      if(use_ticket && pos.Ticket() != (ulong)ticket)
         continue;

      const string sym = pos.Symbol();
      
      //---
      
      trade.SetExpertMagicNumber(magic);
      trade.SetTypeFillingBySymbol(pos.Symbol());
      
      if (!trade.PositionClose(pos.Ticket(), deviation_points))
          printf("Failed to close position #%I64u", pos.Ticket());
     }
  }
//+------------------------------------------------------------------+
//|         Closes all positions with a specified symbol             |
//+------------------------------------------------------------------+
void PositionCloseBySymbol(string symbol, long deviation_points=LONG_MAX)
  {
   PositionClose(deviation_points, symbol);
  }
//+------------------------------------------------------------------+
//|         Closes all positions with a specified magic number       |
//+------------------------------------------------------------------+
void PositionCloseByMagic(int magic, long deviation_points=LONG_MAX)
  {
   PositionClose(deviation_points, "", magic);
  }
//+------------------------------------------------------------------+
//|         Closes all positions with a specified type               |
//+------------------------------------------------------------------+
void PositionCloseByType(ENUM_POSITION_TYPE type, long deviation_points=LONG_MAX)
  {
   PositionClose(deviation_points, "", LONG_MAX, type);
  }
//+------------------------------------------------------------------+
//|         Closes a position with a specified ticket number         |
//+------------------------------------------------------------------+
void PositionCloseByTicket(long ticket, long deviation_points=LONG_MAX)
  {
   PositionClose(deviation_points, "", INT_MAX, -1, ticket);
  }
//+------------------------------------------------------------------+
//|  Closes all profitable positions filtered by                     |
//|  symbol, magic, type, or ticket                                  |
//+------------------------------------------------------------------+
void CloseProfitablePositions(const long deviation_points=LONG_MAX,
                              const string symbol="",
                              const long magic=LONG_MAX,
                              const int type=-1,
                              const long ticket=-1)
  {
   bool use_symbol = (symbol != "");
   bool use_magic  = (magic  != LONG_MAX);
   bool use_type   = (type   != -1);
   bool use_ticket = (ticket != -1);
   
   CPositionInfo pos;
   CTrade trade;
   
   for(int i = PositionsTotal()-1; i >= 0; --i)
     {
      if(!pos.SelectByIndex(i))
         continue;

      if(use_symbol && pos.Symbol() != symbol)
         continue;
      if(use_magic  && pos.Magic()  != magic)
         continue;
      if(use_type   && (int)pos.PositionType() != type)
         continue;
      if(use_ticket && pos.Ticket() != (ulong)ticket)
         continue;

      const string sym = pos.Symbol();
      
      //---
      
      trade.SetExpertMagicNumber(magic);
      trade.SetTypeFillingBySymbol(pos.Symbol());
      
      if (pos.Profit()>0)
         if (!trade.PositionClose(pos.Ticket(), deviation_points))
             printf("Failed to close position #%I64u", pos.Ticket());
     }
  }
//+------------------------------------------------------------------+
//|           Closes all losing positions filtered by                |
//|           symbol, magic, type, or ticket                         |
//+------------------------------------------------------------------+
void CloseLosingPositions(const long deviation_points=LONG_MAX,
                          const string symbol="",
                          const long magic=LONG_MAX,
                          const int type=-1,
                          const long ticket=-1)
  {
   bool use_symbol = (symbol != "");
   bool use_magic  = (magic  != LONG_MAX);
   bool use_type   = (type   != -1);
   bool use_ticket = (ticket != -1);
   
   CPositionInfo pos;
   CTrade trade;
   
   for(int i = PositionsTotal()-1; i >= 0; --i)
     {
      if(!pos.SelectByIndex(i))
         continue;

      if(use_symbol && pos.Symbol() != symbol)
         continue;
      if(use_magic  && pos.Magic()  != magic)
         continue;
      if(use_type   && (int)pos.PositionType() != type)
         continue;
      if(use_ticket && pos.Ticket() != (ulong)ticket)
         continue;

      const string sym = pos.Symbol();
      
      //---
      
      trade.SetExpertMagicNumber(magic);
      trade.SetTypeFillingBySymbol(pos.Symbol());
      
      if (pos.Profit()<0)
         if (!trade.PositionClose(pos.Ticket(), deviation_points))
             printf("Failed to close position #%I64u", pos.Ticket());
     }
  }
//+------------------------------------------------------------------+
//|  Returns the most recently opened position filtered by           |
//|  symbol, magic, or type                                          |
//+------------------------------------------------------------------+
bool GetRecentPosition(CPositionInfo &pos_info,
                       const string symbol="",
                       const long magic=LONG_MAX,
                       const int type=-1)
  {
   bool use_symbol = (symbol != "");
   bool use_magic  = (magic  != LONG_MAX);
   bool use_type   = (type   != -1);
   
   ulong recent_ticket = 0;
   ulong last_time_msc = 0;
   
   CPositionInfo pos;
   
   for(int i = PositionsTotal()-1; i >= 0; --i)
     {
      if(!pos.SelectByIndex(i))
         continue;

      if(use_symbol && pos.Symbol() != symbol)
         continue;
      if(use_magic  && pos.Magic()  != magic)
         continue;
      if(use_type   && (int)pos.PositionType() != type)
         continue;

      //--- passed all active filters
      
      ulong t = pos.TimeMsc();
      if (t > last_time_msc)
         {
            last_time_msc = t;
            recent_ticket = pos.Ticket();
         }
     }
   
   if(recent_ticket == 0)
      return false;
      
   return pos_info.SelectByTicket(recent_ticket); //--- select the latest position using it's ticket
  }
//+------------------------------------------------------------------+
//| Returns the most recently opened position with a specified symbol|
//+------------------------------------------------------------------+
bool GetRecentPositionBySymbol(CPositionInfo &pos_info, const string symbol="")
 { 
  return GetRecentPosition(pos_info, symbol); 
 }
//+------------------------------------------------------------------+
//|  Returns the most recently opened position with a specified      |
//|  magic number                                                    |
//+------------------------------------------------------------------+
bool GetRecentPositionByMagic(CPositionInfo &pos_info, const long magic=LONG_MAX) 
 { 
   return GetRecentPosition(pos_info, "", magic); 
 }
//+------------------------------------------------------------------+
//|  Returns the most recently opened position with a specified type |
//+------------------------------------------------------------------+
bool GetRecentPositionByMagic(CPositionInfo &pos_info, const int type=-1) 
 { 
   return GetRecentPosition(pos_info, "", LONG_MAX, type); 
 }
//+-------------------------------------------------------------------+
//|Returns the oldest open position filtered by symbol, magic, or type|
//+-------------------------------------------------------------------+
bool GetOldestPosition(CPositionInfo &pos_info,
                       const string symbol="",
                       const long magic=LONG_MAX,
                       const int type=-1)
  {
   bool use_symbol = (symbol != "");
   bool use_magic  = (magic  != LONG_MAX);
   bool use_type   = (type   != -1);
   
   ulong oldest_ticket = 0;
   ulong oldest_time_msc = ULONG_MAX;
   
   CPositionInfo pos;
   
   for(int i = PositionsTotal()-1; i >= 0; --i)
     {
      if(!pos.SelectByIndex(i))
         continue;

      if(use_symbol && pos.Symbol() != symbol)
         continue;
      if(use_magic  && pos.Magic()  != magic)
         continue;
      if(use_type   && (int)pos.PositionType() != type)
         continue;

      //--- passed all active filters
      
      ulong t = pos.TimeMsc();
      if (t < oldest_time_msc)
         {
            oldest_time_msc = t;
            oldest_ticket = pos.Ticket();
         }
     }
   
   if(oldest_ticket == 0)
      return false;
      
   return pos_info.SelectByTicket(oldest_ticket); //--- select the oldest position using it's ticket
  }
//+------------------------------------------------------------------+
//|  Returns the oldest open position with a specified symbol        |
//+------------------------------------------------------------------+
bool GetOldestPositionBySymbol(CPositionInfo &pos_info, const string symbol="")
 { 
  return GetOldestPosition(pos_info, symbol); 
 }
//+------------------------------------------------------------------+
//|  Returns the oldest open position with a specified magic number  |
//+------------------------------------------------------------------+
bool GetOldestPositionByMagic(CPositionInfo &pos_info, const long magic=LONG_MAX) 
 { 
   return GetOldestPosition(pos_info, "", magic); 
 }
//+------------------------------------------------------------------+
//|  Returns the oldest open position with a specified type          |
//+------------------------------------------------------------------+
bool GetOldestPositionByType(CPositionInfo &pos_info, const int type=-1) 
 { 
   return GetOldestPosition(pos_info, "", LONG_MAX, type); 
 }
//+------------------------------------------------------------------+
/*
void PositionExpire(const uint x_minutes,
                    const long deviation_points=LONG_MAX,
                    const string symbol="",
                    const long magic=LONG_MAX,
                    const int type=-1,
                    const long ticket=-1)
 {
 
   bool use_symbol = (symbol != "");
   bool use_magic  = (magic  != LONG_MAX);
   bool use_type   = (type   != -1);
   
   ulong recent_ticket = 0;
   ulong last_time_msc = 0;
   
   CPositionInfo pos;
   CTrade trade;
   
   for(int i = PositionsTotal()-1; i >= 0; --i)
     {
      if(!pos.SelectByIndex(i))
         continue;

      if(use_symbol && pos.Symbol() != symbol)
         continue;
      if(use_magic  && pos.Magic()  != magic)
         continue;
      if(use_type   && (int)pos.PositionType() != type)
         continue;
      
      long age_sec = (long)TimeCurrent() - (long)pos.Time();
      if (age_sec >= (long)x_minutes*60)
        {
          trade.SetExpertMagicNumber(magic);
          trade.SetTypeFillingBySymbol(pos.Symbol());
          
          trade.PositionClose(ticket, deviation_points);
        }
     }
 }
*/
//+------------------------------------------------------------------+

