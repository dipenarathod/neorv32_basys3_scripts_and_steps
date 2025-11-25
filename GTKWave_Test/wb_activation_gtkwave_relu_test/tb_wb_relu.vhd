--Uing VS Code for VHDL (first time)
--First time making a testbench this complicated as well
--Copied the interface from wb_peripheral.vhd
--For terminologyy: https://vhdlwhiz.com/terminology/testbench/
--Detailed info about Wishbone signals: https://wishbone-interconnect.readthedocs.io/en/latest/02_interface.html#:~:text=STB_O%5D%20signal%20descriptions.-,STB_O,interface%20such%20as%20%5BSEL_O()%5D.
--Testbench guide: https://fpgatutorial.com/how-to-write-a-basic-testbench-using-vhdl/
--Used VHDL Formatter by Vinrobot
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
LIBRARY work;
ENTITY tb_wb_relu IS
END ENTITY;

ARCHITECTURE sim OF tb_wb_relu IS
  --Copied interface from wb_peripheral
  SIGNAL clk : STD_ULOGIC := '0';--system clock
  SIGNAL reset : STD_ULOGIC := '1';--synchronous reset
  SIGNAL i_wb_cyc : STD_ULOGIC := '0';--Wishbone: cycle valid
  SIGNAL i_wb_stb : STD_ULOGIC := '0';--Wishbone: strobe
  SIGNAL i_wb_we : STD_ULOGIC := '0';--Wishbone: 1=write, 0=read
  SIGNAL i_wb_addr : STD_ULOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');--Wishbone: address
  SIGNAL i_wb_data : STD_ULOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');--Wishbone: write data
  SIGNAL o_wb_ack : STD_ULOGIC;--Wishbone: acknowledge
  SIGNAL o_wb_stall : STD_ULOGIC;--Wishbone: stall (always '0')
  SIGNAL o_wb_data : STD_ULOGIC_VECTOR(31 DOWNTO 0);--Wishbone: read data

  --Cycle counter (what this test bench is being written for)
  SIGNAL cycle_cnt : NATURAL := 0;

  --Addresses (skippng B, C, and pooling registers)
  CONSTANT BASE_ADDRESS : unsigned(31 DOWNTO 0) := x"90000000";
  CONSTANT CTRL_REG_ADDRESS : unsigned(31 DOWNTO 0) := x"90000008";
  CONSTANT STATUS_REG_ADDRESS : unsigned(31 DOWNTO 0) := x"9000000C";
  CONSTANT DIM_REG_ADDRESS : unsigned(31 DOWNTO 0) := x"90000010";
  CONSTANT WORD_INDEX_ADDRESS : unsigned(31 DOWNTO 0) := x"9000001C";
  CONSTANT TENSOR_A_BASE : unsigned(31 DOWNTO 0) := x"90001000";
  CONSTANT TENSOR_R_BASE : unsigned(31 DOWNTO 0) := x"90004000";

  --ReLU opcode (can add more for testing)
  CONSTANT OP_RELU : STD_ULOGIC_VECTOR(4 DOWNTO 0) := "00101";

BEGIN
  --100MHz clock = 10ns period = 5ns high and 5ns low
  clk <= NOT clk AFTER 5 ns;
  reset <= '1', '0' AFTER 5 ns;
  --Cycle counter (the most important funciton
  PROCESS (clk)
  BEGIN
    IF rising_edge(clk) THEN
      cycle_cnt <= cycle_cnt + 1;
    END IF;
  END PROCESS;

  --Device under test (DUT) is the peripheral. Instantiate it
  dut : ENTITY work.wb_peripheral_top
    PORT MAP(
      clk => clk,
      reset => reset,
      i_wb_cyc => i_wb_cyc,
      i_wb_stb => i_wb_stb,
      i_wb_we => i_wb_we,
      i_wb_addr => i_wb_addr,
      i_wb_data => i_wb_data,
      o_wb_ack => o_wb_ack,
      o_wb_stall => o_wb_stall,
      o_wb_data => o_wb_data
    );
  stimulus : PROCESS
    VARIABLE status : STD_ULOGIC_VECTOR(31 DOWNTO 0);
    VARIABLE ctrl_word : STD_ULOGIC_VECTOR(31 DOWNTO 0);
    VARIABLE start_cyc : NATURAL;
    VARIABLE done_cyc : NATURAL;
    VARIABLE i : INTEGER;

    --array of 16 words, each containg 4 bytes = 64 bytes = 8x8 tensor
    TYPE word_array IS ARRAY (0 TO 15) OF STD_ULOGIC_VECTOR(31 DOWNTO 0);
    CONSTANT tensor : word_array := (
      x"807F0010", x"FF010203", x"F0001000", x"7F800010",
      x"01020304", x"F0F1F2F3", x"10111213", x"80818283",
      x"20212223", x"7F7E7D7C", x"00000001", x"FEFDFCFB",
      x"30313233", x"40414243", x"50515253", x"60616263"
    );

    VARIABLE result_word : STD_ULOGIC_VECTOR(31 DOWNTO 0);
    --Wishbone write
    PROCEDURE wb_write(
      addr : IN unsigned(31 DOWNTO 0);
      data : IN STD_ULOGIC_VECTOR(31 DOWNTO 0)
    ) IS
    BEGIN
      i_wb_addr <= STD_ULOGIC_VECTOR(addr);
      i_wb_data <= data;
      i_wb_we <= '1'; --Write
      i_wb_cyc <= '1'; --Valid cycle
      i_wb_stb <= '1'; --Peripheral selected

      --wait for peripheral to assert termination of a valid clock cycle
      WAIT UNTIL rising_edge(clk);
      WHILE o_wb_ack = '0' LOOP
        WAIT UNTIL rising_edge(clk);
      END LOOP;

      i_wb_cyc <= '0'; --Cycle over
      i_wb_stb <= '0';-- peripheral not selected
      i_wb_we <= '0';--Not writing
    END PROCEDURE;

    --Wishbone read
    PROCEDURE wb_read(
      addr : IN unsigned(31 DOWNTO 0);
      data : OUT STD_ULOGIC_VECTOR(31 DOWNTO 0)
    ) IS
    BEGIN
      i_wb_addr <= STD_ULOGIC_VECTOR(addr);
      i_wb_we <= '0'; --Reading
      i_wb_cyc <= '1'; --Valid cycle
      i_wb_stb <= '1'; --Peripheral selected

      --wait for peripheral to assert termination of a valid clock cycle
      WAIT UNTIL rising_edge(clk);
      WHILE o_wb_ack = '0' LOOP
        WAIT UNTIL rising_edge(clk);
      END LOOP;

      data := o_wb_data;
      i_wb_cyc <= '0'; --Cycle over
      i_wb_stb <= '0';-- peripheral not selected
    END PROCEDURE;

  BEGIN
    --Wait for the Reset to be released before 
    WAIT UNTIL (reset = '0');
    --Set DIM = 8
    wb_write(DIM_REG_ADDRESS, x"00000008");

    --Write 8x8 tensor into Tensor A
    FOR i IN 0 TO 15 LOOP
      wb_write(TENSOR_A_BASE + to_unsigned(4 * i, 32),
      tensor(i));
    END LOOP;

    --For each packed word, run ReLU and measure cycles
    FOR i IN 0 TO 15 LOOP
      --Program WORD_INDEX = i
      wb_write(WORD_INDEX_ADDRESS, STD_ULOGIC_VECTOR(to_unsigned(i, 32)));

      --Build CTRL word: [5:1]=OP_RELU, [0]=start=1
      ctrl_word := (OTHERS => '0');
      ctrl_word(5 DOWNTO 1) := OP_RELU;
      ctrl_word(0) := '1';

      --Record starting cycle count (similar to ada timining measurements logic)
      start_cyc := cycle_cnt;
      wb_write(CTRL_REG_ADDRESS, ctrl_word);

      --Poll status register done bit
      LOOP
        wb_read(STATUS_REG_ADDRESS, status);
        EXIT WHEN status(1) = '1';
      END LOOP;
      done_cyc := cycle_cnt;

      REPORT "Word " & INTEGER'image(i) &
        " ReLU latency (cycles) = " &
        INTEGER'image(done_cyc - start_cyc);
    END LOOP;

    WAIT FOR 100 ns;
    REPORT "Simulation finished" SEVERITY failure;
  END PROCESS;
END ARCHITECTURE;
