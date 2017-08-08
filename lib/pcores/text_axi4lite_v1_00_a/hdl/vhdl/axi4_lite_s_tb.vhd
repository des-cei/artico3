library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi4_lite_s_tb is
end axi4_lite_s_tb;

architecture testbench of axi4_lite_s_tb is
    
    -- Configuration parameters
    constant C_NUM_REG          : integer := 10;
    constant C_S_AXI_DATA_WIDTH : integer := 32;
    constant C_S_AXI_ADDR_WIDTH : integer := 16;

    -- Global signals --
    signal S_AXI_ACLK     : std_logic;
    signal S_AXI_ARESETN  : std_logic;
    
    -- Address Write channel --  
    signal S_AXI_AWADDR   : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal S_AXI_AWPROT   : std_logic_vector(2 downto 0);
    signal S_AXI_AWVALID  : std_logic;
    signal S_AXI_AWREADY  : std_logic;
    
    -- Write channel --    
    signal S_AXI_WDATA    : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal S_AXI_WSTRB    : std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
    signal S_AXI_WVALID   : std_logic;
    signal S_AXI_WREADY   : std_logic;
    
    -- Write Response channel --     
    signal S_AXI_BRESP    : std_logic_vector(1 downto 0);
    signal S_AXI_BVALID   : std_logic;
    signal S_AXI_BREADY   : std_logic;
    
    -- Address Read channel --    
    signal S_AXI_ARADDR   : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal S_AXI_ARPROT   : std_logic_vector(2 downto 0);
    signal S_AXI_ARVALID  : std_logic;
    signal S_AXI_ARREADY  : std_logic;
    
    -- Read channel --
    signal S_AXI_RDATA    : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal S_AXI_RRESP    : std_logic_vector(1 downto 0);
    signal S_AXI_RVALID   : std_logic;
    signal S_AXI_RREADY   : std_logic;
    
    -- Other signals
    signal finish_write   : boolean;
    signal finish_read    : boolean;    
    constant clk_period   : time := 1ns;

begin

    uut: entity work.axi4_lite_s
    generic map (
        C_NUM_REG          => C_NUM_REG,
        C_S_AXI_DATA_WIDTH => C_S_AXI_DATA_WIDTH,
        C_S_AXI_ADDR_WIDTH => C_S_AXI_ADDR_WIDTH
    )
    port map (
        S_AXI_ACLK     => S_AXI_ACLK,
        S_AXI_ARESETN  => S_AXI_ARESETN,
        S_AXI_AWADDR   => S_AXI_AWADDR,
        S_AXI_AWPROT   => S_AXI_AWPROT,
        S_AXI_AWVALID  => S_AXI_AWVALID,
        S_AXI_AWREADY  => S_AXI_AWREADY,
        S_AXI_WDATA    => S_AXI_WDATA,
        S_AXI_WSTRB    => S_AXI_WSTRB,
        S_AXI_WVALID   => S_AXI_WVALID,
        S_AXI_WREADY   => S_AXI_WREADY,
        S_AXI_BRESP    => S_AXI_BRESP,
        S_AXI_BVALID   => S_AXI_BVALID,
        S_AXI_BREADY   => S_AXI_BREADY,
        S_AXI_ARADDR   => S_AXI_ARADDR,
        S_AXI_ARPROT   => S_AXI_ARPROT,
        S_AXI_ARVALID  => S_AXI_ARVALID,
        S_AXI_ARREADY  => S_AXI_ARREADY,
        S_AXI_RDATA    => S_AXI_RDATA,
        S_AXI_RRESP    => S_AXI_RRESP,
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
    
    -- Write operations
    write_generator: process
    begin
        finish_write   <= false;    
        S_AXI_AWADDR   <= (others => '0');
        S_AXI_AWPROT   <= (others => '0');
        S_AXI_AWVALID  <= '0';
        S_AXI_WDATA    <= (others => '0');
        S_AXI_WSTRB    <= (others => '0');
        S_AXI_WVALID   <= '0';
        S_AXI_BREADY   <= '0';
        wait until S_AXI_ARESETN'event and S_AXI_ARESETN = '1';
        wait for clk_period/2;
        wait for clk_period*10;
        
        for i in 0 to C_NUM_REG-1 loop
            S_AXI_AWADDR <= std_logic_vector(to_unsigned(i*4,S_AXI_AWADDR'length));
            S_AXI_AWVALID  <= '1';
            wait until S_AXI_AWREADY'event and S_AXI_AWREADY = '0';
            wait for clk_period/2;
            S_AXI_AWADDR   <= (others => '0');
            S_AXI_AWVALID  <= '0';
            wait for clk_period*10;
            S_AXI_WDATA    <= std_logic_vector(to_unsigned(i+1,S_AXI_WDATA'length));
            S_AXI_WSTRB    <= (others => '1');
            S_AXI_WVALID   <= '1';
            wait until S_AXI_WREADY'event and S_AXI_WREADY = '0';
            wait for clk_period/2;
            S_AXI_WDATA    <= (others => '0');
            S_AXI_WSTRB    <= (others => '0');
            S_AXI_WVALID   <= '0';
            wait for clk_period*10;
            S_AXI_BREADY   <= '1';
            wait until S_AXI_BVALID'event and S_AXI_BVALID = '0';
            wait for clk_period/2;
            S_AXI_BREADY   <= '0';
            wait for clk_period*10;
        end loop;
        
        wait for clk_period*100;
        finish_write   <= true;
        wait;
    end process;
           
    -- Read operations
    read_generator: process
    begin
        finish_read    <= false;
        S_AXI_ARADDR   <= (others => '0');
        S_AXI_ARPROT   <= (others => '0');
        S_AXI_ARVALID  <= '0';
        S_AXI_RREADY   <= '0';
        wait until S_AXI_ARESETN'event and S_AXI_ARESETN = '1';
        wait until finish_write'event and finish_write = true;
        wait for clk_period/2;
        wait for clk_period*10;
        
        for i in 0 to C_NUM_REG-1 loop
            S_AXI_ARADDR <= std_logic_vector(to_unsigned(i*4,S_AXI_ARADDR'length));
            S_AXI_ARVALID  <= '1';
            wait until S_AXI_ARREADY'event and S_AXI_ARREADY = '0';
            wait for clk_period/2;
            S_AXI_ARADDR   <= (others => '0');
            S_AXI_ARVALID  <= '0';
            wait for clk_period*10;
            S_AXI_RREADY   <= '1';
            wait until S_AXI_RVALID'event and S_AXI_RVALID = '0';
            wait for clk_period/2;
            S_AXI_RREADY   <= '0';
            wait for clk_period*10;
        end loop;
        
        wait for clk_period*100;
        finish_read <= true;
        wait;
    end process;
    
    gen_autocheck: if TRUE generate
        signal cnt : integer range 1 to C_NUM_REG;
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
                    cnt <= cnt + 1;
                end if;
            end if; 
        end if;
    end process;
    
    end generate;

end testbench;
