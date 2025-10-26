library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity neorv32_basys3_top is
  generic (
    CLOCK_FREQUENCY : natural := 100_000_000  -- Basys 3 has 100 MHz clock
  );
  port (
    -- Clock and Reset (from Basys 3 board)
    clk_i      : in  std_logic;                    -- 100 MHz clock
    rstn_i     : in  std_logic;                    -- Active-low reset (BTN0)

    -- UART0 Interface (to USB-UART bridge on Basys 3)
    uart0_txd_o : out std_ulogic; -- UART0 send data
    uart0_rxd_i : in  std_ulogic  -- UART0 receive data

  );
end entity;

architecture rtl of neorv32_basys3_top is

  -- AXI4 bridge component
  component xbus2axi4_bridge
  generic (
    BURST_EN  : boolean;
    BURST_LEN : natural range 4 to 1024
  );
  port (
    clk           : in  std_logic;
    resetn        : in  std_logic;
    xbus_adr_i    : in  std_ulogic_vector(31 downto 0);
    xbus_dat_i    : in  std_ulogic_vector(31 downto 0);
    xbus_cti_i    : in  std_ulogic_vector(2 downto 0);
    xbus_tag_i    : in  std_ulogic_vector(2 downto 0);
    xbus_we_i     : in  std_ulogic;
    xbus_sel_i    : in  std_ulogic_vector(3 downto 0);
    xbus_stb_i    : in  std_ulogic;
    xbus_ack_o    : out std_ulogic;
    xbus_err_o    : out std_ulogic;
    xbus_dat_o    : out std_ulogic_vector(31 downto 0);
    m_axi_awaddr  : out std_logic_vector(31 downto 0);
    m_axi_awlen   : out std_logic_vector(7 downto 0);
    m_axi_awsize  : out std_logic_vector(2 downto 0);
    m_axi_awburst : out std_logic_vector(1 downto 0);
    m_axi_awcache : out std_logic_vector(3 downto 0);
    m_axi_awprot  : out std_logic_vector(2 downto 0);
    m_axi_awvalid : out std_logic;
    m_axi_awready : in  std_logic;
    m_axi_wdata   : out std_logic_vector(31 downto 0);
    m_axi_wstrb   : out std_logic_vector(3 downto 0);
    m_axi_wlast   : out std_logic;
    m_axi_wvalid  : out std_logic;
    m_axi_wready  : in  std_logic;
    m_axi_araddr  : out std_logic_vector(31 downto 0);
    m_axi_arlen   : out std_logic_vector(7 downto 0);
    m_axi_arsize  : out std_logic_vector(2 downto 0);
    m_axi_arburst : out std_logic_vector(1 downto 0);
    m_axi_arcache : out std_logic_vector(3 downto 0);
    m_axi_arprot  : out std_logic_vector(2 downto 0);
    m_axi_arvalid : out std_logic;
    m_axi_arready : in  std_logic;
    m_axi_rdata   : in  std_logic_vector(31 downto 0);
    m_axi_rresp   : in  std_logic_vector(1 downto 0);
    m_axi_rlast   : in  std_logic;
    m_axi_rvalid  : in  std_logic;
    m_axi_rready  : out std_logic;
    m_axi_bresp   : in  std_logic_vector(1 downto 0);
    m_axi_bvalid  : in  std_logic;
    m_axi_bready  : out std_logic
  );
  end component;

  -- Internal signals
  signal xbus_req : xbus_req_t;
  signal xbus_rsp : xbus_rsp_t;

  -- AXI4 signals (internal - connect your NPU here)
  signal m_axi_awaddr  : std_logic_vector(31 downto 0);
  signal m_axi_awlen   : std_logic_vector(7 downto 0);
  signal m_axi_awsize  : std_logic_vector(2 downto 0);
  signal m_axi_awburst : std_logic_vector(1 downto 0);
  signal m_axi_awcache : std_logic_vector(3 downto 0);
  signal m_axi_awprot  : std_logic_vector(2 downto 0);
  signal m_axi_awvalid : std_logic;
  signal m_axi_awready : std_logic;
  signal m_axi_wdata   : std_logic_vector(31 downto 0);
  signal m_axi_wstrb   : std_logic_vector(3 downto 0);
  signal m_axi_wlast   : std_logic;
  signal m_axi_wvalid  : std_logic;
  signal m_axi_wready  : std_logic;
  signal m_axi_araddr  : std_logic_vector(31 downto 0);
  signal m_axi_arlen   : std_logic_vector(7 downto 0);
  signal m_axi_arsize  : std_logic_vector(2 downto 0);
  signal m_axi_arburst : std_logic_vector(1 downto 0);
  signal m_axi_arcache : std_logic_vector(3 downto 0);
  signal m_axi_arprot  : std_logic_vector(2 downto 0);
  signal m_axi_arvalid : std_logic;
  signal m_axi_arready : std_logic;
  signal m_axi_rdata   : std_logic_vector(31 downto 0);
  signal m_axi_rresp   : std_logic_vector(1 downto 0);
  signal m_axi_rlast   : std_logic;
  signal m_axi_rvalid  : std_logic;
  signal m_axi_rready  : std_logic;
  signal m_axi_bresp   : std_logic_vector(1 downto 0);
  signal m_axi_bvalid  : std_logic;
  signal m_axi_bready  : std_logic;

  signal rstn_internal : std_ulogic;

begin

  rstn_internal <= not(rstn_i);

  -- NEORV32 Core Instance
  neorv32_top_inst: neorv32_top
  generic map (
    -- Clocking
    CLOCK_FREQUENCY     => CLOCK_FREQUENCY,
    -- Boot Configuration
    BOOT_MODE_SELECT    => 0,  -- Boot from bootloader ROM
    BOOT_ADDR_CUSTOM    => x"00000000",
    -- On-Chip Debugger (disabled)
    OCD_EN              => false,
    OCD_HW_BREAKPOINT   => false,
    OCD_AUTHENTICATION  => false,
    OCD_JEDEC_ID        => (others => '0'),
    -- RISC-V CPU Extensions
    RISCV_ISA_C         => true,   -- Compressed instructions
    RISCV_ISA_M         => true,   -- Multiplication/division
    RISCV_ISA_U         => false,
    RISCV_ISA_Zicntr    => true,   -- Base counters
    RISCV_ISA_Zicond    => false,
    RISCV_ISA_Zihpm     => false,
    -- Tuning Options
    CPU_FAST_MUL_EN     => true,
    CPU_FAST_SHIFT_EN   => true,
    -- Physical Memory Protection (disabled)
    PMP_NUM_REGIONS     => 0,
    -- Hardware Performance Monitors (disabled)
    HPM_NUM_CNTS        => 0,
    -- Internal Instruction Memory (64KB)
    IMEM_EN             => true,
    IMEM_SIZE           => 64*1024,
    IMEM_OUTREG_EN      => false,
    -- Internal Data Memory (64KB)
    DMEM_EN             => true,
    DMEM_SIZE           => 64*1024,
    DMEM_OUTREG_EN      => false,
    -- External Bus Interface (enabled for NPU connection)
    XBUS_EN             => true,
    XBUS_TIMEOUT        => 0,
    XBUS_REGSTAGE_EN    => false,
    -- Processor Peripherals
    IO_GPIO_NUM         => 0,
    IO_CLINT_EN         => true,   -- Core Local Interruptor (timers)
    IO_UART0_EN         => true,   -- Primary UART
    IO_UART0_RX_FIFO    => 32,
    IO_UART0_TX_FIFO    => 32,
    IO_UART1_EN         => false,
    IO_SPI_EN           => false,
    IO_SDI_EN           => false,
    IO_TWI_EN           => false,
    IO_TWD_EN           => false,
    IO_PWM_NUM_CH       => 0,
    IO_WDT_EN           => false,
    IO_TRNG_EN          => false,
    IO_CFS_EN           => false,  -- Custom Functions Subsystem disabled
    IO_NEOLED_EN        => false,
    IO_GPTMR_EN         => false,
    IO_ONEWIRE_EN       => false,
    IO_DMA_EN           => false,
    IO_SLINK_EN         => false,
    IO_DISABLE_SYSINFO  => false
  )
  port map (
    -- Global Control
    clk_i          => std_ulogic(clk_i),
    rstn_i         => rstn_internal,
    rstn_ocd_o     => open,
    rstn_wdt_o     => open,
    -- JTAG (disabled)
    jtag_tck_i     => '0',
    jtag_tdi_i     => '0',
    jtag_tdo_o     => open,
    jtag_tms_i     => '0',
    -- External Bus Interface (XBUS)
    xbus_adr_o     => xbus_req.addr,
    xbus_dat_o     => xbus_req.data,
    xbus_cti_o     => xbus_req.cti,
    xbus_tag_o     => xbus_req.tag,
    xbus_we_o      => xbus_req.we,
    xbus_sel_o     => xbus_req.sel,
    xbus_stb_o     => xbus_req.stb,
    xbus_cyc_o     => xbus_req.cyc,
    xbus_dat_i     => xbus_rsp.data,
    xbus_ack_i     => xbus_rsp.ack,
    xbus_err_i     => xbus_rsp.err,
    -- Stream Link (disabled)
    slink_rx_dat_i => (others => '0'),
    slink_rx_src_i => (others => '0'),
    slink_rx_val_i => '0',
    slink_rx_lst_i => '0',
    slink_rx_rdy_o => open,
    slink_tx_dat_o => open,
    slink_tx_dst_o => open,
    slink_tx_val_o => open,
    slink_tx_lst_o => open,
    slink_tx_rdy_i => '0',
    -- GPIO (disabled)
    gpio_o         => open,
    gpio_i         => (others => '0'),
    -- UART0
    uart0_txd_o    => uart0_txd_o,
    uart0_rxd_i    => uart0_rxd_i,
    uart0_rtsn_o   => open,  -- No hardware flow control
    uart0_ctsn_i   => '0',
    -- UART1 (disabled)
    uart1_txd_o    => open,
    uart1_rxd_i    => '0',
    uart1_rtsn_o   => open,
    uart1_ctsn_i   => '0',
    -- SPI (disabled)
    spi_clk_o      => open,
    spi_dat_o      => open,
    spi_dat_i      => '0',
    spi_csn_o      => open,
    -- SDI (disabled)
    sdi_clk_i      => '0',
    sdi_dat_o      => open,
    sdi_dat_i      => '0',
    sdi_csn_i      => '0',
    -- TWI (disabled)
    twi_sda_i      => '0',
    twi_sda_o      => open,
    twi_scl_i      => '0',
    twi_scl_o      => open,
    -- TWD (disabled)
    twd_sda_i      => '0',
    twd_sda_o      => open,
    twd_scl_i      => '0',
    twd_scl_o      => open,
    -- 1-Wire (disabled)
    onewire_i      => '0',
    onewire_o      => open,
    -- PWM (disabled)
    pwm_o          => open,
    -- CFS (disabled)
    cfs_in_i       => (others => '0'),
    cfs_out_o      => open,
    -- NEOLED (disabled)
    neoled_o       => open,
    -- Machine Timer
    mtime_time_o   => open,
    -- Interrupts
    mtime_irq_i    => '0',
    msw_irq_i      => '0',
    mext_irq_i     => '0'
  );


  -- XBUS to AXI4 Bridge
  xbus_to_axi_bridge: xbus2axi4_bridge
  generic map (
    BURST_EN  => false,  -- No caches, so no bursts needed
    BURST_LEN => 4
  )
  port map (
    -- Global Control
    clk           => clk_i,
    resetn        => rstn_i,
    -- XBUS Interface
    xbus_adr_i    => xbus_req.addr,
    xbus_dat_i    => xbus_req.data,
    xbus_cti_i    => xbus_req.cti,
    xbus_tag_i    => xbus_req.tag,
    xbus_we_i     => xbus_req.we,
    xbus_sel_i    => xbus_req.sel,
    xbus_stb_i    => xbus_req.stb,
    xbus_ack_o    => xbus_rsp.ack,
    xbus_err_o    => xbus_rsp.err,
    xbus_dat_o    => xbus_rsp.data,
    -- AXI4 Master Interface
    m_axi_awaddr  => m_axi_awaddr,
    m_axi_awlen   => m_axi_awlen,
    m_axi_awsize  => m_axi_awsize,
    m_axi_awburst => m_axi_awburst,
    m_axi_awcache => m_axi_awcache,
    m_axi_awprot  => m_axi_awprot,
    m_axi_awvalid => m_axi_awvalid,
    m_axi_awready => m_axi_awready,
    m_axi_wdata   => m_axi_wdata,
    m_axi_wstrb   => m_axi_wstrb,
    m_axi_wlast   => m_axi_wlast,
    m_axi_wvalid  => m_axi_wvalid,
    m_axi_wready  => m_axi_wready,
    m_axi_araddr  => m_axi_araddr,
    m_axi_arlen   => m_axi_arlen,
    m_axi_arsize  => m_axi_arsize,
    m_axi_arburst => m_axi_arburst,
    m_axi_arcache => m_axi_arcache,
    m_axi_arprot  => m_axi_arprot,
    m_axi_arvalid => m_axi_arvalid,
    m_axi_arready => m_axi_arready,
    m_axi_rdata   => m_axi_rdata,
    m_axi_rresp   => m_axi_rresp,
    m_axi_rlast   => m_axi_rlast,
    m_axi_rvalid  => m_axi_rvalid,
    m_axi_rready  => m_axi_rready,
    m_axi_bresp   => m_axi_bresp,
    m_axi_bvalid  => m_axi_bvalid,
    m_axi_bready  => m_axi_bready
  );

  -- TODO: Connect NPU module to AXI Bus
  m_axi_awready <= '1';
  m_axi_wready  <= '1';
  m_axi_arready <= '1';
  m_axi_rdata   <= (others => '0');
  m_axi_rresp   <= "00";
  m_axi_rlast   <= '1';
  m_axi_rvalid  <= '0';
  m_axi_bresp   <= "00";
  m_axi_bvalid  <= '0';

end architecture;
