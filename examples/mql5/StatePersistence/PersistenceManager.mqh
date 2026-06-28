//+------------------------------------------------------------------+
//|                                           PersistenceManager.mqh |
//+------------------------------------------------------------------+
#property strict

#define STATE_VERSION 1

//+------------------------------------------------------------------+
//| Structure storing EA persistent runtime state                    |
//+------------------------------------------------------------------+
struct EAState
  {
   int               version;
   datetime          lastSaveTime;
   datetime          lastBarTime;
   int               dailyTradeCount;
   int               lossStreak;
   int               winStreak;
   double            currentLotMult;
   double            sessionHighEq;
   bool              partialClosed;
   int               lastSignal;
   char              reserved[64];
  };

//+------------------------------------------------------------------+
//| Generates the unique state file path for the specific instance   |
//+------------------------------------------------------------------+
string GetStateFilePath()
  {
   return(MQLInfoString(MQL_PROGRAM_NAME) + "_" + _Symbol + "_state.bin");
  }

//+------------------------------------------------------------------+
//| Returns an EAState structure populated with baseline values      |
//+------------------------------------------------------------------+
EAState DefaultState()
  {
   EAState s;
   ZeroMemory(s);
   s.version         = STATE_VERSION;
   s.lastSaveTime    = 0;
   s.lastBarTime     = 0;
   s.dailyTradeCount = 0;
   s.lossStreak      = 0;
   s.winStreak       = 0;
   s.currentLotMult = 1.0;
   s.sessionHighEq  = AccountInfoDouble(ACCOUNT_EQUITY);
   s.partialClosed  = false;
   s.lastSignal     = 0;
   return(s);
  }

//+------------------------------------------------------------------+
//| Serializes and saves the current EAState to disk                 |
//+------------------------------------------------------------------+
bool SaveState(EAState &state)
  {
   state.version      = STATE_VERSION;
   state.lastSaveTime = TimeCurrent();

   string path   = GetStateFilePath();
   int    handle = FileOpen(path, FILE_WRITE | FILE_BIN | FILE_COMMON);

   if(handle == INVALID_HANDLE)
     {
      Print("PersistenceManager: SaveState failed. Error: ", GetLastError());
      return(false);
     }

   uint written = FileWriteStruct(handle, state);
   FileClose(handle);

   if(written != sizeof(EAState))
     {
      Print("PersistenceManager: SaveState structural mismatch.");
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| Deserializes and loads the historical EAState from disk          |
//+------------------------------------------------------------------+
bool LoadState(EAState &state)
  {
//--- Clear the global memory container completely before filling it
   ZeroMemory(state);
   string path = GetStateFilePath();

   if(!FileIsExist(path, FILE_COMMON))
     {
      Print("PersistenceManager: No state file found. Using defaults.");
      state = DefaultState();
      return(false);
     }

   int handle = FileOpen(path, FILE_READ | FILE_BIN | FILE_COMMON);
   if(handle == INVALID_HANDLE)
     {
      Print("PersistenceManager: LoadState failed. Error: ", GetLastError());
      state = DefaultState();
      return(false);
     }

   EAState loaded;
   ZeroMemory(loaded);
   uint bytesRead = FileReadStruct(handle, loaded);
   FileClose(handle);

   if(loaded.version != STATE_VERSION)
     {
      Print("PersistenceManager: Version mismatch. Resetting to defaults.");
      FileDelete(path, FILE_COMMON);
      state = DefaultState();
      return(false);
     }

   state = loaded;
   PrintFormat("PersistenceManager: State loaded. Last saved Server Time: %s",
               TimeToString(state.lastSaveTime, TIME_DATE | TIME_MINUTES));
   return(true);
  }

//+------------------------------------------------------------------+
//| Permanently purges the stored bin file from disk                 |
//+------------------------------------------------------------------+
void DeleteStateFile()
  {
   string path = GetStateFilePath();
   if(FileIsExist(path, FILE_COMMON))
     {
      FileDelete(path, FILE_COMMON);
      Print("PersistenceManager: State file deleted.");
     }
  }
//+------------------------------------------------------------------+