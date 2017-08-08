-------------------------------------------------
-- Custom AXI4-Lite Slave Interface template   --
--                                             --
-- Features:                                   --
--     - SW-accesible register-based interface --
--     - Configurable number of registers      --
--     - Supports byte-wide write operations   --
-------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi4_lite_s is
    generic (
        ---------------------------
        -- Additional parameters --
        ---------------------------
        
        -- NOTE: users to add custom parameters in this section
        
        
    
        ------------------------------
        -- Configuration parameters --
        ------------------------------
        
        -- Number of software-accessible registers
        -- (Note that C_S_AXI_ADDR_WIDTH has to be set accordingly)
        C_NUM_REG          : integer := 20;
        
        --------------------------
        -- Interface parameters --
        --------------------------
        
        -- Width of S_AXI data bus
        C_S_AXI_DATA_WIDTH : integer := 32;
        -- Width of S_AXI address bus
        C_S_AXI_ADDR_WIDTH : integer := 16
    );
    port (
        ----------------------
        -- Additional ports --
        ----------------------
        
        
        
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
end axi4_lite_s;

architecture behavioral of axi4_lite_s is

    -----------------------
    -- Interface signals --
    -----------------------
    
    -- R/W arbiter
    
    type arb_state_t is (S_IDLE, S_READ, S_WRITE);
    signal arb_state     : arb_state_t;        -- Arbiter control FSM
    
    type arb_previous_t is (OP_READ, OP_WRITE);
    signal arb_previous  : arb_previous_t;     -- Most recently used access type (to implement round-robin arbitration in simultaneous accesses)
    
    signal arb_aw_active : std_logic;          -- Write access granted
    signal arb_aw_clear  : std_logic;          -- Write access finished
    signal arb_ar_active : std_logic;          -- Read access granted
    signal arb_ar_clear  : std_logic;          -- Read access finished
    
    -- Address Write channel --
    
    signal axi_awaddr    : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal axi_awprot    : std_logic_vector(2 downto 0);
    signal axi_awvalid   : std_logic;
    signal axi_awready   : std_logic;
        
    -- Write channel --
    
    signal axi_wdata     : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0); 
    signal axi_wstrb     : std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
    signal axi_wvalid    : std_logic;
    signal axi_wready    : std_logic;
    
    type write_state_t is (S_IDLE, S_RUN);
    signal write_state   : write_state_t;
    
    -- Write Response channel --
    
    signal axi_bresp     : std_logic_vector(1 downto 0);
    signal axi_bvalid    : std_logic;
    signal axi_bready    : std_logic;
    
    -- Address Read channel --
    
    signal axi_araddr    : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal axi_arprot    : std_logic_vector(2 downto 0);
    signal axi_arvalid   : std_logic;
    signal axi_arready   : std_logic;
    
    -- Read channel --
    
    signal axi_rdata     : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal axi_rresp     : std_logic_vector(1 downto 0);
    signal axi_rvalid    : std_logic;
    signal axi_rready    : std_logic;
    
    type read_state_t is (S_IDLE, S_RUN);
    signal read_state    : read_state_t;
        
    --------------------------------
    -- Configurable register bank --
    --------------------------------
    
    type reg_out_t is array (0 to C_NUM_REG-1) of std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal reg_out       : reg_out_t;
        
    ------------------------
    -- Additional signals --
    ------------------------
    
    
    
    -----------
    -- DEBUG --
    -----------
    
    attribute mark_debug : string;
    
    attribute mark_debug of arb_state     : signal is "TRUE";
    attribute mark_debug of arb_previous  : signal is "TRUE";
    attribute mark_debug of arb_aw_active : signal is "TRUE";
    attribute mark_debug of arb_aw_clear  : signal is "TRUE";
    attribute mark_debug of arb_ar_active : signal is "TRUE";
    attribute mark_debug of arb_ar_clear  : signal is "TRUE";  
    
    attribute mark_debug of axi_awaddr    : signal is "TRUE";
    attribute mark_debug of axi_awprot    : signal is "TRUE";
    attribute mark_debug of axi_awvalid   : signal is "TRUE";
    attribute mark_debug of axi_awready   : signal is "TRUE";
   
    attribute mark_debug of axi_wdata     : signal is "TRUE";
    attribute mark_debug of axi_wstrb     : signal is "TRUE";
    attribute mark_debug of axi_wvalid    : signal is "TRUE";
    attribute mark_debug of axi_wready    : signal is "TRUE";
    attribute mark_debug of write_state   : signal is "TRUE";
   
    attribute mark_debug of axi_bresp     : signal is "TRUE";
    attribute mark_debug of axi_bvalid    : signal is "TRUE";
    attribute mark_debug of axi_bready    : signal is "TRUE";
   
    attribute mark_debug of axi_araddr    : signal is "TRUE";
    attribute mark_debug of axi_arprot    : signal is "TRUE";
    attribute mark_debug of axi_arvalid   : signal is "TRUE";
    attribute mark_debug of axi_arready   : signal is "TRUE";
   
    attribute mark_debug of axi_rdata     : signal is "TRUE";
    attribute mark_debug of axi_rresp     : signal is "TRUE";
    attribute mark_debug of axi_rvalid    : signal is "TRUE";
    attribute mark_debug of axi_rready    : signal is "TRUE";
    attribute mark_debug of read_state    : signal is "TRUE";
   
    attribute mark_debug of reg_out       : signal is "TRUE";

begin
    
    -------------------------------
    -- AXI4-Lite interface logic --
    -------------------------------
    
    -- R/W arbiter
    
    -- NOTE: this implementation avoids simulataneous accesses from both
    --       read and write channels.
    
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
                            arb_state <= S_IDLE;
                        end if;
                    
                    when S_WRITE =>
                        axi_awready <= '0';
                        if arb_aw_clear = '1' then
                            arb_aw_active <= '0';
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
            else
                -- Write Address is captured when a VALID-READY handshake happens
                if axi_awvalid = '1' and axi_awready = '1' then 
                    axi_awaddr <= std_logic_vector(shift_right(unsigned(S_AXI_AWADDR), (C_S_AXI_DATA_WIDTH/32)+ 1)); -- Remove less significant bits
                    axi_awprot <= S_AXI_AWPROT;
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
            else
                -- Read Address is captured when a VALID-READY handshake happens
                if axi_arvalid = '1' and axi_arready = '1' then 
                    axi_araddr <= std_logic_vector(shift_right(unsigned(S_AXI_ARADDR), (C_S_AXI_DATA_WIDTH/32)+ 1)); -- Remove less significant bits
                    axi_arprot <= S_AXI_ARPROT;
                end if;
            end if;
        end if;
    end process;
    
    -- Read channel --
    
    -- I/O port connections
    S_AXI_RDATA <= axi_rdata;
    S_AXI_RRESP <= axi_rresp;
    S_AXI_RVALID <= axi_rvalid;
    axi_rready <= S_AXI_RREADY;
    
    -- Channel handshake (VALID-READY)
    r_handshake: process(S_AXI_ACLK)
    begin
        if S_AXI_ACLK'event and S_AXI_ACLK = '1' then
            if S_AXI_ARESETN = '0' then
                arb_ar_clear <= '0';
                axi_rvalid <= '0';
                axi_rresp <= (others => '0');
                read_state <= S_IDLE;
            else            
                case read_state is                
                    when S_IDLE =>
                        if arb_ar_active = '1' then
                            axi_rvalid <= '1';
                            axi_rresp <= (others => '0'); -- OKAY response
                            read_state <= S_RUN;
                        end if;                        
                    when S_RUN =>
                        if axi_rvalid = '1' and axi_rready = '1' then
                            arb_ar_clear <= '1';
                            axi_rvalid <= '0';
                        end if;
                        if arb_ar_active = '0' then
                            arb_ar_clear <= '0';
                            read_state <= S_IDLE;
                        end if;                        
                end case;            
            end if;
        end if;
    end process;
       
    --------------------------------
    -- Configurable register bank --
    --------------------------------
    
    register_gen: for i in 0 to C_NUM_REG-1 generate
    
        signal reg : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0); -- Register value
        signal wen : std_logic;                                       -- Register write enable
    
    begin
    
        -- Enable signals are generated using AXI4-Lite signals
        wen <= axi_wvalid and axi_wready;
        
        -- Write operations are synchronous to S_AXI_ACLK
        write_proc: process(S_AXI_ACLK)
        begin
            if S_AXI_ACLK'event and S_AXI_ACLK = '1' then
                if S_AXI_ARESETN = '0' then
                    reg <= (others => '0');
                else
                   if wen = '1' then
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
        end process;
        
        -- Read operations are asynchronous
        reg_out(i) <= reg;
    
    end generate;
    
    -- Multiplex register output to obtain requested value
    axi_rdata <= reg_out(to_integer(unsigned(axi_araddr))) when (axi_rvalid = '1' and axi_rready = '1') else (others => '0');
    
    ----------------------
    -- Additional logic --
    ----------------------
    


end behavioral;
