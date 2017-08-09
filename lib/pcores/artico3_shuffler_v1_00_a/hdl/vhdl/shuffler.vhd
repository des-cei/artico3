----------------------------------------------------------------------------------------------
-- ARTICo3 Data Shuffler top module                                                         --
--                                                                                          --
-- Author: Juan Valverde <juan.valverde@upm.es>                                             --
--         Alfonso Rodriguez <alfonso.rodriguezm@upm.es>                                    --
--         Cesar Castañares <cekafra@gmail.com>                                             --
--                                                                                          --
-- Features:                                                                                --
--     Independent AXI4-Lite (register-based) and AXI4 Full (memory-based) interfaces       --
--     Configurable output pipeline depth to avoid timing problems in large implementations --
--     Dynamic power reduction by clock gating in dynamic region (reconfigurable slots)     --
--     Selective software reset to different computing units                                --
--     Configurable reduction engine for read transactions coming from the compute units    --
--     Accelerator state (READY signals) can be checked via interrupts or register polling  --
--                                                                                          --
-- TODO:                                                                                    --
--     Implement error detection logic (error registers in voter)                           --
--     Implement Side-Channel Attack protection                                             --
--     Generalize architecture for implementations with more than 8 posible compute units   --
--                                                                                          --
-- This peripheral can be attached to any Xilinx AXI4 Interconnect to implement a fully     --
-- enabled ARTICo3 implementation in a system with a host microprocessor                    --
----------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity shuffler is
    generic (
        ------------------------------
        -- Configuration parameters --
        ------------------------------

        -- Number of software-accessible registers
        -- (Note that C_S_AXI_ADDR_WIDTH has to be set accordingly)
        C_NUM_REG_RW         : integer := 10;
        -- Number of read-only software-accessible registers
        -- (Note that C_S_AXI_ADDR_WIDTH has to be set accordingly)
        C_NUM_REG_RO         : integer := 10;
        -- Number of pipeline stages (registers) between IF and hardware accelerators
        C_PIPE_DEPTH         : integer := 3;
        -- Number of cycles required to generate a valid en signal
        C_EN_LATENCY         : integer := 4;
        -- Number of cycles required to vote valid data
        C_VOTER_LATENCY      : integer := 2;
        -- Maximum number of reconfigurable slots (if this value is changed, the port section of the entity needs to be modified too, as well as the ARTICo3 interface section in the architecture)
        C_MAX_SLOTS          : integer := 16;
        -- Clock gating configuration (valid values are "NO_BUFFER", "GLOBAL", "HORIZONTAL")
        C_CLK_GATE_BUFFER    : string := "HORIZONTAL";
        -- Reset buffer configuration (valid values are "NO_BUFFER", "GLOBAL", "HORIZONTAL")
        C_RST_BUFFER         : string := "HORIZONTAL";

        --------------------------
        -- Interface parameters --
        --------------------------

        -- Parameters of ARTICo3 Master Interfaces
        C_ARTICO3_ADDR_WIDTH : integer := 16; -- ARTICo3 address size
        C_ARTICO3_ID_WIDTH   : integer := 4;  -- ARTICo3 ID size
        C_ARTICO3_OP_WIDTH   : integer := 4;  -- ARTICo3 OPeration mode size
        C_ARTICO3_GR_WIDTH   : integer := 4;  -- ARTICo3 DMR/TMR GRoup size

        -- Parameters of Axi Slave Bus Interface S00_AXI (CONTROL PATH)
        C_S_AXI_DATA_WIDTH   : integer := 32;
        C_S_AXI_ADDR_WIDTH   : integer := 20; -- (NOTICE: C_S_AXI_ADDR_WIDTH = C_ARTICO3_ADDR_WIDTH + C_ARTICO3_ID_WIDTH)

        -- Parameters of Axi Slave Bus Interface S01_AXI (DATA PATH)
        C_S_AXI_ID_WIDTH     : integer := 1;
        C_S_AXI_AWUSER_WIDTH : integer := 0;
        C_S_AXI_ARUSER_WIDTH : integer := 0;
        C_S_AXI_WUSER_WIDTH  : integer := 0;
        C_S_AXI_RUSER_WIDTH  : integer := 0;
        C_S_AXI_BUSER_WIDTH  : integer := 0
    );
    port (
        ----------------------
        -- Additional ports --
        ----------------------

        -- Interrupt signal (rising-edge sensitive)
        interrupt           : out std_logic;

        -------------------
        -- ARTICo3 ports --
        -------------------

        -- NOTE: this definition is for Vivado IP Integrator based designs

        -- SLOT #0 --
        m00_artico3_aclk    : out std_logic;
        m00_artico3_aresetn : out std_logic;
        m00_artico3_start   : out std_logic;
        m00_artico3_ready   : in  std_logic;
        m00_artico3_en      : out std_logic;
        m00_artico3_we      : out std_logic;
        m00_artico3_mode    : out std_logic;
        m00_artico3_addr    : out std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
        m00_artico3_wdata   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        m00_artico3_rdata   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

        -- SLOT #1 --
        m01_artico3_aclk    : out std_logic;
        m01_artico3_aresetn : out std_logic;
        m01_artico3_start   : out std_logic;
        m01_artico3_ready   : in  std_logic;
        m01_artico3_en      : out std_logic;
        m01_artico3_we      : out std_logic;
        m01_artico3_mode    : out std_logic;
        m01_artico3_addr    : out std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
        m01_artico3_wdata   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        m01_artico3_rdata   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

        -- SLOT #2 --
        m02_artico3_aclk    : out std_logic;
        m02_artico3_aresetn : out std_logic;
        m02_artico3_start   : out std_logic;
        m02_artico3_ready   : in  std_logic;
        m02_artico3_en      : out std_logic;
        m02_artico3_we      : out std_logic;
        m02_artico3_mode    : out std_logic;
        m02_artico3_addr    : out std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
        m02_artico3_wdata   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        m02_artico3_rdata   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

        -- SLOT #3 --
        m03_artico3_aclk    : out std_logic;
        m03_artico3_aresetn : out std_logic;
        m03_artico3_start   : out std_logic;
        m03_artico3_ready   : in  std_logic;
        m03_artico3_en      : out std_logic;
        m03_artico3_we      : out std_logic;
        m03_artico3_mode    : out std_logic;
        m03_artico3_addr    : out std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
        m03_artico3_wdata   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        m03_artico3_rdata   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

        -- SLOT #4 --
        m04_artico3_aclk    : out std_logic;
        m04_artico3_aresetn : out std_logic;
        m04_artico3_start   : out std_logic;
        m04_artico3_ready   : in  std_logic;
        m04_artico3_en      : out std_logic;
        m04_artico3_we      : out std_logic;
        m04_artico3_mode    : out std_logic;
        m04_artico3_addr    : out std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
        m04_artico3_wdata   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        m04_artico3_rdata   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

        -- SLOT #5 --
        m05_artico3_aclk    : out std_logic;
        m05_artico3_aresetn : out std_logic;
        m05_artico3_start   : out std_logic;
        m05_artico3_ready   : in  std_logic;
        m05_artico3_en      : out std_logic;
        m05_artico3_we      : out std_logic;
        m05_artico3_mode    : out std_logic;
        m05_artico3_addr    : out std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
        m05_artico3_wdata   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        m05_artico3_rdata   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

        -- SLOT #6 --
        m06_artico3_aclk    : out std_logic;
        m06_artico3_aresetn : out std_logic;
        m06_artico3_start   : out std_logic;
        m06_artico3_ready   : in  std_logic;
        m06_artico3_en      : out std_logic;
        m06_artico3_we      : out std_logic;
        m06_artico3_mode    : out std_logic;
        m06_artico3_addr    : out std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
        m06_artico3_wdata   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        m06_artico3_rdata   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

        -- SLOT #7 --
        m07_artico3_aclk    : out std_logic;
        m07_artico3_aresetn : out std_logic;
        m07_artico3_start   : out std_logic;
        m07_artico3_ready   : in  std_logic;
        m07_artico3_en      : out std_logic;
        m07_artico3_we      : out std_logic;
        m07_artico3_mode    : out std_logic;
        m07_artico3_addr    : out std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
        m07_artico3_wdata   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        m07_artico3_rdata   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

        -- SLOT #8 --
        m08_artico3_aclk    : out std_logic;
        m08_artico3_aresetn : out std_logic;
        m08_artico3_start   : out std_logic;
        m08_artico3_ready   : in  std_logic;
        m08_artico3_en      : out std_logic;
        m08_artico3_we      : out std_logic;
        m08_artico3_mode    : out std_logic;
        m08_artico3_addr    : out std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
        m08_artico3_wdata   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        m08_artico3_rdata   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

        -- SLOT #9 --
        m09_artico3_aclk    : out std_logic;
        m09_artico3_aresetn : out std_logic;
        m09_artico3_start   : out std_logic;
        m09_artico3_ready   : in  std_logic;
        m09_artico3_en      : out std_logic;
        m09_artico3_we      : out std_logic;
        m09_artico3_mode    : out std_logic;
        m09_artico3_addr    : out std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
        m09_artico3_wdata   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        m09_artico3_rdata   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

        -- SLOT #10 --
        m10_artico3_aclk    : out std_logic;
        m10_artico3_aresetn : out std_logic;
        m10_artico3_start   : out std_logic;
        m10_artico3_ready   : in  std_logic;
        m10_artico3_en      : out std_logic;
        m10_artico3_we      : out std_logic;
        m10_artico3_mode    : out std_logic;
        m10_artico3_addr    : out std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
        m10_artico3_wdata   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        m10_artico3_rdata   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

        -- SLOT #11 --
        m11_artico3_aclk    : out std_logic;
        m11_artico3_aresetn : out std_logic;
        m11_artico3_start   : out std_logic;
        m11_artico3_ready   : in  std_logic;
        m11_artico3_en      : out std_logic;
        m11_artico3_we      : out std_logic;
        m11_artico3_mode    : out std_logic;
        m11_artico3_addr    : out std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
        m11_artico3_wdata   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        m11_artico3_rdata   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

        -- SLOT #12 --
        m12_artico3_aclk    : out std_logic;
        m12_artico3_aresetn : out std_logic;
        m12_artico3_start   : out std_logic;
        m12_artico3_ready   : in  std_logic;
        m12_artico3_en      : out std_logic;
        m12_artico3_we      : out std_logic;
        m12_artico3_mode    : out std_logic;
        m12_artico3_addr    : out std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
        m12_artico3_wdata   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        m12_artico3_rdata   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

        -- SLOT #13 --
        m13_artico3_aclk    : out std_logic;
        m13_artico3_aresetn : out std_logic;
        m13_artico3_start   : out std_logic;
        m13_artico3_ready   : in  std_logic;
        m13_artico3_en      : out std_logic;
        m13_artico3_we      : out std_logic;
        m13_artico3_mode    : out std_logic;
        m13_artico3_addr    : out std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
        m13_artico3_wdata   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        m13_artico3_rdata   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

        -- SLOT #14 --
        m14_artico3_aclk    : out std_logic;
        m14_artico3_aresetn : out std_logic;
        m14_artico3_start   : out std_logic;
        m14_artico3_ready   : in  std_logic;
        m14_artico3_en      : out std_logic;
        m14_artico3_we      : out std_logic;
        m14_artico3_mode    : out std_logic;
        m14_artico3_addr    : out std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
        m14_artico3_wdata   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        m14_artico3_rdata   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

        -- SLOT #15 --
        m15_artico3_aclk    : out std_logic;
        m15_artico3_aresetn : out std_logic;
        m15_artico3_start   : out std_logic;
        m15_artico3_ready   : in  std_logic;
        m15_artico3_en      : out std_logic;
        m15_artico3_we      : out std_logic;
        m15_artico3_mode    : out std_logic;
        m15_artico3_addr    : out std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
        m15_artico3_wdata   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        m15_artico3_rdata   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);

        ---------------------
        -- Interface ports --
        ---------------------

        -- Common ports (same clock and reset signal in both interfaces)
        s_axi_aclk          : in  std_logic;
        s_axi_aresetn       : in  std_logic;

        -- Ports of Axi Slave Bus Interface S00_AXI (CONTROL PATH)
--        s00_axi_aclk        : in  std_logic;
--        s00_axi_aresetn     : in  std_logic;
        s00_axi_awaddr      : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        s00_axi_awprot      : in  std_logic_vector(2 downto 0);
        s00_axi_awvalid     : in  std_logic;
        s00_axi_awready     : out std_logic;
        s00_axi_wdata       : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        s00_axi_wstrb       : in  std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
        s00_axi_wvalid      : in  std_logic;
        s00_axi_wready      : out std_logic;
        s00_axi_bresp       : out std_logic_vector(1 downto 0);
        s00_axi_bvalid      : out std_logic;
        s00_axi_bready      : in  std_logic;
        s00_axi_araddr      : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        s00_axi_arprot      : in  std_logic_vector(2 downto 0);
        s00_axi_arvalid     : in  std_logic;
        s00_axi_arready     : out std_logic;
        s00_axi_rdata       : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        s00_axi_rresp       : out std_logic_vector(1 downto 0);
        s00_axi_rvalid      : out std_logic;
        s00_axi_rready      : in  std_logic;

        -- Ports of Axi Slave Bus Interface S01_AXI (DATA PATH)
--        s01_axi_aclk        : in  std_logic;
--        s01_axi_aresetn     : in  std_logic;
        s01_axi_awid        : in  std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
        s01_axi_awaddr      : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        s01_axi_awlen       : in  std_logic_vector(7 downto 0);
        s01_axi_awsize      : in  std_logic_vector(2 downto 0);
        s01_axi_awburst     : in  std_logic_vector(1 downto 0);
        s01_axi_awlock      : in  std_logic;
        s01_axi_awcache     : in  std_logic_vector(3 downto 0);
        s01_axi_awprot      : in  std_logic_vector(2 downto 0);
        s01_axi_awqos       : in  std_logic_vector(3 downto 0);
        s01_axi_awregion    : in  std_logic_vector(3 downto 0);
        s01_axi_awuser      : in  std_logic_vector(C_S_AXI_AWUSER_WIDTH-1 downto 0);
        s01_axi_awvalid     : in  std_logic;
        s01_axi_awready     : out std_logic;
        s01_axi_wdata       : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        s01_axi_wstrb       : in  std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
        s01_axi_wlast       : in  std_logic;
        s01_axi_wuser       : in  std_logic_vector(C_S_AXI_WUSER_WIDTH-1 downto 0);
        s01_axi_wvalid      : in  std_logic;
        s01_axi_wready      : out std_logic;
        s01_axi_bid         : out std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
        s01_axi_bresp       : out std_logic_vector(1 downto 0);
        s01_axi_buser       : out std_logic_vector(C_S_AXI_BUSER_WIDTH-1 downto 0);
        s01_axi_bvalid      : out std_logic;
        s01_axi_bready      : in  std_logic;
        s01_axi_arid        : in  std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
        s01_axi_araddr      : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        s01_axi_arlen       : in  std_logic_vector(7 downto 0);
        s01_axi_arsize      : in  std_logic_vector(2 downto 0);
        s01_axi_arburst     : in  std_logic_vector(1 downto 0);
        s01_axi_arlock      : in  std_logic;
        s01_axi_arcache     : in  std_logic_vector(3 downto 0);
        s01_axi_arprot      : in  std_logic_vector(2 downto 0);
        s01_axi_arqos       : in  std_logic_vector(3 downto 0);
        s01_axi_arregion    : in  std_logic_vector(3 downto 0);
        s01_axi_aruser      : in  std_logic_vector(C_S_AXI_ARUSER_WIDTH-1 downto 0);
        s01_axi_arvalid     : in  std_logic;
        s01_axi_arready     : out std_logic;
        s01_axi_rid         : out std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
        s01_axi_rdata       : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        s01_axi_rresp       : out std_logic_vector(1 downto 0);
        s01_axi_rlast       : out std_logic;
        s01_axi_ruser       : out std_logic_vector(C_S_AXI_RUSER_WIDTH-1 downto 0);
        s01_axi_rvalid      : out std_logic;
        s01_axi_rready      : in  std_logic
    );
end shuffler;

architecture arch of shuffler is

    -------------------------------
    -- ARTICo3 interface signals --
    -------------------------------

    type artico3_data_t is array (0 to C_MAX_SLOTS-1) of std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    type artico3_addr_t is array (0 to C_MAX_SLOTS-1) of std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);

    signal artico3_aclk        : std_logic_vector(C_MAX_SLOTS-1 downto 0); -- Clock signals to compute units
    signal artico3_aresetn     : std_logic_vector(C_MAX_SLOTS-1 downto 0); -- Reset signals to compute units (synchronous active-low)
    signal artico3_start       : std_logic_vector(C_MAX_SLOTS-1 downto 0); -- Control signals that start execution in compute units
    signal artico3_ready       : std_logic_vector(C_MAX_SLOTS-1 downto 0); -- Control signals that determine whether the compute units have finished working or not
    signal artico3_en          : std_logic_vector(C_MAX_SLOTS-1 downto 0); -- Compute unit enable signals (compute units can only be accessed from the shuffler when this signal is asserted)
    signal artico3_we          : std_logic_vector(C_MAX_SLOTS-1 downto 0); -- Compute unit write enable signals
    signal artico3_mode        : std_logic_vector(C_MAX_SLOTS-1 downto 0); -- Compute unit access mode (it can be either a memory access [1] or a register access [0])
    signal artico3_addr        : artico3_addr_t;                           -- ARTICo3 address bus
    signal artico3_wdata       : artico3_data_t;                           -- ARTICo3 write data bus
    signal artico3_rdata       : artico3_data_t;                           -- ARTICo3 read data bus

    ----------------------------
    -- AXI4 interface signals --
    ----------------------------

    signal axi_mem_W_data      : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);   -- WDATA in AXI4 Full interface (memory)
    signal axi_mem_R_data      : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);   -- RDATA in AXI4 Full interface (memory)
    signal axi_mem_W_addr      : std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0); -- AWADDR in AXI4 Full interface (memory)
    signal axi_mem_R_addr      : std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0); -- ARADDR in AXI4 Full interface (memory)
    signal axi_reg_W_data      : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);   -- WDATA in AXI4-Lite interface (registers)
    signal axi_reg_R_data      : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);   -- RDATA in AXI4-Lite interface (registers)
    signal axi_reg_W_addr      : std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0); -- AWADDR in AXI4-Lite interface (registers)
    signal axi_reg_R_addr      : std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0); -- ARADDR in AXI4-Lite interface (registers)
    signal axi_mem_AW_hs       : std_logic;                                         -- AWVALID/AWREADY handshake in AXI4 Full interface (memory)
    signal axi_mem_AR_hs       : std_logic;                                         -- ARVALID/ARREADY handshake in AXI4 Full interface (memory)
    signal axi_reg_AW_hs       : std_logic;                                         -- AWVALID/AWREADY handshake in AXI4-Lite interface (registers)
    signal axi_reg_AR_hs       : std_logic;                                         -- ARVALID/ARREADY handshake in AXI4-Lite interface (registers)
    signal axi_mem_W_hs        : std_logic;                                         -- WVALID/WREADY handshake in AXI4 Full interface (memory)
    signal axi_mem_R_hs        : std_logic;                                         -- RVALID/RREADY handshake in AXI4 Full interface (memory) - ASSUMING NO LATENCIES (i.e. no pipeline, nor enable generation)
    signal axi_reg_W_hs        : std_logic;                                         -- WVALID/WREADY handshake in AXI4-Lite interface (registers)
    signal axi_reg_R_hs        : std_logic;                                         -- RVALID/RREADY handshake in AXI4-Lite interface (registers) - ASSUMING NO LATENCIES (i.e. no pipeline, nor enable generation)
    signal axi_mem_W_id        : std_logic_vector(C_ARTICO3_ID_WIDTH-1 downto 0);   -- Captured ID in write channel (AXI4 Full)
    signal axi_mem_R_id        : std_logic_vector(C_ARTICO3_ID_WIDTH-1 downto 0);   -- Captured ID in read channel (AXI4 Full)
    signal axi_reg_W_id        : std_logic_vector(C_ARTICO3_ID_WIDTH-1 downto 0);   -- Captured ID in write channel (AXI4-Lite)
    signal axi_reg_R_id        : std_logic_vector(C_ARTICO3_ID_WIDTH-1 downto 0);   -- Captured ID in read channel (AXI4-Lite)
    signal axi_reg_W_op        : std_logic_vector(C_ARTICO3_OP_WIDTH-1 downto 0);   -- Captured OPeration mode in write channel (AXI4-Lite)
    signal axi_reg_R_op        : std_logic_vector(C_ARTICO3_OP_WIDTH-1 downto 0);   -- Captured OPeration mode in read channel (AXI4-Lite)

    -----------------------
    -- Enable generation --
    -----------------------

    -- Enable signals
    type enable_t is array (0 to C_MAX_SLOTS-1) of std_logic_vector(C_MAX_SLOTS-1 downto 0);
    signal enable              : enable_t;                                            -- Array that stores all enable signals for one transaction
    signal engen_out           : std_logic_vector(C_MAX_SLOTS-1 downto 0);            -- Current enable signal, i.e. which accelerators are selected at a given time
    signal engen_out_dly1      : std_logic_vector(C_MAX_SLOTS-1 downto 0);            -- Enable signal delayed 1 clock cycle to detect falling edges
    signal engen_idx           : integer range 0 to C_MAX_SLOTS-1;                    -- Enable index: used to switch enable signals

    -- Remaining data counters
    signal engen_cnt_remaining : unsigned(C_S_AXI_DATA_WIDTH+C_MAX_SLOTS-1 downto 0); -- Number of elements that still have to be transferred (refers to all slots)
    signal engen_cnt_current   : unsigned(C_S_AXI_DATA_WIDTH-1 downto 0);             -- Number of elements already transferred with the current slot
    signal engen_cnt_max       : unsigned(C_S_AXI_DATA_WIDTH-1 downto 0);             -- Number of elements that have to be transferred per slot

    -- Control signals
    signal engen_mode          : std_logic;                                           -- Enable generation mode, depends on transaction type ('1' memory, '0' register)
    signal engen_rw            : std_logic;                                           -- Enable generation mode, depends on access type in memory transactions ('1' read, '0' write)
    signal engen_start         : std_logic_vector(C_MAX_SLOTS-1 downto 0);            -- Start signal that tells accelerators that processing can start
    signal addr_reset          : std_logic;                                           -- Control signal to tell the address generators that address needs a reset prior to slot changes
    signal addr_capture        : std_logic;                                           -- Control signal to tell the address generators that a new address has to be captured

    -- Control signal registers (used to store current values in configuration parameters)
    signal id_ack_reg          : std_logic_vector(C_MAX_SLOTS-1 downto 0);                      -- ID_ACK register
    signal tmr_reg             : std_logic_vector((C_MAX_SLOTS*C_ARTICO3_GR_WIDTH)-1 downto 0); -- TMR register
    signal dmr_reg             : std_logic_vector((C_MAX_SLOTS*C_ARTICO3_GR_WIDTH)-1 downto 0); -- DMR register
    signal block_size_reg      : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);               -- BLOCK_SIZE register

    signal id_ack_current      : std_logic_vector(C_MAX_SLOTS-1 downto 0);                      -- Registered copy of the content of ID_ACK register (to avoid changes during enable generation)
    signal tmr_current         : std_logic_vector((C_MAX_SLOTS*C_ARTICO3_GR_WIDTH)-1 downto 0); -- Registered copy of the content of TMR register (to avoid changes during enable generation)
    signal dmr_current         : std_logic_vector((C_MAX_SLOTS*C_ARTICO3_GR_WIDTH)-1 downto 0); -- Registered copy of the content of DMR register (to avoid changes during enable generation)
    signal block_size_current  : unsigned(C_S_AXI_DATA_WIDTH-1 downto 0);                       -- Registered copy of the content of BLOCK_SIZE register (to avoid changes during enable generation)

    -- Control FSM definitions
    type engen_state_t is (S_WAIT, S_GEN, S_REG, S_MEM);
    signal engen_state         : engen_state_t;

    -----------------
    -- Voter logic --
    -----------------

    -- Input data from hardware accelerators
    signal voter_data          : artico3_data_t;

    -- Control signals
    signal voter_en            : std_logic_vector(C_MAX_SLOTS-1 downto 0);        -- Enable signal in the voter selector (with latency control to synchronize latencies due to pipelining)
    signal sca_mode            : std_logic;                                       -- Side-Channel Attack protection enabled

    -- Voter registers
    signal voter_out           : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0); -- Voter unit output signal
    signal voter_reg0          : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0); -- First comparison register in the voter unit
    signal voter_reg1          : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0); -- Second comparison register in the voter unit
    signal voter_reg2          : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0); -- Third comparison register in the voter unit
    signal voter_sel0          : std_logic_vector(C_MAX_SLOTS-1 downto 0);        -- Control signal to determine from which accelerator data are loaded in the first register of the voter
    signal voter_sel1          : std_logic_vector(C_MAX_SLOTS-1 downto 0);        -- Control signal to determine from which accelerator data are loaded in the second register of the voter
    signal voter_sel2          : std_logic_vector(C_MAX_SLOTS-1 downto 0);        -- Control signal to determine from which accelerator data are loaded in the third register of the voter
    signal voter_num           : integer range 0 to 3;                            -- There can be 0, 1 (Simplex), 2 (DMR) or 3 (TMR) accelerators

    ---------------------
    -- Reduction logic --
    ---------------------

    signal axi_red_AR_hs       : std_logic;                                         -- ARVALID/ARREADY handshake in AXI4-Lite interface (registers) when a reduction operation is being issued
    signal red_ctrl            : std_logic;                                         -- Control signal that can be used to check if a reduction transaction is being conducted
    signal red_en_base         : std_logic;                                         -- Reduction engine enable (with no latency information), used to generate addresses when performing a reduction. This is similar to RVALID_base in the AXI4 Full interface
    signal red_en              : std_logic;                                         -- Reduction engine enable (with latency information to take into account pipeline, and voter latencies). This is similar to RVALID in the AXI4 Full interface
    signal red_en_dly1         : std_logic;                                         -- Reduction engine enable registered 1 clock cycle (to detect falling edges and generate RVALID signal)
    signal red_rvalid          : std_logic;                                         -- RVALID signal in AXI4-Lite interface (registers) when a reduction operation is being issued (latency information included)
    signal red_araddr          : std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0); -- Reduction logic address signal
    signal red_macreg          : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);   -- Reduction engine MAC register

    ---------------------------
    -- Clock and reset logic --
    ---------------------------

    signal clk_gate_reg        : std_logic_vector(C_MAX_SLOTS-1 downto 0); -- Clock gating configuration register
    signal sw_aresetn          : std_logic;                                -- Software-generated reset signal

    --------------------
    -- Pipeline logic --
    --------------------

    signal ready_reg           : std_logic_vector(C_MAX_SLOTS-1 downto 0); -- Ready flag register (stores which accelerators have finished their processing)

    --------------------------
    -- Transaction ID logic --
    --------------------------

    signal id_current          : std_logic_vector(C_ARTICO3_ID_WIDTH-1 downto 0);               -- Current transaction ID
    signal id_reg              : std_logic_vector((C_MAX_SLOTS*C_ARTICO3_ID_WIDTH)-1 downto 0); -- ID configuration register

    ---------------------
    -- Interrupt logic --
    ---------------------

    signal interrupt_s         : std_logic; -- Internal signal to generate interrupt requests to an external uP

    -----------
    -- DEBUG --
    -----------

    attribute mark_debug : string;

    attribute mark_debug of artico3_aclk        : signal is "TRUE";
    attribute mark_debug of artico3_aresetn     : signal is "TRUE";
    attribute mark_debug of artico3_start       : signal is "TRUE";
    attribute mark_debug of artico3_ready       : signal is "TRUE";
    attribute mark_debug of artico3_en          : signal is "TRUE";
    attribute mark_debug of artico3_we          : signal is "TRUE";
    attribute mark_debug of artico3_mode        : signal is "TRUE";
    attribute mark_debug of artico3_addr        : signal is "TRUE";
    attribute mark_debug of artico3_wdata       : signal is "TRUE";
    attribute mark_debug of artico3_rdata       : signal is "TRUE";

    attribute mark_debug of axi_mem_W_data      : signal is "TRUE";
    attribute mark_debug of axi_mem_R_data      : signal is "TRUE";
    attribute mark_debug of axi_mem_W_addr      : signal is "TRUE";
    attribute mark_debug of axi_mem_R_addr      : signal is "TRUE";
    attribute mark_debug of axi_reg_W_data      : signal is "TRUE";
    attribute mark_debug of axi_reg_R_data      : signal is "TRUE";
    attribute mark_debug of axi_reg_W_addr      : signal is "TRUE";
    attribute mark_debug of axi_reg_R_addr      : signal is "TRUE";
    attribute mark_debug of axi_mem_AW_hs       : signal is "TRUE";
    attribute mark_debug of axi_mem_AR_hs       : signal is "TRUE";
    attribute mark_debug of axi_reg_AW_hs       : signal is "TRUE";
    attribute mark_debug of axi_reg_AR_hs       : signal is "TRUE";
    attribute mark_debug of axi_mem_W_hs        : signal is "TRUE";
    attribute mark_debug of axi_mem_R_hs        : signal is "TRUE";
    attribute mark_debug of axi_reg_W_hs        : signal is "TRUE";
    attribute mark_debug of axi_reg_R_hs        : signal is "TRUE";
    attribute mark_debug of axi_mem_W_id        : signal is "TRUE";
    attribute mark_debug of axi_mem_R_id        : signal is "TRUE";
    attribute mark_debug of axi_reg_W_id        : signal is "TRUE";
    attribute mark_debug of axi_reg_R_id        : signal is "TRUE";
    attribute mark_debug of axi_reg_W_op        : signal is "TRUE";
    attribute mark_debug of axi_reg_R_op        : signal is "TRUE";

    attribute mark_debug of enable              : signal is "TRUE";
    attribute mark_debug of engen_out           : signal is "TRUE";
    attribute mark_debug of engen_idx           : signal is "TRUE";
    attribute mark_debug of engen_cnt_remaining : signal is "TRUE";
    attribute mark_debug of engen_cnt_current   : signal is "TRUE";
    attribute mark_debug of engen_cnt_max       : signal is "TRUE";
    attribute mark_debug of engen_mode          : signal is "TRUE";
    attribute mark_debug of engen_rw            : signal is "TRUE";
    attribute mark_debug of engen_start         : signal is "TRUE";
    attribute mark_debug of addr_reset          : signal is "TRUE";
    attribute mark_debug of addr_capture        : signal is "TRUE";
    attribute mark_debug of id_ack_reg          : signal is "TRUE";
    attribute mark_debug of tmr_reg             : signal is "TRUE";
    attribute mark_debug of dmr_reg             : signal is "TRUE";
    attribute mark_debug of block_size_reg      : signal is "TRUE";
    attribute mark_debug of id_ack_current      : signal is "TRUE";
    attribute mark_debug of tmr_current         : signal is "TRUE";
    attribute mark_debug of dmr_current         : signal is "TRUE";
    attribute mark_debug of block_size_current  : signal is "TRUE";
    attribute mark_debug of engen_state         : signal is "TRUE";

    attribute mark_debug of voter_data          : signal is "TRUE";
    attribute mark_debug of voter_en            : signal is "TRUE";
    attribute mark_debug of sca_mode            : signal is "TRUE";
    attribute mark_debug of voter_out           : signal is "TRUE";
    attribute mark_debug of voter_reg0          : signal is "TRUE";
    attribute mark_debug of voter_reg1          : signal is "TRUE";
    attribute mark_debug of voter_reg2          : signal is "TRUE";
    attribute mark_debug of voter_sel0          : signal is "TRUE";
    attribute mark_debug of voter_sel1          : signal is "TRUE";
    attribute mark_debug of voter_sel2          : signal is "TRUE";
    attribute mark_debug of voter_num           : signal is "TRUE";

    attribute mark_debug of axi_red_AR_hs       : signal is "TRUE";
    attribute mark_debug of red_ctrl            : signal is "TRUE";
    attribute mark_debug of red_en_base         : signal is "TRUE";
    attribute mark_debug of red_en              : signal is "TRUE";
    attribute mark_debug of red_en_dly1         : signal is "TRUE";
    attribute mark_debug of red_rvalid          : signal is "TRUE";
    attribute mark_debug of red_araddr          : signal is "TRUE";
    attribute mark_debug of red_macreg          : signal is "TRUE";

    attribute mark_debug of clk_gate_reg        : signal is "TRUE";
    attribute mark_debug of sw_aresetn          : signal is "TRUE";

    attribute mark_debug of ready_reg           : signal is "TRUE";
    attribute mark_debug of id_current          : signal is "TRUE";
    attribute mark_debug of id_reg              : signal is "TRUE";

    attribute mark_debug of interrupt_s         : signal is "TRUE";

begin

    ---------------------
    -- AXI4 interfaces --
    ---------------------

    -- Instantiation of AXI4-Lite interface (CONTROL PATH)
    shuffler_control: entity work.shuffler_control
    generic map (
        C_NUM_REG_RW         => C_NUM_REG_RW,
        C_NUM_REG_RO         => C_NUM_REG_RO,
        C_PIPE_DEPTH         => C_PIPE_DEPTH,
        C_EN_LATENCY         => C_EN_LATENCY,
        C_VOTER_LATENCY      => C_VOTER_LATENCY,
        C_MAX_SLOTS          => C_MAX_SLOTS,
        C_ARTICO3_ADDR_WIDTH => C_ARTICO3_ADDR_WIDTH,
        C_ARTICO3_ID_WIDTH   => C_ARTICO3_ID_WIDTH,
        C_ARTICO3_OP_WIDTH   => C_ARTICO3_OP_WIDTH,
        C_ARTICO3_GR_WIDTH   => C_ARTICO3_GR_WIDTH,
        C_S_AXI_DATA_WIDTH   => C_S_AXI_DATA_WIDTH,
        C_S_AXI_ADDR_WIDTH   => C_S_AXI_ADDR_WIDTH
    )
    port map (
        axi_reg_W_data => axi_reg_W_data,
        axi_reg_R_data => axi_reg_R_data,
        axi_reg_W_addr => axi_reg_W_addr,
        axi_reg_R_addr => axi_reg_R_addr,
        axi_reg_AW_hs  => axi_reg_AW_hs,
        axi_reg_AR_hs  => axi_reg_AR_hs,
        axi_reg_W_hs   => axi_reg_W_hs,
        axi_reg_R_hs   => axi_reg_R_hs,
        axi_reg_W_id   => axi_reg_W_id,
        axi_reg_R_id   => axi_reg_R_id,
        axi_reg_W_op   => axi_reg_W_op,
        axi_reg_R_op   => axi_reg_R_op,
        axi_red_AR_hs  => axi_red_AR_hs,
        red_rvalid     => red_rvalid,
        red_ctrl       => red_ctrl,
        id_reg         => id_reg,
        tmr_reg        => tmr_reg,
        dmr_reg        => dmr_reg,
        block_size_reg => block_size_reg,
        clk_gate_reg   => clk_gate_reg,
        ready_reg      => ready_reg,
        sw_aresetn     => sw_aresetn,
--        S_AXI_ACLK     => s00_axi_aclk,
--        S_AXI_ARESETN  => s00_axi_aresetn,
        S_AXI_ACLK     => s_axi_aclk,
        S_AXI_ARESETN  => s_axi_aresetn,
        S_AXI_AWADDR   => s00_axi_awaddr,
        S_AXI_AWPROT   => s00_axi_awprot,
        S_AXI_AWVALID  => s00_axi_awvalid,
        S_AXI_AWREADY  => s00_axi_awready,
        S_AXI_WDATA    => s00_axi_wdata,
        S_AXI_WSTRB    => s00_axi_wstrb,
        S_AXI_WVALID   => s00_axi_wvalid,
        S_AXI_WREADY   => s00_axi_wready,
        S_AXI_BRESP    => s00_axi_bresp,
        S_AXI_BVALID   => s00_axi_bvalid,
        S_AXI_BREADY   => s00_axi_bready,
        S_AXI_ARADDR   => s00_axi_araddr,
        S_AXI_ARPROT   => s00_axi_arprot,
        S_AXI_ARVALID  => s00_axi_arvalid,
        S_AXI_ARREADY  => s00_axi_arready,
        S_AXI_RDATA    => s00_axi_rdata,
        S_AXI_RRESP    => s00_axi_rresp,
        S_AXI_RVALID   => s00_axi_rvalid,
        S_AXI_RREADY   => s00_axi_rready
    );

    -- Instantiation of ÄXI4 Full interface (DATA PATH)
    shuffler_data : entity work.shuffler_data
    generic map (
        C_PIPE_DEPTH         => C_PIPE_DEPTH,
        C_EN_LATENCY         => C_EN_LATENCY,
        C_VOTER_LATENCY      => C_VOTER_LATENCY,
        C_ARTICO3_ADDR_WIDTH => C_ARTICO3_ADDR_WIDTH,
        C_ARTICO3_ID_WIDTH   => C_ARTICO3_ID_WIDTH,
        C_S_AXI_ID_WIDTH     => C_S_AXI_ID_WIDTH,
        C_S_AXI_DATA_WIDTH   => C_S_AXI_DATA_WIDTH,
        C_S_AXI_ADDR_WIDTH   => C_S_AXI_ADDR_WIDTH,
        C_S_AXI_AWUSER_WIDTH => C_S_AXI_AWUSER_WIDTH,
        C_S_AXI_ARUSER_WIDTH => C_S_AXI_ARUSER_WIDTH,
        C_S_AXI_WUSER_WIDTH  => C_S_AXI_WUSER_WIDTH,
        C_S_AXI_RUSER_WIDTH  => C_S_AXI_RUSER_WIDTH,
        C_S_AXI_BUSER_WIDTH  => C_S_AXI_BUSER_WIDTH
    )
    port map (
        axi_mem_W_data => axi_mem_W_data,
        axi_mem_R_data => axi_mem_R_data,
        axi_mem_W_addr => axi_mem_W_addr,
        axi_mem_R_addr => axi_mem_R_addr,
        axi_mem_AW_hs  => axi_mem_AW_hs,
        axi_mem_AR_hs  => axi_mem_AR_hs,
        axi_mem_W_hs   => axi_mem_W_hs,
        axi_mem_R_hs   => axi_mem_R_hs,
        axi_mem_W_id   => axi_mem_W_id,
        axi_mem_R_id   => axi_mem_R_id,
        addr_reset     => addr_reset,
        addr_capture   => addr_capture,
--        S_AXI_ACLK     => s01_axi_aclk,
--        S_AXI_ARESETN  => s01_axi_aresetn,
        S_AXI_ACLK     => s_axi_aclk,
        S_AXI_ARESETN  => s_axi_aresetn,
        S_AXI_AWID     => s01_axi_awid,
        S_AXI_AWADDR   => s01_axi_awaddr,
        S_AXI_AWLEN    => s01_axi_awlen,
        S_AXI_AWSIZE   => s01_axi_awsize,
        S_AXI_AWBURST  => s01_axi_awburst,
        S_AXI_AWLOCK   => s01_axi_awlock,
        S_AXI_AWCACHE  => s01_axi_awcache,
        S_AXI_AWPROT   => s01_axi_awprot,
        S_AXI_AWQOS    => s01_axi_awqos,
        S_AXI_AWREGION => s01_axi_awregion,
        S_AXI_AWUSER   => s01_axi_awuser,
        S_AXI_AWVALID  => s01_axi_awvalid,
        S_AXI_AWREADY  => s01_axi_awready,
        S_AXI_WDATA    => s01_axi_wdata,
        S_AXI_WSTRB    => s01_axi_wstrb,
        S_AXI_WLAST    => s01_axi_wlast,
        S_AXI_WUSER    => s01_axi_wuser,
        S_AXI_WVALID   => s01_axi_wvalid,
        S_AXI_WREADY   => s01_axi_wready,
        S_AXI_BID      => s01_axi_bid,
        S_AXI_BRESP    => s01_axi_bresp,
        S_AXI_BUSER    => s01_axi_buser,
        S_AXI_BVALID   => s01_axi_bvalid,
        S_AXI_BREADY   => s01_axi_bready,
        S_AXI_ARID     => s01_axi_arid,
        S_AXI_ARADDR   => s01_axi_araddr,
        S_AXI_ARLEN    => s01_axi_arlen,
        S_AXI_ARSIZE   => s01_axi_arsize,
        S_AXI_ARBURST  => s01_axi_arburst,
        S_AXI_ARLOCK   => s01_axi_arlock,
        S_AXI_ARCACHE  => s01_axi_arcache,
        S_AXI_ARPROT   => s01_axi_arprot,
        S_AXI_ARQOS    => s01_axi_arqos,
        S_AXI_ARREGION => s01_axi_arregion,
        S_AXI_ARUSER   => s01_axi_aruser,
        S_AXI_ARVALID  => s01_axi_arvalid,
        S_AXI_ARREADY  => s01_axi_arready,
        S_AXI_RID      => s01_axi_rid,
        S_AXI_RDATA    => s01_axi_rdata,
        S_AXI_RRESP    => s01_axi_rresp,
        S_AXI_RLAST    => s01_axi_rlast,
        S_AXI_RUSER    => s01_axi_ruser,
        S_AXI_RVALID   => s01_axi_rvalid,
        S_AXI_RREADY   => s01_axi_rready
    );

    ------------------------
    -- ARTICo3 interfaces --
    ------------------------

    -- NOTE: the following port connections are required when targeting Vivado IP Integrator designs

    -- SLOT #0 --
    m00_artico3_aclk <= artico3_aclk(0);
    m00_artico3_aresetn <= artico3_aresetn(0);
    m00_artico3_start <= artico3_start(0);
    artico3_ready(0) <= m00_artico3_ready;
    m00_artico3_en <= artico3_en(0);
    m00_artico3_we <= artico3_we(0);
    m00_artico3_mode <= artico3_mode(0);
    m00_artico3_addr <= artico3_addr(0);
    m00_artico3_wdata <= artico3_wdata(0);
    artico3_rdata(0) <= m00_artico3_rdata;

    -- SLOT #1 --
    m01_artico3_aclk <= artico3_aclk(1);
    m01_artico3_aresetn <= artico3_aresetn(1);
    m01_artico3_start <= artico3_start(1);
    artico3_ready(1) <= m01_artico3_ready;
    m01_artico3_en <= artico3_en(1);
    m01_artico3_we <= artico3_we(1);
    m01_artico3_mode <= artico3_mode(1);
    m01_artico3_addr <= artico3_addr(1);
    m01_artico3_wdata <= artico3_wdata(1);
    artico3_rdata(1) <= m01_artico3_rdata;

    -- SLOT #2 --
    m02_artico3_aclk <= artico3_aclk(2);
    m02_artico3_aresetn <= artico3_aresetn(2);
    m02_artico3_start <= artico3_start(2);
    artico3_ready(2) <= m02_artico3_ready;
    m02_artico3_en <= artico3_en(2);
    m02_artico3_we <= artico3_we(2);
    m02_artico3_mode <= artico3_mode(2);
    m02_artico3_addr <= artico3_addr(2);
    m02_artico3_wdata <= artico3_wdata(2);
    artico3_rdata(2) <= m02_artico3_rdata;

    -- SLOT #3 --
    m03_artico3_aclk <= artico3_aclk(3);
    m03_artico3_aresetn <= artico3_aresetn(3);
    m03_artico3_start <= artico3_start(3);
    artico3_ready(3) <= m03_artico3_ready;
    m03_artico3_en <= artico3_en(3);
    m03_artico3_we <= artico3_we(3);
    m03_artico3_mode <= artico3_mode(3);
    m03_artico3_addr <= artico3_addr(3);
    m03_artico3_wdata <= artico3_wdata(3);
    artico3_rdata(3) <= m03_artico3_rdata;

    -- SLOT #4 --
    m04_artico3_aclk <= artico3_aclk(4);
    m04_artico3_aresetn <= artico3_aresetn(4);
    m04_artico3_start <= artico3_start(4);
    artico3_ready(4) <= m04_artico3_ready;
    m04_artico3_en <= artico3_en(4);
    m04_artico3_we <= artico3_we(4);
    m04_artico3_mode <= artico3_mode(4);
    m04_artico3_addr <= artico3_addr(4);
    m04_artico3_wdata <= artico3_wdata(4);
    artico3_rdata(4) <= m04_artico3_rdata;

    -- SLOT #5 --
    m05_artico3_aclk <= artico3_aclk(5);
    m05_artico3_aresetn <= artico3_aresetn(5);
    m05_artico3_start <= artico3_start(5);
    artico3_ready(5) <= m05_artico3_ready;
    m05_artico3_en <= artico3_en(5);
    m05_artico3_we <= artico3_we(5);
    m05_artico3_mode <= artico3_mode(5);
    m05_artico3_addr <= artico3_addr(5);
    m05_artico3_wdata <= artico3_wdata(5);
    artico3_rdata(5) <= m05_artico3_rdata;

    -- SLOT #6 --
    m06_artico3_aclk <= artico3_aclk(6);
    m06_artico3_aresetn <= artico3_aresetn(6);
    m06_artico3_start <= artico3_start(6);
    artico3_ready(6) <= m06_artico3_ready;
    m06_artico3_en <= artico3_en(6);
    m06_artico3_we <= artico3_we(6);
    m06_artico3_mode <= artico3_mode(6);
    m06_artico3_addr <= artico3_addr(6);
    m06_artico3_wdata <= artico3_wdata(6);
    artico3_rdata(6) <= m06_artico3_rdata;

    -- SLOT #7 --
    m07_artico3_aclk <= artico3_aclk(7);
    m07_artico3_aresetn <= artico3_aresetn(7);
    m07_artico3_start <= artico3_start(7);
    artico3_ready(7) <= m07_artico3_ready;
    m07_artico3_en <= artico3_en(7);
    m07_artico3_we <= artico3_we(7);
    m07_artico3_mode <= artico3_mode(7);
    m07_artico3_addr <= artico3_addr(7);
    m07_artico3_wdata <= artico3_wdata(7);
    artico3_rdata(7) <= m07_artico3_rdata;

    -- SLOT #8 --
    m08_artico3_aclk <= artico3_aclk(8);
    m08_artico3_aresetn <= artico3_aresetn(8);
    m08_artico3_start <= artico3_start(8);
    artico3_ready(8) <= m08_artico3_ready;
    m08_artico3_en <= artico3_en(8);
    m08_artico3_we <= artico3_we(8);
    m08_artico3_mode <= artico3_mode(8);
    m08_artico3_addr <= artico3_addr(8);
    m08_artico3_wdata <= artico3_wdata(8);
    artico3_rdata(8) <= m08_artico3_rdata;

    -- SLOT #9 --
    m09_artico3_aclk <= artico3_aclk(9);
    m09_artico3_aresetn <= artico3_aresetn(9);
    m09_artico3_start <= artico3_start(9);
    artico3_ready(9) <= m09_artico3_ready;
    m09_artico3_en <= artico3_en(9);
    m09_artico3_we <= artico3_we(9);
    m09_artico3_mode <= artico3_mode(9);
    m09_artico3_addr <= artico3_addr(9);
    m09_artico3_wdata <= artico3_wdata(9);
    artico3_rdata(9) <= m09_artico3_rdata;

    -- SLOT #10 --
    m10_artico3_aclk <= artico3_aclk(10);
    m10_artico3_aresetn <= artico3_aresetn(10);
    m10_artico3_start <= artico3_start(10);
    artico3_ready(10) <= m10_artico3_ready;
    m10_artico3_en <= artico3_en(10);
    m10_artico3_we <= artico3_we(10);
    m10_artico3_mode <= artico3_mode(10);
    m10_artico3_addr <= artico3_addr(10);
    m10_artico3_wdata <= artico3_wdata(10);
    artico3_rdata(10) <= m10_artico3_rdata;

    -- SLOT #11 --
    m11_artico3_aclk <= artico3_aclk(11);
    m11_artico3_aresetn <= artico3_aresetn(11);
    m11_artico3_start <= artico3_start(11);
    artico3_ready(11) <= m11_artico3_ready;
    m11_artico3_en <= artico3_en(11);
    m11_artico3_we <= artico3_we(11);
    m11_artico3_mode <= artico3_mode(11);
    m11_artico3_addr <= artico3_addr(11);
    m11_artico3_wdata <= artico3_wdata(11);
    artico3_rdata(11) <= m11_artico3_rdata;

    -- SLOT #12 --
    m12_artico3_aclk <= artico3_aclk(12);
    m12_artico3_aresetn <= artico3_aresetn(12);
    m12_artico3_start <= artico3_start(12);
    artico3_ready(12) <= m12_artico3_ready;
    m12_artico3_en <= artico3_en(12);
    m12_artico3_we <= artico3_we(12);
    m12_artico3_mode <= artico3_mode(12);
    m12_artico3_addr <= artico3_addr(12);
    m12_artico3_wdata <= artico3_wdata(12);
    artico3_rdata(12) <= m12_artico3_rdata;

    -- SLOT #13 --
    m13_artico3_aclk <= artico3_aclk(13);
    m13_artico3_aresetn <= artico3_aresetn(13);
    m13_artico3_start <= artico3_start(13);
    artico3_ready(13) <= m13_artico3_ready;
    m13_artico3_en <= artico3_en(13);
    m13_artico3_we <= artico3_we(13);
    m13_artico3_mode <= artico3_mode(13);
    m13_artico3_addr <= artico3_addr(13);
    m13_artico3_wdata <= artico3_wdata(13);
    artico3_rdata(13) <= m13_artico3_rdata;

    -- SLOT #14 --
    m14_artico3_aclk <= artico3_aclk(14);
    m14_artico3_aresetn <= artico3_aresetn(14);
    m14_artico3_start <= artico3_start(14);
    artico3_ready(14) <= m14_artico3_ready;
    m14_artico3_en <= artico3_en(14);
    m14_artico3_we <= artico3_we(14);
    m14_artico3_mode <= artico3_mode(14);
    m14_artico3_addr <= artico3_addr(14);
    m14_artico3_wdata <= artico3_wdata(14);
    artico3_rdata(14) <= m14_artico3_rdata;

    -- SLOT #15 --
    m15_artico3_aclk <= artico3_aclk(15);
    m15_artico3_aresetn <= artico3_aresetn(15);
    m15_artico3_start <= artico3_start(15);
    artico3_ready(15) <= m15_artico3_ready;
    m15_artico3_en <= artico3_en(15);
    m15_artico3_we <= artico3_we(15);
    m15_artico3_mode <= artico3_mode(15);
    m15_artico3_addr <= artico3_addr(15);
    m15_artico3_wdata <= artico3_wdata(15);
    artico3_rdata(15) <= m15_artico3_rdata;

    -----------------------
    -- Enable generation --
    -----------------------

    -- Control FSM to generate enable signals. Also in charge of the sequencing process during a transaction
    enable_generation: process(s_axi_aclk)
        variable enable_aux : std_logic_vector(C_MAX_SLOTS-1 downto 0); -- Stores enable signal during current index generation
        variable index      : integer range 0 to C_MAX_SLOTS;           -- Stores the index of the next enable vector that has to be generated. It is also used to count the equivalent number of blocks (Simplex: 1 real slot, 1 equivalent slot; DMR: 2, 1; TMR: 3, 1)
        variable engen_step : integer range 0 to 3;                     -- Determines the current enable generation step (0 - Capture, 1 - TMR, 2 - DMR, 3 - Simplex). Stores part of the state in the FSM
    begin
        if s_axi_aclk'event and s_axi_aclk = '1' then
            if s_axi_aresetn = '0' then
                enable <= (others => (others => '0'));
                engen_idx <= 0;
                engen_cnt_remaining <= (others => '0');
                engen_cnt_current <= (others => '0');
                engen_cnt_max <= (others => '0');
                engen_mode <= '0';
                engen_rw <= '0';
                id_ack_current <= (others => '0');
                tmr_current <= (others => '0');
                dmr_current <= (others => '0');
                block_size_current <= (others => '0');
                engen_step := 0;
                engen_state <= S_WAIT;
            else
                -- FSM implementation
                case engen_state is

                    -- Wait state. The system awakens when a new transaction is acknowledged
                    when S_WAIT =>
                        -- Write to registers
                        if axi_reg_AW_hs = '1' then
                            engen_mode <= '0';
                            engen_rw <= '0';
                        end if;
                        -- Read from registers
                        if axi_reg_AR_hs = '1' then
                            engen_mode <= '0';
                            engen_rw <= '1';
                        end if;
                        -- Write to memory
                        if axi_mem_AW_hs = '1' then
                            engen_mode <= '1';
                            engen_rw <= '0';
                        end if;
                        -- Read from memory
                        if (axi_mem_AR_hs or axi_red_AR_hs) = '1' then
                            engen_mode <= '1';
                            engen_rw <= '1';
                        end if;
                        -- Whenever a transaction is issued...
                        if ((axi_reg_AW_hs or axi_reg_AR_hs) or (axi_mem_AW_hs or (axi_mem_AR_hs or axi_red_AR_hs))) = '1' then
                            -- ...change to next state
                            engen_state <= S_GEN;
                        end if;

                    -- Enable vector generation. Enable signals are generated using redundancy groupings
                    when S_GEN =>
                        -- This step is divided in different stages to avoid timing problems with higher frequencies
                        -- Global generic C_EN_LATENCY has to be equal to the maximum value of engen_step variable
                        case engen_step is

                            -- NOTE: if pipelining is required to further enhance ID_ACK generation, an arbitrary number of additional states
                            --       can be included prior to ID ACK registration for current transaction, always taking into account that
                            --       global parameter C_EN_LATENCY has to be set accordingly to achieve valid behavior (this can also be applied
                            --       if enable generation requires additional cycles to, once more, increase system performance/frequency)

                            -- Capture current transaction parameters (id_ack_reg is generated one clock cycle after AXI Ax handshake)
                            when 0 =>
                                id_ack_current <= id_ack_reg;
                                tmr_current <= tmr_reg;
                                dmr_current <= dmr_reg;
                                block_size_current <= unsigned(block_size_reg);
                                -- Set next step
                                engen_step := 1;

                            -- TMR vector generation
                            when 1 =>
                                -- Initialize parameters
                                index := 0;
                                -- Extract enable vectors
                                for i in 1 to 2**C_ARTICO3_GR_WIDTH-1 loop
                                    enable_aux := (others => '0');
                                    for j in 0 to C_MAX_SLOTS-1 loop
                                        if id_ack_current(j) = '1' and unsigned(tmr_current(C_ARTICO3_GR_WIDTH*(j+1)-1 downto C_ARTICO3_GR_WIDTH*j)) = i then
                                            enable_aux(j) := '1';
                                        end if;
                                    end loop;
                                    if unsigned(enable_aux) /= 0 then
                                        enable(index) <= enable_aux;
                                        index := index + 1;
                                    end if;
                                end loop;
                                -- Set next step
                                engen_step := 2;

                            -- DMR vector generation
                            when 2 =>
                                -- Extract enable vectors
                                for i in 1 to 2**C_ARTICO3_GR_WIDTH-1 loop
                                    enable_aux := (others => '0');
                                    for j in 0 to C_MAX_SLOTS-1 loop
                                        if id_ack_current(j) = '1' and unsigned(dmr_current(C_ARTICO3_GR_WIDTH*(j+1)-1 downto C_ARTICO3_GR_WIDTH*j)) = i then
                                            enable_aux(j) := '1';
                                        end if;
                                    end loop;
                                    if unsigned(enable_aux) /= 0 then
                                        enable(index) <= enable_aux;
                                        index := index + 1;
                                    end if;
                                end loop;
                                -- Set next step
                                engen_step := 3;

                            -- Simplex vector generation
                            when 3 =>
                                -- Extract enable vectors
                                for j in 0 to C_MAX_SLOTS-1 loop
                                    enable_aux := (others => '0');
                                    if id_ack_current(j) = '1' and (unsigned(tmr_current(C_ARTICO3_GR_WIDTH*(j+1)-1 downto C_ARTICO3_GR_WIDTH*j)) = 0 and unsigned(dmr_current(C_ARTICO3_GR_WIDTH*(j+1)-1 downto C_ARTICO3_GR_WIDTH*j)) = 0) then
                                        enable_aux(j) := '1';
                                    end if;
                                    if unsigned(enable_aux) /= 0 then
                                        enable(index) <= enable_aux;
                                        index := index + 1;
                                    end if;
                                end loop;
                                -- Select first enable vector as output
                                engen_idx <= 0;
                                -- Change FSM state
                                if engen_mode = '1' then
                                    -- Memory transactions require a counter that stores the remaining values that have to be transferred
                                    engen_cnt_remaining <= resize(index*unsigned(block_size_reg), engen_cnt_remaining'length); -- TODO: check if there is any overflow problem with this operation (multiply)
                                    -- Also, another counter has to be used to count all elements transferred to a single accelerator / group of redundant accelerators
                                    engen_cnt_max <= unsigned(block_size_reg);
                                    -- Change state
                                    engen_state <= S_MEM;
                                else
                                    -- Change state
                                    engen_state <= S_REG;
                                end if;
                                -- Set next step
                                engen_step := 0;

                            when others => -- This should never happen
                                -- Set next step
                                engen_step := 0;

                        end case;

                    -- Transactions to/from registers
                    when S_REG =>
                        -- Since only one piece of data is transferred, the control is simple
                        if (axi_reg_W_hs or axi_reg_R_hs) = '1' then
                            engen_state <= S_WAIT;
                        end if;

                    -- Transactions to/from memory
                    when S_MEM =>
                        -- Monitor write and read channel handshakes
                        if (axi_mem_W_hs or axi_mem_R_hs or red_en_base) = '1' then
                            -- Decrement the number of remaining data
                            engen_cnt_remaining <= engen_cnt_remaining - 1;
                            -- Check whether the slot has received all data and if it is the last slot being addressed
                            if (engen_cnt_current = engen_cnt_max-1) and (engen_cnt_remaining > block_size_current) then
                                engen_cnt_current <= (others => '0');
                                engen_idx <= engen_idx + 1;
                            else
                                engen_cnt_current <= engen_cnt_current + 1;
                            end if;
                            -- Last piece of data is about to be transferred, so the process has finished
                            if engen_cnt_remaining = 1 then
                                engen_cnt_current <= (others => '0');
                                engen_state <= S_WAIT;
                            end if;
                        end if;

                end case;
            end if;
        end if;
    end process;

    -- Address reset generation (address generation logic needs a reset whenever a new slot is going to be accessed)
    addr_reset <= '1' when engen_cnt_current = engen_cnt_max-1 else '0';
    -- Address capture generation (address generation logic must perform captures only in the first AXI burst transaction)
    addr_capture <= '1' when engen_state = S_WAIT else '0';

    -- Enable output MUX
    engen_out <= enable(engen_idx) when (engen_state /= S_WAIT) and (engen_state /= S_GEN) else (others => '0');

    -- Falling edge detection logic to generate start signals
    engen_delay: process(s_axi_aclk)
    begin
        if s_axi_aclk'event and s_axi_aclk = '1' then
            if s_axi_aresetn = '0' then
                engen_out_dly1 <= (others => '0');
            else
                engen_out_dly1 <= engen_out;
            end if;
        end if;
    end process;
    -- Start signal generation (since it is asserted in the falling edges of engen_out, it is delayed 1 clock cycle and thus, START is asserted when all data have been transferred)
    -- Also, START signals are only generated after write transactions to the memories inside the compute units / hardware accelerators
    engen_start <= (not engen_out) and engen_out_dly1 when engen_mode = '1' and engen_rw = '0' else (others => '0');

    -----------------
    -- Voter logic --
    -----------------

    -- Latency control when there is no output pipeline
    nopipe_latency_ctrl: if C_PIPE_DEPTH = 0 generate
    begin

        -- Logic to adapt enable signal to voter engine, only taking into account read latencies from compute units (1 clock cycle)
        voter_en_latency: process(s_axi_aclk)
        begin
            if s_axi_aclk'event and s_axi_aclk = '1' then
                if s_axi_aresetn = '0' then
                    voter_en <= (others => '0');
                else
                    voter_en <= engen_out;
                end if;
            end if;
        end process;

    end generate;

    -- Latency control when there is a configurable output pipeline
    pipe_latency_ctrl: if C_PIPE_DEPTH /= 0 generate
    begin

        -- Logic to adapt enable signal to voter engine, taking into account both pipeline and read (from compute units) latencies
        voter_en_latency: process(s_axi_aclk)
            type pipe_t is array (0 to 2*C_PIPE_DEPTH-1) of std_logic_vector(C_MAX_SLOTS-1 downto 0);
            variable pipe : pipe_t;
        begin
            if s_axi_aclk'event and s_axi_aclk = '1' then
                if s_axi_aresetn = '0' then
                    voter_en <= (others => '0');
                    pipe := (others => (others => '0'));
                else
                    voter_en <= pipe(0);
                    for i in 1 to 2*C_PIPE_DEPTH-1 loop
                        pipe(i-1) := pipe(i);
                    end loop;
                    pipe(2*C_PIPE_DEPTH-1) := engen_out;
                end if;
            end if;
        end process;

    end generate;

    -- Logic to generate control signals to select input datapaths
    voter_selector: process(voter_en)
        variable aux       : std_logic_vector(C_MAX_SLOTS-1 downto 0);
        variable remaining : std_logic_vector(C_MAX_SLOTS-1 downto 0);
        variable cnt       : integer range 0 to 3;
    begin
        -- Initialize accelerator count
        cnt := 0;
        -- Register #0 selector
        remaining := voter_en;
        aux := (others => '0');
        for i in 0 to C_MAX_SLOTS-1 loop
            if remaining(i) = '1' and unsigned(aux) = 0 then
                aux(i) := '1';
                cnt := cnt + 1;
            end if;
        end loop;
        voter_sel0 <= aux;
        -- Register #1 selector
        remaining := remaining xor aux;
        aux := (others => '0');
        for i in 0 to C_MAX_SLOTS-1 loop
            if remaining(i) = '1' and unsigned(aux) = 0 then
                aux(i) := '1';
                cnt := cnt + 1;
            end if;
        end loop;
        voter_sel1 <= aux;
        -- Register #2 selector
        remaining := remaining xor aux;
        aux := (others => '0');
        for i in 0 to C_MAX_SLOTS-1 loop
            if remaining(i) = '1' and unsigned(aux) = 0 then
                aux(i) := '1';
                cnt := cnt + 1;
            end if;
        end loop;
        voter_sel2 <= aux;
        -- Get accelerator count
        voter_num <= cnt;
    end process;

    -- Logic to load values to be voted
    voter_register: process(s_axi_aclk)
        variable aux : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    begin
        if s_axi_aclk'event and s_axi_aclk = '1' then
            if s_axi_aresetn = '0' then
                voter_reg0 <= (others => '0');
                voter_reg1 <= (others => '0');
                voter_reg2 <= (others => '0');
            else
                -- Enable voter logic only when a read transaction is being issued
                if engen_rw = '1' then
                    -- Register #0
                    aux := (others => '0');
                    for i in 0 to C_MAX_SLOTS-1 loop
                        if voter_sel0(i) = '1' then
                            aux := voter_data(i);
                        end if;
                    end loop;
                    voter_reg0 <= aux;
                    -- Register #1
                    aux := (others => '0');
                    for i in 0 to C_MAX_SLOTS-1 loop
                        if voter_sel1(i) = '1' then
                            aux := voter_data(i);
                        end if;
                    end loop;
                    voter_reg1 <= aux;
                    -- Register #2
                    aux := (others => '0');
                    for i in 0 to C_MAX_SLOTS-1 loop
                        if voter_sel2(i) = '1' then
                            aux := voter_data(i);
                        end if;
                    end loop;
                    voter_reg2 <= aux;
                end if;
            end if;
        end if;
    end process;

    -- Voter logic
    voter_logic: process(s_axi_aclk)
        variable num_delay : integer range 0 to 3;
        variable aux       : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    begin
        if s_axi_aclk'event and s_axi_aclk = '1' then
            if s_axi_aresetn = '0' then
                voter_out <= (others => '0');
                num_delay := 0;
            else
                -- Decisions are made based on the number of active slots (defined by the current enable signal)
                case num_delay is
                    when 0 => -- No accelerators
                        voter_out <= (others => '0');
                    when 1 => -- Simplex (voter bypass, old PISO implementation)
                        voter_out <= voter_reg0;
                    when 2 => -- DMR or SCA protection
                        -- Check whether the mode is normal DMR or SCA protected
                        if sca_mode = '1' then
                            aux := not voter_reg1; -- If current mode is SCA protection, toggle reg1 and compare
                        else
                            aux := voter_reg1; -- If current mode is DMR, compare with the value in reg1
                        end if;
                        -- Perform voting process
                        if voter_reg0 = aux then
                            voter_out <= voter_reg0;
                        else
                            voter_out <= aux;
                        end if;
                    when 3 => -- TMR
                        -- Perform voting process
                        if voter_reg0 = voter_reg1 then
                            if voter_reg0 = voter_reg2 then
                                --voter_out <= voter_reg0;
                            else
                                --voter_out <= voter_reg0;
                            end if;
                            voter_out <= voter_reg0;
                        else
                            if voter_reg0 = voter_reg2 then
                                voter_out <= voter_reg0;
                            else
                                if voter_reg1 = voter_reg2 then
                                    voter_out <= voter_reg1;
                                else
                                    voter_out <= voter_reg2;
                                end if;
                            end if;
                        end if;
                    when others => -- This should never happen
                        voter_out <= (others => '0');
                end case;
                -- Register number of accelerators to match latencies
                num_delay := voter_num;
            end if;
        end if;
    end process;

    -- Connect output signal of voter logic to input signal to AXI4 interfaces to forward valid data
    axi_mem_R_data <= voter_out;
    axi_reg_R_data <= voter_out when to_integer(unsigned(axi_reg_R_op)) = 0 else red_macreg;

    ---------------------
    -- Reduction logic --
    ---------------------

    -- Address generation logic
    red_addr_gen: process(S_AXI_ACLK)
    begin
        if s_axi_aclk'event and s_axi_aclk = '1' then
            if s_axi_aresetn = '0' then
                red_araddr <= (others => '0');
            else
                -- Capture address and initialize counter
                if axi_red_AR_hs = '1' then
                    if addr_capture = '1' then
                        red_araddr <= (others => '0');
                    end if;
                -- If not capturing, the system is moving data
                elsif red_en_base = '1' and engen_cnt_remaining /= 0 then -- TODO: verificar esta condición
                    if addr_reset = '1' then
                        red_araddr <= (others => '0');
                    else
                        red_araddr <= std_logic_vector(unsigned(red_araddr) + 1);
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Reduction enable without additional latencies due to enable generation
    nolatency_reduction: if C_EN_LATENCY = 0 generate
    begin

        -- Reduction enable generation
        red_en_gen: process(s_axi_aclk)
            variable red_ctrl_dly1 : std_logic;
        begin
            if s_axi_aclk'event and s_axi_aclk = '1' then
                if s_axi_aresetn = '0' then
                    red_en_base <= '0';
                    red_ctrl_dly1 := '0';
                else
                    if (red_ctrl and (not red_ctrl_dly1)) = '1' then -- Edge detection: rising edge in red_ctrl
                        red_en_base <= '1';
                    elsif engen_cnt_remaining = 1 then -- Wait until the last piece of data is being acknowledged
                        red_en_base <= '0';
                    end if;
                    -- Register red_ctrl
                    red_ctrl_dly1 := red_ctrl;
                end if;
            end if;
        end process;

    end generate;

    -- Reduction enable with additional latencies due to enable generation
    latency_reduction: if C_EN_LATENCY /= 0 generate
    begin

        -- Reduction enable generation
        red_en_gen: process(s_axi_aclk)
            variable red_ctrl_dly1   : std_logic;
            variable red_ctrl_redge : std_logic_vector(C_EN_LATENCY-1 downto 0);
        begin
            if s_axi_aclk'event and s_axi_aclk = '1' then
                if s_axi_aresetn = '0' then
                    red_en_base <= '0';
                    red_ctrl_dly1 := '0';
                    red_ctrl_redge := (others => '0');
                else
                    if red_ctrl_redge(0) = '1' then -- Edge detection: rising edge in red_ctrl wirh a latency of C_EN_LATENCY clock cycles
                        red_en_base <= '1';
                    elsif engen_cnt_remaining = 1 then -- Wait until the last piece of data is being acknowledged
                        red_en_base <= '0';
                    end if;
                    -- en latency control
                    for i in 1 to C_EN_LATENCY-1 loop
                        red_ctrl_redge(i-1) := red_ctrl_redge(i);
                    end loop;
                    red_ctrl_redge(C_EN_LATENCY-1) := red_ctrl and (not red_ctrl_dly1);
                    -- Register red_ctrl
                    red_ctrl_dly1 := red_ctrl;
                end if;
            end if;
        end process;

    end generate;

    -- Latency control when there is no pipeline
    nopipe_latency_ctrl_reduction: if C_PIPE_DEPTH = 0 and C_VOTER_LATENCY = 0 generate
    begin

        -- Control signals have to take into account the latency of a read operation in a BRAM (1 clock cycle)

        -- Latency handling in the returning path from pipeline
        pipe_lat: process(s_axi_aclk)
        begin
            if s_axi_aclk'event and s_axi_aclk = '1' then
                if s_axi_aresetn = '0' then
                    red_en <= '0';
                else
                    red_en <= red_en_base;
                end if;
            end if;
        end process;

    end generate;

    -- Latency control when there is a configurable pipeline
    pipe_latency_ctrl_reduction: if C_PIPE_DEPTH /= 0 or C_VOTER_LATENCY /= 0 generate
    begin

        -- Control signals have to take into account the latency of a read operation in a BRAM (1 clock cycle),
        -- in the voter (C_VOTER_LATENCY clock cycles) and twice the latency of the pipeline (2*C_PIPE_DEPTH clock cycles)

        -- Latency handling in the returning path from pipeline
        pipe_lat: process(s_axi_aclk)
            variable pipe : std_logic_vector(((2*C_PIPE_DEPTH)+C_VOTER_LATENCY)-1 downto 0);
        begin
            if s_axi_aclk'event and s_axi_aclk = '1' then
                if s_axi_aresetn = '0' then
                    red_en <= '0';
                    pipe := (others => '0');
                else
                    red_en <= pipe(0);
                    for i in 1 to ((2*C_PIPE_DEPTH)+C_VOTER_LATENCY)-1 loop
                        pipe(i-1) := pipe(i);
                    end loop;
                    pipe(((2*C_PIPE_DEPTH)+C_VOTER_LATENCY)-1) := red_en_base;
                end if;
            end if;
        end process;

    end generate;

    -- Reduction engine
    reduction_proc: process(s_axi_aclk)
        variable load_macreg : std_logic; -- This variable is used to delay axi_red_AR_hs 1 clock cycle (axi_reg_R_op is updated 1 clock cycle after the channel handshake), so that the initialization of the accumulator is coherent with the current reduction operation
    begin
        if s_axi_aclk'event and s_axi_aclk = '1' then
            if s_axi_aresetn = '0' then
                red_macreg <= (others => '0');
                load_macreg := '0';
            else
                -- The reduction engine is initialized whenever a reduction transaction is issued
                if load_macreg = '1' then
                    -- Operation codes
                    case to_integer(unsigned(axi_reg_R_op)) is
                        when 1 => -- ADD (unsigned)
                            red_macreg <= (others => '0');
                        when 2 => -- MAX (unsigned)
                            red_macreg <= (others => '0');
                        when 3 => -- MIN (unsigned)
                            red_macreg <= (others => '1');
                        when others => -- TODO: add functionality
                            red_macreg <= (others => '0');
                    end case;
                end if;
                -- Delay reduction ARVALID/ARREADY handshake 1 clock cycle
                load_macreg := axi_red_AR_hs;
                -- Reduction engine core
                if red_en = '1' then
                    -- Operation codes
                    case to_integer(unsigned(axi_reg_R_op)) is
                        when 1 => -- ADD (unsigned)
                            red_macreg <= std_logic_vector(unsigned(red_macreg) + unsigned(voter_out));
                        when 2 => -- MAX (unsigned)
                            if unsigned(voter_out) > unsigned(red_macreg) then
                                red_macreg <= voter_out;
                            end if;
                        when 3 => -- MIN (unsigned)
                            if unsigned(voter_out) < unsigned(red_macreg) then
                                red_macreg <= voter_out;
                            end if;
                        when others => -- TODO: add functionality

                    end case;
                end if;
            end if;
        end if;
    end process;

    -- RVALID generation (falling edge in red_en signal, i.e. when the reduction transaction has finished and the last value has been loaded in the accumulator)
    reduction_rvalid: process(s_axi_aclk)
    begin
        if s_axi_aclk'event and s_axi_aclk = '1' then
            if s_axi_aresetn = '0' then
                red_en_dly1 <= '0';
            else
                red_en_dly1 <= red_en;
            end if;
        end if;
    end process;
    -- Falling edge detection
    red_rvalid <= (not red_en) and red_en_dly1;

    ---------------------------------------
    -- Clock and Reset for Compute Units --
    ---------------------------------------

    -- Clock gating is implemented using specific device primitives (TECHNOLOGY DEPENDENT)
    clock_gen: for i in 0 to C_MAX_SLOTS-1 generate
    begin

        -- NOTE: not all implementations will support clock gating techniques, either because the required device primitives
        --       do not exist in all FPGA devices, or because the number of available primitives is not enough to have single
        --       rail control of all compute units (i.e. one buffer per compute unit might not be available in some FPGAs)

        -- NOTE: there are three alternatives: no clock gating, clock gating using global buffers, and clock gating using
        --       horizontal buffers available in 7-Series clock regions. Only one alternative can be used for all compute units
        --       and its value can be configured using a generic in the top module (this one)

        ---------------
        -- No buffer --
        ---------------

        nobuff_gen: if C_CLK_GATE_BUFFER = "NO_BUFFER" generate
        begin

            artico3_aclk(i) <= s_axi_aclk;

        end generate;

        -------------------
        -- Global buffer --
        -------------------

        gbuff_clkgen: if C_CLK_GATE_BUFFER = "GLOBAL" generate
        begin

            -- BUFGCE: Global Clock Buffer with Clock Enable
            --         7-Series
            -- Xilinx HDL Language Template, version 2015.3

            clock_buffer: BUFGCE
            port map (
              O  => artico3_aclk(i), -- 1-bit output: Clock output
              CE => clk_gate_reg(i), -- 1-bit input: Clock enable input for I0
              I  => s_axi_aclk       -- 1-bit input: Primary clock
            );

            -- End of clock_buffer instantiation

        end generate;

        -----------------------
        -- Horizontal buffer --
        -----------------------

        hbuff_clkgen: if C_CLK_GATE_BUFFER = "HORIZONTAL" generate
        begin

            -- BUFHCE: HROW Clock Buffer for a Single Clocking Region with Clock Enable
            --         7-Series
            -- Xilinx HDL Language Template, version 2015.3

            clock_buffer: BUFHCE
            generic map (
               CE_TYPE  => "SYNC", -- "SYNC" (glitchless switching) or "ASYNC" (immediate switch)
               INIT_OUT => 0       -- Initial output value (0-1)
            )
            port map (
               O  => artico3_aclk(i), -- 1-bit output: Clock output
               CE => clk_gate_reg(i), -- 1-bit input: Active high enable
               I  => s_axi_aclk       -- 1-bit input: Clock input
            );

            -- End of clock_buffer instantiation

        end generate;

    end generate;

    -- Reset generation logic using specific device primitives (TECHNOLOGY DEPENDENT)
    reset_gen: for i in 0 to C_MAX_SLOTS-1 generate

        -- Intermediate signal to store gated RESET signal
        signal aresetn : std_logic;

    begin

        -- NOTE: although buffers are intended to be used with clock signals, here they are used to
        --       connect the reset signals for each hardware accelerator (to reduce the number of
        --       interconnections in the reconfigurable border)

        -- NOTE: as with the clock buffers, there are three alternatives: no buffer, global buffer, and
        --       horizontal buffer (available in 7-Series clock regions). Only one alternative can be used
        --       for all compute units and its value can be configured using a generic in the top module (this one)

        -- Assign intermediate signal
        aresetn <= s_axi_aresetn and (sw_aresetn or (not id_ack_reg(i)));

        ---------------
        -- No buffer --
        ---------------

        nobuff_rstgen: if C_RST_BUFFER = "NO_BUFFER" generate
        begin

           artico3_aresetn(i) <= aresetn;

        end generate;

        -------------------
        -- Global buffer --
        -------------------

        gbuff_rstgen: if C_RST_BUFFER = "GLOBAL" generate
        begin

           -- BUFG: Global Clock Simple Buffer
           --       7-Series
           -- Xilinx HDL Language Template, version 2015.3

           reset_buffer: BUFG
           port map (
              O => artico3_aresetn(i), -- 1-bit output: Active-low reset output
              I => aresetn             -- 1-bit input: Active-low reset input
           );

           -- End of reset_buffer instantiation

        end generate;

        -----------------------
        -- Horizontal buffer --
        -----------------------

        hbuff_rstgen: if C_RST_BUFFER = "HORIZONTAL" generate
        begin

            -- BUFH: HROW Clock Buffer for a Single Clocking Region
            --       7-Series
            -- Xilinx HDL Language Template, version 2015.3

            reset_buffer : BUFH
            port map (
              O => artico3_aresetn(i), -- 1-bit output: Active-low reset output
              I => aresetn             -- 1-bit input: Active-low reset input
            );

            -- End of reset_buffer instantiation

        end generate;

    end generate;

    --------------------
    -- Pipeline logic --
    --------------------

    -- If no register is necesary...
    nopipe_logic: if C_PIPE_DEPTH = 0 generate
    begin

        artico3_start <= engen_start;
        ready_reg <= artico3_ready;
        artico3_en <= engen_out;
        artico3_we <= engen_out when axi_mem_W_hs = '1' or axi_reg_W_hs = '1' else (others => '0');
        artico3_mode <= engen_out when (axi_mem_W_hs = '1' or axi_mem_R_hs = '1') or red_en_base = '1' else (others => '0'); -- Mode represents which element is being accessed (1 means memory, 0 means registers)

        slot_logic: for i in 0 to C_MAX_SLOTS-1 generate
        begin

            artico3_addr(i) <= red_araddr when red_en_base = '1' else
                               axi_mem_R_addr when axi_mem_R_hs = '1' else
                               axi_mem_W_addr when axi_mem_W_hs = '1' else
                               axi_reg_R_addr when axi_reg_R_hs = '1' else
                               axi_reg_W_addr when axi_reg_W_hs = '1' else
                               (others => '0');
            artico3_wdata(i) <= axi_mem_W_data when axi_mem_W_hs = '1' else
                                axi_reg_W_data when axi_reg_W_hs = '1' else
                                (others => '0');

        end generate;

        voter_data <= artico3_rdata;

    end generate;

    -- When registers are mandatory to keep high operating frequencies...
    pipe_logic: if C_PIPE_DEPTH /= 0 generate
    begin

        -- NOTE: each compute unit has its own pipeline, which can be switched off by gating the corresponding
        --       clock signal. This helps reducing dynamic power consumption in the static region when some of
        --       the hardware accelerators (compute units) are not clocked

        -- Pipeline logic per slot
        slot_pipe: for i in 0 to C_MAX_SLOTS-1 generate

            signal start      : std_logic;
            signal pipe_start : std_logic_vector(C_PIPE_DEPTH-1 downto 0);
            signal ready      : std_logic;
            signal pipe_ready : std_logic_vector(C_PIPE_DEPTH-1 downto 0);
            signal en         : std_logic;
            signal pipe_en    : std_logic_vector(C_PIPE_DEPTH-1 downto 0);
            signal we         : std_logic;
            signal pipe_we    : std_logic_vector(C_PIPE_DEPTH-1 downto 0);
            signal mode       : std_logic;
            signal pipe_mode  : std_logic_vector(C_PIPE_DEPTH-1 downto 0);

            type pipe_data_t is array (0 to C_PIPE_DEPTH-1) of std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
            type pipe_addr_t is array (0 to C_PIPE_DEPTH-1) of std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
            signal addr       : std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
            signal pipe_addr  : pipe_addr_t;
            signal wdata      : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
            signal pipe_wdata : pipe_data_t;
            signal rdata      : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
            signal pipe_rdata : pipe_data_t;

        begin

            -- Pipeline input
            start <= engen_start(i);
            ready <= artico3_ready(i);
            en <= engen_out(i);
            we <= engen_out(i) when axi_mem_W_hs = '1' or axi_reg_W_hs = '1' else '0';
            mode <= engen_out(i) when (axi_mem_W_hs = '1' or axi_mem_R_hs = '1') or red_en_base = '1' else '0'; -- Mode represents which element is being accessed (1 means memory, 0 means registers)
            addr <= red_araddr when red_en_base = '1' else
                    axi_mem_R_addr when axi_mem_R_hs = '1' else
                    axi_mem_W_addr when axi_mem_W_hs = '1' else
                    axi_reg_R_addr when axi_reg_R_hs = '1' else
                    axi_reg_W_addr when axi_reg_W_hs = '1' else
                    (others => '0');
            wdata <= axi_mem_W_data when axi_mem_W_hs = '1' else
                     axi_reg_W_data when axi_reg_W_hs = '1' else
                     (others => '0');
            rdata <= artico3_rdata(i);

            -- Pipeline logic
            pipe_proc: process(artico3_aclk(i))
            begin
                if artico3_aclk(i)'event and artico3_aclk(i) = '1' then
                    if artico3_aresetn(i) = '0' then
                        pipe_start <= (others => '0');
                        pipe_ready <= (others => '0');
                        pipe_en <= (others => '0');
                        pipe_we <= (others => '0');
                        pipe_mode <= (others => '0');
                        pipe_addr <= (others => (others => '0'));
                        pipe_wdata <= (others => (others => '0'));
                        pipe_rdata <= (others => (others => '0'));
                    else
                        for i in 1 to C_PIPE_DEPTH-1 loop
                            pipe_start(i-1) <= pipe_start(i);
                            pipe_ready(i-1) <= pipe_ready(i);
                            pipe_en(i-1) <= pipe_en(i);
                            pipe_we(i-1) <= pipe_we(i);
                            pipe_mode(i-1) <= pipe_mode(i);
                            pipe_addr(i-1) <= pipe_addr(i);
                            pipe_wdata(i-1) <= pipe_wdata(i);
                            pipe_rdata(i-1) <= pipe_rdata(i);
                        end loop;
                        pipe_start(C_PIPE_DEPTH-1) <= start;
                        pipe_ready(C_PIPE_DEPTH-1) <= ready;
                        pipe_en(C_PIPE_DEPTH-1) <= en;
                        pipe_we(C_PIPE_DEPTH-1) <= we;
                        pipe_mode(C_PIPE_DEPTH-1) <= mode;
                        pipe_addr(C_PIPE_DEPTH-1) <= addr;
                        pipe_wdata(C_PIPE_DEPTH-1) <= wdata;
                        pipe_rdata(C_PIPE_DEPTH-1) <= rdata;
                    end if;
                end if;
            end process;

            -- Pipeline output
            artico3_start(i) <= pipe_start(0);
            ready_reg(i) <= pipe_ready(0);
            artico3_en(i) <= pipe_en(0);
            artico3_we(i) <= pipe_we(0);
            artico3_mode(i) <= pipe_mode(0);
            artico3_addr(i) <= pipe_addr(0);
            artico3_wdata(i) <= pipe_wdata(0);
            voter_data(i) <= pipe_rdata(0);

        end generate;

    end generate;

    --------------------------
    -- Transaction ID logic --
    --------------------------

    -- Select a valid ID signal, which depends on the mode (either memory or registers are being accessed) and on the operation (read or write)
    id_current <= axi_reg_W_id when to_integer(unsigned(axi_reg_W_op)) = 1 else -- SW reset (OP code "0001") has priority over the rest of transactions (NOTE: could be to_integer(unsigned(axi_reg_W_op)) /= 0)
                  axi_reg_R_id when to_integer(unsigned(axi_reg_R_op)) /= 0 else -- Reduction operations require this ID
                  axi_mem_R_id when engen_mode = '1' and engen_rw = '1' else
                  axi_mem_W_id when engen_mode = '1' and engen_rw = '0' else
                  axi_reg_R_id when engen_mode = '0' and engen_rw = '1' else
                  axi_reg_W_id when engen_mode = '0' and engen_rw = '0' else
                  (others => '0');

    -- Generate ID response to identify current available accelerators
    id_ack_generation: process(id_current, id_reg)
        variable aux : std_logic_vector(C_MAX_SLOTS-1 downto 0);
    begin
        -- ID = 0 means that it is the Shuffler the one being accessed; otherwise it is an accelerator
        if to_integer(unsigned(id_current)) /= 0 then
            -- Initialize auxiliary variable
            aux := (others => '0');
            -- Check the contents of ID register
            for i in 0 to C_MAX_SLOTS-1 loop
                if id_reg(C_ARTICO3_ID_WIDTH*(i+1)-1 downto C_ARTICO3_ID_WIDTH*i) = id_current then
                    aux(i) := '1';
                end if;
            end loop;
            -- Get ID acknowledges
            id_ack_reg <= aux;
        else
            id_ack_reg <= (others => '0');
        end if;
    end process;

    ---------------------
    -- Interrupt logic --
    ---------------------

    -- NOTE: in this version, interrupts are generated when all hardware accelerators involved in a
    --       processing round have finished and therefore data are ready to be read from them to the
    --       external memory. Although this is not the best implementation, since it increases the
    --       amount of dead times (no processing nor data transfers taking place) per round, it is
    --       a valid and easy-to-implement approach.

    -- Rising-edge sensitive interrupt generation logic.
    interrupt_gen: process(s_axi_aclk)
        variable ready_reg_dly1 : std_logic_vector(C_MAX_SLOTS-1 downto 0);
    begin
        if s_axi_aclk'event and s_axi_aclk = '1' then
            if s_axi_aresetn = '0' then
                interrupt_s <= '0';
                ready_reg_dly1:= (others => '0');
            else
                -- Interrupt generation
                interrupt_s <= '0';
                for i in 0 to C_MAX_SLOTS-1 loop
                    -- Interrupts are generated whenever a hardware accelerator finishes its processing
                    if ready_reg(i) /= ready_reg_dly1(i) and ready_reg(i) = '1' then
                        interrupt_s <= '1';
                    end if;
                end loop;
                -- The register containing the number of accelerators that have finished
                -- has to be registered in order to be able to detect changes in its contents.
                ready_reg_dly1 := ready_reg;
            end if;
        end if;
    end process;

    -- Connect internal signal with output port
    interrupt <= interrupt_s;

end arch;
