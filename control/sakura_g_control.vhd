library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.STD_LOGIC_MISC.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

use WORK.COMMON.all;

entity sakura_g_control is
	Port (
	-- Reset, Clock
	rstnin_i			: in STD_LOGIC;     
	clkin_i 			: in STD_LOGIC;
	clk_osc_inh_b_o 	: out STD_LOGIC;
	-- FT2232H interface
	usb_rxfn_i 			: in STD_LOGIC;
	usb_txen_i 			: in STD_LOGIC;
	usb_rdn_o 			: out STD_LOGIC;
	usb_wrn_o 			: out STD_LOGIC;
	usb_d_io 			: inout STD_LOGIC_VECTOR(7 downto 0);
	ftdi_acbus4_s_o 	: out STD_LOGIC;
	c_ftdi_reset_b_o 	: out STD_LOGIC;

	-- MAIN FPGA Interface
	lbus_rdy_i 		: in STD_LOGIC;
	lbus_rstn_o 		: out STD_LOGIC;
	lbus_clk_o 			: out STD_LOGIC;
	lbus_wd_o 			: out STD_LOGIC_VECTOR(7 downto 0);
	lbus_we_o 			: out STD_LOGIC;
	lbus_full_i 		: in STD_LOGIC;
  --lbus_afull_i 		: in STD_LOGIC;
	lbus_rd_i 			: in STD_LOGIC_VECTOR(7 downto 0);
	lbus_re_o 			: out STD_LOGIC;
	lbus_emp_i 			: in STD_LOGIC;
  --lbus_aemp_i 		: in STD_LOGIC;

  	-- MAIN FPGA configuration signals
	cfg_din_i			: in STD_LOGIC;   
	cfg_mosi_i			: in STD_LOGIC; 
	cfg_fcsb_i			: in STD_LOGIC;	 
	cfg_cclk_i			: in STD_LOGIC; 
	cfg_progn_i			: in STD_LOGIC; 
	cfg_initn_i			: in STD_LOGIC; 
	cfg_rdwrn_i			: in STD_LOGIC; 
	cfg_busy_i			: in STD_LOGIC; 
	cfg_done_i			: in STD_LOGIC; 

	-- led_o & Switch     
	led_o 				: out STD_LOGIC_VECTOR(9 downto 0);   
	c_pushsw_i 			: in STD_LOGIC;
	c_dipsw_i			: in STD_LOGIC_VECTOR(3 downto 0);

	port_b_rxf_i 		: in STD_LOGIC;
	port_b_txe_i 		: in STD_LOGIC;
	port_b_rd_o 		: out STD_LOGIC;
	port_b_wr_o 		: out STD_LOGIC;
	port_b_din_i 		: in STD_LOGIC_VECTOR(7 downto 0);
	port_b_dout_o 		: out STD_LOGIC_VECTOR(7 downto 0);
	port_b_oen_o 		: out STD_LOGIC
	);
end sakura_g_control;

architecture behavioral of sakura_g_control is


----------------
-- Components --
----------------

component cipher_if
	Port(
		rstn_i		:	in STD_LOGIC;						-- Reset input
		clk_i		:	in STD_LOGIC;						-- Clock input
		
		hrrdyn_i	:	in STD_LOGIC;						-- Host read ready
		hwrdyn_i	: 	in STD_LOGIC;						-- Host write ready
		hdre_o		:	out STD_LOGIC;						-- Host data read enable
		hdwe_o		:  	out STD_LOGIC;						-- Host data write enable
		hdin_i		:  	in STD_LOGIC_VECTOR(7 downto 0);	-- Host data input
		hdout_o		: 	out STD_LOGIC_VECTOR(7 downto 0);	-- Host data output
		
		devrdy_i	: 	in STD_LOGIC;						-- MAIN FPGA ready
		crrdyn_i	:	in STD_LOGIC;						-- Cipher read ready
		cwrdyn_i	:	in STD_LOGIC;						-- Cipher write ready
		cdre_o		:	out STD_LOGIC;						-- Cipher data read enable
		cdwe_o		:  	out STD_LOGIC;						-- Cipher data write enable
		cdin_i		:  	in STD_LOGIC_VECTOR(7 downto 0);	-- Cipher data input
		cdout_o		: 	out STD_LOGIC_VECTOR(7 downto 0)	-- Cipher data output	
	);
end component;

component ft2232h_usb_if 
	Port (
		clk         : in STD_LOGIC; 					-- USB interface clock 
		rstn        : in STD_LOGIC; 					-- Power on reset
		usb_din_i   : in STD_LOGIC_VECTOR(7 downto 0); 	-- USB data input bus
		usb_dout_o  : out STD_LOGIC_VECTOR(7 downto 0); -- USB data output bus
		usb_rdn_o   : out STD_LOGIC; 					-- USB read enable. Active low
		usb_wrn_o   : out STD_LOGIC; 					-- USB write enable. Active low
		usb_rxfn_i  : in STD_LOGIC; 					-- USB rx flag. High: Not ready Low: ready
		usb_txen_i  : in STD_LOGIC; 					-- USB tx enable. High: TX disable Low: TX enable
		usb_den_o   : out STD_LOGIC; 					-- USB tx data enable
		txd_i       : in STD_LOGIC_VECTOR(7 downto 0); 	-- Transmit data input
		rxd_o       : out STD_LOGIC_VECTOR(7 downto 0); -- Receive data output
		txd_re_o  	: out STD_LOGIC; 					-- Read enable
		rxd_we_o  	: out STD_LOGIC; 					-- Write enable
		tx_rdy_i    : in STD_LOGIC; 					-- Transmit data ready 
		rx_busy_i   : in STD_LOGIC 						-- Receive data busy
	);
end component;


component asclk_fifo
	Generic(
		DATA_WIDTH : INTEGER := 8; 
		ADDR_WIDTH : INTEGER := 7
	);
	Port (
		rstn_i   : in STD_LOGIC; 										-- Reset
		wclk_i   : in STD_LOGIC; 										-- Write clock
		rclk_o   : in STD_LOGIC; 										-- Read clock
		d_i      : in STD_LOGIC_VECTOR(sel(DATA_WIDTH) - 1 downto 0); 	-- Data inpute
		we_i     : in STD_LOGIC; 										-- Write enable
		re_i     : in STD_LOGIC; 										-- Rasd enable
		q_o      : out STD_LOGIC_VECTOR(sel(DATA_WIDTH) - 1 downto 0); -- Data output
		full_o   : out STD_LOGIC; 										-- full_o flag
		empty_o  : out STD_LOGIC 										-- empty_o flag											

	);
end component;

component clk_generator
	Port(
		rstnin_i		: in STD_LOGIC;
		clkin_i			: in STD_LOGIC;
		frequency_sel	: in STD_LOGIC_VECTOR(2 downto 0);
		clk				: inout STD_LOGIC;		-- CHANGED
		usbclk			: out STD_LOGIC; 
		rstnout			: out STD_LOGIC
	);
end component;

----------------------
-- Internal signals --
----------------------

-- Reset
signal ext_rstn    		: STD_LOGIC;						
signal resetn    		: STD_LOGIC;						

-- Internal clock						
signal clk        		: STD_LOGIC;						
signal usb_clk    		: STD_LOGIC;	

-- USB					
signal rxfifo_full		: STD_LOGIC;					-- USB receive data FIFO full flag	
signal rxfifo_empty		: STD_LOGIC;					-- USB receive data FIFO full flag	
signal rxfifo_write		: STD_LOGIC;					-- USB receive data FIOF write enable	
signal rxfifo_read		: STD_LOGIC;					-- USB receive data FIFO read enable	
signal rxdata   		: STD_LOGIC_VECTOR(7 downto 0);	-- USB receive data FIFO data output								
signal txfifo_empty		: STD_LOGIC;						
signal txfifo_write		: STD_LOGIC;						
signal txdata			: STD_LOGIC_VECTOR(7 downto 0);	

signal usb_rxf_n		: STD_LOGIC;						
signal usb_txe_n		: STD_LOGIC;						
signal usb_read_n		: STD_LOGIC;						
signal usb_write_n		: STD_LOGIC;					
signal usb_rx_data		: STD_LOGIC_VECTOR(7 downto 0);							
signal usb_tx_data		: STD_LOGIC_VECTOR(7 downto 0);		
signal usb_txen_ia  	: STD_LOGIC;					-- USB transmit data enable

-- Local bus
signal wd1				: STD_LOGIC_VECTOR(7 downto 0);	
signal rd1				: STD_LOGIC_VECTOR(7 downto 0);	

-- etc
signal cnt				: STD_LOGIC_VECTOR(21 downto 0);
					

begin

-- Input reset
ext_rstn <= not (not rstnin_i or not cfg_done_i or not c_pushsw_i);

clk_gen : clk_generator
	Port Map(
		rstnin_i => ext_rstn,
		clkin_i => clkin_i,
		frequency_sel => c_dipsw_i(3 downto 1),
		rstnout => resetn,
		clk => clk,
		usbclk => usb_clk
	);

-- led_o display
led_o(0) <= not cnt(21);
led_o(1) <= not resetn;
led_o(2) <= ( lbus_rdy_i and cfg_done_i );
led_o(3) <= ( cfg_initn_i or cfg_progn_i or cfg_done_i or cfg_rdwrn_i or cfg_busy_i );
led_o(4) <= cfg_din_i;
led_o(5) <= cfg_mosi_i;
led_o(6) <= cfg_fcsb_i;
led_o(7) <= cfg_cclk_i;
led_o(8) <= c_dipsw_i(0);     -- ON : SASEBO-GII software Full compati mode
led_o(9) <= cnt(21);

process (clk, resetn)
	begin
		if (rising_edge(clk) or falling_edge(resetn)) then
			if (resetn = '1') then
				cnt <= (others => '0');
			else
				cnt <= std_logic_vector(to_unsigned(to_integer(unsigned( cnt )) + 1, cnt'length));

			end if;
		else
			null;
		end if;
	end process;

usb_rxf_n <= usb_rxfn_i when c_dipsw_i(0) = '0' else port_b_rxf_i;
usb_txe_n <= usb_txen_i when c_dipsw_i(0) = '0' else port_b_txe_i;
usb_rx_data <= usb_d_io when c_dipsw_i(0) = '0' else port_b_din_i;

ft223h_usbif : ft2232h_usb_if
	Port Map(
		clk       	=>	clk,
		rstn      	=>	resetn,
		usb_din_i 	=>	usb_rx_data,
		usb_dout_o	=>	usb_tx_data,
		usb_rdn_o 	=>	usb_read_n,
		usb_wrn_o 	=>	usb_write_n,
		usb_rxfn_i	=>	usb_rxf_n,
		usb_txen_i	=>	usb_txe_n,
		usb_den_o 	=>	usb_txen_ia,
		txd_i     	=>	txdata,
		rxd_o     	=>	rxdata,
		txd_re_o  	=>	txfifo_read,
		rxd_we_o  	=>	rxfifo_write,
		tx_rdy_i  	=>	not txfifo_empty,
		rx_busy_i 	=>	rxfifo_full
	);

usb_d_io <= usb_tx_data when c_dipsw_i(0) ='0' and usb_txen_i = '1' else (others => 'Z');
usb_rdn_o <= usb_read_n  when c_dipsw_i(0) ='0' else '1';
usb_wrn_o <= usb_write_n when c_dipsw_i(0) ='0' else '1';

port_b_rd_o <= usb_read_n when c_dipsw_i(0) ='1' else '1';
port_b_wr_o <= usb_write_n when c_dipsw_i(0) ='1' else '1';
port_b_dout_o <= usb_tx_data when c_dipsw_i(0) ='1' else (others => 'Z');
port_b_oen_o  <= not usb_txen_ia when c_dipsw_i(0) ='1' else '1';

-- USB Receive Data FIFO
rx_fifo : asclk_fifo 
	Port Map(
		rstn_i => resetn,
		wclk_i => usb_clk,
		rclk_o => clk,
		d_i    => rxdata,
		we_i   => rxfifo_write,
		re_i   => rxfifo_read,
		q_o    => rd1,
		full_o => rxfifo_full,
		empty_o => rxfifo_empty
	);

-- USB Receive Data FIFO
tx_fifo : asclk_fifo 
	Port Map(
		rstn_i => resetn,
		wclk_i => clk,
		rclk_o => usb_clk,
		d_i    => wd1,
		we_i   => txfifo_write,
		re_i   => txfifo_read,
		q_o    => txdata,
		full_o => txfifo_full,
		empty_o => txfifo_empty
	);

-- Cipher FPGA Interface
cipher_if_inst : cipher_if
	Port Map (
		rstn_i	=> resetn,
		clk_i	=> clk,
		hrrdyn_i => rxfifo_empty,
		hwrdyn_i => txfifo_full,
		hdre_o	=> rxfifo_read,
		hdwe_o	=> txfifo_write,
		hdin_i	=> rd1,
		hdout_o	=> wd1,
		devrdy_i => lbus_rdy_i,
		crrdyn_i	=> lbus_emp_i,
		cwrdyn_i	=> lbus_full_i,
		cdre_o		=> lbus_re_o,
		cdwe_o		=> lbus_we_o,
		cdin_i		=> lbus_rd_i,
		cdout_o		=> lbus_wd_o
	);

lbus_rstn_o <= resetn;

-- Lbus clock
u0 : ODDR2
	Port Map(
		d0 => '0',
		d1 => '1',
		c0 => clk,
		c1 => not clk,
		q => lbus_clk_o,
		ce => '1',
		r => '0',
		s => '0'
	);

clk_osc_inh_b_o <= '1';
ftdi_acbus4_s_o <= '0';
c_ftdi_reset_b_o <= rstnin_i;

end behavioral;

