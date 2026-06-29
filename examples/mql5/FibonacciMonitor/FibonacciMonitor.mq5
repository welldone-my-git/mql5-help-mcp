//+------------------------------------------------------------------+
//|                                             FibonacciMonitor.mq5 |
//|                                               Christian Benjamin |
//|                          https://www.mql5.com/en/users/lynnchris |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Christian Benjamin"
#property link      "https://www.mql5.com/en/users/lynnchris"
#property version   "1.0"
#property strict

//--- Input parameters
input bool   AlertPopup         = true;        // Show popup alert on events
input bool   AlertSound         = true;        // Play sound on events
input string SoundFile          = "alert.wav"; // Sound file name
input bool   PushNotifications  = true;        // Send push notification to mobile
input color  MonitorColor       = clrBlue;     // Colour for monitored lines
input int    LineWidth          = 2;           // Line thickness after syncing
input color  PendingColor       = clrGray;     // Colour for newly drawn Fibonacci
input double TouchTolerancePips = 0.5;         // Touch tolerance (pips)
input double ApproachZonePips   = 10.0;        // Approach zone (pips)
input int    PipMultiplier      = 1;           // Points per pip (10 for forex, 1 for indices/commodities)
input bool   NormalizeLevels    = false;       // true: 0% = lowest price, 100% = highest; false: follow drawing direction
input bool   InvertMapping      = true;        // true: first anchor = 100%, second anchor = 0% (only when NormalizeLevels=false)
input bool   ShowLabels         = true;        // Show labels on the chart

//--- Panel settings
input int    PanelX             = 10;
input int    PanelY             = 150;
input color  PanelBgColor       = clrWhite;
input color  PanelHeaderColor   = clrLightGray;
input color  PanelTextColor     = clrBlack;
input int    PanelPadding       = 4;

#define PREFIX      "FiboMonitor_"
#define PANEL_PREFIX "FiboMonitor_Panel_"
#define HEADER_HEIGHT 20

enum EMode { MODE_IDLE, MODE_DRAWING, MODE_SYNC_READY };
enum EAlertState { ALERT_NONE, ALERT_APPROACH_SENT, ALERT_TOUCH_SENT,
                   ALERT_BREAKOUT_SENT, ALERT_REVERSAL_SENT
                 };

struct SMonitoredLevel
  {
   string            name;               // Object name of the horizontal line
   double            levelPercentage;    // The Fibonacci retracement value (e.g., 0.382)
   string            levelLabel;         // The label text from the Fibonacci object (e.g., "38.2%" or custom)
   int               lastSide;           // 1 = below, -1 = above, 0 = unknown
   int               sideBeforeTouch;    // Side just before a touch occurred
   bool              alertedBreak;       // True if a breakout alert was already sent for this cross
   datetime          lastTouchBarTime;   // Time of the last bar checked for touches
   EAlertState       alertState;         // Current alert state for this level
  };

EMode          g_mode = MODE_IDLE;
string         g_pendingFibo = "";
SMonitoredLevel g_monitored[];

int            g_panelX, g_panelY;
string         g_panelBGName = "";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
   ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);

   CreateStyledButton("DrawBtn",     "Draw Fibo",         10, 20, 120, 35, clrGreen, false);
   CreateStyledButton("SynchBtn",    "Convert & Monitor", 10, 60, 140, 35, clrGray,  false);
   CreateStyledButton("ClearAllBtn", "Clear All Levels",  10,100, 140, 35, clrOrange, false);

   ObjectSetInteger(0, PREFIX+"SynchBtn",    OBJPROP_BGCOLOR, clrGray);
   ObjectSetInteger(0, PREFIX+"ClearAllBtn", OBJPROP_BGCOLOR, clrOrange);

   g_panelX = PanelX;
   g_panelY = PanelY;
   ChartRedraw();
   UpdatePanel();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectDelete(0, PREFIX+"DrawBtn");
   ObjectDelete(0, PREFIX+"SynchBtn");
   ObjectDelete(0, PREFIX+"ClearAllBtn");
   DeletePanelObjects();
  }

//+------------------------------------------------------------------+
//| Chart event handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id==CHARTEVENT_OBJECT_CLICK)
     {
      if(sparam==PREFIX+"DrawBtn")
        {
         if(g_mode==MODE_IDLE)
           {
            g_mode=MODE_DRAWING;
            ObjectSetInteger(0,PREFIX+"DrawBtn",OBJPROP_STATE,true);
            ObjectSetString(0,PREFIX+"DrawBtn",OBJPROP_TEXT,"Draw Fibo (Active)");
            ObjectSetInteger(0,PREFIX+"DrawBtn",OBJPROP_BGCOLOR, clrLightBlue);
            ObjectSetInteger(0,PREFIX+"SynchBtn",OBJPROP_BGCOLOR,clrGray);
            ObjectSetString(0,PREFIX+"SynchBtn",OBJPROP_TEXT,"Convert & Monitor");
           }
         else
            if(g_mode==MODE_DRAWING)
              {
               g_mode=MODE_IDLE;
               ObjectSetInteger(0,PREFIX+"DrawBtn",OBJPROP_STATE,false);
               ObjectSetString(0,PREFIX+"DrawBtn",OBJPROP_TEXT,"Draw Fibo");
               ObjectSetInteger(0,PREFIX+"DrawBtn",OBJPROP_BGCOLOR, clrGreen);
              }
         ChartRedraw();
        }
      else
         if(sparam==PREFIX+"SynchBtn")
           {
            if(g_mode==MODE_SYNC_READY && g_pendingFibo!="")
              {
               ProcessFibonacciObject(g_pendingFibo);
               ObjectDelete(0, g_pendingFibo);
               g_mode=MODE_IDLE;
               g_pendingFibo="";
               ObjectSetInteger(0,PREFIX+"DrawBtn",OBJPROP_BGCOLOR, clrGreen);
               ObjectSetInteger(0,PREFIX+"SynchBtn",OBJPROP_BGCOLOR,clrGray);
               ObjectSetString(0,PREFIX+"SynchBtn",OBJPROP_TEXT,"Convert & Monitor");
               ChartRedraw();
               UpdateClearAllButtonState();
               UpdatePanel();
              }
           }
         else
            if(sparam==PREFIX+"ClearAllBtn")
              {
               ClearAllMonitoredLines();
              }
     }
   else
      if(id==CHARTEVENT_OBJECT_CREATE)
        {
         if(g_mode==MODE_DRAWING)
           {
            ENUM_OBJECT objType = (ENUM_OBJECT)ObjectGetInteger(0, sparam, OBJPROP_TYPE);
            if(objType == OBJ_FIBO)
              {
               g_pendingFibo = sparam;
               g_mode = MODE_SYNC_READY;
               ObjectSetInteger(0, sparam, OBJPROP_COLOR, PendingColor);
               ObjectSetInteger(0, PREFIX+"SynchBtn", OBJPROP_BGCOLOR, clrOrange);
               ObjectSetString(0, PREFIX+"SynchBtn", OBJPROP_TEXT, "Convert Ready");
               ObjectSetInteger(0, PREFIX+"DrawBtn", OBJPROP_BGCOLOR, clrGreen);
               ObjectSetString(0, PREFIX+"DrawBtn", OBJPROP_TEXT, "Draw Fibo");
               ChartRedraw();
              }
           }
        }
      else
         if(id==CHARTEVENT_OBJECT_DELETE)
           {
            string objName=sparam;
            for(int i=0; i<ArraySize(g_monitored); i++)
              {
               if(g_monitored[i].name==objName)
                 {
                  string labelName = objName + "_label";
                  if(ObjectFind(0, labelName)>=0)
                     ObjectDelete(0, labelName);
                  for(int j=i; j<ArraySize(g_monitored)-1; j++)
                     g_monitored[j]=g_monitored[j+1];
                  ArrayResize(g_monitored,ArraySize(g_monitored)-1);
                  UpdateClearAllButtonState();
                  UpdatePanel();
                  break;
                 }
              }
            if(g_pendingFibo==objName)
              {
               g_pendingFibo="";
               g_mode=MODE_IDLE;
               ObjectSetInteger(0,PREFIX+"SynchBtn",OBJPROP_BGCOLOR,clrGray);
               ObjectSetString(0,PREFIX+"SynchBtn",OBJPROP_TEXT,"Convert & Monitor");
               ChartRedraw();
              }
           }
         else
            if(id==CHARTEVENT_OBJECT_DRAG)
              {
               if(sparam==g_panelBGName)
                 {
                  long newX=ObjectGetInteger(0,g_panelBGName,OBJPROP_XDISTANCE);
                  long newY=ObjectGetInteger(0,g_panelBGName,OBJPROP_YDISTANCE);
                  int deltaX=(int)newX-g_panelX;
                  int deltaY=(int)newY-g_panelY;
                  if(deltaX!=0 || deltaY!=0)
                    {
                     for(int i=ObjectsTotal(0)-1; i>=0; i--)
                       {
                        string objName=ObjectName(0,i);
                        if(StringFind(objName,PANEL_PREFIX)==0)
                          {
                           long objX=ObjectGetInteger(0,objName,OBJPROP_XDISTANCE);
                           long objY=ObjectGetInteger(0,objName,OBJPROP_YDISTANCE);
                           ObjectSetInteger(0,objName,OBJPROP_XDISTANCE,objX+deltaX);
                           ObjectSetInteger(0,objName,OBJPROP_YDISTANCE,objY+deltaY);
                          }
                       }
                     g_panelX=(int)newX;
                     g_panelY=(int)newY;
                     ChartRedraw();
                    }
                 }
              }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   CheckPriceInteractions();
  }

//+------------------------------------------------------------------+
//| Check price interactions with clear logic                         |
//+------------------------------------------------------------------+
void CheckPriceInteractions()
  {
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double touchTol = TouchTolerancePips * PipMultiplier * point;
   double approachTol = ApproachZonePips * PipMultiplier * point;

   bool needPanelUpdate = false;

   for(int i = 0; i < ArraySize(g_monitored); i++)
     {
      string name = g_monitored[i].name;
      if(ObjectFind(0, name) < 0)
        {
         Print("ERROR: Level object missing: ", name);
         continue;
        }

      // Get level price (horizontal line – both points same price)
      double levelPrice = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
      if(levelPrice == 0)
         continue;

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double distance = MathAbs(bid - levelPrice);
      double distancePips = distance / (PipMultiplier * point);
      string displayLabel = g_monitored[i].levelLabel;

      // Determine current side: 1 = below level, -1 = above level, 0 = exactly on
      int currentSide = 0;
      if(bid < levelPrice)
         currentSide = 1;
      else
         if(bid > levelPrice)
            currentSide = -1;

      // Debug: print if distance is small
      if(distancePips < 50)
        {
         PrintFormat("Monitor: %s (%s) | Price: %G | Bid: %G | Dist: %.2f pips | Side: %d | LastSide: %d | State: %d",
                     name, displayLabel, levelPrice, bid, distancePips,
                     currentSide, g_monitored[i].lastSide, g_monitored[i].alertState);
        }

      EAlertState oldState = g_monitored[i].alertState;

      // 1. Approach detection
      if(distance <= approachTol && g_monitored[i].alertState < ALERT_APPROACH_SENT)
        {
         SendAllAlerts("Approaching Fibonacci level " + displayLabel, levelPrice);
         g_monitored[i].alertState = ALERT_APPROACH_SENT;
        }

      // 2. Touch detection (new bar)
      datetime currBarTime = iTime(NULL, 0, 0);
      if(g_monitored[i].lastTouchBarTime < currBarTime)
        {
         double barHigh = iHigh(NULL, 0, 0);
         double barLow = iLow(NULL, 0, 0);
         // Check if level price is inside bar range (with tolerance)
         if(levelPrice >= barLow - touchTol && levelPrice <= barHigh + touchTol)
           {
            if(g_monitored[i].alertState < ALERT_TOUCH_SENT)
              {
               // Store side before touch for potential reversal
               g_monitored[i].sideBeforeTouch = g_monitored[i].lastSide;
               SendAllAlerts("Touch on Fibonacci level " + displayLabel, levelPrice);
               g_monitored[i].alertState = ALERT_TOUCH_SENT;
               // Reset breakout flag so a new breakout can be detected after touch
               g_monitored[i].alertedBreak = false;
              }
           }
         g_monitored[i].lastTouchBarTime = currBarTime;
        }

      // 3. Breakout detection
      int lastSide = g_monitored[i].lastSide;
      if(lastSide != 0 && currentSide != 0 && currentSide != lastSide)
        {
         if(!g_monitored[i].alertedBreak)
           {
            SendAllAlerts("Breakout on Fibonacci level " + displayLabel, levelPrice);
            g_monitored[i].alertedBreak = true;
            g_monitored[i].alertState = ALERT_BREAKOUT_SENT;
           }
        }

      // 4. Reversal detection
      if(g_monitored[i].alertState == ALERT_TOUCH_SENT &&
         g_monitored[i].sideBeforeTouch != 0 &&
         currentSide == g_monitored[i].sideBeforeTouch &&
         !g_monitored[i].alertedBreak)
        {
         SendAllAlerts("Reversal on Fibonacci level " + displayLabel, levelPrice);
         g_monitored[i].alertState = ALERT_REVERSAL_SENT;
        }

      // Reset alert state when price moves away from level (outside approach zone)
      if(distance > approachTol &&
         g_monitored[i].alertState != ALERT_TOUCH_SENT &&
         g_monitored[i].alertState != ALERT_NONE)
        {
         g_monitored[i].alertState = ALERT_NONE;
         g_monitored[i].alertedBreak = false;
         g_monitored[i].sideBeforeTouch = 0;
        }

      // Store current side for next tick
      g_monitored[i].lastSide = currentSide;

      // If state changed, mark for panel update
      if(oldState != g_monitored[i].alertState)
         needPanelUpdate = true;
     }

// Update the panel if any level's state changed
   if(needPanelUpdate)
      UpdatePanel();
  }

//+------------------------------------------------------------------+
//| Send all alert types (popup, sound, push)                        |
//+------------------------------------------------------------------+
void SendAllAlerts(string msg, double price)
  {
   string fullMsg = StringFormat("%s at %G", msg, price);
   if(AlertPopup)
      Alert(fullMsg);
   if(AlertSound)
      PlaySound(SoundFile);
   if(PushNotifications)
      SendNotification(fullMsg);
   Print(fullMsg);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void AddMonitoredLevel(string lineName, double levelPercentage, string levelLabel)
  {
   int sz = ArraySize(g_monitored);
   ArrayResize(g_monitored, sz+1);
   g_monitored[sz].name = lineName;
   g_monitored[sz].levelPercentage = levelPercentage;
   g_monitored[sz].levelLabel = levelLabel;
   g_monitored[sz].lastSide = 0;
   g_monitored[sz].sideBeforeTouch = 0;
   g_monitored[sz].alertedBreak = false;
   g_monitored[sz].lastTouchBarTime = 0;
   g_monitored[sz].alertState = ALERT_NONE;
   Print("Added monitored level: ", lineName, " (", levelLabel, ")");
   UpdatePanel(); // immediately show the new level
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ClearAllMonitoredLines()
  {
   for(int i = ArraySize(g_monitored)-1; i >= 0; i--)
     {
      string name = g_monitored[i].name;
      if(ObjectFind(0, name) >= 0)
        {
         ObjectDelete(0, name);
         string labelName = name + "_label";
         if(ObjectFind(0, labelName) >= 0)
            ObjectDelete(0, labelName);
        }
     }
   ArrayResize(g_monitored, 0);
   UpdateClearAllButtonState();
   UpdatePanel();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateClearAllButtonState()
  {
   bool hasLevels = (ArraySize(g_monitored) > 0);
   color bgColor = hasLevels ? clrOrange : clrGray;
   ObjectSetInteger(0, PREFIX+"ClearAllBtn", OBJPROP_BGCOLOR, bgColor);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeletePanelObjects()
  {
   for(int i = ObjectsTotal(0)-1; i >= 0; i--)
     {
      string objName = ObjectName(0,i);
      if(StringFind(objName, PANEL_PREFIX) == 0)
         ObjectDelete(0, objName);
     }
   g_panelBGName = "";
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string AlertStateToString(EAlertState state)
  {
   switch(state)
     {
      case ALERT_NONE:
         return("None");
      case ALERT_APPROACH_SENT:
         return("Approach");
      case ALERT_TOUCH_SENT:
         return("Touch");
      case ALERT_BREAKOUT_SENT:
         return("Breakout");
      case ALERT_REVERSAL_SENT:
         return("Reversal");
      default:
         return("Unknown");
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int MeasureTextWidth(string text, int fontSize, string fontName = "Arial")
  {
   uint w = 0, h = 0;
   if(!TextSetFont(fontName, -fontSize, 0, 0))
      return(StringLen(text) * fontSize * 3 / 5);
   if(!TextGetSize(text, w, h))
      return(StringLen(text) * fontSize * 3 / 5);
   return((int)w);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdatePanel()
  {
   DeletePanelObjects();
   int total = ArraySize(g_monitored);
   int x = g_panelX, y = g_panelY;
   int lineHeight = 18, fontSize = 10;
   string fontName = "Arial";

   string headerText = "Fibonacci Levels Monitor";
   int headerWidth = MeasureTextWidth(headerText, fontSize, fontName);
   int maxWidth = headerWidth;
   for(int i = 0; i < total; i++)
     {
      string display = g_monitored[i].levelLabel;
      string text = StringFormat("%s: %s", display, AlertStateToString(g_monitored[i].alertState));
      int w = MeasureTextWidth(text, fontSize, fontName);
      if(w > maxWidth)
         maxWidth = w;
     }
   int panelWidth = maxWidth + PanelPadding;
   int totalHeight = HEADER_HEIGHT + lineHeight * total + 4;

   string bgName = PANEL_PREFIX + "BG";
   ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, panelWidth);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, totalHeight);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, PanelBgColor);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, true);
   ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, bgName, OBJPROP_HIDDEN, false);
   g_panelBGName = bgName;

   string headerBgName = PANEL_PREFIX + "Header";
   ObjectCreate(0, headerBgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, headerBgName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, headerBgName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, headerBgName, OBJPROP_XSIZE, panelWidth);
   ObjectSetInteger(0, headerBgName, OBJPROP_YSIZE, HEADER_HEIGHT);
   ObjectSetInteger(0, headerBgName, OBJPROP_BGCOLOR, PanelHeaderColor);
   ObjectSetInteger(0, headerBgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, headerBgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, headerBgName, OBJPROP_BACK, true);
   ObjectSetInteger(0, headerBgName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, headerBgName, OBJPROP_HIDDEN, false);

   int headerTextX = x + (panelWidth - headerWidth) / 2;
   int headerTextY = y + (HEADER_HEIGHT - fontSize) / 2;
   string headerTextName = PANEL_PREFIX + "HeaderText";
   ObjectCreate(0, headerTextName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, headerTextName, OBJPROP_XDISTANCE, headerTextX);
   ObjectSetInteger(0, headerTextName, OBJPROP_YDISTANCE, headerTextY);
   ObjectSetString(0, headerTextName, OBJPROP_TEXT, headerText);
   ObjectSetInteger(0, headerTextName, OBJPROP_COLOR, PanelTextColor);
   ObjectSetInteger(0, headerTextName, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, headerTextName, OBJPROP_FONT, fontName);
   ObjectSetInteger(0, headerTextName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, headerTextName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, headerTextName, OBJPROP_HIDDEN, false);

   for(int i = 0; i < total; i++)
     {
      string display = g_monitored[i].levelLabel;
      string stateStr = AlertStateToString(g_monitored[i].alertState);
      string text = StringFormat("%s: %s", display, stateStr);
      string objTextName = PANEL_PREFIX + "Line_" + IntegerToString(i);
      ObjectCreate(0, objTextName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, objTextName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, objTextName, OBJPROP_YDISTANCE, y + HEADER_HEIGHT + 2 + i * lineHeight);
      ObjectSetString(0, objTextName, OBJPROP_TEXT, text);
      ObjectSetInteger(0, objTextName, OBJPROP_COLOR, PanelTextColor);
      ObjectSetInteger(0, objTextName, OBJPROP_FONTSIZE, fontSize);
      ObjectSetString(0, objTextName, OBJPROP_FONT, fontName);
      ObjectSetInteger(0, objTextName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objTextName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objTextName, OBJPROP_HIDDEN, false);
     }
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateStyledButton(string btnName, string text, int x, int y, int w, int h, color bgColor, bool state)
  {
   string objName = PREFIX + btnName;
   ObjectCreate(0, objName, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 11);
   ObjectSetString(0, objName, OBJPROP_FONT, "Segoe UI");
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, clrDarkGray);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_RAISED);
   ObjectSetInteger(0, objName, OBJPROP_STATE, state);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, objName, OBJPROP_ZORDER, 0);
  }

//+------------------------------------------------------------------+
//| Process Fibonacci object: create horizontal lines for all levels|
//+------------------------------------------------------------------+
void ProcessFibonacciObject(string fiboName)
  {
   datetime time1 = (datetime)ObjectGetInteger(0, fiboName, OBJPROP_TIME, 0);
   datetime time2 = (datetime)ObjectGetInteger(0, fiboName, OBJPROP_TIME, 1);
   double price1 = ObjectGetDouble(0, fiboName, OBJPROP_PRICE, 0);
   double price2 = ObjectGetDouble(0, fiboName, OBJPROP_PRICE, 1);
   if(price1 == 0 || price2 == 0)
     {
      Print("Invalid price points");
      return;
     }

   int levels = (int)ObjectGetInteger(0, fiboName, OBJPROP_LEVELS);
   if(levels <= 0)
     {
      Print("No levels found");
      return;
     }

   double levelValues[];
   ArrayResize(levelValues, levels);
   string levelTexts[];
   ArrayResize(levelTexts, levels);
   for(int i = 0; i < levels; i++)
     {
      levelValues[i] = ObjectGetDouble(0, fiboName, OBJPROP_LEVELVALUE, i);
      levelTexts[i] = ObjectGetString(0, fiboName, OBJPROP_LEVELTEXT, i);
      if(levelTexts[i] == "") // if no custom text, use percentage
         levelTexts[i] = DoubleToString(levelValues[i] * 100, 1) + "%";
     }

// --- Debug output ---
   Print("=== Fibonacci Object: ", fiboName, " ===");
   Print("  Anchor1: price=", price1, " time=", time1);
   Print("  Anchor2: price=", price2, " time=", time2);
   Print("  NormalizeLevels = ", NormalizeLevels ? "true" : "false");
   Print("  InvertMapping   = ", InvertMapping ? "true" : "false");
   Print("  Levels count = ", levels);
   for(int i = 0; i < levels; i++)
      Print("    level ", i, " = ", levelTexts[i], " (ratio ", levelValues[i], ")");
// --------------------

// Determine the base prices for mapping
   double baseStart, baseEnd;
   if(NormalizeLevels)
     {
      baseStart = MathMin(price1, price2);
      baseEnd   = MathMax(price1, price2);
     }
   else
     {
      baseStart = price1;
      baseEnd   = price2;
     }
   double range = baseEnd - baseStart;

   datetime labelTime = TimeCurrent();

   for(int i = 0; i < levels; i++)
     {
      double ratio = levelValues[i];
      bool swap = (InvertMapping && !NormalizeLevels);
      if(swap)
         ratio = 1.0 - ratio;

      double levelPrice = baseStart + range * ratio;

      Print("  Level ", i, " (", levelTexts[i], ") -> price = ", levelPrice,
            (swap ? " (inverted)" : ""));

      string lineName = PREFIX + "Level_" + fiboName + "_" + IntegerToString(i);
      int suffix = 0;
      while(ObjectFind(0, lineName) >= 0)
        {
         suffix++;
         lineName = PREFIX + "Level_" + fiboName + "_" + IntegerToString(i) + "_" + IntegerToString(suffix);
        }

      if(!ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, levelPrice))
        {
         Print("Failed to create HLINE: ", lineName);
         continue;
        }

      ObjectSetInteger(0, lineName, OBJPROP_COLOR, MonitorColor);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, LineWidth);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(0, lineName, OBJPROP_HIDDEN, false);

      // Determine the label to display on the chart
      string displayLabel = levelTexts[i];
      if(swap)
        {
         if(StringFind(levelTexts[i], "%") > 0)
           {
            double swappedVal = 1.0 - levelValues[i];
            displayLabel = DoubleToString(swappedVal * 100, 1) + "%";
           }
         // custom labels remain unchanged
        }

      AddMonitoredLevel(lineName, levelValues[i], displayLabel);

      if(ShowLabels)
        {
         string labelName = lineName + "_label";
         int labelSuffix = 0;
         string tempLabel = labelName;
         while(ObjectFind(0, tempLabel) >= 0)
           {
            labelSuffix++;
            tempLabel = labelName + "_" + IntegerToString(labelSuffix);
           }
         labelName = tempLabel;

         if(ObjectCreate(0, labelName, OBJ_TEXT, 0, labelTime, levelPrice))
           {
            ObjectSetString(0, labelName, OBJPROP_TEXT, displayLabel);
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, MonitorColor);
            ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
            ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
            ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, false);
           }
         else
           {
            Print("Failed to create label for ", lineName);
           }
        }
     }
   Print("=== Conversion complete ===");
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
