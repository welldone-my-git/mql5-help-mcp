//+------------------------------------------------------------------+
//|                                              GaussianMixture.mqh |
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

struct pred_struct
 {
   vector proba;
   long label;
 };
 
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CGaussianMixture
  {
protected:

   bool initialized;
   long onnx_handle;
   void PrintTypeInfo(const long num,const string layer,const OnnxTypeInfo& type_info);
   
   ulong inputs[]; //Inputs of a model in dimensions [nxn]
   void replace(ulong &arr[]) { for (uint i=0; i<arr.Size(); i++) if (arr[i] < 0 || arr[i]==ULONG_MAX) arr[i] = UNDEFINED_REPLACE; }
   
   struct outputs_struct 
    {
      ulong outputs[];
    } model_output_structure[];  
    
   void replace(outputs_struct &ouputs_strc[]) 
     { 
       for (uint s=0; s<ouputs_strc.Size(); s++) 
         for (uint a=0; a<ouputs_strc[s].outputs.Size(); a++) 
            {
              if (ouputs_strc[s].outputs[a] < 0 || ouputs_strc[s].outputs[a]==ULONG_MAX) 
                ouputs_strc[s].outputs[a] = UNDEFINED_REPLACE;   
            }
     }
   
   bool OnnxLoad(long &handle);
 
    
public:
                     CGaussianMixture(void);
                    ~CGaussianMixture(void);
                     
                     bool Init(const uchar &onnx_buff[], ulong flags=ONNX_DEFAULT);
                     bool Init(string onnx_filename, uint flags=ONNX_DEFAULT);

                     virtual pred_struct predict(const vector &x);
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CGaussianMixture::CGaussianMixture(void):
   initialized(false)
 {
 
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CGaussianMixture::~CGaussianMixture(void)
 {
   if (!OnnxRelease(onnx_handle))
     printf("%s Failed to release ONNX handle Err=%d",__FUNCTION__,GetLastError());
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CGaussianMixture::OnnxLoad(long &handle)
 {
 
//--- since not all sizes defined in the input tensor we must set them explicitly
//--- first index - batch size, second index - series size, third index - number of series (only Close)
   
   OnnxTypeInfo type_info; //Getting onnx information for Reference In case you forgot what the loaded ONNX is all about

   long input_count=OnnxGetInputCount(handle);
   if (MQLInfoInteger(MQL_DEBUG))
      Print("model has ",input_count," input(s)");
   
   //--- Get the inputs of the model outomatically and assign them to the mdoel object
   
   for(long i=0; i<input_count; i++)
     {
      string input_name=OnnxGetInputName(handle,i);
      if (MQLInfoInteger(MQL_DEBUG))
         Print(i," input name is ",input_name);
         
      if(OnnxGetInputTypeInfo(handle,i,type_info)) //Get the inputs of a model outomatically
        {
          if (MQLInfoInteger(MQL_DEBUG))
            PrintTypeInfo(i,"input",type_info);
          ArrayCopy(inputs, type_info.tensor.dimensions);
        }
      
      //--- Assign the input of the model to the model object
      
      replace(inputs); 
      if (!OnnxSetInputShape(handle, i, inputs)) //Giving the Onnx handle the input shape
        {
          if (MQLInfoInteger(MQL_DEBUG))
            printf("Failed to set the input shape Err=%d",GetLastError());
           
          DebugBreak();
          return false;
        }
     }
   
   //--- Get the inputs of the model outomatically and assign them to the mdoel object
   
   long output_count=OnnxGetOutputCount(handle); //Number of the output nodes 
   if (MQLInfoInteger(MQL_DEBUG))
      Print("model has ",output_count," output(s)");
   
   ArrayResize(model_output_structure, (int)output_count);
      
   for(long i=0; i<output_count; i++)
     {
      string output_name=OnnxGetOutputName(handle,i);
      if (MQLInfoInteger(MQL_DEBUG))
         Print(i," output name is ",output_name);
         
      if(OnnxGetOutputTypeInfo(handle,i,type_info))
       {
         if (MQLInfoInteger(MQL_DEBUG))
            PrintTypeInfo(i,"output",type_info);
            
         ArrayCopy(model_output_structure[i].outputs, type_info.tensor.dimensions);
       }
       
       //--- Set the output shape
         
         replace(model_output_structure);
         if(!OnnxSetOutputShape(handle, i, model_output_structure[i].outputs))
          {
            if (MQLInfoInteger(MQL_DEBUG))
              {
                printf("Failed to set the Output[%d] shape Err=%d",i,GetLastError());
                DebugBreak();
              }
              
             return false;
          }
     }
   
//---
     
   initialized = true;
   if (MQLInfoInteger(MQL_DEBUG))
      Print("ONNX model Initialized");
      
   return true;
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CGaussianMixture::Init(string onnx_filename, uint flags=ONNX_DEFAULT)
 {  
   onnx_handle = OnnxCreate(onnx_filename, flags);
   
   if (onnx_handle == INVALID_HANDLE)
     return false;
   
   return OnnxLoad(onnx_handle);
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CGaussianMixture::Init(const uchar &onnx_buff[], ulong flags=ONNX_DEFAULT)
 {  
  onnx_handle = OnnxCreateFromBuffer(onnx_buff, flags); //creating onnx handle buffer 
    
   if (onnx_handle == INVALID_HANDLE)
     return false;
     
  return OnnxLoad(onnx_handle);
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CGaussianMixture::PrintTypeInfo(const long num,const string layer,const OnnxTypeInfo& type_info)
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
//|  This function predicts a single value, it is suitable for live  |
//| trading/ forecasting use                                         |
//|                                                                  |
//+------------------------------------------------------------------+
pred_struct CGaussianMixture::predict(const vector &x)
 {
   pred_struct res;
   
   if (!this.initialized)
    {
      if (MQLInfoInteger(MQL_DEBUG))
         printf("%s The model is not initialized yet to make predictions | call Init function first",__FUNCTION__);
         
      return res;
    }
   
//---
   
   vectorf x_float; //Convert inputs from a vector of double values to those float values
   x_float.Assign(x);
   
   vector label = vector::Zeros(model_output_structure[0].outputs[1]); //outputs[1] we get the second shape (columns) from an array
   vector proba = vector::Zeros(model_output_structure[1].outputs[1]); //outputs[1] we get the second shape (columns) from an array
    
   if (!OnnxRun(onnx_handle, ONNX_DATA_TYPE_FLOAT, x_float, label, proba)) //Run the model and get the predicted label and probability
     {
       if (MQLInfoInteger(MQL_DEBUG))
          printf("Failed to get predictions from Onnx err %d",GetLastError());
       
       DebugBreak();   
       return res;
     }
     
//---

   res.label = (long)label[label.Size()-1]; //Get the last item available at the label's array
   res.proba = proba;
   
   return res;
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
