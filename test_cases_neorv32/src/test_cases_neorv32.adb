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

procedure Test_Cases_Neorv32 is

   Clock_Hz     : constant Unsigned_64 := 100_000_000;
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
      if (Y < 0) then
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
      -- Start_Time, Stop_Time : Time;
      -- Elapsed_Time          : Time_Span;
      -- Start_Time : UInt64:=1;
      -- End_Time   : UInt64:=1;
      -- Clock_Speed : UInt64 := 100_000_000;
      -- Time_Res: UInt64;
   begin
      Build_Tensor (Words, Tx);
      --Set_Dim (N);
      --Start_Time:= Read_CSR(Mcycle);
      --     Start_Time := Clock;
      Start_Cycles := Read_Cycle;
      Write_Words_In_A (Tx);
      End_Cycles := Read_Cycle;
      Delta_Cycles := End_Cycles - Start_Cycles;
      Print_Time ("Time taken to write words to A:", Delta_Cycles);
      -- Stop_Time := Clock;
      -- Elapsed_Time := Stop_Time - Start_Time;

      -- Put_Line
      --   ("Elapsed time: "
      --    & Duration'Image (To_Duration (Elapsed_Time))
      --    & " seconds");
      --End_Time:= Read_CSR(Mcycle);
      -- Time_Res := (End_Time - Start_Time) / Clock_Speed;
      -- Put_Line (UInt64'Image (Time_Res));
      --Not using Read_Words_From_A directly because then words need to be checked individually. Waste of time
      for i in 0 .. Words - 1 loop
         Rx (i) := Read_Word_From_A (i);
         if (Rx (i) /= Tx (i)) then
            Same := False;
            exit;
         end if;
      end loop;
      --Print_Tensor_Q07 (Name => "Input Tensor", Data => Tx, Dimension => N);
      --Print_Tensor_Q07 (Name => "Read Tensor", Data => Rx, Dimension => N);
      Print_Result ("Words written == words read from A", Same);
   end Test_A_Window_Echo_4x4;

   --Invalid opcode should keep R unchanged
   procedure Test_Invalid_Opcode_Result is
      N                  : constant Natural := 4;
      Words              : constant Natural := Tensor_Words (N);
      Invalid_Opcode     : constant Word := 99;
      OB0, OB1, OB2, OB3 : Unsigned_Byte :=
        0; --Bytes extracted from a word (original R)
      B0, B1, B2, B3     : Unsigned_Byte := 0; --Bytes extracted from a word
      Original           : Word_Array (0 .. Words - 1) := (others => 0);
      Rx                 : Word_Array (0 .. Words - 1) := (others => 0);
      OK                 : Boolean := True;
   begin
      Start_Cycles := Read_Cycle;
      Read_Words_From_R (Original);
      End_Cycles := Read_Cycle;
      Delta_Cycles := End_Cycles - Start_Cycles;
      Print_Time ("Time taken to read words from R:", Delta_Cycles);
      Set_Dim (N);
      Perform_Op (Invalid_Opcode);
      Wait_While_Busy;
      Write_Reg (CTRL_Addr, 0); --De-assert start
      Read_Words_From_R (Rx);
      for I in Rx'Range loop
         Unpack_Four_Bytes
           (Original (i), B0 => OB0, B1 => OB1, B2 => OB2, B3 => OB3);
         Unpack_Four_Bytes
           (W => Rx (i), B0 => B0, B1 => B1, B2 => B2, B3 => B3);
         if (B0 /= OB0 or B1 /= OB1 or B2 /= OB2 or B3 /= OB3) then
            OK := False;
            exit;
         end if;
      end loop;
      --Print_Tensor_Q07 ("Original Result Tesnsor", Original, N);
      --Print_Tensor_Q07 ("Result Tensor", Rx, N);
      Print_Result ("Invalid opcode should keeps R unchanged", OK);
   end Test_Invalid_Opcode_Result;


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
      --Set_Dim (N);
      Write_Words_In_A (Src);
      Start_Cycles := Read_Cycle;
      Apply_ReLU_All_Words (N);
      End_Cycles := Read_Cycle;
      Delta_Cycles := End_Cycles - Start_Cycles;
      Print_Time ("Time taken to apply ReLU to A:", Delta_Cycles);
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
      --Print_Tensor_Q07 (Name => "Input Tensor", Data => Src, Dimension => N);
      --Print_Tensor_Q07
      --  (Name => "Result ReLU 8x8", Data => Out_Word_Tensor, Dimension => N);
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
      --Set_Dim (N);
      Write_Words_In_A (Src);
      Start_Cycles := Read_Cycle;
      Apply_Sigmoid_All_Words (N);
      End_Cycles := Read_Cycle;
      Delta_Cycles := End_Cycles - Start_Cycles;
      Print_Time ("Time taken to apply Sigmoid to A:", Delta_Cycles);
      Read_Words_From_R (Out_Word_Tensor);

      for S of Samples loop
         declare
            A_b : constant Unsigned_Byte := Get_Byte_From_Tensor (Src, S);
            R_b : constant Unsigned_Byte :=
              Get_Byte_From_Tensor (Out_Word_Tensor, S);
            A_i : constant Integer := Q07_To_Int (A_b);
            R_i : constant Integer := Q07_To_Int (R_b);
         begin
            if (R_i /= Sigmoid_Sw (A_i)) then
               OK := False;
               exit;
            end if;
         end;
      end loop;
      --Print_Tensor_Q07 (Name => "Input Tensor", Data => Src, Dimension => N);
      --Print_Tensor_Q07
      --  (Name      => "Result Sigmoid 8x8",
      --   Data      => Out_Word_Tensor,
      --   Dimension => N);
      Print_Result ("Sigmoid 8x8 samples match", OK);
   end Test_Sigmoid_8x8;

   --4) Test ReLU on a larger tensor to show logic works for tensors larger than 8x8
        procedure Test_ReLU_16x16 is
        N               : constant Natural := 16;
        Words           : constant Natural := Tensor_Words (N);
        Src             : Word_Array (0 .. Words - 1) := (others => 0);
        Out_Word_Tensor : Word_Array (0 .. Words - 1) := (others => 0);
        OK              : Boolean := True;
        Samples         : constant array (Natural range <>) of Natural :=
          (0, 90, 124, 220);
     begin
        Build_Tensor (Words, Src);
        --Set_Dim (N);
        Write_Words_In_A (Src);
        Start_Cycles := Read_Cycle;
        Apply_ReLU_All_Words (N);
        End_Cycles := Read_Cycle;
        Delta_Cycles := End_Cycles - Start_Cycles;
        Print_Time ("Time taken to apply 16x16 ReLU to A:", Delta_Cycles);
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
        --  Print_Tensor_Q07 (Name => "Input Tensor", Data => Src, Dimension => N);
        --  Print_Tensor_Q07
        --    (Name => "Result ReLU 16x16", Data => Out_Word_Tensor, Dimension => N);
        Print_Result ("ReLU 16x16 samples match", OK);
     end Test_ReLU_16x16;

   procedure Test_ReLU_NxN_Timings(Dim : Natural)  is
      N               : constant Natural := Dim;
      Words           : constant Natural := Tensor_Words (N);
      Src             : Word_Array (0 .. Words - 1) := (others => 0);
   begin
      Build_Tensor (Words, Src);
      --Set_Dim (N);
      Write_Words_In_A (Src);
      Start_Cycles := Read_Cycle;
      Apply_ReLU_All_Words (N);
      End_Cycles := Read_Cycle;
      Delta_Cycles := End_Cycles - Start_Cycles;
      Print_Time ("Time taken to apply " & Natural'Image(N) & "x" & Natural'Image(N) & "ReLU to A:", Delta_Cycles);
   end Test_ReLU_NxN_Timings;

   --5) Test 2x2 MaxPool on a hard-coded 4x4 tensor
   procedure Test_MaxPool_2x2_8x8 is
      N        : constant Natural := 8;
      Words_A  : constant Natural := Tensor_Words (N);
      --Hard-coded 8x8 tensor (row-major), int8 values mapped to Q0.7
      --Rows:
      --[  4,   8,  -12,  -4,   4,  8,  -12,  -4]
      --[  0,   4,   8,   12,   0,  4,   8,   12]
      --[ -16, -12,  16,  20, -16, -12,  16,  20]
      --[  -8,  -4,  24,  28,  -8,  -4,  24,  28]
      --[ 120, 121,  64, 127, 120, 121,  64,  127]
      --[ 80,   81,  75,  82,  80,  81,  75,  82]
      --[ 90,   84,  74,  28, -90, -84, -74, -28]
      --[  8,   -4, -24,  -8. -80, -81, -75, -82]
      A_Tensor : constant Word_Array (0 .. Words_A - 1) :=
        (0  =>
           Pack_Four_Bytes
             (Int_To_Q07 (4),
              Int_To_Q07 (8),
              Int_To_Q07 (-12),
              Int_To_Q07 (-4)),
         1  =>
           Pack_Four_Bytes
             (Int_To_Q07 (4),
              Int_To_Q07 (8),
              Int_To_Q07 (-12),
              Int_To_Q07 (-4)),
         2  =>
           Pack_Four_Bytes
             (Int_To_Q07 (0), Int_To_Q07 (4), Int_To_Q07 (8), Int_To_Q07 (12)),
         3  =>
           Pack_Four_Bytes
             (Int_To_Q07 (0), Int_To_Q07 (4), Int_To_Q07 (8), Int_To_Q07 (12)),
         4  =>
           Pack_Four_Bytes
             (Int_To_Q07 (-16),
              Int_To_Q07 (-12),
              Int_To_Q07 (16),
              Int_To_Q07 (20)),
         5  =>
           Pack_Four_Bytes
             (Int_To_Q07 (-16),
              Int_To_Q07 (-12),
              Int_To_Q07 (16),
              Int_To_Q07 (20)),
         6  =>
           Pack_Four_Bytes
             (Int_To_Q07 (-8),
              Int_To_Q07 (-4),
              Int_To_Q07 (24),
              Int_To_Q07 (28)),
         7  =>
           Pack_Four_Bytes
             (Int_To_Q07 (-8),
              Int_To_Q07 (-4),
              Int_To_Q07 (24),
              Int_To_Q07 (28)),
         8  =>
           Pack_Four_Bytes
             (Int_To_Q07 (120),
              Int_To_Q07 (121),
              Int_To_Q07 (64),
              Int_To_Q07 (127)),
         9  =>
           Pack_Four_Bytes
             (Int_To_Q07 (120),
              Int_To_Q07 (121),
              Int_To_Q07 (64),
              Int_To_Q07 (127)),
         10 =>
           Pack_Four_Bytes
             (Int_To_Q07 (80),
              Int_To_Q07 (81),
              Int_To_Q07 (75),
              Int_To_Q07 (82)),
         11 =>
           Pack_Four_Bytes
             (Int_To_Q07 (80),
              Int_To_Q07 (81),
              Int_To_Q07 (75),
              Int_To_Q07 (82)),
         12 =>
           Pack_Four_Bytes
             (Int_To_Q07 (90),
              Int_To_Q07 (84),
              Int_To_Q07 (74),
              Int_To_Q07 (28)),
         13 =>
           Pack_Four_Bytes
             (Int_To_Q07 (-90),
              Int_To_Q07 (-84),
              Int_To_Q07 (-74),
              Int_To_Q07 (-28)),
         14 =>
           Pack_Four_Bytes
             (Int_To_Q07 (8),
              Int_To_Q07 (-4),
              Int_To_Q07 (-24),
              Int_To_Q07 (-8)),
         15 =>
           Pack_Four_Bytes
             (Int_To_Q07 (-80),
              Int_To_Q07 (-81),
              Int_To_Q07 (-75),
              Int_To_Q07 (-82)));
      Out_N    : constant Natural := N / 2; --Resulting tensor dimensions
      Words_R  : constant Natural := Tensor_Words (Out_N); --Words in tensor R
      R_Tensor : Word_Array (0 .. Words_R - 1) := (others => 0);
      OK       : Boolean := True;

      --Expected MaxPool 4x4 result:
      Expected : constant array (Natural range 0 .. 15) of Integer :=
        (8, 12, 8, 12, -4, 28, -4, 28, 121, 127, 121, 127, 90, 74, -80, -28);
   begin
      Set_Dim (N);
      Write_Words_In_A (A_Tensor);
      Start_Cycles := Read_Cycle;
      Apply_MaxPool_2x2_All_Words (N);
      End_Cycles := Read_Cycle;
      Delta_Cycles := End_Cycles - Start_Cycles;
      Print_Time ("Time taken to apply 2x2 Maxpool to 8x8 A:", Delta_Cycles);
      Read_Words_From_R (R_Tensor);

      --Verify all 16 outputs
      for index in 0 .. 15 loop
         declare
            rb : constant Unsigned_Byte :=
              Get_Byte_From_Tensor (R_Tensor, index);
            ri : constant Integer := Q07_To_Int (rb);
         begin
            if (ri /= Expected (index)) then
               OK := False;
               exit;
            end if;
         end;
      end loop;

      --Print_Tensor_Q07 ("Input 8x8", A_Tensor, N);
      --Print_Tensor_Q07 ("MaxPool 2x2 -> 4x4", R_Tensor, Out_N);
      Print_Result ("MaxPool 2x2 on hard-coded 8x8", OK);
   end Test_MaxPool_2x2_8x8;

   --6) Test 2x2 AvgPool on the same hard-coded 4x4 tensor
   procedure Test_AvgPool_2x2_4x4 is
      N        : constant Natural := 4;
      Words_A  : constant Natural := Tensor_Words (N);
      A_Tensor : constant Word_Array (0 .. Words_A - 1) :=
        (0 =>
           Pack_Four_Bytes
             (Int_To_Q07 (4),
              Int_To_Q07 (8),
              Int_To_Q07 (-12),
              Int_To_Q07 (-4)),
         1 =>
           Pack_Four_Bytes
             (Int_To_Q07 (0), Int_To_Q07 (4), Int_To_Q07 (8), Int_To_Q07 (12)),
         2 =>
           Pack_Four_Bytes
             (Int_To_Q07 (-16),
              Int_To_Q07 (-12),
              Int_To_Q07 (16),
              Int_To_Q07 (20)),
         3 =>
           Pack_Four_Bytes
             (Int_To_Q07 (-8),
              Int_To_Q07 (-4),
              Int_To_Q07 (24),
              Int_To_Q07 (28)));
      Out_N    : constant Natural := N / 2; --2
      Words_R  : constant Natural := Tensor_Words (Out_N); --1
      R_Tensor : Word_Array (0 .. Words_R - 1) := (others => 0);
      OK       : Boolean := True;

      --Expected AvgPool 2x2 result
      Expected : constant array (Natural range 0 .. 3) of Integer :=
        (4, 1, -10, 22);
   begin
      Set_Dim (N);
      Write_Words_In_A (A_Tensor);
      Start_Cycles := Read_Cycle;
      Apply_AvgPool_2x2_All_Words (N);
      End_Cycles := Read_Cycle;
      Delta_Cycles := End_Cycles - Start_Cycles;
      Print_Time ("Time taken to apply 2x2 Maxpool to 4x4 A:", Delta_Cycles);
      Read_Words_From_R (R_Tensor);

      --Verify all 4 outputs
      for index in 0 .. 3 loop
         declare
            rb : constant Unsigned_Byte :=
              Get_Byte_From_Tensor (R_Tensor, index);
            ri : constant Integer := Q07_To_Int (rb);
         begin
            if (ri /= Expected (index)) then
               OK := False;
               exit;
            end if;
         end;
      end loop;

      --Print_Tensor_Q07 ("Input 4x4", A_Tensor, N);
      --Print_Tensor_Q07 ("AvgPool 2x2 -> 2x2", R_Tensor, Out_N);
      Print_Result ("AvgPool 2x2 on hard-coded 4x4", OK);
   end Test_AvgPool_2x2_4x4;

--  procedure Test_MaxPool_2x2_16x16_Timings is
--        N               : constant Natural := 16;
--        Words           : constant Natural := Tensor_Words (N);
--        Src             : Word_Array (0 .. Words - 1) := (others => 0);
--        Out_Word_Tensor : Word_Array (0 .. Words - 1) := (others => 0);
--     begin
--        Build_Tensor (Words, Src);
--        --Set_Dim (N);
--        Write_Words_In_A (Src);
--        Start_Cycles := Read_Cycle;
--        Apply_MaxPool_2x2_All_Words (N);
--        End_Cycles := Read_Cycle;
--        Delta_Cycles := End_Cycles - Start_Cycles;
--        Print_Time ("Time taken to apply 16x16 MaxPool 2x2 to A:", Delta_Cycles);
--     end Test_MaxPool_2x2_16x16_Timings;

procedure Test_MaxPool_2x2_NxN_Timings(Dim : Natural) is
      N               : constant Natural := Dim;
      Words           : constant Natural := Tensor_Words (N);
      Src             : Word_Array (0 .. Words - 1) := (others => 0);
      Out_Word_Tensor : Word_Array (0 .. Words - 1) := (others => 0);
      Out_N    : constant Natural := N / 2;
   begin
      Build_Tensor (Words, Src);
      --Set_Dim (N);
      Write_Words_In_A (Src);
      Start_Cycles := Read_Cycle;
      Apply_MaxPool_2x2_All_Words (N);
      End_Cycles := Read_Cycle;
      Delta_Cycles := End_Cycles - Start_Cycles;
      Print_Time ("Time taken to apply "& Natural'Image(N) & "x" & Natural'Image(N) & " MaxPool 2x2 to A:", Delta_Cycles);
      --  Read_Words_From_R (Out_Word_Tensor);
      --  Print_Tensor_Q07 ("Input 28x28", Src, N);
      --  Print_Tensor_Q07 ("MaxPool 2x2 -> 14x14", Out_Word_Tensor, Out_N);
   end Test_MaxPool_2x2_NxN_Timings;

begin
   Uart0.Init (19200);
   Put_Line ("Reunning Test Cases----------------");
   Test_A_Window_Echo_4x4;
   Test_Invalid_Opcode_Result;
   Test_ReLU_8x8;
   Test_Sigmoid_8x8;
   Test_ReLU_16x16;
   --Test_ReLU_NxN_Timings (4);
   --Test_ReLU_NxN_Timings (8);
   --Test_ReLU_NxN_Timings (12);
   --Test_ReLU_NxN_Timings (16);
   --Test_ReLU_NxN_Timings (20);
   --Test_ReLU_NxN_Timings (24);
   --Test_ReLU_NxN_Timings (28);
   Test_MaxPool_2x2_8x8;
   Test_AvgPool_2x2_4x4;
   --Test_MaxPool_2x2_16x16_Timings;
   --Test_MaxPool_2x2_NxN_Timings(4);
   --Test_MaxPool_2x2_NxN_Timings(8);
   --Test_MaxPool_2x2_NxN_Timings(12);
   --Test_MaxPool_2x2_NxN_Timings(16);
   --Test_MaxPool_2x2_NxN_Timings(20);
   --Test_MaxPool_2x2_NxN_Timings(24);
   --Test_MaxPool_2x2_NxN_Timings(28);
   Put_Line ("Tests Done-------------------------");
   loop
      null;
   end loop;
end Test_Cases_Neorv32;
