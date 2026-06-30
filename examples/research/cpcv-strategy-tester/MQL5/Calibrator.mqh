//+------------------------------------------------------------------+
//| Calibrator.mqh                                                   |
//| Patrick M. Njoroge / Blueprint Quant                             |
//| https://www.mql5.com/en/users/patrickmnjoroge                    |
//|                                                                  |
//| Applies the probability calibrator exported by the Python        |
//| pipeline: either isotonic regression (piecewise constant lookup  |
//| via binary search) or Platt scaling (two-parameter sigmoid).     |
//|                                                                  |
//| Part of: MetaTrader 5 Machine Learning Blueprint (Part 17)       |
//+------------------------------------------------------------------+
#property strict

#ifndef CALIBRATOR_MQH
#define CALIBRATOR_MQH

//---- Method identifiers
#define CAL_METHOD_ISOTONIC  0
#define CAL_METHOD_PLATT     1

//---- Module-level state (populated by LoadCalibrator)
static int    g_cal_method   = CAL_METHOD_ISOTONIC;
static double g_cal_x[];      // isotonic x-breakpoints
static double g_cal_y[];      // isotonic y-breakpoints
static double g_platt_A = 1.0;
static double g_platt_B = 0.0;

//+------------------------------------------------------------------+
//| LoadCalibrator: read calibrator_meta.json and calibrator.csv.    |
//|                                                                  |
//| Returns true if loading succeeded.                               |
//+------------------------------------------------------------------+
bool LoadCalibrator(const string base_dir)
  {
//--- Read calibrator_meta.json
   string meta_path = base_dir + "\\calibrator_meta.json";
   int fh = FileOpen(meta_path, FILE_READ | FILE_TXT | FILE_COMMON);
   if(fh == INVALID_HANDLE)
     {
      PrintFormat("LoadCalibrator: cannot open %s, error=%d",
                  meta_path, GetLastError());
      return(false);
     }
   string meta_json = "";
   while(!FileIsEnding(fh))
      meta_json += FileReadString(fh);
   FileClose(fh);

//--- Detect method from JSON content
   if(StringFind(meta_json, "\"isotonic\"") >= 0)
      g_cal_method = CAL_METHOD_ISOTONIC;
   else
      if(StringFind(meta_json, "\"platt\"") >= 0)
         g_cal_method = CAL_METHOD_PLATT;
      else
        {
         Print("LoadCalibrator: unknown method in calibrator_meta.json");
         return(false);
        }

   if(g_cal_method == CAL_METHOD_PLATT)
     {
      //--- Extract A and B from JSON: {"method":"platt","A":<val>,"B":<val>}
      int a_pos = StringFind(meta_json, "\"A\":");
      int b_pos = StringFind(meta_json, "\"B\":");
      if(a_pos < 0 || b_pos < 0)
        {
         Print("LoadCalibrator: Platt params not found in meta JSON");
         return(false);
        }
      g_platt_A = StringToDouble(StringSubstr(meta_json, a_pos + 4));
      g_platt_B = StringToDouble(StringSubstr(meta_json, b_pos + 4));
      PrintFormat("LoadCalibrator: Platt A=%.6f B=%.6f", g_platt_A, g_platt_B);
      return(true);
     }

//--- Isotonic: load breakpoint CSV
   string csv_path = base_dir + "\\calibrator.csv";
   int cfh = FileOpen(csv_path, FILE_READ | FILE_CSV | FILE_COMMON, ",");
   if(cfh == INVALID_HANDLE)
     {
      PrintFormat("LoadCalibrator: cannot open %s, error=%d",
                  csv_path, GetLastError());
      return(false);
     }

   FileReadString(cfh);  // skip header row ("x,y")

   int n = 0;
   if(ArrayResize(g_cal_x, 0) < 0 || ArrayResize(g_cal_y, 0) < 0)
     {
      Print("LoadCalibrator: ArrayResize init failed");
      FileClose(cfh);
      return(false);
     }

   while(!FileIsEnding(cfh))
     {
      double xv = StringToDouble(FileReadString(cfh));
      double yv = StringToDouble(FileReadString(cfh));
      if(ArrayResize(g_cal_x, n + 1) < 0 ||
         ArrayResize(g_cal_y, n + 1) < 0)
        {
         Print("LoadCalibrator: ArrayResize failed at row ", n);
         FileClose(cfh);
         return(false);
        }
      g_cal_x[n] = xv;
      g_cal_y[n] = yv;
      n++;
     }
   FileClose(cfh);

   PrintFormat("LoadCalibrator: isotonic, %d breakpoints loaded", n);
   return(n > 0);
  }

//+------------------------------------------------------------------+
//| ApplyCalibrator: map a raw model probability to a calibrated one.|
//|                                                                  |
//| For isotonic regression: piecewise constant binary search.       |
//| For Platt scaling: sigmoid(A * raw_prob + B).                    |
//|                                                                  |
//| scikit-learn's IsotonicRegression is piecewise constant, NOT     |
//| piecewise linear.  The calibrated value for raw_prob in the      |
//| interval [x[i], x[i+1]) is y[i] directly — no interpolation.     |
//+------------------------------------------------------------------+
double ApplyCalibrator(double raw_prob)
  {
   if(g_cal_method == CAL_METHOD_ISOTONIC)
     {
      int n = ArraySize(g_cal_x);
      if(n == 0)
         return(raw_prob);
      if(raw_prob <= g_cal_x[0])
         return(g_cal_y[0]);
      if(raw_prob >= g_cal_x[n - 1])
         return(g_cal_y[n - 1]);

      int lo = 0, hi = n - 1;
      while(hi - lo > 1)
        {
         int mid = (lo + hi) / 2;
         if(g_cal_x[mid] <= raw_prob)
            lo = mid;
         else
            hi = mid;
        }
      return(g_cal_y[lo]);  // piecewise constant: left-segment value
     }

//--- Platt scaling: sigmoid(A * x + B)
   return(1.0 / (1.0 + MathExp(-(g_platt_A * raw_prob + g_platt_B))));
  }

#endif // CALIBRATOR_MQH
