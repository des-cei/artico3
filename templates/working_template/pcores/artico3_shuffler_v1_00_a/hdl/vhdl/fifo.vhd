-----------------------------------------------------------
-- Synchronous Symmetric FIFO implementation             --
--                                                       --
-- Author: Alfonso Rodriguez <alfonso.rodriguezm@upm.es> --
-----------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity fifo is
    generic (
        C_DATA_WIDTH : integer := 32;    -- Data width in bits
        C_RST_POL    : std_logic := '0'; -- Reset polarity
        C_FIFO_DEPTH : integer := 32     -- FIFO depth in memory positions
    );
    port (
        -- Clock and reset signals
        clk   : in std_logic;
        reset : in std_logic;
        -- Input channel
        din   : in std_logic_vector(C_DATA_WIDTH-1 downto 0);
        wen   : in std_logic;
        full  : out std_logic;
        -- Output channel
        dout  : out std_logic_vector(C_DATA_WIDTH-1 downto 0);
        ren   : in std_logic;
        empty : out std_logic
    );
    -- DEBUG
    attribute mark_debug : string;
    attribute mark_debug of din   : signal is "true";
    attribute mark_debug of wen   : signal is "true";
    attribute mark_debug of full  : signal is "true";
    attribute mark_debug of dout  : signal is "true";
    attribute mark_debug of ren   : signal is "true";
    attribute mark_debug of empty : signal is "true";
end fifo;

architecture behavioral of fifo is
    -- Type definitions
    type fifo_t is array (0 to C_FIFO_DEPTH-1) of std_logic_vector(C_DATA_WIDTH-1 downto 0);
    -- Signal definitions
    signal mem : fifo_t := (others => (others => '0'));       -- Memory to implement the FIFO
    signal read_pointer  : integer range 0 to C_FIFO_DEPTH-1; -- Read FIFO pointer
    signal write_pointer : integer range 0 to C_FIFO_DEPTH-1; -- Write FIFO pointer
    signal full_s        : std_logic;                         -- FIFO full signal
    signal empty_s       : std_logic;                         -- FIFO empty signal
begin

    -- Output control signals
    full <= full_s;
    empty <= empty_s;

--    -- Read FIFO output (without register)
--    dout <= mem(read_pointer);

    -- FIFO process
    fifo_proc: process(clk,reset)
        -- Variable definitions
        variable num_data : integer range 0 to C_FIFO_DEPTH; -- Number of data in the FIFO
        -- DEBUG
        attribute mark_debug : string;
        attribute mark_debug of num_data : variable is "true";
    begin
        -- Asynchronous reset
        if reset = C_RST_POL then

            -- Reset output register
            dout <= (others => '0');
            -- Reset pointers
            write_pointer <= 0;
            read_pointer <= 0;
            -- Reset control signals
            full_s <= '0';
            empty_s <= '1';
            -- Reset data counter
            num_data := 0;

        -- Synchronous process
        elsif clk'event and clk = '1' then

            ----------------
            -- Write FIFO --
            ----------------
            -- Check control signal and enable signal
            if full_s = '0' and wen = '1' then
                -- Write FIFO input (with register)
                mem(write_pointer) <= din;
                -- Increment data counter
                num_data := num_data + 1;
                -- Increment pointer
                if write_pointer = C_FIFO_DEPTH-1 then
                    write_pointer <= 0;
                else
                    write_pointer <= write_pointer + 1;
                end if; -- read_pointer = C_FIFO_DEPTH-1
            end if; -- full = '0' and wen = '1'

            ---------------
            -- Read FIFO --
            ---------------
            -- Check control signal and enable signal
            if empty_s = '0' and ren = '1' then
                -- Read FIFO output (with register)
                dout <= mem(read_pointer);
                -- Decrement data counter
                num_data := num_data - 1;
                -- Increment pointer
                if read_pointer = C_FIFO_DEPTH-1 then
                    read_pointer <= 0;
                else
                    read_pointer <= read_pointer + 1;
                end if; -- read_pointer = C_FIFO_DEPTH-1
            end if; -- empty = '0' and ren = '1'

            ---------------------
            -- Control signals --
            ---------------------
            -- FIFO full
            if num_data = C_FIFO_DEPTH then
                full_s <= '1';
            else
                full_s <= '0';
            end if; -- num_data = C_FIFO_DEPTH
            -- FIFO empty
            if num_data = 0 then
                empty_s <= '1';
            else
                empty_s <= '0';
            end if; -- num_data = 0

        end if; -- clk
    end process;

end behavioral;
