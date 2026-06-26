//+------------------------------------------------------------------+
//|                                                 Logging Test.mq5 |
//|                                     Copyright 2025, Omega Joctan |
//|                 https://www.mql5.com/en/users/omegajoctan/seller |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Omega Joctan"
#property link      "https://www.mql5.com/en/users/omegajoctan/seller"
#property version   "1.00"

#define PROG_NAME MQLInfoString(MQL_PROGRAM_NAME)
#define PROG_TYPE (ENUM_PROGRAM_TYPE)MQLInfoInteger(MQL_PROGRAM_TYPE)
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
#include <PyMQL5\logging.mqh>
CLogger logger(PROG_NAME, PROG_TYPE);

#define logger_info(msg) logger.info(msg, __FUNCTION__, __LINE__)
#define logger_debugg(msg) logger.debug(msg, __FUNCTION__, __LINE__)
#define logger_warning(msg) logger.warning(msg, __FUNCTION__, __LINE__)
#define logger_error(msg) logger.error(msg, __FUNCTION__, __LINE__)
#define logger_critical(msg) logger.critical(msg, __FUNCTION__, __LINE__)
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
   string format = "%(asctime)s:%(programname)s:%(programtype)s:%(functionname)s:%(linenumber)d:%(message)s";
   
   bool is_tester = (bool)MQLInfoInteger(MQL_TESTER);
   logger.basicConfig(LOG_LEVEL_DEBUG, "logs.log", !is_tester, format, is_tester, true, true);
 
   logger_info("Program started!");
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   logger_info("Program stopped. Reason = "+UninitializeReasonDescription(reason));
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   
   logger_info("Program running");
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string UninitializeReasonDescription(const int reason) 
  { 
   switch(reason) 
     { 
      //--- the EA has stopped working calling the ExpertRemove() function 
      case REASON_PROGRAM : 
        return("Expert Advisor terminated its operation by calling the ExpertRemove() function"); 
      //--- program removed from a chart 
      case REASON_REMOVE : 
        return("Program has been deleted from the chart"); 
      //--- program recompiled 
      case REASON_RECOMPILE : 
        return("Program has been recompiled"); 
      //--- symbol or chart period changed 
      case REASON_CHARTCHANGE : 
        return("Symbol or chart period has been changed"); 
      //--- chart closed 
      case REASON_CHARTCLOSE : 
        return("Chart has been closed"); 
      //--- inputs changed by user 
      case REASON_PARAMETERS : 
        return("Input parameters have been changed by a user"); 
      //--- another account has been activated or reconnection to the trade server has occurred due to changes in the account settings 
      case REASON_ACCOUNT : 
        return("Another account has been activated or reconnection to the trade server has occurred due to changes in the account settings"); 
      //--- another chart template applied 
      case REASON_TEMPLATE : 
        return("A new template has been applied"); 
      //--- OnInit() handler returned a non-zero value 
      case REASON_INITFAILED : 
        return("This value means that OnInit() handler has returned a nonzero value"); 
      //--- terminal closed 
      case REASON_CLOSE : 
        return("Terminal has been closed"); 
     } 
  
//--- deinitialization reason unknown 
   return("Unknown reason"); 
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

