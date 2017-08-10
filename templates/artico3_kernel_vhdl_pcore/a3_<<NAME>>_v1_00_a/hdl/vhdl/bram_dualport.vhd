-----------------------------------------------------------
-- Custom dual port BRAM template                        --
--                                                       --
-- Author: Alfonso Rodriguez <alfonso.rodriguezm@upm.es> --
--                                                       --
-- Notes:                                                --
--     - READ-FIRST RAM implementation                   --
--     - Optional output register                        --
-----------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bram_dualport is
    generic (
        -- Data width (in bits)
        C_DATA_WIDTH : integer := 32;
        -- Address width (in bits)
        C_ADDR_WIDTH : integer := 32;
        -- Memory depth (# positions)
        C_MEM_DEPTH  : integer := 4096;
        -- Memory configuration mode
        C_MEM_MODE   : string := "LOW_LATENCY" -- Memory performance configuration mode (HIGH_PERFORMANCE, LOW_LATENCY)
    );
    port (
        -- Port A --
        clk_a  : in  std_logic;
        rst_a  : in  std_logic;
        en_a   : in  std_logic;
        we_a   : in  std_logic;
        addr_a : in  std_logic_vector(C_ADDR_WIDTH-1 downto 0);
        din_a  : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);
        dout_a : out std_logic_vector(C_DATA_WIDTH-1 downto 0);

        -- Port B --
        clk_b  : in  std_logic;
        rst_b  : in  std_logic;
        en_b   : in  std_logic;
        we_b   : in  std_logic;
        addr_b : in  std_logic_vector(C_ADDR_WIDTH-1 downto 0);
        din_b  : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);
        dout_b : out std_logic_vector(C_DATA_WIDTH-1 downto 0)
    );
    -- DEBUG
    attribute mark_debug : string;
    attribute mark_debug of en_a   : signal is "true";
    attribute mark_debug of we_a   : signal is "true";
    attribute mark_debug of addr_a : signal is "true";
    attribute mark_debug of din_a  : signal is "true";
    attribute mark_debug of dout_a : signal is "true";
    attribute mark_debug of en_b   : signal is "true";
    attribute mark_debug of we_b   : signal is "true";
    attribute mark_debug of addr_b : signal is "true";
    attribute mark_debug of din_b  : signal is "true";
    attribute mark_debug of dout_b : signal is "true";
end bram_dualport;

architecture behavioral of bram_dualport is

    -- NOTE: Xilinx has a strange way of defining dual-port (R/W) RAM memories.
    --       In former ISE tools, the RAM itself had to be defined as a shared
    --       variable (a non-synthesizable construct). In Vivado, the template
    --       to create RAM memories relies on signals that are assigned in two
    --       different processes (that could even be in different clock domains).
    --       Since this approaches are "bad" VHDL coding, this module can be
    --       considered technology-dependent.

    -- NOTE: In line with the previous comment, this technology-dependent code
    --       seems to generate synthesis errors in certain Vivado versions,
    --       namely the 2016.x ones.

    -- RAM definitions
    type mem_t is array (0 to C_MEM_DEPTH-1) of std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal mem    : mem_t := (others => (others => '0'));      -- RAM memory implementation
    signal data_a : std_logic_vector(C_DATA_WIDTH-1 downto 0); -- Port A memory data out
    signal data_b : std_logic_vector(C_DATA_WIDTH-1 downto 0); -- Port B memory data out

    -- Force BRAM inference
    attribute ram_style : string;
    attribute ram_style of mem : signal is "block";

begin

    ------------
    -- Port A --
    ------------

    -- Port A control logic (READ-FIRST implementation)
    port_a: process(clk_a)
        -- Variable definitions
        variable addr : integer range 0 to C_MEM_DEPTH-1;
    begin
        -- Synchronous (clk_a) process
        if clk_a'event and clk_a = '1' then
            -- Memory enable
            if en_a = '1' then
                -- Address capture
                addr := to_integer(unsigned(addr_a));
                -- Write enable
                if we_a = '1' then
                    mem(addr) <= din_a;
                end if;
                -- Read memory
                data_a <= mem(addr);
            end if;
        end if;
    end process;

    ------------
    -- Port B --
    ------------

    -- Port B control logic (READ-FIRST implementation)
    port_b: process(clk_b)
        -- Variable definitions
        variable addr : integer range 0 to C_MEM_DEPTH-1;
    begin
        -- Synchronous (clk_b) process
        if clk_b'event and clk_b = '1' then
            -- Memory enable
            if en_b = '1' then
                -- Address capture
                addr := to_integer(unsigned(addr_b));
                -- Write enable
                if we_b = '1' then
                    mem(addr) <= din_b;
                end if;
                -- Read memory
                data_b <= mem(addr);
            end if;
        end if;
    end process;

    -----------------------
    -- Output generation --
    -----------------------

    --  NOTE: following code generates LOW_LATENCY (no output register)
    --        1 clock cycle read latency at the cost of a longer clock-to-out timing

    no_output_register : if C_MEM_MODE = "LOW_LATENCY" generate
    begin

        dout_a <= data_a;
        dout_b <= data_b;

    end generate;

    --  NOTE: following code generates HIGH_PERFORMANCE (use output register)
    --        2 clock cycle read latency with improved clock-to-out timing

    output_register : if C_MEM_MODE = "HIGH_PERFORMANCE" generate

        -- Signal definitions
        signal dout_a_reg : std_logic_vector(C_DATA_WIDTH-1 downto 0); -- Port A memory data out register
        signal regen_a    : std_logic;                                 -- Port A output register enable
        signal dout_b_reg : std_logic_vector(C_DATA_WIDTH-1 downto 0); -- Port B memory data out register
        signal regen_b    : std_logic;                                 -- Port B output register enable

    begin

        -- NOTE: the output register enable is generated delaying the memory enable signal 1 clock
        --       cycle (to account for the additional latency that the register itself generates)

        -- TODO: check latency effect when adding output register (maybe it is not necessary to
        --       register en_X signals to generate regen_X signals)

        -- Port A output register
        reg_a: process(clk_a)
        begin
            -- Synchronous (clk_a) process
            if clk_a'event and clk_a = '1' then
                -- Synchronous active-high reset
                if rst_a = '1' then
                    regen_a <= '0';
                    dout_a_reg <= (others => '0');
                else
                    -- Delay memory enable 1 clock cycle (latency matching)
                    regen_a <= en_a;
                    -- Output register enable
                    if regen_a = '1' then
                        dout_a_reg <= data_a;
                    end if;
                end if;
            end if;
        end process;

        dout_a <= dout_a_reg;

        -- Port B output register
        reg_b: process(clk_b)
        begin
            -- Synchronous (clk_b) process
            if clk_b'event and clk_b = '1' then
                -- Synchronous active-high reset
                if rst_b = '1' then
                    regen_b <= '0';
                    dout_b_reg <= (others => '0');
                else
                    -- Delay memory enable 1 clock cycle (latency matching)
                    regen_b <= en_b;
                    -- Output register enable
                    if regen_b = '1' then
                        dout_b_reg <= data_b;
                    end if;
                end if;
            end if;
        end process;

        dout_b <= dout_b_reg;

    end generate;

end behavioral;
