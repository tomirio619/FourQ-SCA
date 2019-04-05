library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.STD_LOGIC_MISC.all;

use work.constants.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity sakura_g_main is
	Port(
		lbus_rstn_i				: in STD_LOGIC;							-- Reset from Control FPGA																
		lbus_clk_i 				: in STD_LOGIC;							-- Clock from Control FPGA																
																						
		lbus_rdy_io 			: inout STD_LOGIC;						-- Device ready											
		lbus_wd_i  				: in STD_LOGIC_VECTOR(7 downto 0);		-- Local bus data input															
		lbus_we_i  				: in STD_LOGIC;							-- Data write enable										
		lbus_full_o 			: out STD_LOGIC;						-- Data write ready low											
		lbus_afull_o			: out STD_LOGIC;						-- Data near write end											
		lbus_rd_o  				: out STD_LOGIC_VECTOR(7 downto 0);		-- Data output															
		lbus_re_i  				: in STD_LOGIC;							-- Data read enable								
		lbus_emp_o 				: out STD_LOGIC;						-- Data read ready low											
		lbus_aemp_o				: out STD_LOGIC;						-- Data near read end											
		trgoutn_o  				: out STD_LOGIC;						-- AES start trigger (SAKURA-G Only)											
			
		wait_read_effective_done : out STD_LOGIC;
		-- led_o display																		
		led_o					: out STD_LOGIC_VECTOR(9 downto 0);		-- M_LED (led_o[8], led_o[9] SAKURA-G Only)															
			
		-- Trigger output															
		m_header_o  			: out STD_LOGIC_VECTOR(2 downto 0);		-- User Header Pin (SAKURA-G Only)															
		m_clk_ext0_p_o			: out STD_LOGIC;						-- J4 SMA FourQ start (SAKURA-G Only)	
		m_clk_ext0_n_o			: out STD_LOGIC;						-- J5 SMA FourQ (dlb and add scalar mult)										
			
		-- FTDI USB interface portB (SAKURA-G Only)
  		-- FTDI side														
		ftdi_bcbus0_rxf_b_i		: in STD_LOGIC;																	
		ftdi_bcbus1_txe_b_i		: in STD_LOGIC;																	
		ftdi_bcbus2_rd_b_o		: out STD_LOGIC;																	
		ftdi_bcbus3_wr_b_o		: out STD_LOGIC;																	
		ftdi_bdbus_d_io			: inout STD_LOGIC_VECTOR(7 downto 0);																	
			
		-- FTDI USB interface portB (SAKURA-G Only)
  		-- Control FPGA side																
		port_b_rxf_o				: out STD_LOGIC;																	
		port_b_txe_o				: out STD_LOGIC;																	
		port_b_rd_i					: in STD_LOGIC;																	
		port_b_wr_i					: in STD_LOGIC;																	
		port_b_din_i				: in STD_LOGIC_VECTOR(7 downto 0);																	
		port_b_dout_o				: out STD_LOGIC_VECTOR(7 downto 0);																	
		port_b_oen_i				: in STD_LOGIC																	
	);
end sakura_g_main;

architecture behavioral of sakura_g_main is

----------------
-- Components -- 
----------------

component singlecore
	port(
		clk  : in  STD_LOGIC;
		rst  : in  STD_LOGIC;
		oper : in  STD_LOGIC_VECTOR(7 downto 0);
		we   : in  STD_LOGIC;      
		addr : in  STD_LOGIC_VECTOR(8 downto 0);
		di   : in  STD_LOGIC_VECTOR(63 downto 0);
		busy : out STD_LOGIC;
		do   : out STD_LOGIC_VECTOR(63 downto 0);
		trigger_signals : out std_logic_vector(NR_OF_TRIGGERS - 1 downto 0)
	);
end component;

component host_if
	Port(
	 	rstn_i   				: in STD_LOGIC;							-- Reset input	
	 	clk_i    				: in STD_LOGIC;							-- Clock input	
				
	 	devrdy_o 				: out STD_LOGIC;						-- Device ready		
	 	rrdyn_o  				: out STD_LOGIC;						-- Read data empty		
	 	wrdyn_o 				: out STD_LOGIC;						-- Write buffer almost full	
	 	hre_i 					: in STD_LOGIC;							-- Host read enable
	 	hwe_i    				: in STD_LOGIC;							-- Host write enable
		wait_read_effective_done: out STD_LOGIC;						-- Wait read effective done
	 	hdin_i					: in STD_LOGIC_VECTOR(7 downto 0);		-- Host data input					
	 	hdout_o  				: out STD_LOGIC_VECTOR(7 downto 0);		-- Host data output
		data_valid_o			: out STD_LOGIC;						-- Data valid
		address 				: out STD_LOGIC_VECTOR(8 downto 0); 	-- FourQ address
		operation 				: out STD_LOGIC_VECTOR(7 downto 0); 	-- FourQ operation
		busy 					: in STD_LOGIC;							-- FourQ component busy

	 	rstoutn_o				: out STD_LOGIC;						-- Internal reset output 		
					
	 	data_out_o				: out STD_LOGIC_VECTOR(63 downto 0);	-- Data output						
	 	result_i  				: in STD_LOGIC_VECTOR(63 downto 0)		-- Result input			
	);
end component;

----------------------
-- Internal Signals --
----------------------
-- Reset and clock
signal rst 						: STD_LOGIC;						-- Hardware reset
signal resetn  					: STD_LOGIC;						-- Hardware reset
signal clock   					: STD_LOGIC;						-- System clock
			
-- FourQ			
signal oper						: STD_LOGIC_VECTOR(7 downto 0);		-- Operand
signal addr						: STD_LOGIC_VECTOR(8 downto 0);		-- Address
signal data_in 					: STD_LOGIC_VECTOR(63 downto 0);	-- Data input
signal data_out					: STD_LOGIC_VECTOR(63 downto 0);	-- Data output
signal data_valid 				: STD_LOGIC;						-- Data valid	
signal busy    					: STD_LOGIC;						-- Unit busy


-- Power capture signals
signal trig_start					: STD_LOGIC;
signal trig_end						: STD_LOGIC;
signal trig_exec					: STD_LOGIC;

-- Etc
signal count					: STD_LOGIC_VECTOR(21 downto 0);
signal trigger_signals_tmp : std_logic_vector(NR_OF_TRIGGERS - 1 downto 0);

begin

rst <= not resetn;


-- https://www.xilinx.com/support/answers/5304.html
-- https://www.xilinx.com/support/documentation/sw_manuals/xilinx11/spartan6_hdl.pdf
-- https://forums.xilinx.com/t5/Timing-Analysis/Difference-between-IBUFG-and-BUFG-clock/td-p/36584
-- https://www.xilinx.com/support/documentation/user_guides/ug381.pdf 	Page 18
------------------------
-- Clock input driver --	
------------------------
clkdrv : IBUFG		-- 48MHz input
	Port Map(
		i => lbus_clk_i,
		o => clock
	);

---------------------------
-- Triger signals output --
---------------------------
m_header_o(0) <= not trig_start;
m_header_o(1) <= not trig_end;
m_header_o(2) <= trig_exec;

--------------------
-- Host interface --
--------------------
host_if_inst : host_if
	Port Map(
		rstn_i   				=> 	lbus_rstn_i,
		clk_i    				=> 	clock,
		devrdy_o 				=> 	lbus_rdy_io,
		rrdyn_o  				=> 	lbus_emp_o,
		wrdyn_o 				=> 	lbus_full_o,
		hre_i 					=> 	lbus_re_i,
		hwe_i    				=> 	lbus_we_i,
		wait_read_effective_done=> wait_read_effective_done,
		hdin_i					=> 	lbus_wd_i,
		hdout_o  				=> 	lbus_rd_o,
		data_valid_o		 	=>  data_valid,
		rstoutn_o				=> 	resetn,
		data_out_o				=> 	data_in,
		address 				=> 	addr,
		operation 				=> 	oper,
		busy 					=> 	busy,
		result_i  				=> 	data_out
	);

lbus_afull_o <= '1';
lbus_aemp_o  <= '1';

---------------------
-- FourQ component --
---------------------
single_core : singlecore
	Port Map(
			clk		=> clock,
			rst 	=> rst,
			oper	=> oper,
			we  	=> data_valid,
			addr	=> addr,
			di  	=> data_in,
			busy	=> busy,
			do  	=> data_out,
			trigger_signals => trigger_signals_tmp
	);


---------------------------
-- Clock monitor counter --
---------------------------
clk_monitor_ctr : process(clock, resetn)
begin
	if (resetn = '0') then count <= (others => '0');
	elsif (rising_edge(clock)) then
		count <= std_logic_vector(to_unsigned(to_integer(unsigned( count )) + 1, count'length));
	end if;
end process;

-- THis process can be used to acquire the whole power trace,
-- we however will only focus on the doubling (and addition?) operations for the target trace
trigger_power_capture : process(clock, rst)
begin
	if (rst = '1') then		
		trig_start <= '0';     		-- trig_startn
		trig_end	<= '0';   		-- trig_endn
		trig_exec 	<= '0';     	-- trig_exec
	elsif (rising_edge(clock)) then
	trig_start	<= trig_start;
	trig_end	<= trig_end;
	trig_exec 	<= trig_exec;
		-- case to_integer(unsigned(oper)) is
		-- 	when 16#01# | 16#02# | 16#06# =>
		-- 		trig_start <= '1';
		-- 		trig_exec 	<= '1';
		-- 		trig_end <= '0';
		-- 	when others => null;
		-- end case;
		if ((oper = x"01" ) or (oper = x"02") or (oper = x"06")) then
			trig_start <= '1';
			trig_exec 	<= '1';
			trig_end <= '0';
		elsif trig_exec = '1' and busy = '0' and or_reduce(data_out) /= '0' then
			trig_end <= '1';
			trig_exec <= '0';
			trig_start <= '0';
		end if;
	end if;
end process;

-- Assign from trigger_signals_tmp
m_clk_ext0_n_o <= trigger_signals_tmp(0); -- dlb_and_add_trigger
m_clk_ext0_p_o <= trigger_signals_tmp(1); -- scalar_mult_trigger

-------------------------
-- led_o display outputs --
-------------------------
led_o(0) <= not resetn;
led_o(1) <= lbus_rdy_io;		-- Main FPGA ready
led_o(2) <= '0';
led_o(3) <= '1';
led_o(4) <= '1';
led_o(5) <= '1';
led_o(6) <= '0';
led_o(7) <= busy;
led_o(8) <= count(21);
led_o(9) <= not count(21);

----------------
-- USB PORT B --
----------------
port_b_rxf_o <= ftdi_bcbus0_rxf_b_i;
port_b_txe_o <= ftdi_bcbus1_txe_b_i;
ftdi_bcbus2_rd_b_o <= port_b_rd_i;
ftdi_bcbus3_wr_b_o <= port_b_wr_i;
ftdi_bdbus_d_io <= port_b_din_i when port_b_oen_i = '0' else (others => 'Z');
port_b_dout_o <= ftdi_bdbus_d_io;

end behavioral;