//+------------------------------------------------------------------+
//|                                                 Logging Test.mq5 |
//|                                     Copyright 2025, Omega Joctan |
//|                 https://www.mql5.com/en/users/omegajoctan/seller |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property script_show_inputs


#define PROG_NAME MQLInfoString(MQL_PROGRAM_NAME)
#define PROG_TYPE (ENUM_PROGRAM_TYPE)MQLInfoInteger(MQL_PROGRAM_TYPE)
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
#include <PyMQL5\logging.mqh>
CLogger logger(PROG_NAME, PROG_TYPE);

#define logger_info(msg) logger.info(msg, __FUNCTION__, __LINE__)
#define logger_debug(msg) logger.debug(msg, __FUNCTION__, __LINE__)
#define logger_warning(msg) logger.warning(msg, __FUNCTION__, __LINE__)
#define logger_error(msg) logger.error(msg, __FUNCTION__, __LINE__)
#define logger_critical(msg) logger.critical(msg, __FUNCTION__, __LINE__)
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
input int risk_per_trade = 50; //Risk Per Trade

int important_indicator_handle;
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//---
   
   //string format = "%(asctime)s:%(levelname)s:%(programname)s:%(programtype)s:%(functionname)s:%(linenumber)d:%(message)s";
   
   string format = "%(asctime)s | [%(levelname)s] [%(programname)s] [%(programtype)s] func:%(functionname)s line:%(linenumber)d --> [%(message)s]";
   logger.basicConfig(LOG_LEVEL_DEBUG, "logs.log", false, format);
 
   logger_info("The script has started");
   
   bool num_a = 10;
   bool num_b = -10;
     
   logger_info("num_a>num_b "+(string)bool(num_a>num_b));  

   if (!doSomething())
      {
        logger_error(StringFormat("Some operation has failed Error = %d",GetLastError()));
      }
      
   if (risk_per_trade>10) //if a user has set the risk higher than 10% of the account balance
      logger_warning(StringFormat("You have risked too much for a single trade. Risk percentage = %d", risk_per_trade));
      
   important_indicator_handle = iMA(Symbol(), Period(), -1, 0, MODE_SMA, PRICE_CLOSE); //An indicator with a negative period
   
   if (important_indicator_handle == INVALID_HANDLE)
     {
       logger_critical("Failed to load the Moving Average indicator, Error = "+(string)GetLastError());
       //return;
     }
     
//---

   logger_info("End of the script!");
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool doSomething()
 {
   return false;
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
