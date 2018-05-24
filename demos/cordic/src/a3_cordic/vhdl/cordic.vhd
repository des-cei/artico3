------------------------------------------------------------
-- ARTICo3 test application                               --
-- Vivado IP Integrator - CORDIC sin/cos                  --
--                                                        --
-- Author : Alfonso Rodriguez <alfonso.rodriguezm@upm.es> --
-- Date   : May 2018                                      --
--                                                        --
-- Hardware kernel (HDL)                                  --
-- Core processing function                               --
------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cordic is
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
        -- Input data memory : phase
        bram_0_clk  : out std_logic;
        bram_0_rst  : out std_logic;
        bram_0_en   : out std_logic;
        bram_0_we   : out std_logic;
        bram_0_addr : out std_logic_vector(C_ADDR_WIDTH-1 downto 0);
        bram_0_din  : out std_logic_vector(C_DATA_WIDTH-1 downto 0);
        bram_0_dout : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);
        -- Input data memory : cos(phase)
        bram_1_clk  : out std_logic;
        bram_1_rst  : out std_logic;
        bram_1_en   : out std_logic;
        bram_1_we   : out std_logic;
        bram_1_addr : out std_logic_vector(C_ADDR_WIDTH-1 downto 0);
        bram_1_din  : out std_logic_vector(C_DATA_WIDTH-1 downto 0);
        bram_1_dout : in  std_logic_vector(C_DATA_WIDTH-1 downto 0);
        -- Output data memory : sin(phase)
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
end cordic;

architecture behavioral of cordic is

    -- CORDIC
    signal phase_tvalid  : std_logic;
    signal phase_tready  : std_logic;
    signal phase_tdata   : std_logic_vector(31 downto 0);
    signal dout_tvalid   : std_logic;
    signal dout_tdata    : std_logic_vector(63 downto 0);

    -- Address
    signal en_in         : std_logic;
    signal addr_in       : unsigned(C_ADDR_WIDTH-1 downto 0);
    signal addr_out      : unsigned(C_ADDR_WIDTH-1 downto 0);

    -- Control FSM
    type state_t is (S_IDLE, S_WAIT, S_READ, S_LAST);
    signal state         : state_t;
    signal start_s       : std_logic;
    signal ready_s       : std_logic;

    -- Other definitions
    constant SAMPLES     : integer := 4096;

    -- DEBUG
    attribute mark_debug : string;
    attribute mark_debug of phase_tvalid : signal is "true";
    attribute mark_debug of phase_tready : signal is "true";
    attribute mark_debug of phase_tdata  : signal is "true";
    attribute mark_debug of dout_tvalid  : signal is "true";
    attribute mark_debug of dout_tdata   : signal is "true";
    attribute mark_debug of en_in        : signal is "true";
    attribute mark_debug of addr_in      : signal is "true";
    attribute mark_debug of addr_out     : signal is "true";
    attribute mark_debug of state        : signal is "true";
    attribute mark_debug of start_s      : signal is "true";
    attribute mark_debug of ready_s      : signal is "true";

begin

    ----------------------
    -- Port connections --
    ----------------------

    -- Phase
    bram_0_clk  <= clk;
    bram_0_rst  <= not reset;
    bram_0_en   <= en_in;
    bram_0_we   <= '0';
    bram_0_addr <= std_logic_vector(addr_in);
    bram_0_din  <= (others => '0');
    phase_tdata <= bram_0_dout;

    -- Cosine
    bram_1_clk  <= clk;
    bram_1_rst  <= not reset;
    bram_1_en   <= dout_tvalid;
    bram_1_we   <= dout_tvalid;
    bram_1_addr <= std_logic_vector(addr_out);
    bram_1_din  <= dout_tdata(31 downto 0);

    -- Sine
    bram_2_clk  <= clk;
    bram_2_rst  <= not reset;
    bram_2_en   <= dout_tvalid;
    bram_2_we   <= dout_tvalid;
    bram_2_addr <= std_logic_vector(addr_out);
    bram_2_din  <= dout_tdata(63 downto 32);

    -- Control
    start_s       <= start;
    ready         <= ready_s;

    ---------------
    -- Instances --
    ---------------

    -- CORDIC
    cordic_inst: entity work.cordic_0
    port map (
        aclk                => clk,
        aresetn             => reset,
        s_axis_phase_tvalid => phase_tvalid,
        s_axis_phase_tready => phase_tready,
        s_axis_phase_tdata  => phase_tdata,
        m_axis_dout_tvalid  => dout_tvalid,
        m_axis_dout_tdata   => dout_tdata
    );

    -------------------
    -- Control logic --
    -------------------

    -- Output address generation
    addr_proc: process(clk, reset)
    begin
        if reset = '0' then
            addr_out <= (others => '0');
        elsif clk'event and clk = '1' then
            if state /= S_IDLE then
                if dout_tvalid = '1' then
                    addr_out <= addr_out + 1;
                end if;
            else
                addr_out <= (others => '0');
            end if;
        end if;
    end process;

    -- Control FSM
    fsm_proc: process(clk, reset)
    begin
        if reset = '0' then
            en_in        <= '0';
            addr_in      <= (others => '0');
            phase_tvalid <= '0';
            ready_s      <= '0';
            state        <= S_IDLE;
        elsif clk'event and clk = '1' then
            case state is

                when S_IDLE =>
                    if start_s = '1' then
                        en_in   <= '1';
                        addr_in <= (others => '0');
                        ready_s <= '0';
                        state   <= S_WAIT;
                    end if;

                when S_WAIT =>
                    phase_tvalid <= '1';
                    state        <= S_READ;

                when S_READ =>
                    if phase_tready = '1' then
                        phase_tvalid  <= '0';
                        if addr_in = SAMPLES-1 then
                            en_in <= '0';
                            state <= S_LAST;
                        else
                            addr_in <= addr_in + 1;
                            state   <= S_WAIT;
                        end if;
                    end if;

                when S_LAST =>
                    if addr_out = SAMPLES then
                        ready_s <= '1';
                    end if;
                    if start_s = '0' and ready_s = '1' then
                        state <= S_IDLE;
                    end if;

            end case;
        end if;
    end process;

end behavioral;
