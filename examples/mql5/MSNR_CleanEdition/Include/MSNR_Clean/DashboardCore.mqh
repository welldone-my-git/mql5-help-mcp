//+------------------------------------------------------------------+
//| MSNR Clean Edition - DashboardCore.mqh                           |
//| 收藏内容：最小化 Dashboard 骨架                                  |
//+------------------------------------------------------------------+
#property strict

#ifndef __MSNR_CLEAN_DASHBOARD_CORE_MQH__
#define __MSNR_CLEAN_DASHBOARD_CORE_MQH__

class CDashboardClean
{
private:
   string m_prefix;
   int    m_x;
   int    m_y;

public:
   void Configure(const string prefix, const int x, const int y)
   {
      m_prefix = prefix;
      m_x = x;
      m_y = y;
   }

   string Name(const string key) const
   {
      return m_prefix + "_" + key;
   }

   void Clear()
   {
      ObjectsDeleteAll(0, m_prefix);
   }

   void Text(const string key, const string text, const int row, const color clr = clrWhite)
   {
      string name = Name(key);
      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      }

      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, m_x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, m_y + row * 16);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
   }
};

#endif
