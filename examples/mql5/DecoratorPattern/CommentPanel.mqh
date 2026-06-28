//+------------------------------------------------------------------+
//|                                                 CommentPanel.mqh |
//| CCommentPanel: displays active decorator chain, raw and          |
//| filtered values, and last five bar outputs as a chart comment.   |
//+------------------------------------------------------------------+
#ifndef COMMENTPANEL_MQH
#define COMMENTPANEL_MQH

#include "IIndicator.mqh"

#define PANEL_HISTORY_SIZE 5

//+------------------------------------------------------------------+
//| CCommentPanel                                                    |
//| Purpose: Management panel that stores and displays visual        |
//|          diagnostic summaries of indicator chains on the chart.  |
//+------------------------------------------------------------------+
class CCommentPanel
  {
private:
   double            m_raw_values[];       // Last N raw values from inner chain
   double            m_filtered_values[];  // Last N filtered values from outer chain
   int               m_stored;             // Number of values stored so far

public:
   //--- Lifecycle Management
                     CCommentPanel(void);
                    ~CCommentPanel(void) {}

   //--- Operational Interface Methods
   void              RecordValues(double raw_value, double filtered_value);
   void              Update(string chain_name, IIndicator *inner, IIndicator *outer);
   void              Clear(void);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//| Purpose: Initializes dynamic tracking arrays to fixed historic   |
//|          buffer depths.                                          |
//+------------------------------------------------------------------+
CCommentPanel::CCommentPanel(void) 
   : m_stored(0)
  {
   ArrayResize(m_raw_values,      PANEL_HISTORY_SIZE);
   ArrayResize(m_filtered_values, PANEL_HISTORY_SIZE);
   ArrayInitialize(m_raw_values,      0.0);
   ArrayInitialize(m_filtered_values, 0.0);
  }

//+------------------------------------------------------------------+
//| RecordValues                                                     |
//| Purpose: Shifts historical data array vectors to commit the      |
//|          latest tracking metrics at index position 0.            |
//+------------------------------------------------------------------+
void CCommentPanel::RecordValues(double raw_value, double filtered_value)
  {
   //--- Shift history: index 0 is most recent
   for(int i = PANEL_HISTORY_SIZE - 1; i > 0; i--)
     {
      m_raw_values[i]      = m_raw_values[i - 1];
      m_filtered_values[i] = m_filtered_values[i - 1];
     }

   m_raw_values[0]      = raw_value;
   m_filtered_values[0] = filtered_value;

   if(m_stored < PANEL_HISTORY_SIZE)
     {
      m_stored++;
     }
  }

//+--------------------------------------------------------------------+
//| Update                                                             |
//| Purpose: Formats runtime pipeline structures and historical values |
//|          into human-readable chart comments text blocks.           |
//+--------------------------------------------------------------------+
void CCommentPanel::Update(string chain_name, IIndicator *inner, IIndicator *outer)
  {
   string text = "=== Decorator Pattern EA ===\n";
   text += "Chain: " + chain_name + "\n";
   text += "Inner: " + (inner != NULL ? inner.GetName() : "N/A") + "\n";
   text += "Outer: " + (outer != NULL ? outer.GetName() : "N/A") + "\n";
   text += "\n";

   int display_count = (m_stored < PANEL_HISTORY_SIZE) ? m_stored : PANEL_HISTORY_SIZE;
   for(int i = 0; i < display_count; i++)
     {
      text += "Bar " + IntegerToString(i) + "\n";
      text += "  Raw      = " + DoubleToString(m_raw_values[i],      5) + "\n";
      text += "  Filtered = " + DoubleToString(m_filtered_values[i], 5) + "\n";
     }

   Comment(text);
  }

//+------------------------------------------------------------------+
//| Clear                                                            |
//| Purpose: Flushes existing active user-interface comment strings. |
//+------------------------------------------------------------------+
void CCommentPanel::Clear(void)
  {
   Comment("");
  }

#endif // COMMENTPANEL_MQH
//+------------------------------------------------------------------+