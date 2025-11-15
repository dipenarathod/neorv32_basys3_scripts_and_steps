with Interfaces;
with System;

package Ada_Ml_Library is

   --Rename types for easier use
   --Search https://www.google.com/search?q=how+to+give+a+type+another+name+in+ada&oq=how+to+give+a+type+another+name+in+&gs_lcrp=EgZjaHJvbWUqBwgBECEYoAEyBggAEEUYOTIHCAEQIRigATIHCAIQIRifBTIHCAMQIRifBdIBCDc4NDNqMGo3qAIAsAIA&client=ubuntu-chr&sourceid=chrome&ie=UTF-8

   type Unsigned_Byte is new Interfaces.Unsigned_8;
   --type Signed_Byte is new Interfaces.Integer_8;
   type Word is new Interfaces.Unsigned_32;

   --Make types which are actually arrays(https://learn.adacore.com/courses/intro-to-ada/chapters/arrays.html)
   type Unsigned_Byte_Array is array (Natural range <>) of Unsigned_Byte;
   --type Signed_Byte_Array is array (Natural range <>) of Signed_Byte;
   type Word_Array is array (Natural range <>) of Word;

   --Address is a type in Ada
   --Register addresses
   CTRL_Addr   : constant System.Address :=
     System'To_Address
       (16#90000008#); --Control register. [0]= start flag. [5:1]=opcode
   STATUS_Addr : constant System.Address :=
     System'To_Address
       (16#9000000C#); --Status register. [0] = busy. [1] = done
   DIM_Addr    : constant System.Address :=
     System'To_Address
       (16#90000010#); --Address to store dimensions(side length) of square tensor
   BASEI_Addr  : constant System.Address :=
     System'To_Address (16#90000014#); --top-left idx in A
   OUTI_Addr   : constant System.Address :=
     System'To_Address (16#90000018#); --out idx in R
   WORDI_Addr  : constant System.Address :=
     System'To_Address (16#9000001C#); --word index for OP_ADD/OP_SUB
   ABASE_Addr  : constant System.Address :=
     System'To_Address (16#90001000#); --Tensor A address
   RBASE_Addr  : constant System.Address :=
     System'To_Address (16#90004000#); --Tensor R(result) address

   --Opcodes
   --00 and 01 are reserved for add/sub, which are not used
   OP_MAX  : constant Word := 16#02#; --Max pooling
   OP_AVG  : constant Word := 16#03#; --Average pooling
   OP_SIG  : constant Word := 16#04#; --Sigmoid activation
   OP_RELU : constant Word := 16#05#; --ReLU activation

   --CTRL/STATUS bit masks
   Perform_Bit  : constant Word := 1;      --CTRL[0]
   Opcode_Shift : constant Natural :=
     1;   --Bits to shift to place an opcode in CTRL[5:1] = 1
   Busy_Mask    : constant Word := 1;      --STATUS[0] = 0b1
   Done_Mask    : constant Word := 2;      --STATUS[1] = 0b10

   --Input/Output helpers
   procedure Write_Reg (Addr : System.Address; Value : Word);
   function Read_Reg (Addr : System.Address) return Word;

   --Byte packing/unpacking
   function Pack_Four_Bytes (B0, B1, B2, B3 : Unsigned_Byte) return Word;
   function Unpack_Byte_At_Index
     (W : Word; Index : Natural) return Unsigned_Byte; --Index 0..3
   procedure Unpack_Four_Bytes (W : Word; B0, B1, B2, B3 : out Unsigned_Byte);
   function Get_Byte_From_Tensor
     (Data : Word_Array; Index : Natural) return Unsigned_Byte;
   --Word count for a square N×N int8 tensor when 4 int8 are packed per 32-bit word
   function Tensor_Words (N : Natural) return Natural;

   --Register setters
   procedure Set_Dim (N : Natural); --N in LSB 8 bits
   procedure Set_Pool_Base_Index (Index : Natural); --pooling index in A
   procedure Set_Pool_Out_Index (Index : Natural); --pooling index in R
   procedure Set_Word_Index (Index : Natural);

   --Operation control
   procedure Perform_Op (Opcode : Word);
   procedure Perform_Max_Pool;
   procedure Perform_Avg_Pool;
   procedure Perform_Sigmoid;
   procedure Perform_ReLU;

   function Is_Busy return Boolean;
   function Is_Done return Boolean;
   procedure Wait_While_Busy;
   --procedure Wait_Until_Done;

   procedure Write_Word_In_A (Index : Natural; Value : Word);
   procedure Write_Words_In_A (Src : in Word_Array);

   function Read_Word_From_A (Index : Natural) return Word;
   procedure Read_Words_From_A (Dest : out Word_Array);

   function Read_Word_From_R (Index : Natural) return Word;
   procedure Read_Words_From_R (Dest : out Word_Array);

   --Activation Functions
   procedure Apply_ReLU_All_Words (N : Natural);
   procedure Apply_Sigmoid_All_Words (N : Natural);

   --2x2 pooling across the entire N×N tensor (stride 2, no padding)
   --Produces an (N/2)×(N/2) result into R
   procedure Apply_MaxPool_2x2_All_Words (N : Natural);
   procedure Apply_AvgPool_2x2_All_words (N : Natural);

   procedure Print_Registers;

   --Q0.7 Fixed Point Conversions
   --Q0.7: 1 sign bit + 7 fractional bits
   --Range: [-1.0, 1.0) represented as 0-255
   function Float_To_Q07 (Value : Float) return Unsigned_Byte;
   function Q07_To_Float (Value : Unsigned_Byte) return Float;
   function Int_To_Q07 (Value : Integer) return Unsigned_Byte;
   function Q07_To_Int (Value : Unsigned_Byte) return Integer;

   procedure Print_Tensor_Q07
     (Name : String; Data : Word_Array; Dimension : Natural);
end Ada_Ml_Library;
