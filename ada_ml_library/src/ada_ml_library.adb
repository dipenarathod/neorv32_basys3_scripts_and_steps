with System.Address_To_Access_Conversions;
with System.Storage_Elements;
with Interfaces;
with Ada.Text_IO; use Ada.Text_IO;

package body Ada_Ml_Library is

   use Interfaces;

   --Volatile word
   type Volatile_Word is new Unsigned_32;
   --Reusing word from .ads seems to not work. New declaration for the same works?
   --Works in favor because now we have volatile and non-volatile words
   --Volatile because may change any time
   pragma Volatile_Full_Access (Volatile_Word);

   --Can't use the "use" clause. is new works for package rename as well
   package Convert is new System.Address_To_Access_Conversions (Volatile_Word);

   --Convert address to volatile word pointer
   --access = pointers
   function R32 (Addr : System.Address) return access Volatile_Word is
   begin
      return Convert.To_Pointer (Addr);
   end R32;

   --Add byte offset to an address
   --Refer https://learn.adacore.com/courses/intro-to-embedded-sys-prog/chapters/interacting_with_devices.html
   --System.address is a private type, amking address math possible only via System.Storage_Elements
   --Pg 385 for address arithmetic: http://www.ada-auth.org/standards/22rm/RM-Final.pdf
   function Add_Byte_Offset
     (Address : System.Address; Offset : Unsigned_32) return System.Address is
   begin

      return
        System.Storage_Elements."+"
          (Address, System.Storage_Elements.Storage_Offset (Offset));
   end Add_Byte_Offset;

   --Write value to a register
   procedure Write_Reg (Addr : System.Address; Value : Word) is
   begin
      R32 (Addr).all := Volatile_Word (Value);
   end Write_Reg;

   --Read val from register (need to dereference the word)
   function Read_Reg (Addr : System.Address) return Word is
   begin
      return Word (R32 (Addr).all);
   end Read_Reg;

   --PAck four 8 bits into a 32-bit word
   function Pack_Four_Bytes (B0, B1, B2, B3 : Unsigned_Byte) return Word is
      U0 : constant Word := Word (Unsigned_32 (B0));
      U1 : constant Word := Word (Unsigned_32 (B1));
      U2 : constant Word := Word (Unsigned_32 (B2));
      U3 : constant Word := Word (Unsigned_32 (B3));
   begin
      return
        Word
          (U0
           or Shift_Left (U1, 8)
           or Shift_Left (U2, 16)
           or Shift_Left (U3, 24));
   end Pack_Four_Bytes;

   --Get an int8 at an index (offset) inside a 32-bit word
   --There are 4 bytes, W[7:0], W[15:8], W[23:16], W[31:24]
   --Depending on the index, we shift the word right index * 8 to force the desired byte to exist in positions 7:0
   function Unpack_Byte_At_Index
     (W : Word; Index : Natural) return Unsigned_Byte
   is
      Shift  : constant Natural := Index * 8;
      Byte32 : constant Unsigned_32 :=
        Unsigned_32 (Shift_Right (W, Shift) and 16#FF#); --0xFF = 1111 1111
      --Leading 24 bits are 0

   begin
      return Unsigned_Byte (Byte32);
   end Unpack_Byte_At_Index;

   --Reuse unpack byte at index
   procedure Unpack_Four_Bytes (W : Word; B0, B1, B2, B3 : out Unsigned_Byte)
   is
   begin
      B0 := Unpack_Byte_At_Index (W, 0);
      B1 := Unpack_Byte_At_Index (W, 1);
      B2 := Unpack_Byte_At_Index (W, 2);
      B3 := Unpack_Byte_At_Index (W, 3);
   end Unpack_Four_Bytes;

   --Get byte from tensor using word and byte index
   function Get_Byte_From_Tensor
     (Data : Word_Array; Index : Natural) return Unsigned_Byte
   is
      Word_Index : constant Natural := Index / 4;
      Byte_Index : constant Natural := Index mod 4;
   begin
      return Unpack_Byte_At_Index (Data (Word_Index), Byte_Index);
   end Get_Byte_From_Tensor;

   --Word count for a square N×N int8 tensor when 4 int8 are packed per 32-bit word
   function Tensor_Words (N : Natural) return Natural is
      Elements : constant Natural := N * N;
   begin
      return (Elements + 3) / 4;
   --Why + 3 is necessary:
   --N*N = 9 *9  = 81 elements
   --81/4 = 20 words, but 20 words are insufficient to hold 81 bytes
   --84/4 = 21
   --+3 makes it possible that even partially filled words are counted
   end Tensor_Words;

   --DIM register only reads the right-most 8 bits. The other bits are ignored. Write word
   procedure Set_Dim (N : Natural) is
   begin
      Write_Reg (DIM_Addr, Word (Unsigned_32 (N)));
   end Set_Dim;

   --Set base index in A to perform pooling on
   procedure Set_Pool_Base_Index (Index : Natural) is
   begin
      Write_Reg (BASEI_Addr, Word (Unsigned_32 (Index)));
   end Set_Pool_Base_Index;

   --Set index in R to write result of pooling to
   procedure Set_Pool_Out_Index (Index : Natural) is
   begin
      Write_Reg (OUTI_Addr, Word (Unsigned_32 (Index)));
   end Set_Pool_Out_Index;

   --Index in tensor to perform operation on, such as activation
   procedure Set_Word_Index (Index : Natural) is
   begin
      Write_Reg (WORDI_Addr, Word (Unsigned_32 (Index)));
   end Set_Word_Index;

   --Perform operation
   procedure Perform_Op (Opcode : Word) is
      Val : constant Word :=
        Shift_Left (Opcode, Opcode_Shift)
        or Perform_Bit;   --Need to set perform bit to actually perform an operation
   begin
      Write_Reg (CTRL_Addr, Val);
   end Perform_Op;

   procedure Perform_Max_Pool is
   begin
      Perform_Op (OP_MAX);
   end Perform_Max_Pool;

   procedure Perform_Avg_Pool is
   begin
      Perform_Op (OP_AVG);
   end Perform_Avg_Pool;

   procedure Perform_Sigmoid is
   begin
      Perform_Op (OP_SIG);
   end Perform_Sigmoid;

   procedure Perform_ReLU is
   begin
      Perform_Op (OP_RELU);
   end Perform_ReLU;

   --"/=" is the inequality operator in Ada, not !=
   --Read status_reg[0]
   function Is_Busy return Boolean is
   begin
      return (Read_Reg (STATUS_Addr) and Busy_Mask) /= 0;
   end Is_Busy;

   --Read status_reg[1]
   function Is_Done return Boolean is
   begin
      return (Read_Reg (STATUS_Addr) and Done_Mask) /= 0;
   end Is_Done;

   --Busy waiting
   procedure Wait_While_Busy is
   begin
      while Is_Busy loop
         null;
      end loop;
   end Wait_While_Busy;


   --Each word is 4 bytes apart
   --Base address + index * 4 = actual index of word
   --Applicable for both, A and R
   --Read/Write logic is the same. You read in one, and write in the other
   procedure Write_Word_In_A (Index : Natural; Value : Word) is
      Addr : constant System.Address :=
        Add_Byte_Offset (ABASE_Addr, Unsigned_32 (Index) * 4);
   begin
      Write_Reg (Addr, Value);
   end Write_Word_In_A;

   procedure Write_Words_In_A (Src : in Word_Array) is
      J : Natural := 0;
   begin
      for I in Src'Range loop
         Write_Word_In_A (J, Src (I));
         J := J + 1;
      end loop;
   end Write_Words_In_A;

   function Read_Word_From_A (Index : Natural) return Word is
      Addr : constant System.Address :=
        Add_Byte_Offset (ABASE_Addr, Unsigned_32 (Index) * 4);
   begin
      return Read_Reg (Addr);
   end Read_Word_From_A;

   procedure Read_Words_From_A (Dest : out Word_Array) is
      J : Natural := 0;
   begin
      for I in Dest'Range loop
         Dest (I) := Read_Word_From_A (J);
         J := J + 1;
      end loop;
   end Read_Words_From_A;

   function Read_Word_From_R (Index : Natural) return Word is
      Addr : constant System.Address :=
        Add_Byte_Offset (RBASE_Addr, Unsigned_32 (Index) * 4);
   begin
      return Read_Reg (Addr);
   end Read_Word_From_R;

   procedure Read_Words_From_R (Dest : out Word_Array) is
      J : Natural := 0;
   begin
      for I in Dest'Range loop
         Dest (I) := Read_Word_From_R (J);
         J := J + 1;
      end loop;
   end Read_Words_From_R;


   --Procedures to Apply ReLU and Sigmoid
   --Translatied test C code
   --Sigmoid and ReLU are very similar (because they are activation functions)
   procedure Apply_ReLU_All_Words (N : Natural) is
      Words : constant Natural := Tensor_Words (N);
   begin
      for I in 0 .. Words - 1 loop
         Set_Word_Index (I);
         Perform_ReLU;
         Wait_While_Busy;
         Write_Reg (CTRL_Addr, 0);
      end loop;
   end Apply_ReLU_All_Words;


   procedure Apply_Sigmoid_All_Words (N : Natural) is
      Words : constant Natural := Tensor_Words (N);
   begin
      for I in 0 .. Words - 1 loop
         Set_Word_Index (I);
         Perform_Sigmoid;
         Wait_While_Busy;
         Write_Reg (CTRL_Addr, 0);
      end loop;
   end Apply_Sigmoid_All_Words;

   --Print current register values to understand what is going on
   --should be useful (or not)
   procedure Print_Registers is
      CTRL_Val   : constant Word := Read_Reg (CTRL_Addr);
      STATUS_Val : constant Word := Read_Reg (STATUS_Addr);
      DIM_Val    : constant Word := Read_Reg (DIM_Addr);
      WORDI_Val  : constant Word := Read_Reg (WORDI_Addr);
   begin
      Put ("CTRL=");
      Put (Unsigned_32'Image (Unsigned_32 (CTRL_Val)));
      New_Line;

      Put ("STATUS=");
      Put (Unsigned_32'Image (Unsigned_32 (STATUS_Val)));
      New_Line;

      Put ("DIM=");
      Put (Unsigned_32'Image (Unsigned_32 (DIM_Val)));
      New_Line;

      Put ("WORDI=");
      Put (Unsigned_32'Image (Unsigned_32 (WORDI_Val)));
      New_Line;
   end Print_Registers;

   --Q0.7 conversion
   --Range: [-1.0, 0.992) mapped to unsigned 0-255
   --Signed int8 = -128 to 127
   --If unsigned variant is <128, then number is positive
   --If unsigned num is >=128, then Q0.7 number is negative
   function Q07_To_Float (Value : Unsigned_Byte) return Float is
      Byte_Val : constant Unsigned_8 := Unsigned_8 (Value);
   begin
      if (Byte_Val < 128) then
         return Float (Byte_Val) / 128.0;
      else
         return Float (Integer (Byte_Val) - 256) / 128.0;
      end if;
   end Q07_To_Float;


   --Float should be [-1, 0.992) or [-1,1)
   --In signed int, -128 to 127. Mutliply by 128 to convert float to int8 and then uint8
   --We need to use a normal int because * 128 makes it cross the limits -128 and 127
   --We can clamp this to -128 to 127. Similar logic to clipping in NumPy for quantization.
   --Float -> int8 -> uint8
   function Float_To_Q07 (Value : Float) return Unsigned_Byte is
      Scaled : Integer := Integer (Value * 128.0);
   begin
      if (Scaled <= -128) then
         Scaled := -128;
      elsif (Scaled > 127) then
         Scaled := 127;
      end if;

      if (Scaled < 0) then
         return Unsigned_Byte (Unsigned_8 (256 + Scaled));
      else
         return Unsigned_Byte (Unsigned_8 (Scaled));
      end if;
   end Float_To_Q07;


   --int8 -> unit8
   function Int_To_Q07 (Value : Integer) return Unsigned_Byte is
   begin
      if (Value <= -128) then
         return Unsigned_Byte (128);
      elsif (Value >= 127) then
         return Unsigned_Byte (127);
      elsif (Value < 0) then
         return Unsigned_Byte (Unsigned_8 (256 + Value));
      else
         return Unsigned_Byte (Unsigned_8 (Value));
      end if;
   end Int_To_Q07;

   --unit8 -> int8
   function Q07_To_Int (Value : Unsigned_Byte) return Integer is
      Byte_Val : constant Unsigned_8 := Unsigned_8 (Value);
   begin
      if (Byte_Val < 128) then
         return Integer (Byte_Val);
      else
         return Integer (Byte_Val) - 256;
      end if;
   end Q07_To_Int;

   procedure Print_Tensor_Q07
     (Name : String; Data : Word_Array; Dimension : Natural)
   is
      B0, B1, B2, B3  : Unsigned_Byte := 0; ---Bytes extracted from a word
      Float_Val       : Float; --Float to store float representation
      Last_Word_Index : Natural := Natural'Last; --Index of last word
   begin
      Put_Line (Name);
      for Row in 0 .. Dimension - 1 loop
         --Traverse rows
         Put (" [");
         for Col in 0 .. Dimension - 1 loop
            --Traverse columns
            declare
               Index      : constant Natural :=
                 Row
                 * Dimension
                 + Col;  --2D index modded to work with 1D representations
               Word_Index : constant Natural := Index / 4;  --Word index
               Byte_Sel   : constant Natural :=
                 Index mod 4;   --Byte index within word
            begin

               --if Word_Index /= Last_Word_Index then
               Unpack_Four_Bytes (Data (Word_Index), B0, B1, B2, B3);
               Last_Word_Index := Word_Index;
               --end if;

               case Byte_Sel is
                  when 0      =>
                     Float_Val := Q07_To_Float (B0);

                  when 1      =>
                     Float_Val := Q07_To_Float (B1);

                  when 2      =>
                     Float_Val := Q07_To_Float (B2);

                  when 3      =>
                     Float_Val := Q07_To_Float (B3);

                  when others =>
                     Float_Val := 0.0;
               end case;

               Put (" ");
               Put (Float'Image (Float_Val));
               Put (", ");
            end;
         end loop;
         Put_Line ("]");
      end loop;
      New_Line;
   end Print_Tensor_Q07;

end Ada_Ml_Library;
