//+------------------------------------------------------------------+
//|                                                    SwapTools.mqh |
//|           Swap-aware position management functions for MQL5.     |
//+------------------------------------------------------------------+

#property strict

//+-------------------------------------------------------------------+
//| BACKTESTING NOTE                                                  |
//| MetaTrader 5 applies current broker swap rates when running the   |
//| Strategy Tester, which can make historical carry tests unreliable.|
//| The function below is a simple illustrative stub that injects a   |
//| fixed synthetic swap value for AUDJPY long positions so you can   |
//| observe how carry-aware logic behaves under positive-yield        |
//| conditions. It is NOT a historical reconstruction of real broker  |
//| swap schedules — treat it as a controlled test harness only.      |
//+-------------------------------------------------------------------+
double MockSwapForTesting(string symbol, int direction)
  {
   if(symbol == "AUDJPY" && direction > 0)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);

      //--- Synthetic divergence: simulate post-2024 high-rate period
      return((dt.year >= 2024) ? 14.50 : 3.20);
     }

   return(0.0);
  }

//+------------------------------------------------------------------+
//| Returns estimated daily swap per lot in account currency.        |
//| Covers the most common retail broker swap modes.                 |
//| For SYMBOL_SWAP_MODE_CURRENCY_MARGIN (3) and                     |
//| SYMBOL_SWAP_MODE_REOPEN_CURRENT (7) the function returns 0.0     |
//+------------------------------------------------------------------+
double DailySwapInAccountCurrency(string symbol, int direction)
  {
   double swap_rate = 0.0;

//--- Read raw swap rate with validity check
   if(direction > 0)
     {
      if(!SymbolInfoDouble(symbol, SYMBOL_SWAP_LONG, swap_rate))
        {
         Print("DailySwapInAccountCurrency: failed to read SYMBOL_SWAP_LONG for ", symbol,
               " error=", GetLastError());
         return(0.0);
        }
     }
   else
     {
      if(!SymbolInfoDouble(symbol, SYMBOL_SWAP_SHORT, swap_rate))
        {
         Print("DailySwapInAccountCurrency: failed to read SYMBOL_SWAP_SHORT for ", symbol,
               " error=", GetLastError());
         return(0.0);
        }
     }

   long swap_mode_raw = 0;
   if(!SymbolInfoInteger(symbol, SYMBOL_SWAP_MODE, swap_mode_raw))
     {
      Print("DailySwapInAccountCurrency: failed to read SYMBOL_SWAP_MODE for ", symbol,
            " error=", GetLastError());
      return(0.0);
     }

   ENUM_SYMBOL_SWAP_MODE swap_mode = (ENUM_SYMBOL_SWAP_MODE)swap_mode_raw;

   double contract_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double point_size    = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tick_value    = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size     = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double bid           = SymbolInfoDouble(symbol, SYMBOL_BID);
   double daily_swap    = 0.0;

//--- Validate bid — may be zero if market is closed or symbol not in Market Watch
   if(bid <= 0.0 &&
      (swap_mode == SYMBOL_SWAP_MODE_INTEREST_CURRENT ||
       swap_mode == SYMBOL_SWAP_MODE_INTEREST_OPEN))
     {
      Print("DailySwapInAccountCurrency: bid price is 0 for ", symbol,
            " — result may be inaccurate.");
     }

   switch(swap_mode)
     {
      case SYMBOL_SWAP_MODE_DISABLED:
         daily_swap = 0.0;
         break;

      case SYMBOL_SWAP_MODE_POINTS:
         //--- swap_rate is in points per lot per day
         if(tick_size > 0.0)
            daily_swap = swap_rate * point_size * (tick_value / tick_size);
         break;

      case SYMBOL_SWAP_MODE_CURRENCY_SYMBOL:
         //--- swap_rate is in base currency per lot per day
         //--- Note: for non-account-currency pairs, multiply by the
         //--- base-to-account exchange rate before using in sizing logic.
         daily_swap = swap_rate;
         break;

      case SYMBOL_SWAP_MODE_INTEREST_CURRENT:
         //--- swap_rate is an annual percentage; bid used as price proxy
         if(bid > 0.0)
            daily_swap = (bid * contract_size * swap_rate) / 100.0 / 360.0; // MQL5 standard uses 360 days for interest calculation
         break;

      case SYMBOL_SWAP_MODE_CURRENCY_MARGIN:
         //--- swap_rate is denominated in the margin currency.
         Print("DailySwapInAccountCurrency: SYMBOL_SWAP_MODE_CURRENCY_MARGIN is not ",
               "implemented — returning 0.0 for ", symbol);
         daily_swap = 0.0;
         break;

      case SYMBOL_SWAP_MODE_CURRENCY_DEPOSIT:
         //--- swap_rate is already in the deposit (account) currency per lot
         daily_swap = swap_rate;
         break;

      case SYMBOL_SWAP_MODE_INTEREST_OPEN:
         //--- swap_rate is an annual percentage of the position open price.
         if(bid > 0.0)
            daily_swap = (bid * contract_size * swap_rate) / 100.0 / 360.0; // MQL5 standard uses 360 days for interest calculation
         else
            Print("DailySwapInAccountCurrency: bid is 0 for SYMBOL_SWAP_MODE_INTEREST_OPEN on ",
                  symbol, " — returning 0.0");
         break;

      case SYMBOL_SWAP_MODE_REOPEN_CURRENT:
         //--- Broker-specific implementation (re-opening positions by close price)
         Print("DailySwapInAccountCurrency: SYMBOL_SWAP_MODE_REOPEN_CURRENT is not ",
               "implemented — returning 0.0 for ", symbol);
         daily_swap = 0.0;
         break;

      case SYMBOL_SWAP_MODE_REOPEN_BID:
         //--- Broker-specific implementation (re-opening positions by bid price)
         Print("DailySwapInAccountCurrency: SYMBOL_SWAP_MODE_REOPEN_BID is not ",
               "implemented — returning 0.0 for ", symbol);
         daily_swap = 0.0;
         break;

      default:
         Print("DailySwapInAccountCurrency: unknown swap mode ", swap_mode,
               " for ", symbol, " — returning 0.0");
         daily_swap = 0.0;
         break;
     }

   return(daily_swap);
  }

//+------------------------------------------------------------------+
//| Returns total estimated swap over a holding window.              |
//| hold_days is a calendar approximation — it counts the number of  |
//| nights the position is expected to survive rollover, not exact   |
//| elapsed seconds. Triple swap is estimated by counting Wednesdays |
//| in the window; for non-FX instruments check SYMBOL_SWAP_SUNDAY   |
//| through SYMBOL_SWAP_SATURDAY for the actual multiplier day.      |
//+------------------------------------------------------------------+
double ExpectedSwapForPosition(string symbol, int direction,
                               double lots, int hold_days,
                               datetime start_time = 0)
  {
   if(start_time == 0)
      start_time = TimeCurrent();

   double daily_rate = DailySwapInAccountCurrency(symbol, direction);

//--- Count Wednesdays in the holding window as a triple-swap approximation.
//--- Each Wednesday rollover adds 2 extra swap days (3x total).
   int wed_count = 0;
   for(int d = 0; d < hold_days; d++)
     {
      MqlDateTime dt;
      TimeToStruct(start_time + (datetime)(d * 86400), dt);
      if(dt.day_of_week == 3) // Wednesday — adjust if broker uses different day
         wed_count++;
     }

//--- Total effective swap days: calendar days plus 2 extra for each Wednesday
   double total_days = (double)hold_days + (wed_count * 2.0);

   return(daily_rate * total_days * lots);
  }

//+------------------------------------------------------------------+
//| Evaluates if position drawdown is justified by carry income      |
//+------------------------------------------------------------------+
bool IsWorthHolding(ulong ticket, int max_hold_days, double coverage_pct = 40.0)
  {
   if(!PositionSelectByTicket(ticket))
      return(false);

   double   total_profit = PositionGetDouble(POSITION_PROFIT);
   double   accrued_swap = PositionGetDouble(POSITION_SWAP);
   double   lots         = PositionGetDouble(POSITION_VOLUME);
   string   sym          = PositionGetString(POSITION_SYMBOL);
   datetime open_t       = (datetime)PositionGetInteger(POSITION_TIME);
   int      pos_type     = (int)PositionGetInteger(POSITION_TYPE);
   int      direction    = (pos_type == POSITION_TYPE_BUY) ? 1 : -1;

//--- Isolate the price-driven P/L by removing already-accrued swap.
//--- POSITION_PROFIT includes swap credits, so using it directly would
//--- cause double-counting when we add future expected swap below.
   double price_pnl = total_profit - accrued_swap;

//--- If the trade is already profitable on price alone, keep it.
   if(price_pnl >= 0)
      return(true);

//--- days_held is a calendar approximation. Rollover count may differ
//--- by 1 depending on open time relative to the broker rollover cutoff.
   int days_held = (int)((TimeCurrent() - open_t) / 86400);
   int days_left = max_hold_days - days_held;

   if(days_left <= 0)
      return(false);

   double future_swap = ExpectedSwapForPosition(sym, direction, lots, days_left);

//--- Total carry = what has already been earned + what is still expected.
//--- This gives a complete picture of the position's carry contribution.
   double total_carry = future_swap + accrued_swap;

   if(total_carry <= 0)
      return(false);

   double coverage_req = MathAbs(price_pnl) * (coverage_pct / 100.0);
   return(total_carry >= coverage_req);
  }

//+------------------------------------------------------------------+
//| Returns a carry-adjusted lot size.                               |
//|                                                                  |
//| IMPORTANT: Increasing lot size to chase swap income also         |
//| increases stop-loss risk by the same proportion. Carry should    |
//| never be the primary reason to take on more risk than your       |
//| normal position sizing allows. Use this function to fine-tune    |
//| within your existing risk limits, not to override them.          |
//| The carry-adjusted lot is always capped at base_lots unless swap |
//| income meaningfully justifies a larger size under your model.    |
//+------------------------------------------------------------------+
double CarryAdjustedLotSize(string symbol, int direction,
                            double risk_money, int hold_days,
                            double target_pct  = 50.0,
                            double base_lots   = 0.1)
  {
   double daily_rate = DailySwapInAccountCurrency(symbol, direction);

//--- If swap is zero or negative, no carry adjustment is warranted.
   if(daily_rate <= 0)
      return(base_lots);

   double step    = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

//--- Count Wednesdays for accurate total-day estimate
   datetime now      = TimeCurrent();
   double total_days = (double)hold_days;
   for(int d = 0; d < hold_days; d++)
     {
      MqlDateTime dt;
      TimeToStruct(now + (datetime)(d * 86400), dt);
      if(dt.day_of_week == 3)
         total_days += 2.0;
     }

//--- Target carry is expressed as a percentage of the ORIGINAL risk_money.
//--- We solve for the lot size at which carry == target_pct% of risk_money.
//--- Per-lot carry over the window:
   double carry_per_lot = daily_rate * total_days;
   if(carry_per_lot <= 0)
      return(base_lots);

   double target_carry  = risk_money * (target_pct / 100.0);
   double required_lots = target_carry / carry_per_lot;

//--- NOTE: If required_lots > base_lots, verify that your risk model
//--- permits the larger position. The stop-loss monetary risk scales
//--- linearly with lot size. Always apply your normal risk cap first.
   if(step > 0)
      required_lots = MathFloor(required_lots / step) * step; // floor, not round

   if(required_lots < min_lot)
      required_lots = min_lot;
   if(required_lots > max_lot)
      required_lots = max_lot;

//--- Log for transparency
   PrintFormat("CarryAdjustedLotSize: %s dir=%d carry_per_lot=%.4f "
               "target=%.2f required=%.2f base=%.2f",
               symbol, direction, carry_per_lot, target_carry,
               required_lots, base_lots);

   return(required_lots);
  }
//+------------------------------------------------------------------+