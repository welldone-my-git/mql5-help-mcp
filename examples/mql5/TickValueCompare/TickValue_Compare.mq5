//+------------------------------------------------------------------+
//|                                           TickValue_Compare.mq5  |
//|                           Diagnostic tool for tick-value props.  |
//+------------------------------------------------------------------+
#property copyright   "Public domain - MQL5 community"
#property version     "1.00"
#property description "Diagnostic tool: compares TICK_VALUE, TICK_VALUE_LOSS"
#property description "and TICK_VALUE_PROFIT properties for all symbols in"
#property description "Market Watch. Helps decide which property to use in"
#property description "risk-based lot sizing for EAs."
#property script_show_inputs

//--- Inputs
input group "=== Configuration ==="
input double InpToleranceAbs = 1e-7;   // Absolute tolerance for equality
input double InpToleranceRel = 1e-5;   // Relative tolerance (fraction of value)
input bool   InpVerboseLog   = false;  // Print each symbol (off = summary only)
input bool   InpSaveCSV      = false;  // Save full report to CSV in MQL5/Files
input string InpCSVPrefix    = "TickValueCompare"; // CSV filename prefix

//--- Category constants
#define CAT_ALL_EQUAL          0
#define CAT_TV_MATCHES_PROFIT  1
#define CAT_TV_MATCHES_LOSS    2
#define CAT_ALL_DIFFER         3
#define CAT_COUNT              4

const string CategoryName[CAT_COUNT] =
  {
   "ALL_EQUAL",
   "TV_MATCHES_PROFIT",
   "TV_MATCHES_LOSS",
   "ALL_DIFFER"
  };

//+------------------------------------------------------------------+
//| Tolerance helper                                                 |
//+------------------------------------------------------------------+
bool ApproxEqual(double a, double b)
  {
   const double absDiff = MathAbs(a - b);
   if(absDiff <= InpToleranceAbs)
      return true;
   const double maxAbs = MathMax(MathAbs(a), MathAbs(b));
   return (absDiff <= maxAbs * InpToleranceRel);
  }

//+------------------------------------------------------------------+
//| Classify a symbol into one of four categories                    |
//+------------------------------------------------------------------+
int Classify(double tv, double tvLoss, double tvProfit)
  {
   const bool lossEqProfit = ApproxEqual(tvLoss, tvProfit);
   const bool tvEqLoss     = ApproxEqual(tv, tvLoss);
   const bool tvEqProfit   = ApproxEqual(tv, tvProfit);

   if(lossEqProfit && tvEqLoss)
      return CAT_ALL_EQUAL;
   if(tvEqProfit && !tvEqLoss)
      return CAT_TV_MATCHES_PROFIT;
   if(tvEqLoss   && !tvEqProfit)
      return CAT_TV_MATCHES_LOSS;
   return CAT_ALL_DIFFER;
  }

//+------------------------------------------------------------------+
//| Per-symbol result                                                |
//+------------------------------------------------------------------+
struct SymbolResult
  {
   string            symbol;
   string            marginCcy;
   string            profitCcy;
   double            tv;
   double            tvLoss;
   double            tvProfit;
   int               category;
   bool              valid;
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
SymbolResult AnalyzeSymbol(const string symbol)
  {
   SymbolResult r;
   r.symbol = symbol;
   r.valid  = false;

   r.tv        = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   r.tvLoss    = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   r.tvProfit  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE_PROFIT);
   r.marginCcy = SymbolInfoString(symbol, SYMBOL_CURRENCY_MARGIN);
   r.profitCcy = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);

   if(r.tv <= 0 || r.tvLoss <= 0 || r.tvProfit <= 0)
      return r;

   r.category = Classify(r.tv, r.tvLoss, r.tvProfit);
   r.valid = true;
   return r;
  }

//+------------------------------------------------------------------+
//| CSV writing                                                      |
//+------------------------------------------------------------------+
int OpenCsv()
  {
   const string ts = TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES);
   string fn = InpCSVPrefix + "_" + AccountInfoString(ACCOUNT_COMPANY)
               + "_" + ts + ".csv";
   StringReplace(fn, " ", "_");
   StringReplace(fn, ":", "-");
   StringReplace(fn, "/", "-");

   const int h = FileOpen(fn, FILE_WRITE | FILE_ANSI | FILE_CSV, ';');
   if(h == INVALID_HANDLE)
     {
      PrintFormat("Could not create CSV (err=%d). Skipping file export.",
                  GetLastError());
      return INVALID_HANDLE;
     }
   PrintFormat("CSV report: MQL5/Files/%s", fn);

   FileWrite(h, "Symbol", "MarginCcy", "ProfitCcy",
             "TV", "LOSS", "PROFIT", "Category");
   return h;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void WriteCsvLine(int h, const SymbolResult &r)
  {
   if(h == INVALID_HANDLE)
      return;
   FileWrite(h, r.symbol, r.marginCcy, r.profitCcy,
             DoubleToString(r.tv, 8),
             DoubleToString(r.tvLoss, 8),
             DoubleToString(r.tvProfit, 8),
             CategoryName[r.category]);
  }

//+------------------------------------------------------------------+
//| OnStart                                                          |
//+------------------------------------------------------------------+
void OnStart()
  {
   const string accCcy     = AccountInfoString(ACCOUNT_CURRENCY);
   const long   accLogin   = AccountInfoInteger(ACCOUNT_LOGIN);
   const string accServer  = AccountInfoString(ACCOUNT_SERVER);
   const string accCompany = AccountInfoString(ACCOUNT_COMPANY);
   const int    build      = (int)TerminalInfoInteger(TERMINAL_BUILD);

   PrintFormat("============================================================");
   PrintFormat("  TickValue_Compare v1.00");
   PrintFormat("============================================================");
   PrintFormat("Terminal build  : %d", build);
   PrintFormat("Account         : #%I64d on %s (%s)",
               accLogin, accServer, accCompany);
   PrintFormat("Account currency: %s", accCcy);
   PrintFormat("Tolerance       : abs=%.0e | rel=%.0e",
               InpToleranceAbs, InpToleranceRel);
   PrintFormat("------------------------------------------------------------");

// Snapshot Market Watch BEFORE iterating (avoid surprises if MW changes)
   const int totalSymbols = SymbolsTotal(true);
   string symbolList[];
   ArrayResize(symbolList, totalSymbols);
   for(int i = 0; i < totalSymbols; i++)
      symbolList[i] = SymbolName(i, true);

   PrintFormat("Symbols in Market Watch: %d", totalSymbols);
   PrintFormat("------------------------------------------------------------");

   int catCount[CAT_COUNT] = {0,0,0,0};
   int skipped = 0;

   const int csv = (InpSaveCSV ? OpenCsv() : INVALID_HANDLE);

   for(int i = 0; i < totalSymbols; i++)
     {
      const string sym = symbolList[i];
      if(sym == "")
        {
         skipped++;
         continue;
        }

      const SymbolResult r = AnalyzeSymbol(sym);

      if(!r.valid)
        {
         if(InpVerboseLog)
            PrintFormat("  [SKIP] %s (invalid properties)", sym);
         skipped++;
         continue;
        }

      catCount[r.category]++;

      if(InpVerboseLog)
         PrintFormat("  [%-18s] %-15s (m=%s p=%s) | TV=%.8f"
                     " | LOSS=%.8f | PROFIT=%.8f",
                     CategoryName[r.category], r.symbol,
                     r.marginCcy, r.profitCcy,
                     r.tv, r.tvLoss, r.tvProfit);

      WriteCsvLine(csv, r);
     }

   if(csv != INVALID_HANDLE)
      FileClose(csv);

// ---------- Summary ----------
   PrintFormat("------------------------------------------------------------");
   PrintFormat("  SUMMARY");
   PrintFormat("------------------------------------------------------------");
   PrintFormat("Skipped : %d", skipped);
   PrintFormat("");
   PrintFormat("Property categories:");
   for(int c = 0; c < CAT_COUNT; c++)
      PrintFormat("  %-20s : %d", CategoryName[c], catCount[c]);

   PrintFormat("============================================================");

// ---------- Interpretation ----------
   PrintFormat("INTERPRETATION");
   PrintFormat("------------------------------------------------------------");

   if(catCount[CAT_ALL_EQUAL] == totalSymbols - skipped)
     {
      Print("All symbols treated TV, LOSS and PROFIT as identical.");
      Print("For this broker, any of the three properties is safe.");
     }
   else
      if(catCount[CAT_TV_MATCHES_PROFIT] > catCount[CAT_TV_MATCHES_LOSS])
        {
         Print("Predominant pattern: TV equals PROFIT (LOSS slightly higher).");
         Print("For risk-based lot sizing, prefer SYMBOL_TRADE_TICK_VALUE_LOSS");
         Print("because it gives a more conservative (larger) loss estimate.");
        }
      else
         if(catCount[CAT_TV_MATCHES_LOSS] > 0)
           {
            Print("Unusual pattern detected: TV equals LOSS for some symbols.");
            Print("This is uncommon. Verify your broker's tick-value reporting.");
           }
   PrintFormat("============================================================");
  }

//+------------------------------------------------------------------+
