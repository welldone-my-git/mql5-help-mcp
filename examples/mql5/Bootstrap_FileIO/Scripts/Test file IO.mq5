//+------------------------------------------------------------------+
//|                                                 Test file IO.mq5 |
//|                                    Copyright 2025, Omega Joctan. |
//|                 https://www.mql5.com/en/users/omegajoctan/seller |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Omega Joctan."
#property link      "https://www.mql5.com/en/users/omegajoctan/seller"
#property version   "1.00"

#include <PyMQL5\\fileIO\\fileIO.mqh>
#include <PyMQL5\\fileIO\\csv.mqh>
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//--- Reading a text file

    CFile f = CFileIO::open("readme.txt", "r"); //open the file in read-only mode
    
    printf("Reading a text file line by line....");
    string text;
    while(f.readline(text))
       Print(text);
    
    Print("is writable: ", f.iswritable());
    Print("is readable: ", f.isreadable());  
    
    f.close(); //closing after you are done with it
    
//---
    
    f = CFileIO::open("MT5.log", "r"); //readonly 
    f.close();
    
//--- Reading a CSV file
    
    Print("\nOpening a CSV file in read/write mode....");
    f = CFileIO::open("mydata.csv", "r+"); //read/write mode for a CSV file
    
    CSVReader reader(f, ",");
    
    string out_row[];
    while(reader.readRow(out_row))
      ArrayPrint(out_row);
    
    f.close();
    
//--- Reading a binary file
    
    f = CFileIO::open("array.bin", "wb+");
    
    int value, count = 0;
    while (f.readline(value)) 
     {
       printf("array[%d]: %d",count,value);
       count++;
     }
      
    f.close();  
    

//--- Writting 

//--- Writing to a text file

    f = CFileIO::open("readme.txt", "r+a");
    f.write("Newly added data | "+string(TimeLocal()));
    f.close();
    
//--- Writting array to a text file

    f = CFileIO::open("array.txt", "wt");
    
    string data[] = {"data01", "data02", "data03", "data04"};
    f.write( data);
    f.close();
    
//--- Writting an Array to a binary file
    
    f = CFileIO::open("array.bin", "w+b");
    
    int arr[] = {1,2,3,4,5,6};
    f.write(arr);
    
    f.close();
   
//--- writting a CSV row
      
   f = CFileIO::open("mydata.csv","w+a");
   CSVWriter writer(f, ",");
   
   double open = iOpen(Symbol(), Period(), 0);
   double high = iHigh(Symbol(), Period(), 0);
   double low = iLow(Symbol(), Period(), 0);
   double close = iClose(Symbol(), Period(), 0);
   
   string row[] = {string(TimeCurrent()), (string)open, (string)high, (string)low, (string)close};
   
   writer.writeRow(row);
   f.close();

//--- Read method
   
   f = CFileIO::open("readme.txt", "rt");
   Print(f.read());
   
   f.close();
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

