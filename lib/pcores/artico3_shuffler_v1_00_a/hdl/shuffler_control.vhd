-----------------------------------------------------------------------------
-- ARTICo3 - Data Shuffler Control datapath                                --
--                                                                         --
-- Author: Alfonso Rodriguez <alfonso.rodriguezm@upm.es>                   --
--                                                                         --
-- Features:                                                               --
--     AXI4-Lite protocol                                                  --
--     Register-based interface                                            --
--     Configurable register bank                                          --
--                                                                         --
-- This module includes all logic required for implementing control and    --
-- configuration in ARTICo3 Shuffler                                       --
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity shuffler_control is
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
        -- Number of pipeline stages (registers) between IF and software-accessible registers
        C_PIPE_DEPTH         : integer := 3;
        -- Number of cycles required to generate a valid en signal
        C_EN_LATENCY         : integer := 4;
        -- Number of cycles required to vote valid data
        C_VOTER_LATENCY      : integer := 2;
        -- Maximum number of reconfigurable slots
        C_MAX_SLOTS          : integer := 8;

        --------------------------
        -- Interface parameters --
        --------------------------

        -- ARTICo3 address size
        C_ARTICO3_ADDR_WIDTH : integer := 16;
        -- ARTICo3 ID size
        C_ARTICO3_ID_WIDTH   : integer := 4;
        -- ARTICo3 OPeration mode size
        C_ARTICO3_OP_WIDTH   : integer := 4;
        -- ARTICo3 DMR/TMR GRoup size
        C_ARTICO3_GR_WIDTH   : integer := 4;

        -- Width of S_AXI data bus
        C_S_AXI_DATA_WIDTH   : integer := 32;
        -- Width of S_AXI address bus
        C_S_AXI_ADDR_WIDTH   : integer := 20
    );
    port (
        ----------------------
        -- Additional ports --
        ----------------------

        -- AXI4 Interface signals used inside the Shuffler module --

        -- AXI4-Lite WDATA
        axi_reg_W_data : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        -- AXI4-Lite RDATA
        axi_reg_R_data : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        -- AXI4-Lite AWADDR (without compute unit ID and OPeration code)
        axi_reg_W_addr : out std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
        -- AXI4-Lite ARADDR (without compute unit ID and OPeration code)
        axi_reg_R_addr : out std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
        -- AXI4-Lite AWVALID/AWREADY handshake
        axi_reg_AW_hs  : out std_logic;
        -- AXI4-Lite ARVALID/ARREADY handshake
        axi_reg_AR_hs  : out std_logic;
        -- AXI4-Lite WVALID/WREADY handshake
        axi_reg_W_hs   : out std_logic;
        -- AXI4-Lite RVALID/RREADY handshake
        axi_reg_R_hs   : out std_logic;
        -- AXI4-Lite Write transaction ID (captured from AWADDR)
        axi_reg_W_id   : out std_logic_vector(C_ARTICO3_ID_WIDTH-1 downto 0);
        -- AXI4-Lite Read transaction ID (captured from ARADDR)
        axi_reg_R_id   : out std_logic_vector(C_ARTICO3_ID_WIDTH-1 downto 0);
        -- AXI4-Lite Write transaction OPeration mode (captured from AWADDR)
        axi_reg_W_op   : out std_logic_vector(C_ARTICO3_OP_WIDTH-1 downto 0);
        -- AXI4-Lite Read transaction OPeration mode (captured from ARADDR)
        axi_reg_R_op   : out std_logic_vector(C_ARTICO3_OP_WIDTH-1 downto 0);

        -- Reduction engine signals --

        -- AXI4-Lite ARVALID/ARREADY handshake in reduction transactions
        axi_red_AR_hs  : out std_logic;
        -- Reduction engine RVALID signal (generated outside this module)
        red_rvalid     : in  std_logic;
        -- Control signal that can be used to check if a reduction transaction is being conducted
        red_ctrl       : out std_logic;

        -- ARTICo3 registers --

        -- ID Register contents (ARTICo3 configuration register)
        id_reg         : out std_logic_vector((C_MAX_SLOTS*C_ARTICO3_ID_WIDTH)-1 downto 0);
        -- TMR Register contents (ARTICo3 configuration register)
        tmr_reg        : out std_logic_vector((C_MAX_SLOTS*C_ARTICO3_GR_WIDTH)-1 downto 0);
        -- DMR Register contents (ARTICo3 configuration register)
        dmr_reg        : out std_logic_vector((C_MAX_SLOTS*C_ARTICO3_GR_WIDTH)-1 downto 0);
        -- BLOCK_SIZE Register contents (ARTICo3 configuration register)
        block_size_reg : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        -- Clock gating configuration register (ARTICo3 configuration register)
        clk_gate_reg   : out std_logic_vector(C_MAX_SLOTS-1 downto 0);
        -- READY Register contents (ARTICo3 status register)
        ready_reg      : in  std_logic_vector(C_MAX_SLOTS-1 downto 0);

        -- PMC registers --

        -- Slot execution cycles
        pmc_cycles     : in  std_logic_vector((C_MAX_SLOTS*C_S_AXI_DATA_WIDTH)-1 downto 0);
        -- Slot execution errors
        pmc_errors     : in  std_logic_vector((C_MAX_SLOTS*C_S_AXI_DATA_WIDTH)-1 downto 0);
        pmc_errors_rst : out std_logic_vector(C_MAX_SLOTS-1 downto 0);

        -- Other signals --

        -- Software-generated reset signal
        sw_aresetn     : out std_logic;

        -- Software-generated start signal
        sw_start       : out std_logic;

        ---------------------
        -- Interface ports --
        ---------------------

        -- Global Clock Signal
        S_AXI_ACLK    : in  std_logic;
        -- Global Reset Signal. This Signal is Active LOW
        S_AXI_ARESETN : in  std_logic;

        -- Address Write channel --

        -- Write address (issued by master, acceped by Slave)
        S_AXI_AWADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        -- Write channel Protection type. This signal indicates the
        -- privilege and security level of the transaction, and whether
        -- the transaction is a data access or an instruction access.
        S_AXI_AWPROT  : in  std_logic_vector(2 downto 0);
        -- Write address valid. This signal indicates that the master signaling
        -- valid write address and control information.
        S_AXI_AWVALID : in  std_logic;
        -- Write address ready. This signal indicates that the slave is ready
        -- to accept an address and associated control signals.
        S_AXI_AWREADY : out std_logic;

        -- Write channel --

        -- Write data (issued by master, acceped by Slave)
        S_AXI_WDATA   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        -- Write strobes. This signal indicates which byte lanes hold
        -- valid data. There is one write strobe bit for each eight
        -- bits of the write data bus.
        S_AXI_WSTRB   : in  std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
        -- Write valid. This signal indicates that valid write
        -- data and strobes are available.
        S_AXI_WVALID  : in  std_logic;
        -- Write ready. This signal indicates that the slave
        -- can accept the write data.
        S_AXI_WREADY  : out std_logic;

        -- Write Response channel --

        -- Write response. This signal indicates the status
        -- of the write transaction.
        S_AXI_BRESP   : out std_logic_vector(1 downto 0);
        -- Write response valid. This signal indicates that the channel
        -- is signaling a valid write response.
        S_AXI_BVALID  : out std_logic;
        -- Response ready. This signal indicates that the master
        -- can accept a write response.
        S_AXI_BREADY  : in  std_logic;

        -- Address Read channel --

        -- Read address (issued by master, acceped by Slave)
        S_AXI_ARADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        -- Protection type. This signal indicates the privilege
        -- and security level of the transaction, and whether the
        -- transaction is a data access or an instruction access.
        S_AXI_ARPROT  : in  std_logic_vector(2 downto 0);
        -- Read address valid. This signal indicates that the channel
        -- is signaling valid read address and control information.
        S_AXI_ARVALID : in  std_logic;
        -- Read address ready. This signal indicates that the slave is
        -- ready to accept an address and associated control signals.
        S_AXI_ARREADY : out std_logic;

        -- Read channel --

        -- Read data (issued by slave)
        S_AXI_RDATA   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        -- Read response. This signal indicates the status of the
        -- read transfer.
        S_AXI_RRESP   : out std_logic_vector(1 downto 0);
        -- Read valid. This signal indicates that the channel is
        -- signaling the required read data.
        S_AXI_RVALID  : out std_logic;
        -- Read ready. This signal indicates that the master can
        -- accept the read data and response information.
        S_AXI_RREADY  : in  std_logic
    );
end shuffler_control;

architecture behavioral of shuffler_control is

    -----------------------
    -- Interface signals --
    -----------------------

    -- R/W arbiter

    type arb_state_t is (S_IDLE, S_READ, S_WRITE, S_LAST);
    signal arb_state          : arb_state_t;     -- Arbiter control FSM

    type arb_previous_t is (OP_READ, OP_WRITE);
    signal arb_previous       : arb_previous_t;  -- Most recently used access type (to implement round-robin arbitration in simultaneous accesses)

    signal arb_aw_active      : std_logic;       -- Write access granted
    signal arb_aw_clear       : std_logic;       -- Write access finished
    signal arb_ar_active      : std_logic;       -- Read access granted
    signal arb_ar_clear       : std_logic;       -- Read access finished

    -- Address Write channel --

    signal axi_awaddr         : std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
    signal axi_awprot         : std_logic_vector(2 downto 0);
    signal axi_awvalid        : std_logic;
    signal axi_awready        : std_logic;

    -- Write channel --

    signal axi_wdata          : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal axi_wstrb          : std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
    signal axi_wvalid         : std_logic;
    signal axi_wready         : std_logic;

    type write_state_t is (S_IDLE, S_RUN);
    signal write_state        : write_state_t;

    -- Write Response channel --

    signal axi_bresp          : std_logic_vector(1 downto 0);
    signal axi_bvalid         : std_logic;
    signal axi_bready         : std_logic;

    -- Address Read channel --

    signal axi_araddr         : std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
    signal axi_arprot         : std_logic_vector(2 downto 0);
    signal axi_arvalid        : std_logic;
    signal axi_arready        : std_logic;

    -- Read channel --

    signal axi_rdata          : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal axi_rresp          : std_logic_vector(1 downto 0);
    signal axi_rvalid         : std_logic;
    signal axi_rready         : std_logic;

    signal axi_rvalid_base    : std_logic; -- For registers inside the Shuffler module (not affected by the pipeline)
    signal axi_rvalid_ext     : std_logic; -- For registers in the compute units (affected by the pipeline)
    signal axi_rvalid_regctrl : std_logic; -- Control signal to select which RVALID signal set as output when accessing registers, either inside or outside the shuffler module
    signal axi_rvalid_redctrl : std_logic; -- Control signal to select which RVALID signal set as output, either the one coming from register accesses or the one coming from reduction logic

    type read_state_t is (S_IDLE, S_RUN);
    signal read_state         : read_state_t;

    --------------------------------
    -- Configurable register bank --
    --------------------------------

    constant C_NUM_REG : integer := C_NUM_REG_RW + C_NUM_REG_RO;
    type reg_out_t is array (0 to C_NUM_REG-1) of std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal reg_out            : reg_out_t; -- Register bank outputs

    ------------------------
    -- Additional signals --
    ------------------------

    -- ID signals
    signal reg_wid            : std_logic_vector(C_ARTICO3_ID_WIDTH-1 downto 0); -- Current write transaction ID
    signal reg_rid            : std_logic_vector(C_ARTICO3_ID_WIDTH-1 downto 0); -- Current read transaction ID

    -- OPeration mode signals
    signal reg_wop            : std_logic_vector(C_ARTICO3_OP_WIDTH-1 downto 0); -- Current write transaction OPeration
    signal reg_rop            : std_logic_vector(C_ARTICO3_OP_WIDTH-1 downto 0); -- Current read transaction OPeration

    -----------
    -- DEBUG --
    -----------

    attribute mark_debug : string;

    attribute mark_debug of arb_state          : signal is "TRUE";
    attribute mark_debug of arb_previous       : signal is "TRUE";
    attribute mark_debug of arb_aw_active      : signal is "TRUE";
    attribute mark_debug of arb_aw_clear       : signal is "TRUE";
    attribute mark_debug of arb_ar_active      : signal is "TRUE";
    attribute mark_debug of arb_ar_clear       : signal is "TRUE";

    attribute mark_debug of axi_awaddr         : signal is "TRUE";
    attribute mark_debug of axi_awprot         : signal is "TRUE";
    attribute mark_debug of axi_awvalid        : signal is "TRUE";
    attribute mark_debug of axi_awready        : signal is "TRUE";

    attribute mark_debug of axi_wdata          : signal is "TRUE";
    attribute mark_debug of axi_wstrb          : signal is "TRUE";
    attribute mark_debug of axi_wvalid         : signal is "TRUE";
    attribute mark_debug of axi_wready         : signal is "TRUE";
    attribute mark_debug of write_state        : signal is "TRUE";

    attribute mark_debug of axi_bresp          : signal is "TRUE";
    attribute mark_debug of axi_bvalid         : signal is "TRUE";
    attribute mark_debug of axi_bready         : signal is "TRUE";

    attribute mark_debug of axi_araddr         : signal is "TRUE";
    attribute mark_debug of axi_arprot         : signal is "TRUE";
    attribute mark_debug of axi_arvalid        : signal is "TRUE";
    attribute mark_debug of axi_arready        : signal is "TRUE";

    attribute mark_debug of axi_rdata          : signal is "TRUE";
    attribute mark_debug of axi_rresp          : signal is "TRUE";
    attribute mark_debug of axi_rvalid         : signal is "TRUE";
    attribute mark_debug of axi_rready         : signal is "TRUE";
    attribute mark_debug of axi_rvalid_base    : signal is "TRUE";
    attribute mark_debug of axi_rvalid_ext     : signal is "TRUE";
    attribute mark_debug of axi_rvalid_regctrl : signal is "TRUE";
    attribute mark_debug of axi_rvalid_redctrl : signal is "TRUE";
    attribute mark_debug of read_state         : signal is "TRUE";

    attribute mark_debug of reg_out            : signal is "TRUE";

    attribute mark_debug of reg_wid            : signal is "TRUE";
    attribute mark_debug of reg_rid            : signal is "TRUE";

    attribute mark_debug of reg_wop            : signal is "TRUE";
    attribute mark_debug of reg_rop            : signal is "TRUE";

begin

    -------------------------------
    -- AXI4-Lite interface logic --
    -------------------------------

    -- R/W arbiter

    -- NOTE: this implementation avoids simulataneous accesses from both
    --       read and write channels, using Round-Robin arbitration.

    rw_arbiter: process(S_AXI_ACLK)
    begin
        if S_AXI_ACLK'event and S_AXI_ACLK = '1' then
            if S_AXI_ARESETN = '0' then
                axi_awready <= '0';
                axi_arready <= '0';
                arb_aw_active <= '0';
                arb_ar_active <= '0';
                arb_previous <= OP_READ;
                arb_state <= S_IDLE;
            else
                case arb_state is

                    when S_IDLE =>
                        if (axi_arvalid = '1' and axi_awvalid = '1' and arb_previous = OP_WRITE) or
                           (axi_arvalid = '1' and axi_awvalid = '0') then
                            axi_arready <= '1';
                            arb_ar_active <= '1';
                            arb_previous <= OP_READ;
                            arb_state <= S_READ;
                        elsif axi_awvalid = '1' then -- TODO: add condition to limit the maximum number of pending write responses (B channel in AXI4 interface)
                            axi_awready <= '1';
                            arb_aw_active <= '1';
                            arb_previous <= OP_WRITE;
                            arb_state <= S_WRITE;
                        end if;

                    when S_READ =>
                        axi_arready <= '0';
                        if arb_ar_clear = '1' then
                            arb_ar_active <= '0';
                            arb_state <= S_LAST;
                        end if;

                    when S_WRITE =>
                        axi_awready <= '0';
                        if arb_aw_clear = '1' then
                            arb_aw_active <= '0';
                            arb_state <= S_LAST;
                        end if;

                    when S_LAST =>
                        if arb_aw_clear = '0' and arb_ar_clear = '0' then
                            arb_state <= S_IDLE;
                        end if;

                end case;
            end if;
        end if;
    end process;

    -- Address Write channel --

    -- I/O port connections
    axi_awvalid <= S_AXI_AWVALID;
    S_AXI_AWREADY <= axi_awready;

    -- Channel signal processing
    aw_data: process(S_AXI_ACLK)
    begin
        if S_AXI_ACLK'event and S_AXI_ACLK = '1' then
            if S_AXI_ARESETN = '0' then
                axi_awaddr <= (others => '0');
                axi_awprot <= (others => '0');
                reg_wid <= (others => '0');
                reg_wop <= (others => '0');
            else
                -- Write Address and transaction ID are captured when a VALID-READY handshake happens
                if axi_awvalid = '1' and axi_awready = '1' then
                    axi_awaddr <= std_logic_vector(resize(shift_right(unsigned(S_AXI_AWADDR(C_ARTICO3_ADDR_WIDTH-C_ARTICO3_OP_WIDTH-1 downto 0)), (C_S_AXI_DATA_WIDTH/32)+ 1), axi_awaddr'length)); -- Remove less significant bits
                    axi_awprot <= S_AXI_AWPROT;
                    reg_wid <= S_AXI_AWADDR(C_ARTICO3_ID_WIDTH+C_ARTICO3_ADDR_WIDTH-1 downto C_ARTICO3_ADDR_WIDTH);
                    reg_wop <= S_AXI_AWADDR(C_ARTICO3_ADDR_WIDTH-1 downto C_ARTICO3_ADDR_WIDTH-C_ARTICO3_OP_WIDTH);
                end if;
            end if;
        end if;
    end process;

    -- Write channel --

    -- I/O port connections
    axi_wdata <= S_AXI_WDATA;
    axi_wstrb <= S_AXI_WSTRB;
    axi_wvalid <= S_AXI_WVALID;
    S_AXI_WREADY <= axi_wready;

    -- Write handshake without additional latencies due to en generation
    nolatency_write: if C_EN_LATENCY = 0 generate
    begin

        -- Channel handshake (VALID-READY)
        w_handshake: process(S_AXI_ACLK)
        begin
            if S_AXI_ACLK'event and S_AXI_ACLK = '1' then
                if S_AXI_ARESETN = '0' then
                    arb_aw_clear <= '0';
                    axi_wready <= '0';
                    write_state <= S_IDLE;
                else
                    case write_state is
                        when S_IDLE =>
                            if axi_wvalid = '1' and arb_aw_active = '1' then
                                axi_wready <= '1';
                                write_state <= S_RUN;
                            end if;
                        when S_RUN =>
                            if axi_wvalid = '1' and axi_wready = '1' then
                                arb_aw_clear <= '1';
                                axi_wready <= '0';
                            end if;
                            if arb_aw_active = '0' then
                                arb_aw_clear <= '0';
                                write_state <= S_IDLE;
                            end if;
                    end case;
                end if;
            end if;
        end process;

    end generate;

    -- Write handshake with additional latencies due to en generation
    latency_write: if C_EN_LATENCY /= 0 generate
    begin

        -- Channel handshake (VALID-READY)
        w_handshake: process(S_AXI_ACLK)
            variable pipe : std_logic_vector(C_EN_LATENCY-1 downto 0);
        begin
            if S_AXI_ACLK'event and S_AXI_ACLK = '1' then
                if S_AXI_ARESETN = '0' then
                    arb_aw_clear <= '0';
                    axi_wready <= '0';
                    write_state <= S_IDLE;
                    pipe := (others => '0');
                else
                    case write_state is
                        when S_IDLE =>
                            if axi_wvalid = '1' and pipe(0) = '1' then
                                axi_wready <= '1';
                                write_state <= S_RUN;
                            end if;
                        when S_RUN =>
                            if axi_wvalid = '1' and axi_wready = '1' then
                                arb_aw_clear <= '1';
                                axi_wready <= '0';
                            end if;
                            if pipe(0) = '0' then
                                arb_aw_clear <= '0';
                                write_state <= S_IDLE;
                            end if;
                    end case;
                    -- Delay arb_aw_active signal to match enable generation latency
                    pipe := arb_aw_active & pipe(C_EN_LATENCY-1 downto 1);
                end if;
            end if;
        end process;

    end generate;

    -- Write Response channel --

    -- I/O port connections
    S_AXI_BRESP <= axi_bresp;
    S_AXI_BVALID <= axi_bvalid;
    axi_bready <= S_AXI_BREADY;

    -- Channel handshake (VALID-READY)
    b_handshake: process(S_AXI_ACLK)
    begin
        if S_AXI_ACLK'event and S_AXI_ACLK = '1' then
            if S_AXI_ARESETN = '0' then
                axi_bvalid <= '0';
                axi_bresp <= (others => '0');
            else
                if axi_wvalid = '1' and axi_wready = '1' then
                    axi_bvalid <= '1';
                    axi_bresp <= (others => '0'); -- OKAY response
                elsif axi_bvalid = '1' and axi_bready = '1' then
                    axi_bvalid <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Address Read channel --

    -- I/O port connections
    axi_arvalid <= S_AXI_ARVALID;
    S_AXI_ARREADY <= axi_arready;

    -- Channel signal processing
    ar_data: process(S_AXI_ACLK)
    begin
        if S_AXI_ACLK'event and S_AXI_ACLK = '1' then
            if S_AXI_ARESETN = '0' then
                axi_araddr <= (others => '0');
                axi_arprot <= (others => '0');
                reg_rid <= (others => '0');
                reg_rop <= (others => '0');
            else
                -- Read Address and transaction ID are captured when a VALID-READY handshake happens
                if axi_arvalid = '1' and axi_arready = '1' then
                    axi_araddr <= std_logic_vector(resize(shift_right(unsigned(S_AXI_ARADDR(C_ARTICO3_ADDR_WIDTH-C_ARTICO3_OP_WIDTH-1 downto 0)), (C_S_AXI_DATA_WIDTH/32)+ 1), axi_araddr'length)); -- Remove less significant bits
                    axi_arprot <= S_AXI_ARPROT;
                    reg_rid <= S_AXI_ARADDR(C_ARTICO3_ID_WIDTH+C_ARTICO3_ADDR_WIDTH-1 downto C_ARTICO3_ADDR_WIDTH);
                    reg_rop <= S_AXI_ARADDR(C_ARTICO3_ADDR_WIDTH-1 downto C_ARTICO3_ADDR_WIDTH-C_ARTICO3_OP_WIDTH);
                end if;
            end if;
        end if;
    end process;

    -- Pipeline control signal generation (sets control signal that affects RVALID MUX)
    pipe_ctrl: process(S_AXI_ACLK)
    begin
        if S_AXI_ACLK'event and S_AXI_ACLK = '1' then
            if S_AXI_ARESETN = '0' then
                axi_rvalid_regctrl <= '0';
                axi_rvalid_redctrl <= '0';
            else
                -- Always reset pipeline control and reduction control signals whenever a transaction finishes
                if axi_rvalid = '1' and axi_rready = '1' then -- RVALID (after the MUX) is asserted when the transaction finishes
                    axi_rvalid_regctrl <= '0';
                    axi_rvalid_redctrl <= '0';
                end if;
                -- When a ARVALID/ARREADY handshake appears...
                if axi_arvalid = '1' and axi_arready = '1' then
                    -- ...check whether the register that is being accessed is inside the Shuffler or the compute units
                    if to_integer(unsigned(S_AXI_ARADDR(C_ARTICO3_ID_WIDTH+C_ARTICO3_ADDR_WIDTH-1 downto C_ARTICO3_ADDR_WIDTH))) /= 0 then -- Transactions are forwarded to the compute units (accelerators) whenever the transaction ID is not 0
                        axi_rvalid_regctrl <= '1';
                    end if;
                    -- ...check whether the read OPeration code means that a reduction operation is being issued
                    if to_integer(unsigned(S_AXI_ARADDR(C_ARTICO3_ADDR_WIDTH-1 downto C_ARTICO3_ADDR_WIDTH-C_ARTICO3_OP_WIDTH))) /= 0 then -- Transaction is a reduction when the OPeration code is not 0
                        axi_rvalid_redctrl <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Read channel --

    -- I/O port connections
    S_AXI_RDATA <= axi_rdata;
    S_AXI_RRESP <= axi_rresp;
    S_AXI_RVALID <= axi_rvalid;
    axi_rvalid <= red_rvalid when axi_rvalid_redctrl = '1' else
                  axi_rvalid_ext when axi_rvalid_regctrl = '1' else
                  axi_rvalid_base; -- RVALID MUX that depends upon the register (Shuffler or compute units) that is being accessed, and on the OPeration mode (reduction or register access)
    axi_rready <= S_AXI_RREADY;

    -- Read handshake without additional latencies due to en generation
    nolatency_read: if C_EN_LATENCY = 0 generate
    begin

         -- Channel handshake (VALID-READY)
        r_handshake: process(S_AXI_ACLK)
        begin
            if S_AXI_ACLK'event and S_AXI_ACLK = '1' then
                if S_AXI_ARESETN = '0' then
                    arb_ar_clear <= '0';
                    axi_rvalid_base <= '0';
                    axi_rresp <= (others => '0');
                    read_state <= S_IDLE;
                else
                    case read_state is
                        when S_IDLE =>
                            if arb_ar_active = '1' then
                                axi_rvalid_base <= '1';
                                axi_rresp <= (others => '0'); -- OKAY response
                                read_state <= S_RUN;
                            end if;
                        when S_RUN =>
                            if axi_rvalid = '1' and axi_rready = '1' then
                                arb_ar_clear <= '1';
                                axi_rvalid_base <= '0';
                            end if;
                            if arb_ar_active = '0' then
                                arb_ar_clear <= '0';
                                read_state <= S_IDLE;
                            end if;
                    end case;
                end if;
            end if;
        end process;

    end generate;

    -- Read handshake with additional latencies due to en generation
    latency_read: if C_EN_LATENCY /= 0 generate
    begin

        -- Channel handshake (VALID-READY)
        r_handshake: process(S_AXI_ACLK)
            variable pipe : std_logic_vector(C_EN_LATENCY-1 downto 0);
        begin
           if S_AXI_ACLK'event and S_AXI_ACLK = '1' then
               if S_AXI_ARESETN = '0' then
                   arb_ar_clear <= '0';
                   axi_rvalid_base <= '0';
                   axi_rresp <= (others => '0');
                   read_state <= S_IDLE;
                   pipe := (others => '0');
               else
                   case read_state is
                       when S_IDLE =>
                           if pipe(0) = '1' then
                               axi_rvalid_base <= '1';
                               axi_rresp <= (others => '0'); -- OKAY response
                               read_state <= S_RUN;
                           end if;
                       when S_RUN =>
                           if axi_rvalid = '1' and axi_rready = '1' then
                               arb_ar_clear <= '1';
                               axi_rvalid_base <= '0';
                           end if;
                           if pipe(0) = '0' then
                               arb_ar_clear <= '0';
                               read_state <= S_IDLE;
                           end if;
                   end case;
                   -- Delay arb_ar_active signal to match enable generation latency
                    pipe := arb_ar_active & pipe(C_EN_LATENCY-1 downto 1);
               end if;
           end if;
        end process;

    end generate;

    -- Latency control when there is no pipeline
    nopipe_latency_ctrl: if C_PIPE_DEPTH = 0 and C_VOTER_LATENCY = 0 generate
    begin

        -- Control signals have to take into account the latency of a read operation in the accelerator registers: 1 clock cycle
        -- This has been done to have the same latency in the returning datapaths from the accelerators, i.e. memory and registers

        -- Latency handling in the returning path from pipeline
        pipe_lat: process(S_AXI_ACLK)
        begin
           if S_AXI_ACLK'event and S_AXI_ACLK = '1' then
               if S_AXI_ARESETN = '0' then
                   axi_rvalid_ext <= '0';
               else
                   axi_rvalid_ext <= axi_rvalid_base;
               end if;
           end if;
        end process;

    end generate;

    -- Latency control when there is a configurable pipeline
    pipe_latency_ctrl: if C_PIPE_DEPTH /= 0 or C_VOTER_LATENCY /= 0 generate
    begin

        -- Control signals have to take into account the latency of a read operation in the accelerator registers: 1 clock cycle
        -- and twice the latency of the pipeline: 2*C_PIPE_DEPTH clock cycles
        -- This has been done to have the same latency in the returning datapaths from the accelerators, i.e. memory and registers

        -- Latency handling in the returning path from pipeline
        pipe_lat: process(S_AXI_ACLK)
            variable pipe : std_logic_vector(((2*C_PIPE_DEPTH)+C_VOTER_LATENCY)-1 downto 0);
        begin
            if S_AXI_ACLK'event and S_AXI_ACLK = '1' then
                if S_AXI_ARESETN = '0' then
                    axi_rvalid_ext <= '0';
                    pipe := (others => '0');
                else
                    axi_rvalid_ext <= pipe(0);
                    pipe := axi_rvalid_base & pipe(((2*C_PIPE_DEPTH)+C_VOTER_LATENCY)-1 downto 1);
                end if;
            end if;
        end process;

    end generate;

    --------------------------------
    -- Configurable register bank --
    --------------------------------

    -- NOTE: this section contains all ARTICo3 configuration registers, which are used
    --       to read/write user modes, error reports, etc.

    -- Read-Write (to/from a master in the AXI4-Lite interface) capable registers
    register_rw: for i in 0 to C_NUM_REG_RW-1 generate

        signal reg : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0); -- Register value
        signal we  : std_logic;                                       -- Register write en

    begin

        -- Enable signals are generated using AXI4-Lite signals
        we <= axi_wvalid and axi_wready;

        -- Write operations are synchronous to S_AXI_ACLK
        write_proc: process(S_AXI_ACLK)
        begin
            if S_AXI_ACLK'event and S_AXI_ACLK = '1' then
                if S_AXI_ARESETN = '0' then
                    reg <= (others => '0');
                else
                   -- Only write to Shuffler registers when ID = 0; otherwise, do nothing
                   if to_integer(unsigned(reg_wid)) = 0 then
                       if we = '1' then
                           if to_integer(unsigned(axi_awaddr)) = i then
                               for j in 0 to (C_S_AXI_DATA_WIDTH/8)-1 loop
                                   if axi_wstrb(j) = '1' then
                                       reg(j*8+7 downto j*8) <= axi_wdata(j*8+7 downto j*8);
                                   end if;
                               end loop;
                           end if;
                       end if;
                   end if;
                end if;
            end if;
        end process;

        -- Read operations are asynchronous
        reg_out(i) <= reg;

    end generate;

    -- Read-Only (to a master in the AXI4-Lite interface) capable registers
    -- NOTE: some of these registers have to be manually introduced here, since there
    --       is no easy way to automate the procedure (as with R/W enabled registers).
    --       An example of an "easy" implementation of RO registers can be seen
    --       further down with the connections of the PMC registers (uses generate).
    --
    -- NOTE: moved connection of ready_reg to the ARTICo3 register section (further down)

    -- Multiplex register output to obtain requested value
    axi_rdata <= axi_reg_R_data when (axi_rvalid = '1' and axi_rready = '1') and (axi_rvalid_redctrl = '1' or axi_rvalid_regctrl = '1') else -- Returning data can be either the result of a reduction operation or the value in the registers of the compute units
                 reg_out(to_integer(unsigned(axi_araddr))) when (axi_rvalid = '1' and axi_rready = '1') and axi_rvalid_regctrl = '0' else
                 (others => '0');

    ----------------------
    -- Additional logic --
    ----------------------

    -- Address and data channel connections
    axi_reg_W_addr <= axi_awaddr;
    axi_reg_W_data <= axi_wdata;
    axi_reg_R_addr <= axi_araddr;

    -- Handshake connections (notice that signals can only be asserted when accessing compute units outside the Shuffler)
    axi_reg_AW_hs <= axi_awvalid and axi_awready when unsigned(S_AXI_AWADDR(C_ARTICO3_ID_WIDTH+C_ARTICO3_ADDR_WIDTH-1 downto C_ARTICO3_ADDR_WIDTH)) /= 0
                     and unsigned(S_AXI_AWADDR(C_ARTICO3_ADDR_WIDTH-1 downto C_ARTICO3_ADDR_WIDTH-C_ARTICO3_OP_WIDTH)) = 0 else '0';                     -- NOTE: register access operation code is "0000"
    axi_reg_AR_hs <= axi_arvalid and axi_arready when unsigned(S_AXI_ARADDR(C_ARTICO3_ID_WIDTH+C_ARTICO3_ADDR_WIDTH-1 downto C_ARTICO3_ADDR_WIDTH)) /= 0
                     and unsigned(S_AXI_ARADDR(C_ARTICO3_ADDR_WIDTH-1 downto C_ARTICO3_ADDR_WIDTH-C_ARTICO3_OP_WIDTH)) = 0 else '0';                     -- NOTE: register access operation code is "0000"
    axi_red_AR_hs <= axi_arvalid and axi_arready when unsigned(S_AXI_ARADDR(C_ARTICO3_ID_WIDTH+C_ARTICO3_ADDR_WIDTH-1 downto C_ARTICO3_ADDR_WIDTH)) /= 0
                     and unsigned(S_AXI_ARADDR(C_ARTICO3_ADDR_WIDTH-1 downto C_ARTICO3_ADDR_WIDTH-C_ARTICO3_OP_WIDTH)) /= 0 else '0';                    -- NOTE: reduction operation code is different from "0000"
    axi_reg_W_hs <= axi_wvalid and axi_wready when unsigned(reg_wid) /= 0 and unsigned(reg_wop) = 0 else '0';                                            -- NOTE: register access operation code is "0000"
    axi_reg_R_hs <= axi_rvalid_base and axi_rready when unsigned(reg_rid) /= 0 and unsigned(reg_rop) = 0 else '0';                                       -- NOTE: register access operation code is "0000"

    -- Transaction ID connections
    axi_reg_W_id <= reg_wid;
    axi_reg_R_id <= reg_rid;

    -- Transaction OPeration mode connections
    axi_reg_W_op <= reg_wop;
    axi_reg_R_op <= reg_rop;

    -- Write OPerands
    write_op: process(S_AXI_ACLK)
    begin
        if S_AXI_ACLK'event and S_AXI_ACLK = '1' then
            if S_AXI_ARESETN = '0' then
                sw_aresetn <= '1';
                sw_start   <= '0';
            else
                -- Generate software triggers right after WVALID/WREADY handshake, so that ID ACK is already generated
                if (axi_wvalid = '1' and axi_wready = '1') then
                    case to_integer(unsigned(reg_wop)) is
                        when 1      => sw_aresetn <= '0'; -- NOTE: SW reset operation code is "0001"
                        when 2      => sw_start   <= '1'; -- NOTE: SW start operation code is "0010"
                        when others => null;              -- NOTE: Default case (normal register access)
                    end case;
                else
                    sw_aresetn <= '1';
                    sw_start   <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Reduction mode connections
    red_ctrl <= axi_rvalid_redctrl;

    -----------------------
    -- ARTICo3 registers --
    -----------------------

    -- NOTE: this connections are here for this particular implementation. Other implementations might need to change this,
    --       according to their specific settings regarding C_ARTICO3_ID_WIDTH, C_MAX_SLOTS, etc.

    id_reg         <= std_logic_vector(resize(unsigned(reg_out(1)) & unsigned(reg_out(0)), id_reg'length));
    tmr_reg        <= std_logic_vector(resize(unsigned(reg_out(3)) & unsigned(reg_out(2)), tmr_reg'length));
    dmr_reg        <= std_logic_vector(resize(unsigned(reg_out(5)) & unsigned(reg_out(4)), dmr_reg'length));
    block_size_reg <= reg_out(6);
    clk_gate_reg   <= reg_out(7)(C_MAX_SLOTS-1 downto 0); -- NOTE: compute units are DISABLED by default. To have them ENABLED by default, change to "not reg_out(7)"

    reg_out(C_NUM_REG_RW + 0) <= std_logic_vector(to_unsigned(C_MAX_SLOTS, C_S_AXI_DATA_WIDTH));    -- Firmware info: number of slots in THIS ARTICo3 implementation
    reg_out(C_NUM_REG_RW + 1) <= std_logic_vector(resize(unsigned(ready_reg), C_S_AXI_DATA_WIDTH));

    -------------------
    -- PMC registers --
    -------------------

    pmc_cycles_gen: for i in 0 to C_MAX_SLOTS-1 generate
    begin
        reg_out(C_NUM_REG_RW + 2 + i) <= pmc_cycles(((i + 1) * C_S_AXI_DATA_WIDTH)-1 downto (i * C_S_AXI_DATA_WIDTH));
    end generate;

    pmc_errors_gen: for i in 0 to C_MAX_SLOTS-1 generate
    begin
        reg_out(C_NUM_REG_RW + 2 + C_MAX_SLOTS + i) <= pmc_errors(((i + 1) * C_S_AXI_DATA_WIDTH)-1 downto (i * C_S_AXI_DATA_WIDTH));
        pmc_errors_rst(i) <= '1' when (unsigned(axi_araddr) = (C_NUM_REG_RW + 2 + C_MAX_SLOTS + i)) and (axi_rvalid = '1' and axi_rready = '1') else '0'; -- Reset PMC error counters after successful reads to the register.
    end generate;

end behavioral;
