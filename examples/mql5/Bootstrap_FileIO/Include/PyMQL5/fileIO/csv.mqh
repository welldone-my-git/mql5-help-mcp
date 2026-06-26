//+------------------------------------------------------------------+
//|                                                          csv.mqh |
//|                                     Copyright 2025, Omega Joctan |
//|                 https://www.mql5.com/en/users/omegajoctan/seller |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Omega Joctan"
#property link      "https://www.mql5.com/en/users/omegajoctan/seller"
//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
#define MAX_FILE_SIZE_MB 200
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
#include "fileIO.mqh"
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CSVReader
  {
protected:
   int               m_handle;
   string            m_delimiter;
   char              m_quote;
   bool              m_doublequote;
   bool              m_skipinitialspace;
   char              m_escape;
   uint              cols_found;
   
   string StringTrim(string s)
     { 
       StringTrimLeft(s); 
       StringTrimRight(s); 
       return s; 
     }
   
   void ParseCSVLine(string line, string &fields[]);
   
public:
                     CSVReader(CFile &file,
                               const string delimiter = ",",
                               const char quotechar = '"',
                               const char escapechar = '\\',
                               const bool doublequote = true,
                               const bool skipinitialspace = false
                              );

                    ~CSVReader(void);
                    bool readRow(string &row[]);
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CSVReader::CSVReader(CFile &file,
                     const string delimiter = ",",
                     const char quotechar = '"',
                     const char escapechar = '\\',
                     const bool doublequote = true,
                     const bool skipinitialspace = false)
  {
//---

   m_handle = file.getHandle();
   m_delimiter = delimiter;
   m_quote = quotechar;
   m_doublequote = doublequote;
   m_skipinitialspace = skipinitialspace;
   m_escape = escapechar;
   
//--- Getting the file size in MegaBytes

   double file_size_MB = (double)FileSize(m_handle) / (double)1e6;
   printf("%s Filesize in ~ MB [%.3f]", __FUNCTION__, file_size_MB);

   if((uint)file_size_MB > MAX_FILE_SIZE_MB)
     {
      printf("%s Failed, CSV filesize [%.3f] in MBs is greater than the maximum file size accepted [%I64u] in MBs. To pass this limit, change the variable 'MAX_FILE_SIZE_MB'", 
             __FUNCTION__, file_size_MB, MAX_FILE_SIZE_MB);
      return;
     }

//--- Ensuring the CSV file size doesn't exceed available memory for the Terminal

   ulong free_ram_MB = (ulong)TerminalInfoInteger(TERMINAL_MEMORY_AVAILABLE);
   printf("Free Terminal RAM ~ %I64u MB", free_ram_MB);

//--- The CSV file isn't supposed to be greater in size than half of the available memory

   if(file_size_MB >= free_ram_MB)
     {
      printf("Filesize in MB [%.3f] is greater than available memory [%I64u] in the Terminal", file_size_MB, free_ram_MB);
      return;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CSVReader::~CSVReader(void)
 {
 
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CSVReader::readRow(string &row[])
{
   while(!FileIsEnding(m_handle))
   {
      string line = FileReadString(m_handle);
      ParseCSVLine(line, row);
      
      return true;
   }

   return false;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CSVReader::ParseCSVLine(string line, string &fields[])
{
   ArrayResize(fields, 0);

   string current = "";
   bool inQuotes = false;
   int len = StringLen(line);

   for(int i = 0; i < len; i++)
   {
      char ch = (char)StringGetCharacter(line, i);

      // Escape character handling
      if(m_escape != 0 && ch == m_escape && i + 1 < len)
      {
         current += CharToString((char)StringGetCharacter(line, i + 1));
         i++;
         continue;
      }

      // Quote handling
      if(ch == m_quote)
      {
         if(inQuotes)
         {
            // Double-quote escape ("")
            if(m_doublequote && i + 1 < len && line[i + 1] == m_quote)
            {
               current += CharToString(m_quote);
               i++;
            }
            else
            {
               inQuotes = false;
            }
         }
         else
         {
            inQuotes = true;
         }
         continue;
      }

      // Delimiter (only if NOT in quotes)
      if(!inQuotes && CharToString(ch) == m_delimiter)
      {
         int sz = ArraySize(fields);
         ArrayResize(fields, sz + 1);
         fields[sz] = m_skipinitialspace ? StringTrim(current) : current;
         current = "";
         continue;
      }

      // Normal character
      current += CharToString(ch);
   }

   // Push last field
   int sz = ArraySize(fields);
   ArrayResize(fields, sz + 1);
   fields[sz] = m_skipinitialspace ? StringTrim(current) : current;
}
//+------------------------------------------------------------------+
//|                                                                  |
//|                                                                  |
//|               CSV writter                                        |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
class CSVWriter
{
protected:
   int    m_handle;
   string m_delimiter;
   char   m_quote;
   char   m_escape;
   bool   m_doublequote;

   string EscapeField(const string value);

public:

   CSVWriter(CFile &file,
             const string delimiter = ",",
             const char quotechar = '"',
             const char escapechar = '\\',
             const bool doublequote = true);

   bool writeRow(const string &row[]);
};
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CSVWriter::CSVWriter(CFile &file,
                     const string delimiter,
                     const char quotechar,
                     const char escapechar,
                     const bool doublequote)
{
   m_handle      = file.getHandle();
   m_delimiter   = delimiter;
   m_quote       = quotechar;
   m_escape      = escapechar;
   m_doublequote = doublequote;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string CSVWriter::EscapeField(const string value)
{
   bool must_quote = false;
   string out = "";

   int len = StringLen(value);
   for(int i = 0; i < len; i++)
   {
      char ch = (char)StringGetCharacter(value, i);

      // Detect if quoting is needed
      if(ch == m_quote ||
         ch == '\n' ||
         ch == '\r' ||
         CharToString(ch) == m_delimiter)
      {
         must_quote = true;
      }

      // Quote escaping
      if(ch == m_quote)
      {
         if(m_doublequote)
            out += CharToString(m_quote) + CharToString(m_quote); // ""
         else
            out += CharToString(m_escape) + CharToString(m_quote); // \"
      }
      else
      {
         out += CharToString(ch);
      }
   }

   if(must_quote)
      return CharToString(m_quote) + out + CharToString(m_quote);

   return out;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CSVWriter::writeRow(const string &row[])
{
   string line = "";
   int cols = ArraySize(row);

   for(int i = 0; i < cols; i++)
   {
      if(i > 0)
         line += m_delimiter;

      line += EscapeField(row[i]);
   }

   FileWriteString(m_handle, "\n"+line);
   return true;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
