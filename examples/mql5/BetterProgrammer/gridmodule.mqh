//+------------------------------------------------------------------+
//|                                                  gridmodule.mqh |
//|                                     Copyright 2021, Omega Joctan |
//|                        https://www.mql5.com/en/users/omegajoctan |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, Omega Joctan"
#property link      "https://www.mql5.com/en/users/omegajoctan"
//+------------------------------------------------------------------+
//| Libraries                                                        |
//+------------------------------------------------------------------+ 
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>

CSymbolInfo   m_symbol;
CPositionInfo m_position;
//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
class CGrid
  {
   protected:
     int                   MagicNumber;
  
   public:
                           CGrid(void);
                          ~CGrid(void);
      void                 InitializeModule(int magic) { MagicNumber = magic; }
      double               LastPositionOpenPrice(ENUM_POSITION_TYPE type);
      int                  CountPositions(ENUM_POSITION_TYPE type);
   
  };
//+------------------------------------------------------------------+
//|               Constructor                                        |
//+------------------------------------------------------------------+
CGrid::CGrid(void)
 {
 
 }
//+------------------------------------------------------------------+
//|                Destructor                                        |
//+------------------------------------------------------------------+
CGrid :: ~CGrid(void)
 {
 
 }
//+------------------------------------------------------------------+
//|           Last Position Open Price By Position Type              |
//+------------------------------------------------------------------+
double CGrid::LastPositionOpenPrice(ENUM_POSITION_TYPE type)
 {
  double LastPrice = -1;
  ulong  LastTime = 0; 
   for (int i=PositionsTotal()-1; i>=0; i--)
     if (m_position.SelectByIndex(i))
       if (m_position.Magic() == MagicNumber && m_position.Symbol()==Symbol() && m_position.PositionType()==type)
          {
             ulong positionTime = m_position.TimeMsc();
             if ( positionTime > LastTime ) //FInd the latest position
               {
                  LastPrice = m_position.PriceOpen();
                  LastTime = m_position.TimeMsc();
               }
          }
       return LastPrice;
 }
//+------------------------------------------------------------------+
//|                Count Positions By Type                           |
//+------------------------------------------------------------------+
int CGrid::CountPositions(ENUM_POSITION_TYPE type)
 {
   int counter = 0; //variable to store our positions number
   for (int i=PositionsTotal()-1; i>=0; i--)
     if (m_position.SelectByIndex(i)) // Select position by its index
        if (m_position.Magic() == MagicNumber && m_position.Symbol() == Symbol() && m_position.PositionType() == type)
          {
            counter++; 
          }
      return counter;
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+