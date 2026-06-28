//+------------------------------------------------------------------+
//|                                                Random Forest.mqh |
//|                                          Copyright 2023, Omegafx |
//|                 https://www.mql5.com/en/users/omegajoctan/seller |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Omegafx"
#property link      "https://www.mql5.com/en/users/omegajoctan/seller"
//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+

#ifndef UNDEFINED_REPLACE
#define UNDEFINED_REPLACE 1
#endif 

#ifndef NaN
#define NaN double("nan")
#endif 

struct clf_tree_pred_struct
 {
   double proba;
   long cls;
 };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

class CRandomForestClassifier
  {

protected:

   bool initialized;
   long onnx_handle;
   void PrintTypeInfo(const long num,const string layer,const OnnxTypeInfo& type_info);
   
   ulong inputs[], outputs[];
   void replace(ulong &arr[]) { for (uint i=0; i<arr.Size(); i++) if (arr[i] < 0 || arr[i]==ULONG_MAX) arr[i] = UNDEFINED_REPLACE; }
   
   bool OnnxLoad(long &handle);
   
public:
                     CRandomForestClassifier(void);
                    ~CRandomForestClassifier(void);
                     
                     virtual bool Init(const uchar &onnx_buff[], ulong flags=ONNX_DEFAULT); //Initilaized ONNX model from a resource uchar array with default flag
                     virtual bool Init(string onnx_filename, uint flags=ONNX_DEFAULT); //Initializes the ONNX model from a .onnx filename given
                     
                     clf_tree_pred_struct predict(const vector &x);
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CRandomForestClassifier::CRandomForestClassifier(void)
 {
 
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CRandomForestClassifier::~CRandomForestClassifier(void)
 {
   if (!OnnxRelease(onnx_handle))
     printf("%s Failed to release ONNX handle Err=%d",__FUNCTION__,GetLastError());
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CRandomForestClassifier::OnnxLoad(long &handle)
 {
 
//--- since not all sizes defined in the input tensor we must set them explicitly
//--- first index - batch size, second index - series size, third index - number of series (only Close)
   
   OnnxTypeInfo type_info; //Getting onnx information for Reference In case you forgot what the loaded ONNX is all about

   long input_count=OnnxGetInputCount(handle);
   if (MQLInfoInteger(MQL_DEBUG))
      Print("model has ",input_count," input(s)");
   
   for(long i=0; i<input_count; i++)
     {
      string input_name=OnnxGetInputName(handle,i);
      if (MQLInfoInteger(MQL_DEBUG))
         Print(i," input name is ",input_name);
         
      if(OnnxGetInputTypeInfo(handle,i,type_info))
        {
          if (MQLInfoInteger(MQL_DEBUG))
            PrintTypeInfo(i,"input",type_info);
          ArrayCopy(inputs, type_info.tensor.dimensions);
        }
     }

   long output_count=OnnxGetOutputCount(handle);
   if (MQLInfoInteger(MQL_DEBUG))
      Print("model has ",output_count," output(s)");
      
   for(long i=0; i<output_count; i++)
     {
      string output_name=OnnxGetOutputName(handle,i);
      if (MQLInfoInteger(MQL_DEBUG))
         Print(i," output name is ",output_name);
         
      if(OnnxGetOutputTypeInfo(handle,i,type_info))
       {
         if (MQLInfoInteger(MQL_DEBUG))
            PrintTypeInfo(i,"output",type_info);
         ArrayCopy(outputs, type_info.tensor.dimensions);
       }
     }
   
//---
   
   replace(inputs);
   replace(outputs);
      
//--- Setting the input size

   for (long i=0; i<input_count; i++)   
     if (!OnnxSetInputShape(handle, i, inputs)) //Giving the Onnx handle the input shape
       {
         if (MQLInfoInteger(MQL_DEBUG))
           printf("Failed to set the input shape Err=%d",GetLastError());
         DebugBreak();
         return false;
       }
   
//--- Setting the output size
   
   for(long i=0; i<output_count; i++)
     {
      if(!OnnxSetOutputShape(handle,i,outputs))
       {
         if (MQLInfoInteger(MQL_DEBUG))
             printf("Failed to set the Output[%d] shape Err=%d",i,GetLastError());
          //DebugBreak();
          //return false;
       }
     }
     
   initialized = true;
   
   if (MQLInfoInteger(MQL_DEBUG))
      Print("ONNX model Initialized");
   return true;
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CRandomForestClassifier::Init(string onnx_filename, uint flags=ONNX_DEFAULT)
 {  
   onnx_handle = OnnxCreate(onnx_filename, flags);
   
   if (onnx_handle == INVALID_HANDLE)
     return false;
   
   return OnnxLoad(onnx_handle);
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CRandomForestClassifier::Init(const uchar &onnx_buff[], ulong flags=ONNX_DEFAULT)
 {  
  onnx_handle = OnnxCreateFromBuffer(onnx_buff, flags); //creating onnx handle buffer 
    
   if (onnx_handle == INVALID_HANDLE)
     return false;
     
  return OnnxLoad(onnx_handle);
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void CRandomForestClassifier::PrintTypeInfo(const long num,const string layer,const OnnxTypeInfo& type_info)
  {
   Print("   type ",EnumToString(type_info.type));
   Print("   data type ",EnumToString(type_info.type));

   if(type_info.tensor.dimensions.Size()>0)
     {
      bool   dim_defined=(type_info.tensor.dimensions[0]>0);
      string dimensions=IntegerToString(type_info.tensor.dimensions[0]);
      
      
      for(long n=1; n<type_info.tensor.dimensions.Size(); n++)
        {
         if(type_info.tensor.dimensions[n]<=0)
            dim_defined=false;
         dimensions+=", ";
         dimensions+=IntegerToString(type_info.tensor.dimensions[n]);
        }
      Print("   shape [",dimensions,"]");
      //--- not all dimensions defined
      if(!dim_defined)
         PrintFormat("   %I64d %s shape must be defined explicitly before model inference",num,layer);
      //--- reduce shape
      uint reduced=0;
      long dims[];
      for(long n=0; n<type_info.tensor.dimensions.Size(); n++)
        {
         long dimension=type_info.tensor.dimensions[n];
         //--- replace undefined dimension
         if(dimension<=0)
            dimension=UNDEFINED_REPLACE;
         //--- 1 can be reduced
         if(dimension>1)
           {
            ArrayResize(dims,reduced+1);
            dims[reduced++]=dimension;
           }
        }
      //--- all dimensions assumed 1
      if(reduced==0)
        {
         ArrayResize(dims,1);
         dims[reduced++]=1;
        }
      //--- shape was reduced
      if(reduced<type_info.tensor.dimensions.Size())
        {
         dimensions=IntegerToString(dims[0]);
         for(long n=1; n<dims.Size(); n++)
           {
            dimensions+=", ";
            dimensions+=IntegerToString(dims[n]);
           }
         string sentence="";
         if(!dim_defined)
            sentence=" if undefined dimension set to "+(string)UNDEFINED_REPLACE;
         PrintFormat("   shape of %s data can be reduced to [%s]%s",layer,dimensions,sentence);
        }
     }
   else
      PrintFormat("no dimensions defined for %I64d %s",num,layer);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
clf_tree_pred_struct CRandomForestClassifier::predict(const vector &x)
 {
   clf_tree_pred_struct res;
   
   if (!this.initialized)
    {
      if (MQLInfoInteger(MQL_DEBUG))
         printf("%s The model is not initialized yet to make predictions | call Init function first",__FUNCTION__);
      return res;
    }

//---
   
   vectorf x_float;
   x_float.Assign(x);
   
   float output_data[];   
   struct Map
     {
      ulong          key[];
      float          value[];
     } output_data_map[];
   
//---

   ArrayResize(output_data, outputs.Size());
    
   if (!OnnxRun(onnx_handle, ONNX_DATA_TYPE_FLOAT, x_float, output_data, output_data_map))
     {
       if (MQLInfoInteger(MQL_DEBUG))
          printf("Failed to get predictions from Onnx err %d",GetLastError());
          
       return res;
     }
     
//---

   vector proba = {};
   double value[];
   ArrayCopy(value, output_data_map[0].value);
   proba.Swap(value);

//---

   res.proba = proba.Max();
   res.cls = (long)output_data_map[0].key[proba.ArgMax()];
     
   return res;
 }

//+------------------------------------------------------------------+
//|                                                                  |
//|                                                                  |
//|                                                                  |
//|                                                                  |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+

class CRandomForestRegressor
  {
   bool initialized;
   long onnx_handle;
   void PrintTypeInfo(const long num,const string layer,const OnnxTypeInfo& type_info);
   
   ulong inputs[], outputs[];
   void replace(ulong &arr[]) { for (uint i=0; i<arr.Size(); i++) if (arr[i] < 0 || arr[i]==ULONG_MAX) arr[i] = UNDEFINED_REPLACE; }
   
   bool OnnxLoad(long &handle);
   
public:
                     CRandomForestRegressor(void);
                    ~CRandomForestRegressor(void);
                     
                     virtual bool Init(const uchar &onnx_buff[], ulong flags=ONNX_DEFAULT); //Initilaized ONNX model from a resource uchar array with default flag
                     virtual bool Init(string onnx_filename, uint flags=ONNX_DEFAULT); //Initializes the ONNX model from a .onnx filename given

                     virtual double predict(const vector &x);
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CRandomForestRegressor::CRandomForestRegressor(void)
 {
 
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CRandomForestRegressor::~CRandomForestRegressor(void)
 {
   if (!OnnxRelease(onnx_handle))
     printf("%s Failed to release ONNX handle Err=%d",__FUNCTION__,GetLastError());
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CRandomForestRegressor::OnnxLoad(long &handle)
 {
//--- since not all sizes defined in the input tensor we must set them explicitly
//--- first index - batch size, second index - series size, third index - number of series (only Close)
   
   OnnxTypeInfo type_info; //Getting onnx information for Reference In case you forgot what the loaded ONNX is all about

   long input_count=OnnxGetInputCount(handle);
   if (MQLInfoInteger(MQL_DEBUG))
      Print("model has ",input_count," input(s)");
   
   for(long i=0; i<input_count; i++)
     {
      string input_name=OnnxGetInputName(handle,i);
      if (MQLInfoInteger(MQL_DEBUG))
         Print(i," input name is ",input_name);
         
      if(OnnxGetInputTypeInfo(handle,i,type_info))
        {
          if (MQLInfoInteger(MQL_DEBUG))
            PrintTypeInfo(i,"input",type_info);
          ArrayCopy(inputs, type_info.tensor.dimensions);
        }
     }

   long output_count=OnnxGetOutputCount(handle);
   if (MQLInfoInteger(MQL_DEBUG))
      Print("model has ",output_count," output(s)");
      
   for(long i=0; i<output_count; i++)
     {
      string output_name=OnnxGetOutputName(handle,i);
      if (MQLInfoInteger(MQL_DEBUG))
         Print(i," output name is ",output_name);
         
      if(OnnxGetOutputTypeInfo(handle,i,type_info))
       {
         if (MQLInfoInteger(MQL_DEBUG))
            PrintTypeInfo(i,"output",type_info);
         ArrayCopy(outputs, type_info.tensor.dimensions);
       }
     }
   
//---
   
   replace(inputs);
   replace(outputs);
      
//--- Setting the input size

   for (long i=0; i<input_count; i++)   
     if (!OnnxSetInputShape(handle, i, inputs)) //Giving the Onnx handle the input shape
       {
         if (MQLInfoInteger(MQL_DEBUG))
           printf("Failed to set the input shape Err=%d",GetLastError());
         DebugBreak();
         return false;
       }
   
//--- Setting the output size
   
   for(long i=0; i<output_count; i++)
     {
      if(!OnnxSetOutputShape(handle,i,outputs))
       {
         if (MQLInfoInteger(MQL_DEBUG))
             printf("Failed to set the Output[%d] shape Err=%d",i,GetLastError());
           
           DebugBreak();
           return false;
       }
     }
     
   initialized = true;
   
   if (MQLInfoInteger(MQL_DEBUG))
      Print("ONNX model Initialized");
   return true;
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CRandomForestRegressor::Init(string onnx_filename, uint flags=ONNX_DEFAULT)
 {  
   onnx_handle = OnnxCreate(onnx_filename, flags);
   
   if (onnx_handle == INVALID_HANDLE)
     return false;
     
   return OnnxLoad(onnx_handle);
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CRandomForestRegressor::Init(const uchar &onnx_buff[], ulong flags=ONNX_DEFAULT)
 {  
  onnx_handle = OnnxCreateFromBuffer(onnx_buff, flags); //creating onnx handle buffer 
    
   if (onnx_handle == INVALID_HANDLE)
     return false;
     
  return OnnxLoad(onnx_handle);
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void CRandomForestRegressor::PrintTypeInfo(const long num,const string layer,const OnnxTypeInfo& type_info)
  {
   Print("   type ",EnumToString(type_info.type));
   Print("   data type ",EnumToString(type_info.type));

   if(type_info.tensor.dimensions.Size()>0)
     {
      bool   dim_defined=(type_info.tensor.dimensions[0]>0);
      string dimensions=IntegerToString(type_info.tensor.dimensions[0]);
      
      
      for(long n=1; n<type_info.tensor.dimensions.Size(); n++)
        {
         if(type_info.tensor.dimensions[n]<=0)
            dim_defined=false;
         dimensions+=", ";
         dimensions+=IntegerToString(type_info.tensor.dimensions[n]);
        }
      Print("   shape [",dimensions,"]");
      //--- not all dimensions defined
      if(!dim_defined)
         PrintFormat("   %I64d %s shape must be defined explicitly before model inference",num,layer);
      //--- reduce shape
      uint reduced=0;
      long dims[];
      for(long n=0; n<type_info.tensor.dimensions.Size(); n++)
        {
         long dimension=type_info.tensor.dimensions[n];
         //--- replace undefined dimension
         if(dimension<=0)
            dimension=UNDEFINED_REPLACE;
         //--- 1 can be reduced
         if(dimension>1)
           {
            ArrayResize(dims,reduced+1);
            dims[reduced++]=dimension;
           }
        }
      //--- all dimensions assumed 1
      if(reduced==0)
        {
         ArrayResize(dims,1);
         dims[reduced++]=1;
        }
      //--- shape was reduced
      if(reduced<type_info.tensor.dimensions.Size())
        {
         dimensions=IntegerToString(dims[0]);
         for(long n=1; n<dims.Size(); n++)
           {
            dimensions+=", ";
            dimensions+=IntegerToString(dims[n]);
           }
         string sentence="";
         if(!dim_defined)
            sentence=" if undefined dimension set to "+(string)UNDEFINED_REPLACE;
         PrintFormat("   shape of %s data can be reduced to [%s]%s",layer,dimensions,sentence);
        }
     }
   else
      PrintFormat("no dimensions defined for %I64d %s",num,layer);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CRandomForestRegressor::predict(const vector &x)
 {
   if (!this.initialized)
    {
      if (MQLInfoInteger(MQL_DEBUG))
         printf("%s The model is not initialized yet to make predictions | call Init function first",__FUNCTION__);
      return NaN;
    }

//---
   
   vectorf x_float;
   x_float.Assign(x);
   
   vector res  = vector::Zeros(outputs[1]);

//---

   if (!OnnxRun(onnx_handle, ONNX_DATA_TYPE_FLOAT, x_float, res))
     {
       if (MQLInfoInteger(MQL_DEBUG))
          printf("Failed to get predictions from Onnx err %d",GetLastError());
          
       return NaN;
     }
     
   return res[0]; 
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
