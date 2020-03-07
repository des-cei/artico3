-----------------------------------------------------------------------------
-- ARTICo3 Compute Unit Wrapper                                            --
--                                                                         --
-- Author: Alfonso Rodriguez <alfonso.rodriguezm@upm.es>                   --
--                                                                         --
-- Features:                                                               --
--     Configurable memory size (in bytes)                                 --
--     Configurable number of memory banks                                 --
--     Configurable number of registers                                    --
--     Data counter to know how many elements are written into memory      --
--                                                                         --
-- Notes:                                                                  --
--     Compute units begin execution when START signal is asserted         --
--     Compute units finish execution and assert READY signal              --
--     Compute units are accesed either in register (0) or memory (1) MODE --
--     Data counter is reset when a memory read transaction is issued      --
--                                                                         --
-- TODO:                                                                   --
--     Implement Side-Channel Attack protection                            --
--                                                                         --
-- This template should be used to implement user-defined accelerators     --
-- targeting ARTICo3-enabled platforms                                     --
-----------------------------------------------------------------------------

<a3<artico3_preproc>a3>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity a3_wrapper is
    generic (
        C_ARTICO3_DATA_WIDTH : integer := 32;    -- Data bus width (in bits)
        C_ARTICO3_ADDR_WIDTH : integer := 16;    -- Address bus width (in bits)
        C_MAX_MEM            : integer := <a3<MEMBYTES>a3>; -- Total memory size (in bytes) inside the compute unit
        C_NUM_MEM            : integer := <a3<MEMBANKS>a3>;     -- Number of memory banks inside the compute unit (to allow parallel accesses from logic
        C_NUM_REG            : integer := <a3<NUMREGS>a3>      -- Number of Read/Write registers inside the compute unit
    );
    port (
        s_artico3_aclk    : in  std_logic;
        s_artico3_aresetn : in  std_logic;
        s_artico3_start   : in  std_logic;                                         -- Control signal that starts execution in the compute unit
        s_artico3_ready   : out std_logic;                                         -- Control signal that determines whether the compute unit has finished working or not
        s_artico3_en      : in  std_logic;                                         -- Compute unit enable signal (compute units can only be accessed from the shuffler when this signal is asserted)
        s_artico3_we      : in  std_logic;                                         -- Compute unit write enable signal
        s_artico3_mode    : in  std_logic;                                         -- Compute unit access mode (it can be either a memory access [1] or a register access [0])
        s_artico3_addr    : in  std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0); -- ARTICo3 address bus
        s_artico3_wdata   : in  std_logic_vector(C_ARTICO3_DATA_WIDTH-1 downto 0); -- ARTICo3 write data bus
        s_artico3_rdata   : out std_logic_vector(C_ARTICO3_DATA_WIDTH-1 downto 0)  -- ARTICo3 read data bus
    );
end a3_wrapper;

architecture behavioral of a3_wrapper is

<a3<if NAME!="dummy">a3>
<a3<=if HWSRC=="verilog"=>a3>
    ----------------
    -- User Logic --
    ----------------

    -- Verilog-based hardware kernel
    component <a3<NAME>a3>
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        start       : in  std_logic;
        ready       : out std_logic;

<a3<generate for REGS>a3>
        reg_<a3<rid>a3>_o_vld : out std_logic;
        reg_<a3<rid>a3>_o     : out std_logic_vector(C_ARTICO3_DATA_WIDTH-1 downto 0);
        reg_<a3<rid>a3>_i     : in  std_logic_vector(C_ARTICO3_DATA_WIDTH-1 downto 0);
<a3<end generate>a3>
<a3<generate for PORTS>a3>
        bram_<a3<pid>a3>_clk  : out std_logic;
        bram_<a3<pid>a3>_rst  : out std_logic;
        bram_<a3<pid>a3>_en   : out std_logic;
        bram_<a3<pid>a3>_we   : out std_logic;
        bram_<a3<pid>a3>_addr : out std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
        bram_<a3<pid>a3>_din  : out std_logic_vector(C_ARTICO3_DATA_WIDTH-1 downto 0);
        bram_<a3<pid>a3>_dout : in  std_logic_vector(C_ARTICO3_DATA_WIDTH-1 downto 0);
<a3<end generate>a3>
        values      : in  std_logic_vector(31 downto 0)
    );
    end component;

<a3<=end if=>a3>
<a3<=if HWSRC=="hls"=>a3>
    ----------------
    -- User Logic --
    ----------------

    -- HLS control signals
    signal ap_start      : std_logic;
    signal ap_done       : std_logic;

    -- HLS memory signals
<a3<generate for PORTS>a3>
    signal bram_<a3<pid>a3>_WEN_A  : std_logic_vector(3 downto 0);
    signal bram_<a3<pid>a3>_Addr_A : std_logic_vector(31 downto 0);
<a3<end generate>a3>
<a3<=end if=>a3>
<a3<end if>a3>
    -------------------------------
    -- Configurable memory banks --
    -------------------------------

    type mem_data_t is array (0 to C_NUM_MEM-1) of std_logic_vector(C_ARTICO3_DATA_WIDTH-1 downto 0);
    type mem_addr_t is array (0 to C_NUM_MEM-1) of std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
    signal mem_out  : mem_data_t;                             -- Output data in memory banks
    signal mem_rst  : std_logic_vector(C_NUM_MEM-1 downto 0); -- Reset signal from user logic to PORTB of memory banks (currently unused)
    signal mem_en   : std_logic_vector(C_NUM_MEM-1 downto 0); -- Enable signal from user logic to PORTB of memory banks
    signal mem_we   : std_logic_vector(C_NUM_MEM-1 downto 0); -- Write enable signal from user logic to PORTB of memory banks
    signal mem_addr : mem_addr_t;                             -- Address signal from user logic to PORTB of memory banks
    signal mem_din  : mem_data_t;                             -- Input data signal from user logic to PORTB of memory banks
    signal mem_dout : mem_data_t;                             -- Output data signal from PORTB of memory banks to user logic

<a3<if NUMREGS!=0>a3>
    --------------------------------
    -- Configurable register bank --
    --------------------------------

    type reg_data_t is array (0 to C_NUM_REG-1) of std_logic_vector(C_ARTICO3_DATA_WIDTH-1 downto 0);
    signal reg_out  : reg_data_t;                             -- Output data in register bank
    signal reg_we   : std_logic_vector(C_NUM_REG-1 downto 0); -- Write enable signal from user logic to registers
    signal reg_din  : reg_data_t;                             -- Input data signal from user logic to registers
    signal reg_dout : reg_data_t;                             -- Output data signal from registers to user logic

<a3<end if>a3>
    ---------------------
    -- Output data MUX --
    ---------------------

    signal mem_path : std_logic_vector(C_ARTICO3_DATA_WIDTH-1 downto 0); -- Read data from memory banks (only addressed data appear here)
    signal reg_path : std_logic_vector(C_ARTICO3_DATA_WIDTH-1 downto 0); -- Read data from register bank (only addressed data appear here)

    ------------------------
    -- Additional signals --
    ------------------------

    -- Synchronization logic
    signal addr_sync : std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0); -- Read address registered to match BRAM/registers latency
    signal en_sync   : std_logic;                                         -- Enable signal registered to match BRAM/registers latency
    signal mode_sync : std_logic;                                         -- Mode signal registered to match BRAM/registers latency

    -- Data counter logic
    constant MAX_DATA : integer := C_MAX_MEM/(C_ARTICO3_DATA_WIDTH/8); -- A maximum of MAX_DATA elements can be stored in this module
    signal data_cnt   : integer range 0 to MAX_DATA;                   -- Data counter

    -----------
    -- DEBUG --
    -----------

    attribute mark_debug : string;

<a3<if NAME!="dummy">a3>
<a3<=if HWSRC=="hls"=>a3>
    attribute mark_debug of ap_start      : signal is "TRUE";
    attribute mark_debug of ap_done       : signal is "TRUE";

<a3<generate for PORTS>a3>
    attribute mark_debug of bram_<a3<pid>a3>_WEN_A  : signal is "TRUE";
    attribute mark_debug of bram_<a3<pid>a3>_Addr_A : signal is "TRUE";
<a3<end generate>a3>
<a3<=end if=>a3>
<a3<end if>a3>
    attribute mark_debug of mem_out       : signal is "TRUE";
    attribute mark_debug of mem_rst       : signal is "TRUE";
    attribute mark_debug of mem_en        : signal is "TRUE";
    attribute mark_debug of mem_we        : signal is "TRUE";
    attribute mark_debug of mem_addr      : signal is "TRUE";
    attribute mark_debug of mem_din       : signal is "TRUE";
    attribute mark_debug of mem_dout      : signal is "TRUE";

<a3<if NUMREGS!=0>a3>
    attribute mark_debug of reg_out       : signal is "TRUE";
    attribute mark_debug of reg_we        : signal is "TRUE";
    attribute mark_debug of reg_din       : signal is "TRUE";
    attribute mark_debug of reg_dout      : signal is "TRUE";

<a3<end if>a3>
    attribute mark_debug of mem_path      : signal is "TRUE";
    attribute mark_debug of reg_path      : signal is "TRUE";

    attribute mark_debug of addr_sync     : signal is "TRUE";
    attribute mark_debug of en_sync       : signal is "TRUE";
    attribute mark_debug of mode_sync     : signal is "TRUE";

    attribute mark_debug of data_cnt      : signal is "TRUE";

begin

    ----------------
    -- User logic --
    ----------------

<a3<if NAME=="dummy">a3>
    -- Dummy hardware kernel (no user logic)
    mem_rst         <= (others => '1');
    mem_en          <= (others => '0');
    mem_we          <= (others => '0');
    mem_addr        <= (others => (others => '0'));
    mem_din         <= (others => (others => '0'));
    reg_we          <= (others => '0');
    reg_din         <= (others => (others => '0'));
    s_artico3_ready <= '1';
<a3<end if>a3>
<a3<if NAME!="dummy">a3>
<a3<=if HWSRC=="vhdl"=>a3>
    -- VHDL-based hardware kernel
    kernel_i: entity work.<a3<NAME>a3>
<a3<=end if=>a3>
<a3<=if HWSRC=="verilog"=>a3>
    -- Verilog-based hardware kernel
    kernel_i: <a3<NAME>a3>
<a3<=end if=>a3>
<a3<=if HWSRC!="hls"=>a3>
    port map (
        clk         => s_artico3_aclk,
<a3<==if RST_POL=="low"==>a3>
        reset       => s_artico3_aresetn,
<a3<==end if==>a3>
<a3<==if RST_POL!="low"==>a3>
        reset       => not s_artico3_aresetn,
<a3<==end if==>a3>
        start       => s_artico3_start,
        ready       => s_artico3_ready,

<a3<generate for REGS>a3>
        reg_<a3<rid>a3>_o_vld => reg_we(<a3<rid>a3>),
        reg_<a3<rid>a3>_o     => reg_din(<a3<rid>a3>),
        reg_<a3<rid>a3>_i     => reg_dout(<a3<rid>a3>),
<a3<end generate>a3>
<a3<generate for PORTS>a3>
        bram_<a3<pid>a3>_clk  => open,
        bram_<a3<pid>a3>_rst  => mem_rst(<a3<pid>a3>),
        bram_<a3<pid>a3>_en   => mem_en(<a3<pid>a3>),
        bram_<a3<pid>a3>_we   => mem_we(<a3<pid>a3>),
        bram_<a3<pid>a3>_addr => mem_addr(<a3<pid>a3>),
        bram_<a3<pid>a3>_din  => mem_din(<a3<pid>a3>),
        bram_<a3<pid>a3>_dout => mem_dout(<a3<pid>a3>),
<a3<end generate>a3>
        values      => std_logic_vector(to_unsigned(data_cnt, 32))
    );
<a3<=end if=>a3>
<a3<=if HWSRC=="hls"=>a3>
    -- HLS-based hardware kernel
    kernel_i: entity work.<a3<NAME>a3>
    port map (
        ap_clk         => s_artico3_aclk,
        ap_rst_n       => s_artico3_aresetn,
        ap_start       => ap_start,
        ap_done        => ap_done,
        ap_idle        => open,
        ap_ready       => open,

<a3<generate for REGS>a3>
        reg_<a3<rid>a3>_o_ap_vld => reg_we(<a3<rid>a3>),
        reg_<a3<rid>a3>_o        => reg_din(<a3<rid>a3>),
        reg_<a3<rid>a3>_i        => reg_dout(<a3<rid>a3>),
<a3<end generate>a3>
<a3<generate for PORTS>a3>
        bram_<a3<pid>a3>_Clk_A   => open,
        bram_<a3<pid>a3>_Rst_A   => mem_rst(<a3<pid>a3>),
        bram_<a3<pid>a3>_EN_A    => mem_en(<a3<pid>a3>),
        bram_<a3<pid>a3>_WEN_A   => bram_<a3<pid>a3>_WEN_A,
        bram_<a3<pid>a3>_Addr_A  => bram_<a3<pid>a3>_Addr_A,
        bram_<a3<pid>a3>_Din_A   => mem_din(<a3<pid>a3>),
        bram_<a3<pid>a3>_Dout_A  => mem_dout(<a3<pid>a3>),
<a3<end generate>a3>
        values         => std_logic_vector(to_unsigned(data_cnt, 32))
    );

    -- Adapt HLS memory signals
<a3<generate for PORTS>a3>
    mem_we(<a3<pid>a3>)   <= bram_<a3<pid>a3>_WEN_A(0) or bram_<a3<pid>a3>_WEN_A(1) or bram_<a3<pid>a3>_WEN_A(2) or bram_<a3<pid>a3>_WEN_A(3);
    mem_addr(<a3<pid>a3>) <= std_logic_vector(resize(shift_right(unsigned(bram_<a3<pid>a3>_Addr_A), 2), C_ARTICO3_ADDR_WIDTH));
<a3<end generate>a3>
    -- Additional control for HLS control signals (handshake protocol)
    process(s_artico3_aclk)
    begin
        if s_artico3_aclk'event and s_artico3_aclk = '1' then
            if s_artico3_aresetn = '0' then
                ap_start <= '0';
                s_artico3_ready <= '0';
            else
                if s_artico3_start = '1' then
                    ap_start <= '1';
                    s_artico3_ready <= '0';
                end if;
                if ap_done = '1' then
                    ap_start <= '0';
                    s_artico3_ready <= '1';
                end if;
            end if;
        end if;
    end process;
<a3<=end if=>a3>
<a3<end if>a3>

    -------------------------------
    -- Configurable memory banks --
    -------------------------------

    memory_bank: for i in 0 to C_NUM_MEM-1 generate

        -- Memory definitions
        constant MEM_POS : integer := (C_MAX_MEM/C_NUM_MEM)/(C_ARTICO3_DATA_WIDTH/8); -- Compute how many memory positions per memory bank are required to have a total of C_MAX_MEM bytes in the compute unit

        -- Port A definitions
        signal clk_a  : std_logic;
        signal rst_a  : std_logic;
        signal en_a   : std_logic;
        signal we_a   : std_logic;
        signal addr_a : std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
        signal din_a  : std_logic_vector(C_ARTICO3_DATA_WIDTH-1 downto 0);
        signal dout_a : std_logic_vector(C_ARTICO3_DATA_WIDTH-1 downto 0);

        -- Port B definitions
        signal clk_b  : std_logic;
        signal rst_b  : std_logic;
        signal en_b   : std_logic;
        signal we_b   : std_logic;
        signal addr_b : std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
        signal din_b  : std_logic_vector(C_ARTICO3_DATA_WIDTH-1 downto 0);
        signal dout_b : std_logic_vector(C_ARTICO3_DATA_WIDTH-1 downto 0);

    begin

        -- Memory I/O connections (port A)
        clk_a      <= s_artico3_aclk;
        rst_a      <= not s_artico3_aresetn;
        en_a       <= (s_artico3_en and s_artico3_mode) when (unsigned(s_artico3_addr) >= MEM_POS*i) and (unsigned(s_artico3_addr) < MEM_POS*(i+1)) else '0';
        we_a       <= s_artico3_we and s_artico3_mode;
        addr_a     <= std_logic_vector(unsigned(s_artico3_addr) - MEM_POS*i) when s_artico3_en = '1' else
                      (others => '0');
        din_a      <= s_artico3_wdata;
        mem_out(i) <= dout_a;

        -- Memory I/O connections (port B)
        clk_b       <= s_artico3_aclk;
        rst_b       <= mem_rst(i);
        en_b        <= mem_en(i);
        we_b        <= mem_we(i);
        addr_b      <= mem_addr(i);
        din_b       <= mem_din(i);
        mem_dout(i) <= dout_b;

        -- Memory instantiation
        mem_i: entity work.bram_dualport
        generic map (
            C_DATA_WIDTH => C_ARTICO3_DATA_WIDTH,
            C_ADDR_WIDTH => C_ARTICO3_ADDR_WIDTH,
            C_MEM_DEPTH  => MEM_POS,
            C_MEM_MODE   => "LOW_LATENCY"
        )
        port map (
            clk_a  => clk_a,
            rst_a  => rst_a,
            en_a   => en_a,
            we_a   => we_a,
            addr_a => addr_a,
            din_a  => din_a,
            dout_a => dout_a,
            clk_b  => clk_b,
            rst_b  => rst_b,
            en_b   => en_b,
            we_b   => we_b,
            addr_b => addr_b,
            din_b  => din_b,
            dout_b => dout_b
        );

    end generate;

    -- Multiplex register output to obtain requested value
    mux_out: process(mem_out, addr_sync, en_sync)
        constant MEM_POS : integer := (C_MAX_MEM/C_NUM_MEM)/(C_ARTICO3_DATA_WIDTH/8);
        variable index : integer range -1 to C_NUM_MEM-1;
    begin
        -- Check if a value has to be read
        if en_sync = '1' then
            -- Default value
            index := -1;
            -- Check the memory range to select the correct bank
            for i in 0 to C_NUM_MEM-1 loop
                if (unsigned(addr_sync) >= MEM_POS*i) and (unsigned(addr_sync) < MEM_POS*(i+1)) then
                    index := i;
                end if;
            end loop;
            -- Assign value to output
            if index < 0 then
                mem_path <= (others => '0');
            else
                mem_path <= mem_out(index);
            end if;
        else
            -- Assign value to output
            mem_path <= (others => '0');
        end if;
    end process;

    --------------------------------
    -- Configurable register bank --
    --------------------------------

<a3<if NUMREGS==0>a3>
    -- Set register output to a dummy value
    reg_path <= x"deadbeef";
<a3<end if>a3>
<a3<if NUMREGS!=0>a3>
    register_bank: for i in 0 to C_NUM_REG-1 generate
        signal reg : std_logic_vector(C_ARTICO3_DATA_WIDTH-1 downto 0); -- Register value
        signal we  : std_logic;                                         -- Register write enable signal
    begin

        -- Control signal generation
        we <= s_artico3_we and (not s_artico3_mode);

        -- Synchronous write and read operations
        readwrite_proc: process(s_artico3_aclk)
        begin
            if s_artico3_aclk'event and s_artico3_aclk = '1' then
                if s_artico3_aresetn = '0' then
                    reg <= (others => '0');
                    reg_out(i) <= (others => '0');
                else
                    -- DATA BUS: Write operation
                    if we = '1' then
                        if to_integer(unsigned(s_artico3_addr)) = i then
                            reg <= s_artico3_wdata;
                        end if;
                    end if;
                    -- USER LOGIC: Write operation
                    if reg_we(i) = '1' then
                        reg <= reg_din(i);
                    end if;
                    -- DATA BUS: Read operation (read operations could be asynchronous,
                    --           but with this approach the latencies when accessing memory
                    --           or registers are the same)
                    reg_out(i) <= reg;
                end if;
            end if;
        end process;

        -- USER LOGIC: Read operation
        reg_dout(i) <= reg;

    end generate;

    -- Set register output value (notice that the address has to be delayed 1 clock cycle to take into account registered read accesses to registers)
    reg_path <= reg_out(to_integer(unsigned(addr_sync)));
<a3<end if>a3>

    ---------------------
    -- Output data MUX --
    ---------------------

    -- Select data that either come from memory or from registers by using the MODE flag
    s_artico3_rdata <= mem_path when (mode_sync = '1') and (en_sync = '1') else
                       reg_path when (mode_sync = '0') and (en_sync = '1') else
                       (others => '0');

    ----------------------
    -- Additional logic --
    ----------------------

    -- Synchronization process to take into account the latency of 1 clock cycle in the BRAM and register read operations
    sync_proc: process(s_artico3_aclk)
    begin
       if s_artico3_aclk'event and s_artico3_aclk = '1' then
           if s_artico3_aresetn = '0' then
               addr_sync <= (others => '0');
               en_sync <= '0';
               mode_sync <= '0';
           else
               addr_sync <= s_artico3_addr;
               en_sync <= s_artico3_en;
               mode_sync <= s_artico3_mode;
           end if;
       end if;
    end process;

    -- Data counter that can be used to let the user logic know how many memory positions have to be read from memory banks
    data_cnt_proc: process(s_artico3_aclk)
    begin
       if s_artico3_aclk'event and s_artico3_aclk = '1' then
           if s_artico3_aresetn = '0' then
               data_cnt <= 0;
           else
               -- When the compute unit is enabled and memory is being accessed...
               if s_artico3_en = '1' and s_artico3_mode = '1' then
                   -- ...check the value of the write enable signal and...
                   if s_artico3_we = '1' then
                       -- ...increment data counter when writing
                       data_cnt <= data_cnt + 1;
                   else
                       -- ...reset data counter when reading
                       data_cnt <= 0;
                   end if;
               end if;
           end if;
       end if;
    end process;

end behavioral;
