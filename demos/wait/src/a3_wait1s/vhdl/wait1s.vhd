------------------------------------------------------------
-- ARTICo3 test application                               --
-- Parallel "wait" kernels                                --
--                                                        --
-- Author : Alfonso Rodriguez <alfonso.rodriguezm@upm.es> --
-- Date   : August 2017                                   --
--                                                        --
-- Hardware kernel (HDL)                                  --
-- Core processing function                               --
------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity wait1s is
    generic (
        C_DATA_WIDTH : natural := 32; -- Data bus width (for ARTICo3 in Zynq, use 32 bits)
        C_ADDR_WIDTH : natural := 16  -- Address bus width (for ARTICo3 in Zynq, use 16 bits)
    );
    port (
        -- Global signals
        clk         : in  std_logic;
        reset       : in  std_logic;
        -- Control signals
        start       : in  std_logic;
        ready       : out std_logic;
        -- Input data memory : array A
        bram_0_clk  : out std_logic;
        bram_0_rst  : out std_logic;
        bram_0_en   : out std_logic;
        bram_0_we   : out std_logic;
        bram_0_addr : out std_logic_vector(C_ADDR_WIDTH-1 downto 0);
        bram_0_din  : out std_logic_vector(C_DATA_WIDTH-1 downto 0);
        bram_0_dout : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);
        -- Input data memory : array B
        bram_1_clk  : out std_logic;
        bram_1_rst  : out std_logic;
        bram_1_en   : out std_logic;
        bram_1_we   : out std_logic;
        bram_1_addr : out std_logic_vector(C_ADDR_WIDTH-1 downto 0);
        bram_1_din  : out std_logic_vector(C_DATA_WIDTH-1 downto 0);
        bram_1_dout : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);
        -- Output data memory : array C
        bram_2_clk  : out std_logic;
        bram_2_rst  : out std_logic;
        bram_2_en   : out std_logic;
        bram_2_we   : out std_logic;
        bram_2_addr : out std_logic_vector(C_ADDR_WIDTH-1 downto 0);
        bram_2_din  : out std_logic_vector(C_DATA_WIDTH-1 downto 0);
        bram_2_dout : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);
        -- Data counter (not used in this example, size fixed for being integer)
        values      : in  std_logic_vector(31 downto 0)
    );
end wait1s;

architecture behavioral of wait1s is

    constant C_SYS_FREQ : integer := 10000000;
    constant C_REQ_SECS : integer := 1;
    signal cnt : integer range 0 to C_REQ_SECS*C_SYS_FREQ-1;
    signal en  : std_logic;

begin

    ready <= not en;

    process(clk,reset)
    begin
        if reset = '1' then

            en <= '0';
            cnt <= 0;

        elsif clk'event and clk = '1' then

            if start = '1' then
                en <= '1';
            end if;

            if en = '1' then
                if cnt = C_REQ_SECS*C_SYS_FREQ-1 then
                    cnt <= 0;
                    en <= '0';
                else
                    cnt <= cnt + 1;
                end if;
            end if;

        end if;
    end process;

end behavioral;
