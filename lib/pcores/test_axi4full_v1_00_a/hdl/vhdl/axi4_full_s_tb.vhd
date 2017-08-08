library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi4_full_s_tb is
end axi4_full_s_tb;

architecture testbench of axi4_full_s_tb is
    
    -- Configuration parameters
    constant C_MEMORY_SIZE        : integer := 64*4*4;
    constant C_MEMORY_BANKS       : integer := 2**2;             
    constant C_S_AXI_ID_WIDTH     : integer := 1;
    constant C_S_AXI_DATA_WIDTH   : integer := 32;
    constant C_S_AXI_ADDR_WIDTH   : integer := 16;
    constant C_S_AXI_AWUSER_WIDTH : integer := 0;
    constant C_S_AXI_ARUSER_WIDTH : integer := 0;
    constant C_S_AXI_WUSER_WIDTH  : integer := 0;
    constant C_S_AXI_RUSER_WIDTH  : integer := 0;
    constant C_S_AXI_BUSER_WIDTH  : integer := 0;

    -- Global signals --
    signal S_AXI_ACLK     : std_logic;
    signal S_AXI_ARESETN  : std_logic;
    
    -- Address Write channel --  
    signal S_AXI_AWID     : std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    signal S_AXI_AWADDR   : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal S_AXI_AWLEN    : std_logic_vector(7 downto 0);
    signal S_AXI_AWSIZE   : std_logic_vector(2 downto 0);
    signal S_AXI_AWBURST  : std_logic_vector(1 downto 0);
    signal S_AXI_AWLOCK   : std_logic;
    signal S_AXI_AWCACHE  : std_logic_vector(3 downto 0);
    signal S_AXI_AWPROT   : std_logic_vector(2 downto 0);
    signal S_AXI_AWQOS    : std_logic_vector(3 downto 0);
    signal S_AXI_AWREGION : std_logic_vector(3 downto 0);
    signal S_AXI_AWUSER   : std_logic_vector(C_S_AXI_AWUSER_WIDTH-1 downto 0);
    signal S_AXI_AWVALID  : std_logic;
    signal S_AXI_AWREADY  : std_logic;
    
    -- Write channel --    
    signal S_AXI_WDATA    : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal S_AXI_WSTRB    : std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
    signal S_AXI_WLAST    : std_logic;
    signal S_AXI_WUSER    : std_logic_vector(C_S_AXI_WUSER_WIDTH-1 downto 0);
    signal S_AXI_WVALID   : std_logic;
    signal S_AXI_WREADY   : std_logic;
    
    -- Write Response channel --     
    signal S_AXI_BID      : std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    signal S_AXI_BRESP    : std_logic_vector(1 downto 0);
    signal S_AXI_BUSER    : std_logic_vector(C_S_AXI_BUSER_WIDTH-1 downto 0);
    signal S_AXI_BVALID   : std_logic;
    signal S_AXI_BREADY   : std_logic;
    
    -- Address Read channel --    
    signal S_AXI_ARID     : std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    signal S_AXI_ARADDR   : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal S_AXI_ARLEN    : std_logic_vector(7 downto 0);
    signal S_AXI_ARSIZE   : std_logic_vector(2 downto 0);
    signal S_AXI_ARBURST  : std_logic_vector(1 downto 0);
    signal S_AXI_ARLOCK   : std_logic;
    signal S_AXI_ARCACHE  : std_logic_vector(3 downto 0);
    signal S_AXI_ARPROT   : std_logic_vector(2 downto 0);
    signal S_AXI_ARQOS    : std_logic_vector(3 downto 0);
    signal S_AXI_ARREGION : std_logic_vector(3 downto 0);
    signal S_AXI_ARUSER   : std_logic_vector(C_S_AXI_ARUSER_WIDTH-1 downto 0);
    signal S_AXI_ARVALID  : std_logic;
    signal S_AXI_ARREADY  : std_logic;
    
    -- Read channel --
    signal S_AXI_RID      : std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    signal S_AXI_RDATA    : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal S_AXI_RRESP    : std_logic_vector(1 downto 0);
    signal S_AXI_RLAST    : std_logic;
    signal S_AXI_RUSER    : std_logic_vector(C_S_AXI_RUSER_WIDTH-1 downto 0);
    signal S_AXI_RVALID   : std_logic;
    signal S_AXI_RREADY   : std_logic;
    
    -- Other signals
    signal finish_write   : boolean;
    signal finish_read    : boolean;    
    constant clk_period   : time := 1ns;

begin

    uut: entity work.axi4_full_s
    generic map (
        C_MEMORY_SIZE        => C_MEMORY_SIZE,
        C_MEMORY_BANKS       => C_MEMORY_BANKS,
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
        S_AXI_ACLK     => S_AXI_ACLK,
        S_AXI_ARESETN  => S_AXI_ARESETN,
        S_AXI_AWID     => S_AXI_AWID,
        S_AXI_AWADDR   => S_AXI_AWADDR,
        S_AXI_AWLEN    => S_AXI_AWLEN,
        S_AXI_AWSIZE   => S_AXI_AWSIZE,
        S_AXI_AWBURST  => S_AXI_AWBURST,
        S_AXI_AWLOCK   => S_AXI_AWLOCK,
        S_AXI_AWCACHE  => S_AXI_AWCACHE,
        S_AXI_AWPROT   => S_AXI_AWPROT,
        S_AXI_AWQOS    => S_AXI_AWQOS,
        S_AXI_AWREGION => S_AXI_AWREGION,
        S_AXI_AWUSER   => S_AXI_AWUSER,
        S_AXI_AWVALID  => S_AXI_AWVALID,
        S_AXI_AWREADY  => S_AXI_AWREADY,
        S_AXI_WDATA    => S_AXI_WDATA,
        S_AXI_WSTRB    => S_AXI_WSTRB,
        S_AXI_WLAST    => S_AXI_WLAST,
        S_AXI_WUSER    => S_AXI_WUSER,
        S_AXI_WVALID   => S_AXI_WVALID,
        S_AXI_WREADY   => S_AXI_WREADY,
        S_AXI_BID      => S_AXI_BID,
        S_AXI_BRESP    => S_AXI_BRESP,
        S_AXI_BUSER    => S_AXI_BUSER,
        S_AXI_BVALID   => S_AXI_BVALID,
        S_AXI_BREADY   => S_AXI_BREADY,
        S_AXI_ARID     => S_AXI_ARID,
        S_AXI_ARADDR   => S_AXI_ARADDR,
        S_AXI_ARLEN    => S_AXI_ARLEN,
        S_AXI_ARSIZE   => S_AXI_ARSIZE,
        S_AXI_ARBURST  => S_AXI_ARBURST,
        S_AXI_ARLOCK   => S_AXI_ARLOCK,
        S_AXI_ARCACHE  => S_AXI_ARCACHE,
        S_AXI_ARPROT   => S_AXI_ARPROT,
        S_AXI_ARQOS    => S_AXI_ARQOS,
        S_AXI_ARREGION => S_AXI_ARREGION,
        S_AXI_ARUSER   => S_AXI_ARUSER,
        S_AXI_ARVALID  => S_AXI_ARVALID,
        S_AXI_ARREADY  => S_AXI_ARREADY,
        S_AXI_RID      => S_AXI_RID,
        S_AXI_RDATA    => S_AXI_RDATA,
        S_AXI_RRESP    => S_AXI_RRESP,
        S_AXI_RLAST    => S_AXI_RLAST,
        S_AXI_RUSER    => S_AXI_RUSER,
        S_AXI_RVALID   => S_AXI_RVALID,
        S_AXI_RREADY   => S_AXI_RREADY
    );
    
    clock_generator: process
    begin
        if (finish_write = false or finish_read = false) then
            S_AXI_ACLK <= '1';
            wait for clk_period/2;
            S_AXI_ACLK <= '0';
            wait for clk_period/2;
        else
            wait;
        end if;
    end process;
    
    reset_generator: process
    begin
        S_AXI_ARESETN <= '0';
        wait for clk_period*100;
        wait for clk_period/2;
        S_AXI_ARESETN <= '1';
        wait;
    end process;
    
    -- Write operations (TODO)
    finish_write   <= true;    
    S_AXI_AWID     <= (others => '0');
    S_AXI_AWADDR   <= (others => '0');
    S_AXI_AWLEN    <= (others => '0');
    S_AXI_AWSIZE   <= (others => '0');
    S_AXI_AWBURST  <= (others => '0');
    S_AXI_AWLOCK   <= '0';
    S_AXI_AWCACHE  <= (others => '0');
    S_AXI_AWPROT   <= (others => '0');
    S_AXI_AWQOS    <= (others => '0');
    S_AXI_AWREGION <= (others => '0');
    S_AXI_AWUSER   <= (others => '0');
    S_AXI_AWVALID  <= '0';
    S_AXI_WDATA    <= (others => '0');
    S_AXI_WSTRB    <= (others => '0');
    S_AXI_WLAST    <= '0';
    S_AXI_WUSER    <= (others => '0');
    S_AXI_WVALID   <= '0';
    S_AXI_BREADY   <= '0';
    
    -- Read operations
    read_generator: process
    begin
        finish_read    <= false;
        S_AXI_ARID     <= (others => '0');
        S_AXI_ARADDR   <= (others => '0');
        S_AXI_ARLEN    <= (others => '0');
        S_AXI_ARSIZE   <= (others => '0');
        S_AXI_ARBURST  <= (others => '0');
        S_AXI_ARLOCK   <= '0';
        S_AXI_ARCACHE  <= (others => '0');
        S_AXI_ARPROT   <= (others => '0');
        S_AXI_ARQOS    <= (others => '0');
        S_AXI_ARREGION <= (others => '0');
        S_AXI_ARUSER   <= (others => '0');
        S_AXI_ARVALID  <= '0';
        S_AXI_RREADY   <= '0';
        wait until S_AXI_ARESETN'event and S_AXI_ARESETN = '1';
        wait for clk_period/2;
        wait for clk_period*10;
        
        S_AXI_ARID     <= "1";
        S_AXI_ARADDR   <= x"0000";
        S_AXI_ARLEN    <= x"FF";
        S_AXI_ARSIZE   <= "010";
        S_AXI_ARBURST  <= "01";
        S_AXI_ARLOCK   <= '0';
        S_AXI_ARCACHE  <= (others => '0');
        S_AXI_ARPROT   <= (others => '0');
        S_AXI_ARQOS    <= (others => '0');
        S_AXI_ARREGION <= (others => '0');
        S_AXI_ARUSER   <= (others => '0');
        S_AXI_ARVALID  <= '1';
        S_AXI_RREADY   <= '1';        
        wait until S_AXI_ARREADY'event and S_AXI_ARREADY = '0';
        wait for clk_period/2;
        S_AXI_ARVALID  <= '0';
        wait until S_AXI_RLAST'event and S_AXI_RLAST= '0';
        wait for clk_period/2;
        S_AXI_RREADY   <= '0';
        wait for clk_period*10;
        
        S_AXI_ARVALID  <= '1';
        wait until S_AXI_ARREADY'event and S_AXI_ARREADY = '0';
        wait for clk_period/2;
        S_AXI_ARVALID  <= '0';
        wait until S_AXI_RVALID = '1';
        wait for clk_period/2;
        wait for clk_period*10;
        S_AXI_RREADY   <= '1';
        wait until S_AXI_RLAST'event and S_AXI_RLAST= '0';
        wait for clk_period/2;
        S_AXI_RREADY   <= '0';
        wait for clk_period*10;
        
        S_AXI_ARVALID  <= '1';
        S_AXI_RREADY   <= '1';        
        wait until S_AXI_ARREADY'event and S_AXI_ARREADY = '0';
        wait for clk_period/2;
        S_AXI_ARVALID  <= '0';
        wait until S_AXI_RVALID = '1';
        wait for clk_period/2;
        wait for clk_period;
        S_AXI_RREADY   <= '0';
        wait for clk_period*10;
        S_AXI_RREADY   <= '1';
        wait for clk_period;
        S_AXI_RREADY   <= '0';
        wait for clk_period;
        S_AXI_RREADY   <= '1';
        wait for clk_period;
        S_AXI_RREADY   <= '0';
        wait for 2*clk_period;
        S_AXI_RREADY   <= '1';
        wait until S_AXI_RLAST'event and S_AXI_RLAST= '0';
        wait for clk_period/2;
        S_AXI_RREADY   <= '0';
        wait for clk_period*10;
        
        S_AXI_ARVALID  <= '1';
        wait until S_AXI_ARREADY'event and S_AXI_ARREADY = '0';
        wait for clk_period/2;
        S_AXI_ARVALID  <= '0';
        wait until S_AXI_RVALID = '1';
        wait for clk_period/2;
        wait for clk_period*10;
        S_AXI_RREADY   <= '1';
        wait for clk_period;
        S_AXI_RREADY   <= '0';
        wait for clk_period*10;
        S_AXI_RREADY   <= '1';
        wait for clk_period;
        S_AXI_RREADY   <= '0';
        wait for clk_period;
        S_AXI_RREADY   <= '1';
        wait for clk_period;
        S_AXI_RREADY   <= '0';
        wait for 2*clk_period;
        S_AXI_RREADY   <= '1';
        wait until S_AXI_RLAST'event and S_AXI_RLAST= '0';
        wait for clk_period/2;
        S_AXI_RREADY   <= '0';
        wait for clk_period*10;
        
        wait for clk_period*100;
        finish_read <= true;
        wait;
    end process;
    
    gen_autocheck: if TRUE generate
        signal cnt : integer range 1 to (C_MEMORY_SIZE/16);
    begin
    
    check_generator: process(S_AXI_ACLK)
    begin
        if S_AXI_ACLK'event and S_AXI_ACLK = '1' then
            if S_AXI_ARESETN = '0' then 
                cnt <= 1;
            else
                if S_AXI_RVALID = '1' and S_AXI_RREADY = '1' then
                    if to_integer(unsigned(S_AXI_RDATA)) /= cnt then
                        assert false report "Simulation failed: result is not valid" & " RDATA = " & integer'image(to_integer(unsigned(S_AXI_RDATA))) & " cnt = " & integer'image(cnt) severity failure;
                    end if;
                    if cnt = C_MEMORY_SIZE/16 then
                        cnt <= 1;
                    else
                        cnt <= cnt + 1;
                    end if;                    
                end if;
            end if; 
        end if;
    end process;
    
    end generate;

end testbench;
