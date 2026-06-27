//+------------------------------------------------------------------+
//|                                                  AlertManager.mqh|
//|                                 Copyright 2026, Clemence Benjamin|
//|                                              https://www.mql5.com|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Clemence Benjamin"
#property link      "https://www.mql5.com"

#include "InteractionDetector.mqh"

//+------------------------------------------------------------------+
//| Alert record for duplicate suppression                           |
//+------------------------------------------------------------------+
struct SAlertRecord
  {
   string            objName;        // chart object name
   ENUM_INTERACTION  lastAction;     // last action alerted
   double            lastLevelPrice; // price of last alert
   datetime          lastAlertTime;  // time of last alert
  };

//+------------------------------------------------------------------+
//| Alert manager class                                              |
//+------------------------------------------------------------------+
class CAlertManager
  {
private:
   SAlertRecord      m_records[];        // list of alert records
   int               m_recordCount;      // number of records
   bool              m_useAlert;         // enable terminal alerts
   bool              m_useNotification;  // enable push notifications
   bool              m_useSound;         // enable sound
   string            m_soundFile;        // sound file name

   int               FindRecord(const string &objName);
   void              AddOrUpdateRecord(const string &objName, ENUM_INTERACTION action, double price);

public:
                     CAlertManager();
   void              SetAlertUse(bool flag)           { m_useAlert=flag; }
   void              SetNotificationUse(bool flag)    { m_useNotification=flag; }
   void              SetSoundUse(bool flag)           { m_useSound=flag; }
   void              SetSoundFile(const string &file) { m_soundFile=file; }

   void              ProcessInteractions(const SInteraction &interList[], int count);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CAlertManager::CAlertManager() : m_recordCount(0),
   m_useAlert(true),
   m_useNotification(false),
   m_useSound(false),
   m_soundFile("alert.wav")
  {
  }

//+------------------------------------------------------------------+
//| Find a record by object name; returns index or -1                |
//+------------------------------------------------------------------+
int CAlertManager::FindRecord(const string &objName)
  {
   for(int i=0; i<m_recordCount; i++)
     {
      if(m_records[i].objName==objName)
         return(i);
     }
   return(-1);
  }

//+------------------------------------------------------------------+
//| Add or update a record                                            |
//+------------------------------------------------------------------+
void CAlertManager::AddOrUpdateRecord(const string &objName, ENUM_INTERACTION action, double price)
  {
   int idx=FindRecord(objName);
   if(idx<0)
     {
      //--- Create a new record if not found
      idx=m_recordCount;
      ArrayResize(m_records, idx+1);
      m_recordCount=idx+1;
      m_records[idx].objName=objName;
     }
   m_records[idx].lastAction    =action;
   m_records[idx].lastLevelPrice=price;
   m_records[idx].lastAlertTime =TimeCurrent();
  }

//+------------------------------------------------------------------+
//| Process interactions and fire alerts if new                       |
//+------------------------------------------------------------------+
void CAlertManager::ProcessInteractions(const SInteraction &interList[], int count)
  {
   for(int i=0; i<count; i++)
     {
      SInteraction inter=interList[i];

      int idx=FindRecord(inter.objName);

      //--- Determine if we should alert: no record, new action, or old alert >10 sec
      bool shouldAlert=false;
      if(idx<0)
         shouldAlert=true;
      else
        {
         if(m_records[idx].lastAction!=inter.action)
            shouldAlert=true;
         else
            if(TimeCurrent()-m_records[idx].lastAlertTime>10)
               shouldAlert=true;
        }

      if(shouldAlert)
        {
         //--- Build message with side and level description
         string sideStr =(inter.side!="") ? " from "+inter.side : "";
         string levelStr=(inter.levelText!="") ? " ("+inter.levelText+")" : "";
         string msg=StringFormat("Object '%s' [%s] – %s%s%s at %.5f",
                                 inter.objName,
                                 ObjectTypeToString(inter.objType),
                                 EnumToString(inter.action),
                                 sideStr,
                                 levelStr,
                                 inter.levelPrice);
         //--- Fire notifications
         if(m_useAlert)
            Alert(msg);
         if(m_useNotification)
            SendNotification(msg);
         if(m_useSound)
            PlaySound(m_soundFile);

         AddOrUpdateRecord(inter.objName, inter.action, inter.levelPrice);
        }
     }
  }
//+------------------------------------------------------------------+
