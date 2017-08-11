------------------------------------------------------------
-- ARTICo3 test application                               --
-- Array addition                                         --
--                                                        --
-- Author : Alfonso Rodriguez <alfonso.rodriguezm@upm.es> --
-- Date   : June 2017                                     --
--                                                        --
-- Hardware Thread (HDL)                                  --
-- Core processing function                               --
------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity addvector is
    generic (
        C_NUM_DATA   : natural := 2048; -- Number of elements to be added (array size)
        C_DATA_WIDTH : natural := 32;   -- Data bus width (for ARTICo3 in Zynq, use 32 bits)
        C_ADDR_WIDTH : natural := 32    -- Address bus width (for ARTICo3 in Zynq, use 32 bits)
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
        bram_2_dout : in  std_logic_vector(C_DATA_WIDTH-1 downto 0)
    );
end addvector;

architecture behavioral of addvector is

    -- Control FSM definitions
    type state_t is (S_IDLE, S_ADD, S_FINISH);
    signal state      : state_t;

    -- Signal definitions
    signal read_en    : std_logic;
    signal write_en   : std_logic;
    signal read_addr  : unsigned(C_ADDR_WIDTH-1 downto 0);
    signal write_addr : unsigned(C_ADDR_WIDTH-1 downto 0);

begin

    -- Signal connections
    bram_a_clk  <= clk;
    bram_a_rst  <= reset;
    bram_a_en   <= read_en;
    bram_a_we   <= '0';
    bram_a_addr <= std_logic_vector(read_addr);
    bram_a_din  <= (others => '0');

    bram_b_clk  <= clk;
    bram_b_rst  <= reset;
    bram_b_en   <= read_en;
    bram_b_we   <= '0';
    bram_b_addr <= std_logic_vector(read_addr);
    bram_b_din  <= (others => '0');

    bram_c_clk  <= clk;
    bram_c_rst  <= reset;
    bram_c_en   <= write_en;
    bram_c_we   <= write_en;
    bram_c_addr <= std_logic_vector(write_addr);
    bram_c_din  <= std_logic_vector(unsigned(bram_a_dout) + unsigned(bram_b_dout));

    -- Control FSM
    process(clk,reset)
    begin

        if reset = '1' then

            -- Reset control signals
            state <= S_IDLE;
            ready <= '0';

            -- Reset memory-related signals
            read_en <= '0';
            write_en <= '0';
            read_addr <= (others => '0');
            write_addr <= (others => '0');

        elsif clk'event and clk = '1' then

            -- Output data memory control (latency of 1 clock cycle with respect to input data memory control)
            write_en <= read_en;
            write_addr <= read_addr;

            -- FSM
            case state is

                -- Wait for assertion on control signal to start processing
                when S_IDLE =>
                    if start = '1' then
                        read_en <= '1';
                        ready <= '0';
                        state <= S_ADD;
                    end if;

                -- Perform processing: vector addition
                when S_ADD =>
                    if read_addr = C_NUM_DATA-1 then
                        read_en <= '0';
                        read_addr <= (others => '0');
                        state <= S_FINISH;
                    else
                        read_addr <= read_addr + 1;
                    end if;

                -- Wait for deassertion on control signal to finish
                when S_FINISH =>
                    ready <= '1';
                    if start = '0' then
                        state <= S_IDLE;
                    end if;

            end case;

        end if;

    end process;

end behavioral;
