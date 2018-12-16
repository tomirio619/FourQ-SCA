library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;


-- RX means Reception FIFO
-- TX means Transmission FIFO
-- Both FIFOs have the following inputs: two clock inputs for writing and reading, rst, one data input (D) and
-- an output signal (Q), write and read enable signals (WE, RE) and two 
-- ags to know if the FIFO is full or empty.

entity ft2232h_usb_if is
	port (
		clk         : in STD_LOGIC; -- USB interface clock 
		rstn        : in STD_LOGIC; -- Power on reset

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
end ft2232h_usb_if;

architecture behavioral of ft2232h_usb_if is

	-----------
	-- Types --
	-----------
	type state is (USB_IDLE, USB_READ1, USB_READ2, USB_READ3, USB_WRITE1, USB_WRITE2, USB_WRITE3, USB_BACK_OFF);

	----------------
	-- Components --
	----------------

	---------------------
	-- Internal signals --
	----------------------
	signal usb_state : state;								-- USB Interface State Machine
	signal usb_rxf_reg : STD_LOGIC; 						-- #RXF input register
	signal usb_txe_reg : STD_LOGIC; 						-- #TXE input register

	signal usb_rxd_o_read : STD_LOGIC; 						-- #usb_rdn_o output register
	signal usb_rxd_oata : STD_LOGIC_VECTOR(7 downto 0); 	-- #USB_D input register
	signal usb_txd_i_write : STD_LOGIC; 					-- #usb_wrn_o output register
	signal usb_txd_iata : STD_LOGIC_VECTOR(7 downto 0); 	-- #USB_D output register
	signal usb_dbus_oe : STD_LOGIC; 						-- #USB_D output enable register

	signal rxfifo_write : STD_LOGIC; 						--
	signal txfifo_read : STD_LOGIC; 						--
	signal rxfifo_full : STD_LOGIC; 						--
	signal rxfifo_emp : STD_LOGIC; 							--
	signal txfifo_full : STD_LOGIC; 						--
	signal txfifo_emp : STD_LOGIC; 		

begin

	signal_input_reg : process (clk, rstn) 
	begin
		if (rising_edge(clk)) then
			if (rstn = '1') then
				usb_rxf_reg <= '0'; 					-- USB #RXF input register clear
				usb_txe_reg <= '0'; 					-- USB #TXE input register clear
			else
				usb_rxf_reg <= not usb_rxfn_i;			-- USB #RXF input
				usb_txe_reg <= not usb_txen_i;			-- USB #TXE input
			end if;
		else
			null;
		end if;
	end process;

	-- USB(FT2232H ) read/write state machine
	rw_state_reg : process (clk, rstn)
	begin
		if (rising_edge(clk)) then
			if (rstn = '1') then
				usb_rxd_o_read <= '1';
				usb_rxd_oata <= (others => '0');
				usb_txd_i_write <= '1';
				rxfifo_write <= '1';
				txfifo_read <= '1';
				usb_dbus_oe <= '1';
				usb_state <= USB_IDLE;
			else
				case usb_state is
					when USB_IDLE => 
						if (usb_rxf_reg = '1' and rx_busy_i = '1') then 	-- USB receive data valid
							usb_rxd_o_read <= '1'; 							-- USB RD# Active
							usb_state <= USB_READ1;
						elsif (usb_txe_reg = '1' and tx_rdy_i = '1') then 	-- USB transmit
							txfifo_read <= '1';
							usb_state <= USB_WRITE1;
						else
							usb_state <= USB_IDLE;
						end if;
					when USB_READ1 => 
						usb_rxd_oata <= usb_din_i;	-- Read and store value from RX FIFO
					when USB_READ2 => 
						usb_rxd_o_read <= '0'; 		-- USB RD# Disable
						rxfifo_write <= '1'; 		-- RX FIFO write enable active
						usb_state <= USB_READ3;
					when USB_READ3 => 
						rxfifo_write <= '0';
						usb_state <= USB_BACK_OFF;
					when USB_WRITE1 => 
						txfifo_read <= '0';
						usb_dbus_oe <= '1'; 		-- USB_D output enable active
						usb_state <= USB_WRITE2;
					when USB_WRITE2 => 
						txfifo_read <= '0'; 		-- TX FIFO read enable
						usb_txd_i_write <= '1'; 	-- USB data write
						usb_state <= USB_WRITE3; 
					when USB_WRITE3 => 
						usb_state <= USB_BACK_OFF;
					when USB_BACK_OFF => 
						usb_txd_i_write <= '0'; 	-- USB bus Recovery cycle
						usb_dbus_oe <= '0';
						usb_state <= USB_IDLE;
					when others => 
						usb_state <= USB_IDLE;
				end case;
			end if;
		else null;
		end if;
	end process;

	-- USB Signals
	usb_rdn_o <= not usb_rxd_o_read;
	usb_wrn_o <= not usb_txd_i_write;
	usb_dout_o <= txd_i;
	usb_den_o <= usb_dbus_oe;

	rxd_o <= usb_rxd_oata;
	rxd_we_o <= rxfifo_write;

	txd_re_o <= txfifo_read;

end behavioral;