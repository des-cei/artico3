-----------------------------------------------------------
-- ARTICo3 - Data Shuffler Data datapath                 --
--                                                       --
-- Author: Alfonso Rodriguez <alfonso.rodriguezm@upm.es> --
--                                                       --
-- Features:                                             --
--     AXI4 Full protocol                                --
--     Memory-based interface                            --
-----------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity shuffler_data is
    generic (
        ------------------------------
        -- Configuration parameters --
        ------------------------------

        -- Number of pipeline stages (registers) between IF and memory banks
        C_PIPE_DEPTH         : integer := 3;
        -- Number of cycles required to generate a valid en signal
        C_EN_LATENCY         : integer := 4;
        -- Number of cycles required to vote valid data
        C_VOTER_LATENCY      : integer := 2;

        --------------------------
        -- Interface parameters --
        --------------------------

        -- ARTICo3 address size
        C_ARTICO3_ADDR_WIDTH : integer := 16;
        -- ARTICo3 ID size
        C_ARTICO3_ID_WIDTH   : integer := 4;

        -- Width of ID for for write address, write data, read address and read data
        C_S_AXI_ID_WIDTH     : integer := 1;
        -- Width of S_AXI data bus
        C_S_AXI_DATA_WIDTH   : integer := 32;
        -- Width of S_AXI address bus (NOTICE: C_S_AXI_ADDR_WIDTH = C_ARTICO3_ADDR_WIDTH + C_ARTICO3_ID_WIDTH)
        C_S_AXI_ADDR_WIDTH   : integer := 20;
        -- Width of optional user defined signal in write address channel
        C_S_AXI_AWUSER_WIDTH : integer := 0;
        -- Width of optional user defined signal in read address channel
        C_S_AXI_ARUSER_WIDTH : integer := 0;
        -- Width of optional user defined signal in write data channel
        C_S_AXI_WUSER_WIDTH  : integer := 0;
        -- Width of optional user defined signal in read data channel
        C_S_AXI_RUSER_WIDTH  : integer := 0;
        -- Width of optional user defined signal in write response channel
        C_S_AXI_BUSER_WIDTH  : integer := 0
    );
    port (
       ----------------------
       -- Additional ports --
       ----------------------

       -- AXI4 Full WDATA
       axi_mem_W_data  : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
       -- AXI4 Full RDATA
       axi_mem_R_data  : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
       -- AXI4 Full AWADDR (without compute unit ID)
       axi_mem_W_addr  : out std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
       -- AXI4 Full ARADDR (without compute unit ID)
       axi_mem_R_addr  : out std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
       -- AXI4 Full AWVALID/AWREADY handshake
       axi_mem_AW_hs   : out std_logic;
       -- AXI4 Full ARVALID/ARREADY handshake
       axi_mem_AR_hs   : out std_logic;
       -- AXI4 Full WVALID/WREADY handshake
       axi_mem_W_hs    : out std_logic;
       -- AXI4 Full RVALID/RREADY handshake
       axi_mem_R_hs    : out std_logic;
       -- AXI4 Full Write transaction ID (captured from AWADDR)
       axi_mem_W_id    : out std_logic_vector(C_ARTICO3_ID_WIDTH-1 downto 0);
       -- AXI4 Full Read transaction ID (captured from ARADDR)
       axi_mem_R_id    : out std_logic_vector(C_ARTICO3_ID_WIDTH-1 downto 0);
       -- Signal used to reset address generation logic whenever slots are switched
       addr_reset      : in  std_logic;
       -- Signal used to capture initial address in every transaction
       addr_capture    : in  std_logic;

       ---------------------
       -- Interface ports --
       ---------------------

        -- Global Clock Signal
        S_AXI_ACLK     : in  std_logic;
        -- Global Reset Signal. This Signal is Active LOW
        S_AXI_ARESETN  : in  std_logic;

        -- Address Write channel --

        -- Write Address ID
        S_AXI_AWID     : in  std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
        -- Write address
        S_AXI_AWADDR   : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        -- Burst length. The burst length gives the exact number of transfers in a burst
        S_AXI_AWLEN    : in  std_logic_vector(7 downto 0);
        -- Burst size. This signal indicates the size of each transfer in the burst
        S_AXI_AWSIZE   : in  std_logic_vector(2 downto 0);
        -- Burst type. The burst type and the size information,
        -- determine how the address for each transfer within the burst is calculated.
        S_AXI_AWBURST  : in  std_logic_vector(1 downto 0);
        -- Lock type. Provides additional information about the
        -- atomic characteristics of the transfer.
        S_AXI_AWLOCK   : in  std_logic;
        -- Memory type. This signal indicates how transactions
        -- are required to progress through a system.
        S_AXI_AWCACHE  : in  std_logic_vector(3 downto 0);
        -- Protection type. This signal indicates the privilege
        -- and security level of the transaction, and whether
        -- the transaction is a data access or an instruction access.
        S_AXI_AWPROT   : in  std_logic_vector(2 downto 0);
        -- Quality of Service, QoS identifier sent for each
        -- write transaction.
        S_AXI_AWQOS    : in  std_logic_vector(3 downto 0);
        -- Region identifier. Permits a single physical interface
        -- on a slave to be used for multiple logical interfaces.
        S_AXI_AWREGION : in  std_logic_vector(3 downto 0);
        -- Optional User-defined signal in the write address channel.
        S_AXI_AWUSER   : in  std_logic_vector(C_S_AXI_AWUSER_WIDTH-1 downto 0);
        -- Write address valid. This signal indicates that
        -- the channel is signaling valid write address and
        -- control information.
        S_AXI_AWVALID  : in  std_logic;
        -- Write address ready. This signal indicates that
        -- the slave is ready to accept an address and associated
        -- control signals.
        S_AXI_AWREADY  : out std_logic;

        -- Write channel --

        -- Write Data
        S_AXI_WDATA    : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        -- Write strobes. This signal indicates which byte
        -- lanes hold valid data. There is one write strobe
        -- bit for each eight bits of the write data bus.
        S_AXI_WSTRB    : in  std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
        -- Write last. This signal indicates the last transfer
        -- in a write burst.
        S_AXI_WLAST    : in  std_logic;
        -- Optional User-defined signal in the write data channel.
        S_AXI_WUSER    : in  std_logic_vector(C_S_AXI_WUSER_WIDTH-1 downto 0);
        -- Write valid. This signal indicates that valid write
        -- data and strobes are available.
        S_AXI_WVALID   : in  std_logic;
        -- Write ready. This signal indicates that the slave
        -- can accept the write data.
        S_AXI_WREADY   : out std_logic;

        -- Write Response channel --

        -- Response ID tag. This signal is the ID tag of the
        -- write response.
        S_AXI_BID      : out std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
        -- Write response. This signal indicates the status
        -- of the write transaction.
        S_AXI_BRESP    : out std_logic_vector(1 downto 0);
        -- Optional User-defined signal in the write response channel.
        S_AXI_BUSER    : out std_logic_vector(C_S_AXI_BUSER_WIDTH-1 downto 0);
        -- Write response valid. This signal indicates that the
        -- channel is signaling a valid write response.
        S_AXI_BVALID   : out std_logic;
        -- Response ready. This signal indicates that the master
        -- can accept a write response.
        S_AXI_BREADY   : in  std_logic;

        -- Address Read channel --

        -- Read address ID. This signal is the identification
        -- tag for the read address group of signals.
        S_AXI_ARID     : in  std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
        -- Read address. This signal indicates the initial
        -- address of a read burst transaction.
        S_AXI_ARADDR   : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        -- Burst length. The burst length gives the exact number of transfers in a burst
        S_AXI_ARLEN    : in  std_logic_vector(7 downto 0);
        -- Burst size. This signal indicates the size of each transfer in the burst
        S_AXI_ARSIZE   : in  std_logic_vector(2 downto 0);
        -- Burst type. The burst type and the size information,
        -- determine how the address for each transfer within the burst is calculated.
        S_AXI_ARBURST  : in  std_logic_vector(1 downto 0);
        -- Lock type. Provides additional information about the
        -- atomic characteristics of the transfer.
        S_AXI_ARLOCK   : in  std_logic;
        -- Memory type. This signal indicates how transactions
        -- are required to progress through a system.
        S_AXI_ARCACHE  : in  std_logic_vector(3 downto 0);
        -- Protection type. This signal indicates the privilege
        -- and security level of the transaction, and whether
        -- the transaction is a data access or an instruction access.
        S_AXI_ARPROT   : in  std_logic_vector(2 downto 0);
        -- Quality of Service, QoS identifier sent for each
        -- read transaction.
        S_AXI_ARQOS    : in  std_logic_vector(3 downto 0);
        -- Region identifier. Permits a single physical interface
        -- on a slave to be used for multiple logical interfaces.
        S_AXI_ARREGION : in  std_logic_vector(3 downto 0);
        -- Optional User-defined signal in the read address channel.
        S_AXI_ARUSER   : in  std_logic_vector(C_S_AXI_ARUSER_WIDTH-1 downto 0);
        -- Write address valid. This signal indicates that
        -- the channel is signaling valid read address and
        -- control information.
        S_AXI_ARVALID  : in  std_logic;
        -- Read address ready. This signal indicates that
        -- the slave is ready to accept an address and associated
        -- control signals.
        S_AXI_ARREADY  : out std_logic;

        -- Read channel --

        -- Read ID tag. This signal is the identification tag
        -- for the read data group of signals generated by the slave.
        S_AXI_RID      : out std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
        -- Read Data
        S_AXI_RDATA    : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        -- Read response. This signal indicates the status of
        -- the read transfer.
        S_AXI_RRESP    : out std_logic_vector(1 downto 0);
        -- Read last. This signal indicates the last transfer
        -- in a read burst.
        S_AXI_RLAST    : out std_logic;
        -- Optional User-defined signal in the read address channel.
        S_AXI_RUSER    : out std_logic_vector(C_S_AXI_RUSER_WIDTH-1 downto 0);
        -- Read valid. This signal indicates that the channel
        -- is signaling the required read data.
        S_AXI_RVALID   : out std_logic;
        -- Read ready. This signal indicates that the master can
        -- accept the read data and response information.
        S_AXI_RREADY   : in  std_logic
    );
end shuffler_data;

architecture behavioral of shuffler_data is

    -----------------------
    -- Interface signals --
    -----------------------

    -- R/W arbiter

    type arb_state_t is (S_IDLE, S_READ, S_WRITE, S_LAST);
    signal arb_state        : arb_state_t;        -- Arbiter control FSM

    type arb_previous_t is (OP_READ, OP_WRITE);
    signal arb_previous     : arb_previous_t;     -- Most recently used access type (to implement round-robin arbitration in simultaneous accesses)

    signal arb_aw_active    : std_logic;          -- Write access granted
    signal arb_aw_clear     : std_logic;          -- Write access finished
    signal arb_ar_active    : std_logic;          -- Read access granted
    signal arb_ar_clear     : std_logic;          -- Read access finished

    -- Address Write channel --

    signal axi_awid         : std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    signal axi_awaddr       : unsigned(C_ARTICO3_ADDR_WIDTH-1 downto 0);
    signal axi_awlen        : integer range 0 to 2**8;                           -- Stores the remaining data elements to process (AWLEN + 1)
    signal axi_awsize       : std_logic_vector(2 downto 0);
    signal axi_awburst      : std_logic_vector(1 downto 0);
    signal axi_awlock       : std_logic;
    signal axi_awcache      : std_logic_vector(3 downto 0);
    signal axi_awprot       : std_logic_vector(2 downto 0);
    signal axi_awqos        : std_logic_vector(3 downto 0);
    signal axi_awregion     : std_logic_vector(3 downto 0);
    signal axi_awuser       : std_logic_vector(C_S_AXI_AWUSER_WIDTH-1 downto 0);
    signal axi_awvalid      : std_logic;
    signal axi_awready      : std_logic;

    signal axi_awaddr_base  : unsigned(C_ARTICO3_ADDR_WIDTH-1 downto 0);         -- Reset value when changing slots

    -- Write channel --

    signal axi_wdata        : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal axi_wstrb        : std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
    signal axi_wlast        : std_logic;
    signal axi_wuser        : std_logic_vector(C_S_AXI_WUSER_WIDTH-1 downto 0);
    signal axi_wvalid       : std_logic;
    signal axi_wready       : std_logic;

    type write_state_t is (S_IDLE, S_RUN);
    signal write_state      : write_state_t;

    -- Write Response channel --

    signal axi_bid          : std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    signal axi_bresp        : std_logic_vector(1 downto 0);
    signal axi_buser        : std_logic_vector(C_S_AXI_BUSER_WIDTH-1 downto 0);
    signal axi_bvalid       : std_logic;
    signal axi_bready       : std_logic;

    -- Address Read channel --

    signal axi_arid         : std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    signal axi_araddr       : unsigned(C_ARTICO3_ADDR_WIDTH-1 downto 0);
    signal axi_arlen        : integer range 0 to 2**8;                           -- Stores the remaining data elements to process (AWLEN + 1)
    signal axi_arsize       : std_logic_vector(2 downto 0);
    signal axi_arburst      : std_logic_vector(1 downto 0);
    signal axi_arlock       : std_logic;
    signal axi_arcache      : std_logic_vector(3 downto 0);
    signal axi_arprot       : std_logic_vector(2 downto 0);
    signal axi_arqos        : std_logic_vector(3 downto 0);
    signal axi_arregion     : std_logic_vector(3 downto 0);
    signal axi_aruser       : std_logic_vector(C_S_AXI_ARUSER_WIDTH-1 downto 0);
    signal axi_arvalid      : std_logic;
    signal axi_arready      : std_logic;

    signal axi_araddr_base  : unsigned(C_ARTICO3_ADDR_WIDTH-1 downto 0);         -- Reset value when changing slots
    signal axi_arlen_addr   : integer range 0 to 2**8;                           -- Stores the remaining data elements to process (starts at AWLEN + 1)

    -- Read channel --

    signal axi_rid          : std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    signal axi_rdata        : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal axi_rresp        : std_logic_vector(1 downto 0);
    signal axi_rlast        : std_logic;
    signal axi_ruser        : std_logic_vector(C_S_AXI_RUSER_WIDTH-1 downto 0);
    signal axi_rvalid       : std_logic;
    signal axi_rready       : std_logic;

    signal axi_rlast_addr   : std_logic;                                        -- Signal to generate RLAST assuming no latencies (for address generation control)
    signal axi_rvalid_addr  : std_logic;                                        -- Signal to generate RVALID assuming no latencies (for address generation control)

    -- FIFO
    constant FIFO_DEPTH     : integer := 2**S_AXI_ARLEN'length;                -- The FIFO can hold a whole AXI4 burst transaction
    signal fifo_din         : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal fifo_wen         : std_logic;
    signal fifo_full        : std_logic;
    signal fifo_dout        : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal fifo_ren         : std_logic;
    signal fifo_empty       : std_logic;
    type fifo_op_state_t is (S_IDLE, S_RUN);
    signal fifo_write_state : fifo_op_state_t;
    signal fifo_read_state  : fifo_op_state_t;

    ------------------------
    -- Additional signals --
    ------------------------

    -- ID signals
    signal mem_wid          : std_logic_vector(C_ARTICO3_ID_WIDTH-1 downto 0); -- Current write transaction ID
    signal mem_rid          : std_logic_vector(C_ARTICO3_ID_WIDTH-1 downto 0); -- Current read transaction ID

    -----------
    -- DEBUG --
    -----------

    attribute mark_debug : string;

    attribute mark_debug of arb_state        : signal is "TRUE";
    attribute mark_debug of arb_previous     : signal is "TRUE";
    attribute mark_debug of arb_aw_active    : signal is "TRUE";
    attribute mark_debug of arb_aw_clear     : signal is "TRUE";
    attribute mark_debug of arb_ar_active    : signal is "TRUE";
    attribute mark_debug of arb_ar_clear     : signal is "TRUE";

    attribute mark_debug of axi_awid         : signal is "TRUE";
    attribute mark_debug of axi_awaddr       : signal is "TRUE";
    attribute mark_debug of axi_awlen        : signal is "TRUE";
    attribute mark_debug of axi_awsize       : signal is "TRUE";
    attribute mark_debug of axi_awburst      : signal is "TRUE";
    attribute mark_debug of axi_awlock       : signal is "TRUE";
    attribute mark_debug of axi_awcache      : signal is "TRUE";
    attribute mark_debug of axi_awprot       : signal is "TRUE";
    attribute mark_debug of axi_awqos        : signal is "TRUE";
    attribute mark_debug of axi_awregion     : signal is "TRUE";
    attribute mark_debug of axi_awuser       : signal is "TRUE";
    attribute mark_debug of axi_awvalid      : signal is "TRUE";
    attribute mark_debug of axi_awready      : signal is "TRUE";
    attribute mark_debug of axi_awaddr_base  : signal is "TRUE";

    attribute mark_debug of axi_wdata        : signal is "TRUE";
    attribute mark_debug of axi_wstrb        : signal is "TRUE";
    attribute mark_debug of axi_wlast        : signal is "TRUE";
    attribute mark_debug of axi_wuser        : signal is "TRUE";
    attribute mark_debug of axi_wvalid       : signal is "TRUE";
    attribute mark_debug of axi_wready       : signal is "TRUE";
    attribute mark_debug of write_state      : signal is "TRUE";

    attribute mark_debug of axi_bid          : signal is "TRUE";
    attribute mark_debug of axi_bresp        : signal is "TRUE";
    attribute mark_debug of axi_buser        : signal is "TRUE";
    attribute mark_debug of axi_bvalid       : signal is "TRUE";
    attribute mark_debug of axi_bready       : signal is "TRUE";

    attribute mark_debug of axi_arid         : signal is "TRUE";
    attribute mark_debug of axi_araddr       : signal is "TRUE";
    attribute mark_debug of axi_arlen        : signal is "TRUE";
    attribute mark_debug of axi_arsize       : signal is "TRUE";
    attribute mark_debug of axi_arburst      : signal is "TRUE";
    attribute mark_debug of axi_arlock       : signal is "TRUE";
    attribute mark_debug of axi_arcache      : signal is "TRUE";
    attribute mark_debug of axi_arprot       : signal is "TRUE";
    attribute mark_debug of axi_arqos        : signal is "TRUE";
    attribute mark_debug of axi_arregion     : signal is "TRUE";
    attribute mark_debug of axi_aruser       : signal is "TRUE";
    attribute mark_debug of axi_arvalid      : signal is "TRUE";
    attribute mark_debug of axi_arready      : signal is "TRUE";
    attribute mark_debug of axi_araddr_base  : signal is "TRUE";
    attribute mark_debug of axi_arlen_addr   : signal is "TRUE";

    attribute mark_debug of axi_rid          : signal is "TRUE";
    attribute mark_debug of axi_rdata        : signal is "TRUE";
    attribute mark_debug of axi_rresp        : signal is "TRUE";
    attribute mark_debug of axi_rlast        : signal is "TRUE";
    attribute mark_debug of axi_ruser        : signal is "TRUE";
    attribute mark_debug of axi_rvalid       : signal is "TRUE";
    attribute mark_debug of axi_rready       : signal is "TRUE";
    attribute mark_debug of axi_rlast_addr   : signal is "TRUE";
    attribute mark_debug of axi_rvalid_addr  : signal is "TRUE";

    attribute mark_debug of fifo_din         : signal is "TRUE";
    attribute mark_debug of fifo_wen         : signal is "TRUE";
    attribute mark_debug of fifo_full        : signal is "TRUE";
    attribute mark_debug of fifo_dout        : signal is "TRUE";
    attribute mark_debug of fifo_ren         : signal is "TRUE";
    attribute mark_debug of fifo_empty       : signal is "TRUE";
    attribute mark_debug of fifo_write_state : signal is "TRUE";
    attribute mark_debug of fifo_read_state  : signal is "TRUE";

    attribute mark_debug of mem_wid          : signal is "TRUE";
    attribute mark_debug of mem_rid          : signal is "TRUE";

begin

    -------------------------------
    -- AXI4-Full interface logic --
    -------------------------------

    -- R/W arbiter

    -- NOTE: this implementation uses dual port BRAMs as a bridge between
    --       the AXI4 interface and the custom user logic. Therefore, only
    --       one port is available on each side, and arbitration is required
    --       to avoid simultaneous read and write operations (not allowed).
    --       The arbiter solves simultaneous accesses in round-robin fashion,
    --       enabling the least recently used type of access. This implementation
    --       is similar to the one provided by Xilinx in their AXI BRAM Controller
    --       IP, being the extra clock cycles required to go through the state
    --       S_IDLE and S_LAST (added to take into account variable latencies
    --       in the returning pipelined datapath) the only difference.

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
                axi_awid <= (others => '0');
                axi_awsize <= (others => '0');
                axi_awburst <= (others => '0');
                axi_awlock <= '0';
                axi_awcache <= (others => '0');
                axi_awprot <= (others => '0');
                axi_awqos <= (others => '0');
                axi_awregion <= (others => '0');
                axi_awuser <= (others => '0');
            else
                -- Transaction parameters are captured when a VALID-READY handshake happens
                if axi_awvalid = '1' and axi_awready = '1' then
                    axi_awid <= S_AXI_AWID;
                    axi_awsize <= S_AXI_AWSIZE;
                    axi_awburst <= S_AXI_AWBURST;
                    axi_awlock <= S_AXI_AWLOCK;
                    axi_awcache <= S_AXI_AWCACHE;
                    axi_awprot <= S_AXI_AWPROT;
                    axi_awqos <= S_AXI_AWQOS;
                    axi_awregion <= S_AXI_AWREGION;
                    axi_awuser <= S_AXI_AWUSER;
                end if;
            end if;
        end if;
    end process;

    -- Address generation logic
    aw_addr_gen: process(S_AXI_ACLK)
    begin
        if S_AXI_ACLK'event and S_AXI_ACLK = '1' then
            if S_AXI_ARESETN = '0' then
                axi_awaddr <= (others => '0');
                axi_awaddr_base <= (others => '0');
                axi_awlen <= 0;
                mem_wid <= (others => '0');
            else
                -- Capture address and initialize counter
                if axi_awvalid = '1' and axi_awready = '1' then
                    if addr_capture = '1' then
                        axi_awaddr <= shift_right(unsigned(S_AXI_AWADDR(C_ARTICO3_ADDR_WIDTH-1 downto 0)), (C_S_AXI_DATA_WIDTH/32)+ 1);
                        axi_awaddr_base <= shift_right(unsigned(S_AXI_AWADDR(C_ARTICO3_ADDR_WIDTH-1 downto 0)), (C_S_AXI_DATA_WIDTH/32)+ 1);
                        mem_wid <= S_AXI_AWADDR(C_ARTICO3_ID_WIDTH+C_ARTICO3_ADDR_WIDTH-1 downto C_ARTICO3_ADDR_WIDTH);
                    end if;
                    axi_awlen <= to_integer(unsigned(S_AXI_AWLEN)) + 1;
                -- If not capturing, the system is moving data
                elsif axi_wvalid = '1' and axi_wready = '1' then
                    if addr_reset = '1' then
                        axi_awaddr <= axi_awaddr_base;
                    else
                        axi_awaddr <= axi_awaddr + 1;
                    end if;
                    axi_awlen <= axi_awlen - 1;
                end if;
            end if;
        end if;
    end process;

    -- Write channel --

    -- I/O port connections
    axi_wdata <= S_AXI_WDATA;
    axi_wstrb <= S_AXI_WSTRB;
    axi_wlast<= S_AXI_WLAST;
    axi_wuser <= S_AXI_WUSER;
    axi_wvalid <= S_AXI_WVALID;
    S_AXI_WREADY <= axi_wready;

    -- Write handshake without additional latencies due to enable generation
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
                            if (axi_wvalid = '1' and axi_wready = '1') and axi_wlast = '1' then
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

    -- Write handshake with additional latencies due to enable generation
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
                            if (axi_wvalid = '1' and axi_wready = '1') and axi_wlast = '1' then
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

    -- NOTE: this implementation assumes that the AXI4 Master interface will accept write responses
    --       (B channel) after each write transaction. Hence, each VALID-READY handshake in the AW
    --       channel is assumed to have its corresponding VALID-READY handshake in the B channel on
    --       a transaction basis.

    -- TODO: modify this implementation to support pending write responses (delay VALID-READY handshakes
    --       in the B channel).

    -- I/O port connections
    S_AXI_BID <= axi_bid;
    S_AXI_BRESP <= axi_bresp;
    S_AXI_BUSER <= axi_buser;
    S_AXI_BVALID <= axi_bvalid;
    axi_bready <= S_AXI_BREADY;

    -- NOTE: combinationally assigned to capture the value when necessary
    axi_bid <= axi_awid; -- Slaves are required to reflect on the appropriate BID or RID response an AXI ID received from a master (AMBA AXI4 Protocol Specification)

    -- Channel handshake (VALID-READY)
    b_handshake: process(S_AXI_ACLK)
    begin
        if S_AXI_ACLK'event and S_AXI_ACLK = '1' then
            if S_AXI_ARESETN = '0' then
                axi_bvalid <= '0';
--                axi_bid <= (others => '0');
                axi_bresp <= (others => '0');
                axi_buser <= (others => '0');
            else
                if (axi_wvalid = '1' and axi_wready = '1') and axi_wlast = '1' then
                    axi_bvalid <= '1';
--                    axi_bid <= (others => '0'); -- Not needed, so all bits are set to 0
--                    axi_bid <= axi_awid; -- Slaves are required to reflect on the appropriate BID or RID response an AXI ID received from a master (AMBA AXI4 Protocol Specification)
                    axi_bresp <= (others => '0'); -- OKAY response
                    axi_buser <= (others => '0'); -- Not needed, so all bits are set to 0
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
                axi_arid <= (others => '0');
                axi_arsize <= (others => '0');
                axi_arburst <= (others => '0');
                axi_arlock <= '0';
                axi_arcache <= (others => '0');
                axi_arprot <= (others => '0');
                axi_arqos <= (others => '0');
                axi_arregion <= (others => '0');
                axi_aruser <= (others => '0');
            else
                -- Transaction parameters are captured when a VALID-READY handshake happens
                if axi_arvalid = '1' and axi_arready = '1' then
                    axi_arid <= S_AXI_ARID;
                    axi_arsize <= S_AXI_ARSIZE;
                    axi_arburst <= S_AXI_ARBURST;
                    axi_arlock <= S_AXI_ARLOCK;
                    axi_arcache <= S_AXI_ARCACHE;
                    axi_arprot <= S_AXI_ARPROT;
                    axi_arqos <= S_AXI_ARQOS;
                    axi_arregion <= S_AXI_ARREGION;
                    axi_aruser <= S_AXI_ARUSER;
                end if;
            end if;
        end if;
    end process;

    -- Address generation logic
    ar_addr_gen: process(S_AXI_ACLK)
    begin
        if S_AXI_ACLK'event and S_AXI_ACLK = '1' then
            if S_AXI_ARESETN = '0' then
                axi_araddr <= (others => '0');
                axi_araddr_base <= (others => '0');
                axi_arlen <= 0;
                axi_arlen_addr <= 0;
                mem_rid <= (others => '0');
            else
                -- Capture address and initialize counter
                if axi_arvalid = '1' and axi_arready = '1' then
                    if addr_capture = '1' then
                        axi_araddr <= shift_right(unsigned(S_AXI_ARADDR(C_ARTICO3_ADDR_WIDTH-1 downto 0)), (C_S_AXI_DATA_WIDTH/32)+ 1);
                        axi_araddr_base <= shift_right(unsigned(S_AXI_ARADDR(C_ARTICO3_ADDR_WIDTH-1 downto 0)), (C_S_AXI_DATA_WIDTH/32)+ 1);
                        mem_rid <= S_AXI_ARADDR(C_ARTICO3_ID_WIDTH+C_ARTICO3_ADDR_WIDTH-1 downto C_ARTICO3_ADDR_WIDTH);
                    end if;
                    axi_arlen <= to_integer(unsigned(S_AXI_ARLEN)) + 1;
                    axi_arlen_addr <= to_integer(unsigned(S_AXI_ARLEN)) + 1;
                -- If not capturing, the system is moving data
                else
                    if axi_rvalid_addr = '1' then
                        if addr_reset = '1' then
                            axi_araddr <= axi_araddr_base;
                        else
                            axi_araddr <= axi_araddr + 1;
                        end if;
                        axi_arlen_addr <= axi_arlen_addr - 1;
                    end if;
                    if axi_rvalid = '1' and axi_rready = '1' then
                        axi_arlen <= axi_arlen - 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Read channel --

    -- FIFO
    fifo_i: entity work.fifo
    generic map (
        C_DATA_WIDTH => C_S_AXI_DATA_WIDTH,
        C_RST_POL    => '0',
        C_FIFO_DEPTH => FIFO_DEPTH
    )
    port map (
        clk   => S_AXI_ACLK,
        reset => S_AXI_ARESETN,
        din   => fifo_din,
        wen   => fifo_wen,
        full  => fifo_full,
        dout  => fifo_dout,
        ren   => fifo_ren,
        empty => fifo_empty
    );

    fifo_din <= axi_mem_R_data;
    axi_rdata <= fifo_dout;

    -- I/O port connections
    S_AXI_RID <= axi_rid;
    S_AXI_RDATA <= axi_rdata;
    S_AXI_RRESP <= axi_rresp;
    S_AXI_RLAST <= axi_rlast;
    S_AXI_RUSER <= axi_ruser;
    S_AXI_RVALID <= axi_rvalid;
    axi_rready <= S_AXI_RREADY;

    -- NOTE: combinationally assigned to capture the value when necessary
    axi_rid <= axi_arid; -- Slaves are required to reflect on the appropriate BID or RID response an AXI ID received from a master (AMBA AXI4 Protocol Specification)

    -- Unused AXI4 read channel signals, set to zero
    axi_rresp <= (others => '0');
    axi_ruser <= (others => '0');

    -- Read handshake without additional latencies due to en generation
    nolatency_read: if C_EN_LATENCY = 0 generate
    begin

        -- FIFO write control (data are written from BRAM memories)
        fifo_write: process(S_AXI_ACLK)
        begin
            if S_AXI_ACLK'event and S_AXI_ACLK = '1' then
                if S_AXI_ARESETN = '0' then
                    axi_rvalid_addr <= '0';
                    fifo_write_state <= S_IDLE;
                else
                    case fifo_write_state is
                        when S_IDLE =>
                            if arb_ar_active = '1' then
                                axi_rvalid_addr <= '1';
                                fifo_write_state <= S_RUN;
                            end if;
                        when S_RUN =>
                            if axi_rvalid_addr = '1' and axi_rlast_addr = '1' then
                                axi_rvalid_addr <= '0';
                            end if;
                            if arb_ar_active = '0' then
                                fifo_write_state <= S_IDLE;
                            end if;
                    end case;
                end if;
            end if;
        end process;

        -- FIFO read control (data are read to AXI4 Read channel)
        fifo_read: process(S_AXI_ACLK)
        begin
            if S_AXI_ACLK'event and S_AXI_ACLK = '1' then
                if S_AXI_ARESETN = '0' then
                    arb_ar_clear <= '0';
                    axi_rvalid <= '0';
                    fifo_read_state <= S_IDLE;
                else
                    case fifo_read_state is
                        when S_IDLE =>
                            if fifo_empty = '0' then
                                fifo_read_state <= S_RUN;
                            end if;
                        when S_RUN =>
                            if fifo_empty = '1' then
                                fifo_read_state <= S_IDLE;
                            end if;
                    end case;
                    -- RVALID control
                    if fifo_ren = '1' then
                        axi_rvalid <= '1';
                    elsif axi_rvalid = '1' and axi_rready = '1' then
                        axi_rvalid <= '0';
                    end if;
                    -- Arbiter control (read processes)
                    if (axi_rvalid = '1' and axi_rready = '1') and axi_rlast = '1' then
                       arb_ar_clear <= '1';
                    end if;
                    if arb_ar_active = '0' then
                       arb_ar_clear <= '0';
                    end if;
                end if;
            end if;
        end process;

    end generate;

    -- Read handshake with additional latencies due to en generation
    latency_read: if C_EN_LATENCY /= 0 generate
        signal pipe : std_logic_vector(C_EN_LATENCY-1 downto 0);
    begin

        -- FIFO write control (data are written from BRAM memories)
        fifo_write: process(S_AXI_ACLK)
        begin
            if S_AXI_ACLK'event and S_AXI_ACLK = '1' then
                if S_AXI_ARESETN = '0' then
                    axi_rvalid_addr <= '0';
                    fifo_write_state <= S_IDLE;
                    pipe <= (others => '0');
                else
                    case fifo_write_state is
                        when S_IDLE =>
                            if pipe(0) = '1' then
                                axi_rvalid_addr <= '1';
                                fifo_write_state <= S_RUN;
                            end if;
                        when S_RUN =>
                            if axi_rvalid_addr = '1' and axi_rlast_addr = '1' then
                                axi_rvalid_addr <= '0';
                            end if;
                            if pipe(0) = '0' then
                                fifo_write_state <= S_IDLE;
                            end if;
                    end case;
                    -- Delay arb_ar_active signal to match enable generation latency
                    pipe <= arb_ar_active & pipe(C_EN_LATENCY-1 downto 1);
                end if;
            end if;
        end process;

        -- FIFO read control (data are read to AXI4 Read channel)
        fifo_read: process(S_AXI_ACLK)
        begin
            if S_AXI_ACLK'event and S_AXI_ACLK = '1' then
                if S_AXI_ARESETN = '0' then
                    arb_ar_clear <= '0';
                    axi_rvalid <= '0';
                    fifo_read_state <= S_IDLE;
                else
                    case fifo_read_state is
                        when S_IDLE =>
                            if fifo_empty = '0' then
                                fifo_read_state <= S_RUN;
                            end if;
                        when S_RUN =>
                            if fifo_empty = '1' then
                                fifo_read_state <= S_IDLE;
                            end if;
                    end case;
                    -- RVALID control
                    if fifo_ren = '1' then
                        axi_rvalid <= '1';
                    elsif axi_rvalid = '1' and axi_rready = '1' then
                        axi_rvalid <= '0';
                    end if;
                    -- Arbiter control (read processes)
                    if (axi_rvalid = '1' and axi_rready = '1') and axi_rlast = '1' then
                       arb_ar_clear <= '1';
                    end if;
                    if pipe(0) = '0' then
                       arb_ar_clear <= '0';
                    end if;
                end if;
            end if;
        end process;

    end generate;

    -- Latency control when there is no pipeline
    nopipe_latency_ctrl: if C_PIPE_DEPTH = 0 and C_VOTER_LATENCY = 0 generate
    begin

        -- Control signals have to take into account the latency of a read operation from the accelerator memories: 1 clock cycle
        -- This has been done to have the same latency in the returning datapaths from the accelerators, i.e. memory and registers

        -- Latency handling in the returning path from pipeline
        pipe_lat: process(S_AXI_ACLK)
        begin
            if S_AXI_ACLK'event and S_AXI_ACLK = '1' then
                if S_AXI_ARESETN = '0' then
                    fifo_wen <= '0';
                else
                    -- NOTE: for BRAMs, latency is 1-2 clock cycles (depending on the implementation)
                    fifo_wen <= axi_rvalid_addr;
                end if;
            end if;
        end process;

    end generate;

    -- Latency control when there is a configurable pipeline
    pipe_latency_ctrl: if C_PIPE_DEPTH /= 0 or C_VOTER_LATENCY /= 0 generate
    begin

        -- Control signals have to take into account the latency of a read operation from the accelerator memories: 1 clock cycle
        -- and twice the latency of the pipeline: 2*C_PIPE_DEPTH clock cycles
        -- This has been done to have the same latency in the returning datapaths from the accelerators, i.e. memory and registers

        -- Latency handling in the returning path from pipeline
        pipe_lat: process(S_AXI_ACLK)
            variable pipe : std_logic_vector(((2*C_PIPE_DEPTH)+C_VOTER_LATENCY)-1 downto 0);
        begin
            if S_AXI_ACLK'event and S_AXI_ACLK = '1' then
                if S_AXI_ARESETN = '0' then
                    fifo_wen <= '0';
                    pipe := (others => '0');
                else
                    -- NOTE: for BRAMs, latency is 1-2 clock cycles (depending on the implementation)
                    fifo_wen <= pipe(0);
                    pipe := axi_rvalid_addr & pipe(((2*C_PIPE_DEPTH)+C_VOTER_LATENCY)-1 downto 1);
                end if;
            end if;
        end process;

    end generate;

    -- FIFO read control
    fifo_ren <= not fifo_empty when fifo_read_state = S_IDLE else
                axi_rready when axi_rlast = '0' else
                '0';

    -- RLAST generation
    axi_rlast_addr <= '1' when axi_arlen_addr = 1 and axi_rvalid_addr = '1' else '0';
    axi_rlast <= '1' when axi_arlen = 1 and axi_rvalid = '1' else '0';

    ----------------------
    -- Additional logic --
    ----------------------

    -- Address and data channel connections
    axi_mem_W_addr <= std_logic_vector(axi_awaddr);
    axi_mem_W_data <= axi_wdata;
    axi_mem_R_addr <= std_logic_vector(axi_araddr);

    -- Handshake connections (since memory transactions only affect compute units in the slots, signals are always forwarded)
    axi_mem_AW_hs <= axi_awvalid and axi_awready;
    axi_mem_AR_hs <= axi_arvalid and axi_arready;
    axi_mem_W_hs <= axi_wvalid and axi_wready;
    axi_mem_R_hs <= axi_rvalid_addr; -- and axi_rready; -- Using the FIFO, this is no longer required.

    -- Transaction ID connections
    axi_mem_W_id <= mem_wid;
    axi_mem_R_id <= mem_rid;

end behavioral;
