with Ada_Ml_Library;      use Ada_Ml_Library;
with Interfaces;          use Interfaces;
with Ada.Text_IO;         use Ada.Text_IO;
with Uart0;
with Runtime_Support;
with Ada_Ml_Library;      use Ada_Ml_Library;
with Interfaces;          use Interfaces;
with Ada.Text_IO;         use Ada.Text_IO;
with Uart0;
with neorv32;             use neorv32;
with RISCV.CSR;           use RISCV.CSR;
with riscv.CSR_Generic;   use riscv.CSR_Generic;
--with Ada.Real_Time;  use Ada.Real_Time;
with System.Machine_Code; use System.Machine_Code;

procedure Timing_Tests_Neorv32 is
   Clock_Hz     : constant Unsigned_64 := 72_000_000;
   Start_Cycles : Unsigned_64;
   End_Cycles   : Unsigned_64;
   Delta_Cycles : Unsigned_64;
   --Read 64-bit mcycle counter
   --Copied Read_CSR from riscvcsr_generic.adb because I can't use that directly here (as it is a generic subprogram)
   function Read_Cycle return Unsigned_64 is
      Low  : Unsigned_32;
      High : Unsigned_32;
   begin
      --Read low 32 bits
      Asm
        ("csrr %0, mcycle",
         Outputs  => Unsigned_32'Asm_Output ("=r", Low),
         Volatile => True);

      --Read high 32 bits
      Asm
        ("csrr %0, mcycleh",
         Outputs  => Unsigned_32'Asm_Output ("=r", High),
         Volatile => True);

      return Shift_Left (Unsigned_64 (High), 32) or Unsigned_64 (Low);
   end Read_Cycle;


   procedure Print_Time (Name : String; Cycles : Unsigned_64) is
      Microseconds : constant Unsigned_64 := (Cycles * 1_000_000) / Clock_Hz;
   begin
      Put_Line (Name & " cycles =" & Unsigned_64'Image (Cycles));
      Put_Line (Name & " time (us) =" & Unsigned_64'Image (Microseconds));
   end Print_Time;
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

   procedure Test_ReLU_NxN_Timings (Dim : Natural) is
      N     : constant Natural := Dim;
      Words : constant Natural := Tensor_Words (N);
      Src   : Word_Array (0 .. Words - 1) := (others => 0);
   begin
      Build_Tensor (Words, Src);
      --Set_Dim (N);
      Write_Words_In_A (Src);
      Start_Cycles := Read_Cycle;
      Apply_ReLU_All_Words (N);
      End_Cycles := Read_Cycle;
      Delta_Cycles := End_Cycles - Start_Cycles;
      Print_Time
        ("Time taken to apply "
         & Natural'Image (N)
         & "x"
         & Natural'Image (N)
         & "ReLU to A:",
         Delta_Cycles);
   end Test_ReLU_NxN_Timings;

   procedure Test_MaxPool_2x2_NxN_Timings (Dim : Natural) is
      N               : constant Natural := Dim;
      Words           : constant Natural := Tensor_Words (N);
      Src             : Word_Array (0 .. Words - 1) := (others => 0);
      Out_Word_Tensor : Word_Array (0 .. Words - 1) := (others => 0);
      Out_N           : constant Natural := N / 2;
   begin
      Build_Tensor (Words, Src);
      --Set_Dim (N);
      Write_Words_In_A (Src);
      Start_Cycles := Read_Cycle;
      Apply_MaxPool_2x2_All_Words (N);
      End_Cycles := Read_Cycle;
      Delta_Cycles := End_Cycles - Start_Cycles;
      Print_Time
        ("Time taken to apply "
         & Natural'Image (N)
         & "x"
         & Natural'Image (N)
         & " MaxPool 2x2 to A:",
         Delta_Cycles);
   --  Read_Words_From_R (Out_Word_Tensor);
   --  Print_Tensor_Q07 ("Input 28x28", Src, N);
   --  Print_Tensor_Q07 ("MaxPool 2x2 -> 14x14", Out_Word_Tensor, Out_N);
   end Test_MaxPool_2x2_NxN_Timings;
begin
   Uart0.Init (19200);
   Put_Line ("Reunning Test Cases----------------");
   Put_Line
     ("Times For ReLU can be applied for Sigmoid. Times for MaxPool can be applied for AvgPool");
   Test_ReLU_NxN_Timings (4);
   Test_ReLU_NxN_Timings (8);
   Test_ReLU_NxN_Timings (12);
   Test_ReLU_NxN_Timings (16);
   Test_ReLU_NxN_Timings (20);
   Test_ReLU_NxN_Timings (24);
   Test_ReLU_NxN_Timings (28);
   Test_ReLU_NxN_Timings (50);
   Test_MaxPool_2x2_NxN_Timings (4);
   Test_MaxPool_2x2_NxN_Timings (8);
   Test_MaxPool_2x2_NxN_Timings (12);
   Test_MaxPool_2x2_NxN_Timings (16);
   Test_MaxPool_2x2_NxN_Timings (20);
   Test_MaxPool_2x2_NxN_Timings (24);
   Test_MaxPool_2x2_NxN_Timings (50);
   Put_Line ("Tests Done-------------------------");
   loop
      null;
   end loop;
end Timing_Tests_Neorv32;
