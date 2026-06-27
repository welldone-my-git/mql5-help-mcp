//+------------------------------------------------------------------+
//| OrderBuilder.mqh                                                 |
//| COrderBuilder: fluent interface builder for MqlTradeRequest.     |
//| Provides method chaining via pointer returns, per-field input    |
//| validation, and a multi-stage pre-dispatch gate before server    |
//| submission.                                                      |
//|                                                                  |
//| Usage:                                                           |
//|    COrderBuilder *builder = new COrderBuilder();                 |
//|    MqlTradeResult result  = {};                                  |
//|    bool ok = builder.Symbol(_Symbol).Volume(0.1).Buy()           |
//|                     .AtMarket().StopLoss(sl).TakeProfit(tp)      |
//|                     .Send(result);                               |
//|    delete builder;                                               |
//|                                                                  |
//| Or as a stack instance using the non-chained Reset() pattern:    |
//|    COrderBuilder builder;                                        |
//|    builder.Symbol(_Symbol).Volume(0.1).Buy()                     |
//|           .AtMarket().StopLoss(sl).TakeProfit(tp);               |
//|    bool ok = builder.Send(result);                               |
//+------------------------------------------------------------------+
#ifndef ORDERBUILDER_MQH
#define ORDERBUILDER_MQH

//+------------------------------------------------------------------+
//| COrderBuilder — class declaration                                |
//| All chainable methods return COrderBuilder* (pointer to self).   |
//| MQL5 does not support reference return types on class methods;   |
//| pointer return is the correct substitute for *this chaining.     |
//+------------------------------------------------------------------+
class COrderBuilder
  {
private:
   //--- Identity group
   string                     m_symbol;
   double                     m_volume;
   ulong                      m_magic;
   string                     m_comment;

   //--- Direction and action group
   ENUM_TRADE_REQUEST_ACTIONS m_action;
   ENUM_ORDER_TYPE            m_order_type;

   //--- Price level group
   double                     m_price;
   double                     m_stoplimit_price;

   //--- Stop level group
   double                     m_sl;
   double                     m_tp;

   //--- Execution group
   ulong                      m_deviation;
   ENUM_ORDER_TYPE_FILLING    m_filling;
   datetime                   m_expiration;
   ENUM_ORDER_TYPE_TIME       m_type_time;

   //--- Validity flags
   bool                       m_symbol_valid;
   bool                       m_volume_valid;
   bool                       m_direction_valid;
   bool                       m_price_valid;
   bool                       m_stops_consistent;

   //--- Diagnostic
   string                     m_error_message;

   //--- Internal helpers
   bool                       ValidateStops();
   bool                       AllFlagsValid() const;
   void                       BuildRequest(MqlTradeRequest &req) const;

public:
                              COrderBuilder();
                             ~COrderBuilder() {}

   //--- Identity methods (return pointer to self for chaining)
   COrderBuilder             *Symbol(const string &symbol);
   COrderBuilder             *Volume(double volume);
   COrderBuilder             *Magic(ulong magic);
   COrderBuilder             *Comment(const string &comment);
   COrderBuilder             *Deviation(ulong deviation);
   COrderBuilder             *Filling(ENUM_ORDER_TYPE_FILLING filling);

   //--- Direction methods — market
   COrderBuilder             *Buy();
   COrderBuilder             *Sell();

   //--- Direction methods — pending
   COrderBuilder             *BuyLimit(double price);
   COrderBuilder             *SellLimit(double price);
   COrderBuilder             *BuyStop(double price);
   COrderBuilder             *SellStop(double price);
   COrderBuilder             *BuyStopLimit(double stop_price, double limit_price);
   COrderBuilder             *SellStopLimit(double stop_price, double limit_price);

   //--- Price methods
   COrderBuilder             *AtMarket();
   COrderBuilder             *AtPrice(double price);

   //--- Stop level methods
   COrderBuilder             *StopLoss(double sl);
   COrderBuilder             *TakeProfit(double tp);

   //--- Expiry method (pending orders only)
   COrderBuilder             *Expiry(datetime expiration);

   //--- Terminal methods (do not return pointer; chain ends here)
   bool                       Send(MqlTradeResult &result);
   void                       Reset();

   //--- Diagnostics
   bool                       IsValid()      const { return(AllFlagsValid()); }
   string                     ErrorMessage() const { return(m_error_message); }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
COrderBuilder::COrderBuilder()
  {
   Reset();
  }

//+------------------------------------------------------------------+
//| Reset internal states to default settings                        |
//+------------------------------------------------------------------+
void COrderBuilder::Reset()
  {
   m_symbol           = "";
   m_volume           = 0.0;
   m_magic            = 0;
   m_comment          = "";
   m_action           = TRADE_ACTION_DEAL;
   m_order_type       = ORDER_TYPE_BUY;
   m_price            = 0.0;
   m_stoplimit_price  = 0.0;
   m_sl               = 0.0;
   m_tp               = 0.0;
   m_deviation        = 10;
   m_filling          = ORDER_FILLING_IOC;
   m_expiration       = 0;
   m_type_time        = ORDER_TIME_GTC;
   m_symbol_valid     = false;
   m_volume_valid     = false;
   m_direction_valid  = false;
   m_price_valid      = false;
   m_stops_consistent = true;
   m_error_message    = "";
  }

//+------------------------------------------------------------------+
//| Set symbol and verify it is selected in Market Watch             |
//+------------------------------------------------------------------+
COrderBuilder *COrderBuilder::Symbol(const string &symbol)
  {
   m_symbol_valid = false;

   if(StringLen(symbol) == 0)
     {
      m_error_message = "Symbol(): empty symbol string provided.";
      return(&this);
     }

   //--- Ensure the symbol is active and visible in the platform terminal
   if(!SymbolSelect(symbol, true))
     {
      m_error_message = "Symbol(): '" + symbol + "' could not be selected in Market Watch.";
      return(&this);
     }

   m_symbol       = symbol;
   m_symbol_valid = true;
   return(&this);
     }

//+------------------------------------------------------------------+
//| Set trade lot volume and validate against broker limits           |
//+------------------------------------------------------------------+
COrderBuilder *COrderBuilder::Volume(double volume)
  {
   m_volume_valid = false;

   if(!m_symbol_valid)
     {
      m_error_message = "Volume(): symbol must be set and valid before specifying volume.";
      return(&this);
     }

   //--- Fetch broker contract specifications for volumes
   double min_lot  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
   double max_lot  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);

   if(volume <= 0.0 || volume < min_lot || volume > max_lot)
     {
      m_error_message = "Volume(): " + DoubleToString(volume, 4) +
                        " out of valid range [" + DoubleToString(min_lot, 4) +
                        ", " + DoubleToString(max_lot, 4) + "] for " + m_symbol + ".";
      return(&this);
     }

   //--- Quantize volume to match the broker's minimum allowable step size
   m_volume       = MathRound(volume / lot_step) * lot_step;
   m_volume_valid = true;
   return(&this);
  }

//+------------------------------------------------------------------+
//| Magic                                                            |
//+------------------------------------------------------------------+
COrderBuilder *COrderBuilder::Magic(ulong magic)
  {
   m_magic = magic;
   return(&this);
  }

//+------------------------------------------------------------------+
//| Comment                                                          |
//+------------------------------------------------------------------+
COrderBuilder *COrderBuilder::Comment(const string &comment)
  {
   m_comment = comment;
   return(&this);
  }

//+------------------------------------------------------------------+
//| Deviation                                                        |
//+------------------------------------------------------------------+
COrderBuilder *COrderBuilder::Deviation(ulong deviation)
  {
   m_deviation = deviation;
   return(&this);
  }

//+------------------------------------------------------------------+
//| Filling                                                          |
//+------------------------------------------------------------------+
COrderBuilder *COrderBuilder::Filling(ENUM_ORDER_TYPE_FILLING filling)
  {
   m_filling = filling;
   return(&this);
  }

//+------------------------------------------------------------------+
//| Set trade direction to instant Buy                              |
//+------------------------------------------------------------------+
COrderBuilder *COrderBuilder::Buy()
  {
   m_direction_valid = false;

   if(!m_symbol_valid)
     {
      m_error_message = "Buy(): symbol must be valid before setting direction.";
      return(&this);
     }

   m_action          = TRADE_ACTION_DEAL;
   m_order_type      = ORDER_TYPE_BUY;
   m_direction_valid = true;
   ValidateStops();
   return(&this);
  }

//+------------------------------------------------------------------+
//| Set trade direction to instant Sell                             |
//+------------------------------------------------------------------+
COrderBuilder *COrderBuilder::Sell()
  {
   m_direction_valid = false;

   if(!m_symbol_valid)
     {
      m_error_message = "Sell(): symbol must be valid before setting direction.";
      return(&this);
     }

   m_action          = TRADE_ACTION_DEAL;
   m_order_type      = ORDER_TYPE_SELL;
   m_direction_valid = true;
   ValidateStops();
   return(&this);
  }

//+------------------------------------------------------------------+
//| Set Buy Limit pending order with price validation                |
//+------------------------------------------------------------------+
COrderBuilder *COrderBuilder::BuyLimit(double price)
  {
   m_direction_valid = false;
   m_price_valid     = false;

   if(!m_symbol_valid)
     {
      m_error_message = "BuyLimit(): symbol must be valid before setting direction.";
      return(&this);
     }

   //--- Buy Limit price must be entry-restricted below market Ask
   double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   if(price <= 0.0 || price >= ask)
     {
      m_error_message = "BuyLimit(): price " + DoubleToString(price, 5) +
                        " must be below current ask " + DoubleToString(ask, 5) + ".";
      return(&this);
     }

   m_action          = TRADE_ACTION_PENDING;
   m_order_type      = ORDER_TYPE_BUY_LIMIT;
   m_price           = price;
   m_type_time       = ORDER_TIME_GTC;
   m_direction_valid = true;
   m_price_valid     = true;
   ValidateStops();
   return(&this);
  }

//+------------------------------------------------------------------+
//| Set Sell Limit pending order with price validation               |
//+------------------------------------------------------------------+
COrderBuilder *COrderBuilder::SellLimit(double price)
  {
   m_direction_valid = false;
   m_price_valid     = false;

   if(!m_symbol_valid)
     {
      m_error_message = "SellLimit(): symbol must be valid before setting direction.";
      return(&this);
     }

   //--- Sell Limit price must be entry-restricted above market Bid
   double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   if(price <= 0.0 || price <= bid)
     {
      m_error_message = "SellLimit(): price " + DoubleToString(price, 5) +
                        " must be above current bid " + DoubleToString(bid, 5) + ".";
      return(&this);
     }

   m_action          = TRADE_ACTION_PENDING;
   m_order_type      = ORDER_TYPE_SELL_LIMIT;
   m_price           = price;
   m_type_time       = ORDER_TIME_GTC;
   m_direction_valid = true;
   m_price_valid     = true;
   ValidateStops();
   return(&this);
  }

//+------------------------------------------------------------------+
//| Set Buy Stop pending order with price validation                 |
//+------------------------------------------------------------------+
COrderBuilder *COrderBuilder::BuyStop(double price)
  {
   m_direction_valid = false;
   m_price_valid     = false;

   if(!m_symbol_valid)
     {
      m_error_message = "BuyStop(): symbol must be valid before setting direction.";
      return(&this);
     }

   //--- Buy Stop price must be entry-restricted above market Ask
   double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   if(price <= 0.0 || price <= ask)
     {
      m_error_message = "BuyStop(): price " + DoubleToString(price, 5) +
                        " must be above current ask " + DoubleToString(ask, 5) + ".";
      return(&this);
     }

   m_action          = TRADE_ACTION_PENDING;
   m_order_type      = ORDER_TYPE_BUY_STOP;
   m_price           = price;
   m_type_time       = ORDER_TIME_GTC;
   m_direction_valid = true;
   m_price_valid     = true;
   ValidateStops();
   return(&this);
  }

//+------------------------------------------------------------------+
//| Set Sell Stop pending order with price validation                |
//+------------------------------------------------------------------+
COrderBuilder *COrderBuilder::SellStop(double price)
  {
   m_direction_valid = false;
   m_price_valid     = false;

   if(!m_symbol_valid)
     {
      m_error_message = "SellStop(): symbol must be valid before setting direction.";
      return(&this);
     }

   //--- Sell Stop price must be entry-restricted below market Bid
   double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   if(price <= 0.0 || price >= bid)
     {
      m_error_message = "SellStop(): price " + DoubleToString(price, 5) +
                        " must be below current bid " + DoubleToString(bid, 5) + ".";
      return(&this);
     }

   m_action          = TRADE_ACTION_PENDING;
   m_order_type      = ORDER_TYPE_SELL_STOP;
   m_price           = price;
   m_type_time       = ORDER_TIME_GTC;
   m_direction_valid = true;
   m_price_valid     = true;
   ValidateStops();
   return(&this);
  }

//+------------------------------------------------------------------+
//| Set Buy Stop Limit pending order with boundary checks            |
//+------------------------------------------------------------------+
COrderBuilder *COrderBuilder::BuyStopLimit(double stop_price, double limit_price)
  {
   m_direction_valid = false;
   m_price_valid     = false;

   if(!m_symbol_valid)
     {
      m_error_message = "BuyStopLimit(): symbol must be valid before setting direction.";
      return(&this);
     }

   double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   if(stop_price <= ask)
     {
      m_error_message = "BuyStopLimit(): stop price " + DoubleToString(stop_price, 5) +
                        " must be above current ask " + DoubleToString(ask, 5) + ".";
      return(&this);
     }

   if(limit_price >= stop_price)
     {
      m_error_message = "BuyStopLimit(): limit price " + DoubleToString(limit_price, 5) +
                        " must be below stop price " + DoubleToString(stop_price, 5) + ".";
      return(&this);
     }

   m_action          = TRADE_ACTION_PENDING;
   m_order_type      = ORDER_TYPE_BUY_STOP_LIMIT;
   m_price           = stop_price;
   m_stoplimit_price = limit_price;
   m_type_time       = ORDER_TIME_GTC;
   m_direction_valid = true;
   m_price_valid     = true;
   ValidateStops();
   return(&this);
  }

//+------------------------------------------------------------------+
//| Set Sell Stop Limit pending order with boundary checks           |
//+------------------------------------------------------------------+
COrderBuilder *COrderBuilder::SellStopLimit(double stop_price, double limit_price)
  {
   m_direction_valid = false;
   m_price_valid     = false;

   if(!m_symbol_valid)
     {
      m_error_message = "SellStopLimit(): symbol must be valid before setting direction.";
      return(&this);
     }

   double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   if(stop_price >= bid)
     {
      m_error_message = "SellStopLimit(): stop price " + DoubleToString(stop_price, 5) +
                        " must be below current bid " + DoubleToString(bid, 5) + ".";
      return(&this);
     }

   if(limit_price <= stop_price)
     {
      m_error_message = "SellStopLimit(): limit price " + DoubleToString(limit_price, 5) +
                        " must be above stop price " + DoubleToString(stop_price, 5) + ".";
      return(&this);
     }

   m_action          = TRADE_ACTION_PENDING;
   m_order_type      = ORDER_TYPE_SELL_STOP_LIMIT;
   m_price           = stop_price;
   m_stoplimit_price = limit_price;
   m_type_time       = ORDER_TIME_GTC;
   m_direction_valid = true;
   m_price_valid     = true;
   ValidateStops();
   return(&this);
  }

//+------------------------------------------------------------------+
//| Automatically fetch and assign the current market execution price|
//+------------------------------------------------------------------+
COrderBuilder *COrderBuilder::AtMarket()
  {
   m_price_valid = false;

   if(!m_direction_valid)
     {
      m_error_message = "AtMarket(): direction must be set before calling AtMarket().";
      return(&this);
     }

   if(!m_symbol_valid)
     {
      m_error_message = "AtMarket(): symbol must be valid.";
      return(&this);
     }

   //--- Map live execution quote type depending on direction
   bool is_buy = (m_order_type == ORDER_TYPE_BUY);
   m_price     = is_buy
                 ? SymbolInfoDouble(m_symbol, SYMBOL_ASK)
                 : SymbolInfoDouble(m_symbol, SYMBOL_BID);

   if(m_price <= 0.0)
     {
      m_error_message = "AtMarket(): could not retrieve valid market price for " + m_symbol + ".";
      return(&this);
     }

   m_price_valid = true;
   ValidateStops();
   return(&this);
  }

//+------------------------------------------------------------------+
//| Set custom explicit target execution price                       |
//+------------------------------------------------------------------+
COrderBuilder *COrderBuilder::AtPrice(double price)
  {
   m_price_valid = false;

   if(price <= 0.0)
     {
      m_error_message = "AtPrice(): price " + DoubleToString(price, 5) + " must be positive.";
      return(&this);
     }

   m_price       = price;
   m_price_valid = true;
   ValidateStops();
   return(&this);
  }

//+------------------------------------------------------------------+
//| StopLoss                                                         |
//+------------------------------------------------------------------+
COrderBuilder *COrderBuilder::StopLoss(double sl)
  {
   m_sl = sl;
   ValidateStops();
   return(&this);
  }

//+------------------------------------------------------------------+
//| TakeProfit                                                       |
//+------------------------------------------------------------------+
COrderBuilder *COrderBuilder::TakeProfit(double tp)
  {
   m_tp = tp;
   ValidateStops();
   return(&this);
  }

//+------------------------------------------------------------------+
//| Expiry                                                           |
//+------------------------------------------------------------------+
COrderBuilder *COrderBuilder::Expiry(datetime expiration)
  {
   if(expiration <= TimeCurrent())
     {
      m_error_message = "Expiry(): expiration timestamp must be in the future.";
      return(&this);
     }

   m_expiration = expiration;
   m_type_time  = ORDER_TIME_SPECIFIED;
   return(&this);
  }

//+------------------------------------------------------------------+
//| Internal logic checking alignment of SL/TP against broker limitations|
//+------------------------------------------------------------------+
bool COrderBuilder::ValidateStops()
  {
   m_stops_consistent = true;

   if(!m_direction_valid || !m_symbol_valid)
      return(true);

   //--- Extract broker minimum point distance requirement
   double point        = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   long   stops_level  = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double min_distance = stops_level * point;

   //--- Use current market rate as a validation anchor if explicit price is omitted
   double entry = m_price;
   if(entry <= 0.0)
     {
      bool is_buy_dir = (m_order_type == ORDER_TYPE_BUY          ||
                         m_order_type == ORDER_TYPE_BUY_LIMIT     ||
                         m_order_type == ORDER_TYPE_BUY_STOP      ||
                         m_order_type == ORDER_TYPE_BUY_STOP_LIMIT);
      entry = is_buy_dir
              ? SymbolInfoDouble(m_symbol, SYMBOL_ASK)
              : SymbolInfoDouble(m_symbol, SYMBOL_BID);
     }

   bool is_buy = (m_order_type == ORDER_TYPE_BUY          ||
                  m_order_type == ORDER_TYPE_BUY_LIMIT     ||
                  m_order_type == ORDER_TYPE_BUY_STOP      ||
                  m_order_type == ORDER_TYPE_BUY_STOP_LIMIT);

   //--- Validate Stop Loss orientations and broker-required distance gaps
   if(m_sl > 0.0)
     {
      if(is_buy && m_sl >= entry)
        {
         m_error_message    = "StopLoss " + DoubleToString(m_sl, 5) +
                              " must be below buy entry " + DoubleToString(entry, 5) + ".";
         m_stops_consistent = false;
         return(false);
        }
      if(!is_buy && m_sl <= entry)
        {
         m_error_message    = "StopLoss " + DoubleToString(m_sl, 5) +
                              " must be above sell entry " + DoubleToString(entry, 5) + ".";
         m_stops_consistent = false;
         return(false);
        }
      if(min_distance > 0.0 && MathAbs(entry - m_sl) < min_distance)
        {
         m_error_message    = "StopLoss distance " +
                              DoubleToString(MathAbs(entry - m_sl) / point, 1) +
                              " points is below broker minimum " +
                              IntegerToString(stops_level) + " points.";
         m_stops_consistent = false;
         return(false);
        }
     }

   //--- Validate Take Profit orientations and broker-required distance gaps
   if(m_tp > 0.0)
     {
      if(is_buy && m_tp <= entry)
        {
         m_error_message    = "TakeProfit " + DoubleToString(m_tp, 5) +
                              " must be above buy entry " + DoubleToString(entry, 5) + ".";
         m_stops_consistent = false;
         return(false);
        }
      if(!is_buy && m_tp >= entry)
        {
         m_error_message    = "TakeProfit " + DoubleToString(m_tp, 5) +
                              " must be below sell entry " + DoubleToString(entry, 5) + ".";
         m_stops_consistent = false;
         return(false);
        }
      if(min_distance > 0.0 && MathAbs(entry - m_tp) < min_distance)
        {
         m_error_message    = "TakeProfit distance " +
                              DoubleToString(MathAbs(entry - m_tp) / point, 1) +
                              " points is below broker minimum " +
                              IntegerToString(stops_level) + " points.";
         m_stops_consistent = false;
         return(false);
        }
     }

   m_stops_consistent = true;
   return(true);
  }

//+------------------------------------------------------------------+
//| Verify that all internal pipeline parameter gates are valid     |
//+------------------------------------------------------------------+
bool COrderBuilder::AllFlagsValid() const
  {
   return(m_symbol_valid    &&
          m_volume_valid    &&
          m_direction_valid &&
          m_price_valid     &&
          m_stops_consistent);
  }

//+------------------------------------------------------------------+
//| BuildRequest (internal)                                          |
//+------------------------------------------------------------------+
void COrderBuilder::BuildRequest(MqlTradeRequest &req) const
  {
   req.action       = m_action;
   req.symbol       = m_symbol;
   req.volume       = m_volume;
   req.type         = m_order_type;
   req.deviation    = m_deviation;
   req.magic        = m_magic;
   req.comment      = m_comment;
   req.type_filling = m_filling;
   req.type_time    = m_type_time;
   req.expiration   = m_expiration;
   req.sl           = m_sl;
   req.tp           = m_tp;
   req.stoplimit    = m_stoplimit_price;

   //--- Market orders submit with price = 0; terminal resolves at best bid/ask.
   //--- Pending orders require the explicit price set during direction method calls.
   req.price = (m_action == TRADE_ACTION_DEAL) ? 0.0 : m_price;
  }

//+------------------------------------------------------------------+
//| Send                                                             |
//+------------------------------------------------------------------+
bool COrderBuilder::Send(MqlTradeResult &result)
  {
   ZeroMemory(result);

   //--- Stage 1: Flag completeness check
   if(!AllFlagsValid())
     {
      if(StringLen(m_error_message) == 0)
         m_error_message = "Send(): one or more required builder fields are missing or invalid.";
      return(false);
     }

   //--- Stage 2: Final cross-field consistency pass
   if(!ValidateStops())
      return(false);

   //--- Stage 3: Broker pre-flight via OrderCheck()
   //--- OrderCheck() requires MqlTradeCheckResult, which is separate from MqlTradeResult.
   //--- The check result retcode is copied into the caller's MqlTradeResult for uniform
   //--- error reporting before returning false on failure.
   MqlTradeRequest    request      = {};
   MqlTradeCheckResult check_result = {};
   BuildRequest(request);

   if(!OrderCheck(request, check_result))
     {
      result.retcode  = check_result.retcode;
      m_error_message = "Send(): OrderCheck() failed. Retcode: " +
                        IntegerToString(check_result.retcode) + ".";
      return(false);
     }

   //--- Stage 4: Server dispatch
   if(!OrderSend(request, result))
     {
      m_error_message = "Send(): OrderSend() failed. Retcode: " +
                        IntegerToString(result.retcode) + " - " + result.comment;
      return(false);
     }

   return(true);
  }

#endif // ORDERBUILDER_MQH
//+------------------------------------------------------------------+