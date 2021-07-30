-----------------------------------------------------------------------------
-- ARTICo3 HDL kernel testbench
--
-- Author : Álvaro Ortega Lozano <alvaro.ortega.lozano@alumnos.upm.es>
--
-- Date   : May 2021
-----------------------------------------------------------------------------

<a3<artico3_preproc>a3>

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use ieee.std_logic_1164.all;

library ieee_proposed;
use ieee_proposed.float_pkg.all;


entity a3_wrapper_tb is
end a3_wrapper_tb;


architecture Behavioral of a3_wrapper_tb is

	--------------------------
	-- Constant declaration --
	--------------------------  
	constant C_ARTICO3_DATA_WIDTH : integer := 32;    -- Data bus width (in bits)
	constant C_ARTICO3_ADDR_WIDTH : integer := 16;    -- Address bus width (in bits)
	constant C_MAX_MEM            : integer := <a3<MEMBYTES>a3>;  -- Total memory size (in bytes) inside the compute unit
	constant C_NUM_MEM            : integer := <a3<MEMBANKS>a3>;     -- Number of memory banks inside the compute unit (to allow parallel accesses from logic
	constant C_NUM_REG            : integer := <a3<NUMREGS>a3>;     -- Number of Read/Write registers inside the compute unit 

	--Time constant
	constant clk_period: time := 8ns;
    
	------------------------
	-- Signal declaration --
	------------------------
	--DUT signals
	signal clk_tb: std_logic := '0';
	signal reset_tb: std_logic;
	signal start_tb: std_logic;
	signal ready_tb: std_logic;
	signal en_tb: std_logic;
	signal we_tb: std_logic;
	signal mode_tb: std_logic;
	signal addr_tb: std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
	signal wdata_tb: std_logic_vector(C_ARTICO3_DATA_WIDTH-1 downto 0);
	signal rdata_tb: std_logic_vector(C_ARTICO3_DATA_WIDTH-1 downto 0);

	--Auxiliary signal



begin

	-----------------------
	-- DUT instantiation --
	-----------------------
	dut: entity work.a3_wrapper
	generic map (
		C_ARTICO3_DATA_WIDTH =>    C_ARTICO3_DATA_WIDTH,
		C_ARTICO3_ADDR_WIDTH =>    C_ARTICO3_ADDR_WIDTH,
		C_MAX_MEM            =>    C_MAX_MEM,
		C_NUM_MEM            =>    C_NUM_MEM,
		C_NUM_REG            =>    C_NUM_REG
	)
	port map(
		s_artico3_aclk       =>    clk_tb,
		s_artico3_aresetn    =>    reset_tb,
		s_artico3_start      =>    start_tb,                                        
		s_artico3_ready      =>    ready_tb,                                  
		s_artico3_en         =>    en_tb,                                   
		s_artico3_we         =>    we_tb,                                         
		s_artico3_mode       =>    mode_tb,                                       
		s_artico3_addr       =>    addr_tb,
		s_artico3_wdata      =>    wdata_tb, 
		s_artico3_rdata      =>    rdata_tb
	);
    
	-----------------
	-- CLK stimuli --
	-----------------                       
	clk_tb <= not clk_tb after clk_period/2;

	------------------------
	-- Stimuli generation --
	------------------------    
	stimuli: process
		constant MEM_POS : integer := (C_MAX_MEM/C_NUM_MEM)/(C_ARTICO3_DATA_WIDTH/8);  

		--Reset Procedure
		procedure reset_init is                            
		begin
			reset_tb <= '0';
			start_tb <= '0';
			en_tb <= '0';
			we_tb <= '0';
			mode_tb <= '0';
			addr_tb <= (others => '0');
			wdata_tb <= (others => '0');
			wait for 10*clk_period;
			reset_tb <= '1';
			wait for 10*clk_period;
		end procedure;

		--Write Memory Procedure for std_logic_vector
		procedure write_mem( constant addr: in std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
							 constant wdata: in std_logic_vector(C_ARTICO3_DATA_WIDTH-1 downto 0) ) is
		begin
			en_tb <= '1';
			we_tb <= '1';
			mode_tb <= '1';
			addr_tb <= addr;
			wdata_tb <= wdata;
			wait for clk_period;
			en_tb <= '0';
			we_tb <= '0';
			-- wait for clk_period;
		end procedure;

		--Write Memory Procedure for integer
		procedure write_mem( constant addr: in std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
						     constant wdata: in integer) is
		begin
			en_tb <= '1';
			we_tb <= '1';
			mode_tb <= '1';
			addr_tb <= addr;
			wdata_tb <= std_logic_vector(to_unsigned(wdata, C_ARTICO3_DATA_WIDTH));
			wait for clk_period;
			en_tb <= '0';
			we_tb <= '0';
		end procedure;

		--Write Memory Procedure for floating point
		procedure write_mem( constant addr: in std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
							 constant wdata: in real) is
		begin
			en_tb <= '1';
			we_tb <= '1';
			mode_tb <= '1';
			addr_tb <= addr;
			wdata_tb <= to_slv(to_float(wdata));
			wait for clk_period;
			en_tb <= '0';
			we_tb <= '0';
		end procedure;  

		--Write Register Procedure for std_logic_vector
		procedure write_reg( constant addr: in std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
							 constant wdata: in std_logic_vector(C_ARTICO3_DATA_WIDTH-1 downto 0) ) is
		begin
			en_tb <= '1';
			we_tb <= '1';
			mode_tb <= '0';
			addr_tb <= addr;
			wdata_tb <= wdata;
			wait for clk_period;
			en_tb <= '0';
			we_tb <= '0';
		end procedure;


		--Write Register Procedure for integer
		procedure write_reg( constant addr: in std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
						     constant wdata: in integer) is
		begin
			en_tb <= '1';
			we_tb <= '1';
			mode_tb <= '0';
			addr_tb <= addr;
			wdata_tb <= std_logic_vector(to_unsigned(wdata, C_ARTICO3_DATA_WIDTH));
			wait for clk_period;
			en_tb <= '0';
			we_tb <= '0';
		end procedure;

		--Write Register Procedure for floating point
		procedure write_reg( constant addr: in std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0);
							 constant wdata: in real) is
		begin
			en_tb <= '1';
			we_tb <= '1';
			mode_tb <= '0';
			addr_tb <= addr;
			wdata_tb <= to_slv(to_float(wdata));
			wait for clk_period;
			en_tb <= '0';
			we_tb <= '0';
		end procedure;  

		--Start Procedure  
		procedure kernel_start is
		begin
			start_tb <= '1';
			wait for clk_period;
		end procedure; 

		--Wait Procedure  
		procedure kernel_wait is
		begin
			wait until ready_tb = '1';
			start_tb <= '0';
			wait for clk_period;
		end procedure;      

		--Read Memory Procedure
		procedure read_mem( constant addr: in std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0)) is                             
		begin
			en_tb <= '1';
			mode_tb <= '1';
			addr_tb <= addr;
			wait for 2*clk_period;
			en_tb <= '0';	
			assert false 
				report to_string(to_float(rdata_tb)) 
				severity warning;
		end procedure;

		--Read Register Procedure
		procedure read_reg( constant addr: in std_logic_vector(C_ARTICO3_ADDR_WIDTH-1 downto 0)) is                             
		begin
			en_tb <= '1';
			mode_tb <= '0';
			addr_tb <= addr;
			wait for 2*clk_period;
			en_tb <= '0';
			assert false 
				report to_string(to_float(rdata_tb)) 
				severity warning;
		end procedure;


	begin   
		--setup
		reset_init;  

		--WRITING BRAM: function (memory_location, value_to_write)
		--
		--NOTE: for output ports remove the write_mem function and for input ports
		--      change the value to write and the memory location according to 
		--      kernel application
		--	        
		--NOTE: bram_0 starts at memory location 0,
		--      bram_1 starts at memory location MEM_POS
		--      bram_2 starts at memory locarion 2*MEM_POS
		--
		--NOTE: value_to_write can be std_logic_vector, integer or real type
		--
<a3<generate for PORTS>a3>
		--Write bram_<a3<pid>a3>
		write_mem(std_logic_vector(to_unsigned(<a3<pid>a3> * MEM_POS, addr_tb'length)), <a3<pid>a3>);
		write_mem(std_logic_vector(to_unsigned(<a3<pid>a3> * MEM_POS + 1, addr_tb'length)), 2*<a3<pid>a3>);									   
<a3<end generate>a3>
       
		--WRITING REG: function (memory_location, value_to_write)   
		--
		--NOTE: value_to_write can be std_logic_vector, integer or real type
		--
<a3<generate for REGS>a3>
		--Write reg_<a3<rid>a3>
		write_reg(std_logic_vector(to_unsigned(<a3<rid>a3>, addr_tb'length)), 5);										   
<a3<end generate>a3>
											   
        --kernel implementation
        kernel_start;
        kernel_wait;
        
        --READ BRAM: function (memory_location)
		--
		--NOTE: for input ports remove the read_mem function and change
		--      the memory location according to the writing ports
		--
		--NOTE: bram_0 starts at memory location 0,
		--      bram_1 starts at memory location MEM_POS
		--      bram_2 starts at memory locarion 2*MEM_POS
		--
<a3<generate for PORTS>a3>
		--Read bram_<a3<pid>a3>
		read_mem(std_logic_vector(to_unsigned(<a3<pid>a3> * MEM_POS, addr_tb'length)));			
		read_mem(std_logic_vector(to_unsigned(<a3<pid>a3> * MEM_POS + 1, addr_tb'length)));			
<a3<end generate>a3>
											  
        --READ BRAM: function (memory_location)										  
<a3<generate for REGS>a3>
		--Read reg_<a3<rid>a3>
		read_reg(std_logic_vector(to_unsigned(<a3<rid>a3>, addr_tb'length)));	
<a3<end generate>a3>

		wait;

    end process;
   
end Behavioral;

