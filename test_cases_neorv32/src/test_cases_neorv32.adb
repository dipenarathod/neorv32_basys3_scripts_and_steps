with Ada_Ml_Library; use Ada_Ml_Library;
with Interfaces;     use Interfaces;
with Ada.Text_IO;    use Ada.Text_IO;
with Uart0;
with Runtime_Support;
with Ada_Ml_Library; use Ada_Ml_Library;
with Interfaces;     use Interfaces;
with Ada.Text_IO;    use Ada.Text_IO;
with Uart0;

procedure Test_Cases_Neorv32 is

   --Test pass or fail result print
   procedure Print_Result (Name : String; Passed : Boolean) is
   begin
      if Passed then
         Put_Line (Name & " PASS");
      else
         Put_Line (Name & " FAIL");
      end if;
   end Print_Result;

   --Same generator as the C tests
   procedure Build_Tensor (Words : Natural; Out_W : out Word_Array) is
   begin
      for i in 0 .. Words - 1 loop
         declare
            base : constant Integer := Integer (i) * 4 - 40;
            b0   : constant Unsigned_Byte := Int_To_Q07 (base);
            b1   : constant Unsigned_Byte := Int_To_Q07 (base + 16);
            b2   : constant Unsigned_Byte := Int_To_Q07 (base + 32);
            b3   : constant Unsigned_Byte := Int_To_Q07 (base + 48);
         begin
            Out_W (i) := Pack_Four_Bytes (b0, b1, b2, b3);
         end;
      end loop;
   end Build_Tensor;


   --Software ReLU
   function ReLU_Sw (X : Integer) return Integer is
   begin
      if (X < 0) then
         return 0;
      else
         return X;
      end if;
   end ReLU_Sw;

   --Software Sigmoid
   function Sigmoid_Sw (X : Integer) return Integer is
      Y : Integer := 64 + (X / 4);  --0.5 + x/4 in Q0.7 => 64 + (x>>2)
   begin
      if(Y < 0) then
         Y := 0;
      elsif (Y > 127) then
         Y := 127;
      end if;
      return Y;
   end Sigmoid_Sw;

   --1)write/read A must match
   procedure Test_A_Window_Echo_4x4 is
      N     : constant Natural := 4;
      Words : constant Natural := Tensor_Words (N);
      Tx    : Word_Array (0 .. Words - 1) := (others => 0);
      Rx    : Word_Array (0 .. Words - 1) := (others => 0);
      Same  : Boolean := True;
   begin
      Build_Tensor (Words, Tx);
      Set_Dim (N);
      Write_Words_In_A (Tx);
      --Not using Read_Words_From_A directly because then words need to be checked individually. Waste of time
      for i in 0 .. Words - 1 loop
         Rx (i) := Read_Word_From_A (i);
         if (Rx (i) /= Tx (i)) then
            Same := False;
            exit;
         end if;
      end loop;
      Print_Tensor_Q07 (Name => "Input Tensor", Data => Tx, Dimension => N);
      Print_Tensor_Q07 (Name => "Read Tensor", Data => Rx, Dimension => N);
      Print_Result ("Words written == words read from A", Same);
   end Test_A_Window_Echo_4x4;

   --2)Test ReLU in 8x8 on some values
   procedure Test_ReLU_8x8 is
      N               : constant Natural := 8;
      Words           : constant Natural := Tensor_Words (N);
      Src             : Word_Array (0 .. Words - 1) := (others => 0);
      Out_Word_Tensor : Word_Array (0 .. Words - 1) := (others => 0);
      OK              : Boolean := True;
      --Test only some
      Samples         : constant array (Natural range <>) of Natural :=
        (0, 7, 15, 31, 48, 63);
   begin
      Build_Tensor (Words, Src);
      Set_Dim (N);
      Write_Words_In_A (Src);
      Apply_ReLU_All_Words (N);
      Read_Words_From_R (Out_Word_Tensor);

      for S of Samples loop
         declare
            A_b : constant Unsigned_Byte := Get_Byte_From_Tensor (Src, S);
            R_b : constant Unsigned_Byte :=
              Get_Byte_From_Tensor (Out_Word_Tensor, S);
            A_i : constant Integer := Q07_To_Int (A_b);
            R_i : constant Integer := Q07_To_Int (R_b);
         begin
            if (R_i /= ReLU_Sw (A_i)) then
               OK := False;
               exit;
            end if;
         end;
      end loop;
      Print_Tensor_Q07 (Name => "Input Tensor", Data => Src, Dimension => N);
      Print_Tensor_Q07
        (Name => "Result ReLU 8x8", Data => Out_Word_Tensor, Dimension => N);
      Print_Result ("ReLU 8x8 samples match", OK);
   end Test_ReLU_8x8;

   --3) Test sigmoid in 8x8 tensor (on some samples)
   procedure Test_Sigmoid_8x8 is
      N               : constant Natural := 8;
      Words           : constant Natural := Tensor_Words (N);
      Src             : Word_Array (0 .. Words - 1) := (others => 0);
      Out_Word_Tensor : Word_Array (0 .. Words - 1) := (others => 0);
      OK              : Boolean := True;
      Samples         : constant array (Natural range <>) of Natural :=
        (0, 7, 15, 31, 48, 63);
   begin
      Build_Tensor (Words, Src);
      Set_Dim (N);
      Write_Words_In_A (Src);
      Apply_Sigmoid_All_Words (N);
      Read_Words_From_R (Out_Word_Tensor);

      for S of Samples loop
         declare
            A_b : constant Unsigned_Byte := Get_Byte_From_Tensor (Src, S);
            R_b : constant Unsigned_Byte :=
              Get_Byte_From_Tensor (Out_Word_Tensor, S);
            A_i : constant Integer := Q07_To_Int (A_b);
            R_i : constant Integer := Q07_To_Int (R_b);
         begin
            if(R_i /= Sigmoid_Sw (A_i)) then
               OK := False;
               exit;
            end if;
         end;
      end loop;
      Print_Tensor_Q07 (Name => "Input Tensor", Data => Src, Dimension => N);
      Print_Tensor_Q07
        (Name      => "Result Sigmoid 8x8",
         Data      => Out_Word_Tensor,
         Dimension => N);
      Print_Result ("Sigmoid 8x8 samples match", OK);
   end Test_Sigmoid_8x8;

   --4) Test ReLU on a larger tensor to show logic works for tensors larger than 8x8
   procedure Test_ReLU_10x10 is
      N               : constant Natural := 10;
      Words           : constant Natural := Tensor_Words (N);
      Src             : Word_Array (0 .. Words - 1) := (others => 0);
      Out_Word_Tensor : Word_Array (0 .. Words - 1) := (others => 0);
      OK              : Boolean := True;
      Samples         : constant array (Natural range <>) of Natural :=
        (0, 9, 24, 50, 75, 99);
   begin
      Build_Tensor (Words, Src);
      Set_Dim (N);
      Write_Words_In_A (Src);
      Apply_ReLU_All_Words (N);
      Read_Words_From_R (Out_Word_Tensor);

      for S of Samples loop
         declare
            A_b : constant Unsigned_Byte := Get_Byte_From_Tensor (Src, S);
            R_b : constant Unsigned_Byte :=
              Get_Byte_From_Tensor (Out_Word_Tensor, S);
            A_i : constant Integer := Q07_To_Int (A_b);
            R_i : constant Integer := Q07_To_Int (R_b);
         begin
            if(R_i /= ReLU_Sw (A_i)) then
               OK := False;
               exit;
            end if;
         end;
      end loop;
      Print_Tensor_Q07 (Name => "Input Tensor", Data => Src, Dimension => N);
      Print_Tensor_Q07
        (Name => "Result ReLU 10x10", Data => Out_Word_Tensor, Dimension => N);
      Print_Result ("ReLU 10x10 samples match", OK);
   end Test_ReLU_10x10;

begin
   Uart0.Init (19200);
   Put_Line ("Reunning Test Cases----------------");
   Test_A_Window_Echo_4x4;
   Test_ReLU_8x8;
   Test_Sigmoid_8x8;
   Test_ReLU_10x10;
   Put_Line ("Tests Done-------------------------");
   loop
      null;
   end loop;
end Test_Cases_Neorv32;
