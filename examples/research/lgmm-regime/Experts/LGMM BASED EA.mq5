//+------------------------------------------------------------------+
//|                                                LGMM BASED EA.mq5 |
//|                                          Copyright 2023, Omegafx |
//|                 https://www.mql5.com/en/users/omegajoctan/seller |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Omegafx"
#property link      "https://www.mql5.com/en/users/omegajoctan/seller"
#property version   "1.00"

#include <Random Forest.mqh> 
#include <Gaussian Mixture.mqh>
#include <Arrays\ArrayString.mqh>
#include <pandas.mqh> //https://www.mql5.com/en/articles/17030
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <errordescription.mqh>

CRandomForestClassifier rfc;
CGaussianMixture lgmm;
CSymbolInfo m_symbol;
CTrade m_trade;
CPositionInfo m_position;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
#define MAGICNUMBER 11062025

input string SYMBOL = "XAUUSD";
input ENUM_TIMEFRAMES TIMEFRAME = PERIOD_D1;
input uint LOOKAHEAD = 5;
input uint SLIPPAGE = 100;

struct indicator_struct
 {
   long handle;
   CArrayString buffer_names;
 };

indicator_struct indicators[15];
int OldNumBars=-1;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   
   if (!MQLInfoInteger(MQL_DEBUG) && !MQLInfoInteger(MQL_TESTER))
    {
      ChartSetSymbolPeriod(0, SYMBOL, TIMEFRAME);
      if (!SymbolSelect(SYMBOL, true))
         {
            printf("%s failed to select SYMBOL %s, Error = %s",__FUNCTION__,SYMBOL,ErrorDescription(GetLastError()));
            return INIT_FAILED;
         }
    }

//--- Loading the Gaussian Mixture model

   string filename = StringFormat("LGMM.%s.%s.onnx",SYMBOL, EnumToString(TIMEFRAME));
   if (!lgmm.Init(filename, ONNX_COMMON_FOLDER))
      {
         printf("%s Failed to initialize the GaussianMixture model (LGMM) in ONNX format file={%s}, Error = %s",__FUNCTION__,filename,ErrorDescription(GetLastError()));
      }
   
//--- Loading the RFC model
   
   filename = StringFormat("rfc.%s.%s.onnx",SYMBOL,EnumToString(TIMEFRAME));
   Print(filename);
   if (!rfc.Init(filename, ONNX_COMMON_FOLDER))
      {
         printf("func=%s line=%d, Failed to Load the RFC in ONNX file={%s}, Error = %s",__FUNCTION__,__LINE__,filename,ErrorDescription(GetLastError()));
         return INIT_FAILED;
      }

//--- Oscillators
   
   indicators[0].handle = iATR(SYMBOL, TIMEFRAME, 14);
   indicators[0].buffer_names.Add("ATR");
   
   indicators[1].handle = iBearsPower(SYMBOL, TIMEFRAME, 13);
   indicators[1].buffer_names.Add("BearsPower");
   
   indicators[2].handle = iBullsPower(SYMBOL, TIMEFRAME, 13);
   indicators[2].buffer_names.Add("BullsPower");
   
   indicators[3].handle = iChaikin(SYMBOL, TIMEFRAME, 3, 10, MODE_EMA, VOLUME_TICK);
   indicators[3].buffer_names.Add("Chainkin");
   
   indicators[4].handle = iCCI(SYMBOL, TIMEFRAME, 14, PRICE_OPEN);
   indicators[4].buffer_names.Add("CCI"); 
   
   indicators[5].handle = iDeMarker(SYMBOL, TIMEFRAME, 14);
   indicators[5].buffer_names.Add("Demarker");
   
   indicators[6].handle = iForce(SYMBOL, TIMEFRAME, 13, MODE_SMA, VOLUME_TICK);
   indicators[6].buffer_names.Add("Force");
   
   indicators[7].handle = iMACD(SYMBOL, TIMEFRAME, 12, 26, 9, PRICE_OPEN);
   indicators[7].buffer_names.Add("MACD MAIN_LINE");
   indicators[7].buffer_names.Add("MACD SIGNAL_LINE");
   
   indicators[8].handle = iMomentum(SYMBOL, TIMEFRAME, 14, PRICE_OPEN);
   indicators[8].buffer_names.Add("Momentum");
   
   indicators[9].handle = iOsMA(SYMBOL, TIMEFRAME, 12, 26, 9, PRICE_OPEN);
   indicators[9].buffer_names.Add("OsMA");
   
   indicators[10].handle = iRSI(SYMBOL, TIMEFRAME, 14, PRICE_OPEN);
   indicators[10].buffer_names.Add("RSI");
   
   indicators[11].handle = iRVI(SYMBOL, TIMEFRAME, 10);
   indicators[11].buffer_names.Add("RVI MAIN_LINE");
   indicators[11].buffer_names.Add("RVI SIGNAL_LINE");
   
   indicators[12].handle = iStochastic(SYMBOL, TIMEFRAME, 5, 3,3,MODE_SMA,STO_LOWHIGH);
   indicators[12].buffer_names.Add("StochasticOscillator MAIN_LINE");
   indicators[12].buffer_names.Add("StochasticOscillator SIGNAL_LINE");
   
   indicators[13].handle = iTriX(SYMBOL, TIMEFRAME, 14, PRICE_OPEN);
   indicators[13].buffer_names.Add("TEMA");
   
   indicators[14].handle = iWPR(SYMBOL, TIMEFRAME, 14);
   indicators[14].buffer_names.Add("WPR");
   
//--- modules configurations

   m_trade.SetExpertMagicNumber(MAGICNUMBER);
   m_trade.SetTypeFillingBySymbol(SYMBOL);
   m_trade.SetDeviationInPoints(SLIPPAGE);
   
   m_symbol.Name(SYMBOL);
   
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
//--- Close trades after AI predictive horizon is over

   CloseTradeAfterTime(MAGICNUMBER, PeriodSeconds(TIMEFRAME)*LOOKAHEAD);
   
//--- Refresh tick information

   if (!m_symbol.RefreshRates())
     {
       printf("func=%s line=%s. Failed to copy rates, Error = %s",__FUNCTION__,ErrorDescription(GetLastError()));
       return;
     }
      
//---

    vector x = getX(); //Get all the input for the model
    
    if (x.Size()==0)
      return;
    
    long signal = rfc.predict(x).cls; //the class predicted by the random forest classifier
    double proba = rfc.predict(x).proba; //probability of the predictions
    
    double volume = m_symbol.LotsMin();
      
    if (!PosExists(POSITION_TYPE_SELL, MAGICNUMBER) && !PosExists(POSITION_TYPE_BUY, MAGICNUMBER)) //no position is open
      {
        if (signal == 1) //If a model predicts a bullish signal
          m_trade.Buy(volume, SYMBOL, m_symbol.Ask()); //Open a buy trade 
        else if (signal == -1) // if a model predicts a bearish signal
          m_trade.Sell(volume, SYMBOL, m_symbol.Bid()); //open a sell trade
      }
  }
//+------------------------------------------------------------------+
//| Horizontally stack two vectors                                   |
//+------------------------------------------------------------------+
vector hstack(const vector &a, const vector &b)
{
    vector result(a.Size() + b.Size());
    
    for(ulong i = 0; i < a.Size(); i++)
        result[i] = a[i];
    
    for(ulong i = 0; i < b.Size(); i++)
        result[i + a.Size()] = b[i];
    
    return result;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
vector getX(uint start=0, uint count=10)
 {
//--- Get buffers

   CDataFrame df;
   for (uint ind=0; ind<indicators.Size(); ind++) //Loop through all the indicators
      {    
        uint buffers_total = indicators[ind].buffer_names.Total();
        
         for (uint buffer_no=0; buffer_no<buffers_total; buffer_no++) //Their buffer names resemble their buffer numbers 
            {
               string name = indicators[ind].buffer_names.At(buffer_no); //Get the name of the buffer, it is helpful for the DataFrame and CSV file
               
               vector buffer = {};
               if (!buffer.CopyIndicatorBuffer(indicators[ind].handle, buffer_no, start, count)) //Copy indicator buffer 
                  {
                     printf("func=%s line=%d | Failed to copy %s indicator buffer, Error = %d",__FUNCTION__,__LINE__,name,GetLastError());
                     continue;
                  }
               
               df.insert(name, buffer); //Insert a buffer vector and its name to a dataframe object
            }
      }
   
   if ((uint)df.shape()[0]==0)
      return vector::Zeros(0);
   
//--- predict the latent features

   vector indicators_data = df.iloc(-1); //index=-1 returns the last row from the dataframe which is the most recent buffer from all indicators
   
//--- Given the indicators let's predict the latent features
   
   vector latent_features = lgmm.predict(indicators_data).proba;
   
   if (latent_features.Size()==0)
      return vector::Zeros(0);
         
   return hstack(indicators_data, latent_features); //Return indicators data stacked alongside latent features 
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double LotValidate(double volume)
{
   // Get the minimum, maximum, and step size for the SYMBOL
   double min_volume = SymbolInfoDouble(SYMBOL, SYMBOL_VOLUME_MIN);
   double max_volume = SymbolInfoDouble(SYMBOL, SYMBOL_VOLUME_MAX);
   double step_volume = SymbolInfoDouble(SYMBOL, SYMBOL_VOLUME_STEP);

   // Check if the volume is less than the minimum
   if (volume < min_volume)
      return min_volume;

   // Check if the volume is greater than the maximum
   if (volume > max_volume)
      return max_volume;

   // Check if the volume is a multiple of the step size
   int ratio = (int) MathRound(volume / step_volume);
   double adjusted_volume = ratio * step_volume;
   
   if (MathAbs(adjusted_volume - volume) > 0.0000001)
      return adjusted_volume;
      
   return adjusted_volume;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseTradeAfterTime(int magic_number, int period_seconds)
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
      if (m_position.SelectByIndex(i))
         if (m_position.Magic() == magic_number)
            if (TimeCurrent() - m_position.Time() >= period_seconds)
               m_trade.PositionClose(m_position.Ticket(), SLIPPAGE);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool PosExists(ENUM_POSITION_TYPE type, int magic)
 {
    for (int i=PositionsTotal()-1; i>=0; i--)
      if (m_position.SelectByIndex(i))
         if (m_position.Symbol()==SYMBOL && m_position.Magic() == magic && m_position.PositionType()==type)
            return (true);
            
    return (false);
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
