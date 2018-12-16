library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.STD_LOGIC_MISC.all;

entity host_if is 
	Port(
		 rstn_i   				: in STD_LOGIC;							-- Reset input	
		 clk_i    				: in STD_LOGIC;							-- Clock input	
		 devrdy_o 				: out STD_LOGIC;						-- Device ready		
		 rrdyn_o  				: out STD_LOGIC;						-- Read data empty		
		 wrdyn_o 				: out STD_LOGIC;						-- Write buffer almost full	
		 hre_i 					: in STD_LOGIC;							-- Host read enable
		 hwe_i    				: in STD_LOGIC;							-- Host write enable
		 wait_read_effective_done : out STD_LOGIC;						-- Wait read effective
		 hdin_i					: in STD_LOGIC_VECTOR(7 downto 0);		-- Host data input					
		 hdout_o  				: out STD_LOGIC_VECTOR(7 downto 0);		-- Host data output
		 rstoutn_o				: out STD_LOGIC;						-- Internal reset output 		
		 data_out_o				: out STD_LOGIC_VECTOR(63 downto 0);	-- Data output	
		 data_valid_o			: out STD_LOGIC;						-- Data valid
		 address 				: out STD_LOGIC_VECTOR(8 downto 0);		-- FourQ Address
		 operation 				: out STD_LOGIC_VECTOR(7 downto 0);		-- FourQ Operation
		 busy 					: in STD_LOGIC;							-- FourQ Component Busy			
		 result_i  				: in STD_LOGIC_VECTOR(63 downto 0)		-- Result input			
	);
end host_if;

architecture behavioral of host_if is

----------------
-- Components --
----------------

component host_if_state_machine
	Port(
		rstn_i   					: in STD_LOGIC;						
		clk_i    					: in STD_LOGIC;						
		hwe_i						: in STD_LOGIC;	
		hre_i						: in STD_LOGIC;
		lbus_din_reg				: in STD_LOGIC_VECTOR(7 downto 0);
		address_high_write 			: out STD_LOGIC;
		address_low_write 			: out STD_LOGIC;
		data_high_read				: out STD_LOGIC;
		data_low_read				: out STD_LOGIC;
		data_high_write				: out STD_LOGIC;
		data_low_write				: out STD_LOGIC;
		write_ena     				: out STD_LOGIC;
		wbusy_reg     				: out STD_LOGIC;
		rrdy_reg      				: out STD_LOGIC;
		wait_read_effective_done	: out STD_LOGIC
	);
end component;


----------------------
-- Internal Signals --
----------------------

signal cnt           				: STD_LOGIC_VECTOR(4 downto 0);		-- Reset delay counter					
signal lbus_din_reg  				: STD_LOGIC_VECTOR(7 downto 0);		-- Write data input register						
signal addr_reg      				: STD_LOGIC_VECTOR(15 downto 0);	-- Internal address bus register					
signal data_reg      				: STD_LOGIC_VECTOR(15 downto 0);		-- Internal write data bus register		

---------------------
-- Control signals --
---------------------

signal rst 							: STD_LOGIC;						-- Internal reset for the FourQ module
signal address_high_write			: STD_LOGIC;						
signal address_low_write 			: STD_LOGIC;						
signal data_high_read				: STD_LOGIC;						
signal data_low_read				: STD_LOGIC;						
signal data_high_write				: STD_LOGIC;						
signal data_low_write				: STD_LOGIC;	

				
signal write_ena     				: STD_LOGIC;						-- Internal register write enable
signal wbusy_reg     				: STD_LOGIC;						-- Write busy register
signal rrdy_reg      				: STD_LOGIC;						-- Read ready register


-- FourQ specific signals
signal oper							: STD_LOGIC_VECTOR(7 downto 0);		-- Operation	
signal addr 						: STD_LOGIC_VECTOR(8 downto 0); 	-- Address
signal data_out						: STD_LOGIC_VECTOR(63 downto 0);	-- Data output
		
signal data_valid      				: STD_LOGIC;						-- Data enable
signal din_reg       				: STD_LOGIC_VECTOR(63 downto 0);	-- Register for incoming data
		
signal dout_mux      				: STD_LOGIC_VECTOR(15 downto 0);	-- Read data multiplex					
signal hdout_reg     				: STD_LOGIC_VECTOR(7 downto 0);		-- Read data register					

begin

	state_machine : host_if_state_machine
		Port Map(
			rstn_i   					=> rstn_i,   				
			clk_i    					=> clk_i,    				
			hwe_i						=> hwe_i,
			hre_i						=> hre_i,					
			lbus_din_reg				=> lbus_din_reg, 
			address_high_write			=> address_high_write,	
			address_low_write			=> address_low_write,
			data_high_read				=> data_high_read,
			data_low_read				=> data_low_read,	
			data_high_write				=> data_high_write,
			data_low_write				=> data_low_write,
			write_ena     				=> write_ena,    			
			wbusy_reg     				=> wbusy_reg,   			
			rrdy_reg      				=> rrdy_reg,
			wait_read_effective_done	=> wait_read_effective_done   			
		);

	-- Reset delay counter
	rst_delay_ctr_reg : process(clk_i, rstn_i)
		begin
			if (rstn_i = '0') then
					cnt <= (others => '0');
			elsif (rising_edge(clk_i)) then
				if (and_reduce(cnt) = '0') then
					cnt <= std_logic_vector(to_unsigned(to_integer(unsigned( cnt )) + 1, cnt'length));
				else null;
				end if;
			end if;
		end process;


	rstoutn_o <= and_reduce(cnt(3 downto 0));
	devrdy_o <= and_reduce(cnt);

	-- Local bus input registers
	lbus_in_reg : process(clk_i, rstn_i)
		begin
			if (rstn_i = '0') then
				lbus_din_reg <= (others => '0');
			elsif(rising_edge(clk_i)) then
				if (hwe_i = '1') then lbus_din_reg <= hdin_i;
				else lbus_din_reg <= lbus_din_reg;
				end if;
			end if;
		end process;


	-- Internal bus
	-- Write/read data from/to the data/address registers (or maintain this data)
	-- Writing is always done first to the MSB (odd-numbered states) and then to the LSB of the data register (even-numbered states) (same applies to the addr_reg).
	internal_bus_reg : process(clk_i, rstn_i)
		begin
			if (rstn_i = '0') then
				addr_reg <= (others => '0');
				data_reg <= (others => '0');
			elsif (rising_edge(clk_i)) then
				if (address_high_write = '1') then addr_reg(15 downto 8) <= lbus_din_reg;	-- Write address MSB
				else addr_reg (15 downto 8) <= addr_reg(15 downto 8);
				end if;

				if (address_low_write = '1') then addr_reg(7 downto 0) <= lbus_din_reg;		-- Write address LSB 
				else addr_reg(7 downto 0) <= addr_reg(7 downto 0);
				end if;

				if (data_high_write = '1') then data_reg(15 downto 8) <= lbus_din_reg; 		-- Write data MSB 
				else data_reg(15 downto 8) <= data_reg(15 downto 8);
				end if;

				if(data_low_write = '1') then data_reg(7 downto 0) <= lbus_din_reg; 		-- Write data LSB
				else data_reg(7 downto 0) <= data_reg(7 downto 0);
				end if;
			end if;
		end process;


	-- Registers for storing values that are being "constructed" using the READ/WRITE state machine. It also stores algorithm-specific signals used in the computation
	data_in_reg : process(clk_i, rstn_i)
	begin
		if (rstn_i = '0') then 
			oper <= (others => '0');
			addr <= (others => '0');
			din_reg <= (others => '0');
			data_valid <= '0';
			
		elsif (rising_edge(clk_i)) then
			rst <= '0';
			data_valid <= '0';
			oper <= (others => '0');
			addr <= addr;
			din_reg <= din_reg;

			if write_ena = '1' then
				case to_integer(unsigned(addr_reg)) is
					when 16#0002# =>
						if data_reg(0) = '1' then
							rst <= '1';
						elsif data_reg(1) = '1' then
							data_valid <= '1';
						end if;
					when 16#0136# => oper <= data_reg(7 downto 0);
					when 16#0138# => addr <= data_reg(15 downto 8) & data_reg(0);
					when 16#0140# => din_reg(63 downto 48) <= data_reg;
					when 16#0142# => din_reg(47 downto 32) <= data_reg;
					when 16#0144# => din_reg(31 downto 16) <= data_reg;
					when 16#0146# => din_reg(15 downto 0) <= data_reg;
					when others => null;
				end case;
			end if;
		end if;
	end process;


	-- Read data multiplexer
	read_data_mult_reg : process(addr_reg, rst, busy, data_valid, result_i, din_reg, oper, addr)
	begin
		case to_integer(unsigned(addr_reg)) is
			when 16#0001# => dout_mux <= (0 => rst, 1 => data_valid, 2 => busy, others => '0');
			when 16#0014# => dout_mux <= STD_LOGIC_VECTOR(resize(unsigned(oper), dout_mux'length));
			when 16#0016# => dout_mux <= STD_LOGIC_VECTOR(resize(unsigned(addr), dout_mux'length));
			when 16#0186# => dout_mux <= result_i(63 downto 48);
			when 16#0188# => dout_mux <= result_i(47 downto 32);
			when 16#018a# => dout_mux <= result_i(31 downto 16);
			when 16#018c# => dout_mux <= result_i(15 downto 0);
			when 16#0296# => dout_mux <= din_reg(63 downto 48);
			when 16#0298# => dout_mux <= din_reg(47 downto 32);
			when 16#029a# => dout_mux <= din_reg(31 downto 16);
			when 16#029c# => dout_mux <= din_reg(15 downto 0);
			when 16#ffff# => dout_mux <= x"1337";				-- Test value
			when others   => dout_mux <= (others => '0');
		end case;
	end process;


	-- Note that we do not care about the addressess which are written in the READ1 and READ2 states, therefore 
	-- we make the assumption that the process is still "write busy"
	host_data_out_reg : process(clk_i, rstn_i)
	begin
		if (rstn_i = '0') then
			hdout_reg <= (others => '0');
		elsif (rising_edge(clk_i)) then
			if (data_high_read = '1') then 
				hdout_reg <= dout_mux(15 downto 8); -- Read MSB 
			elsif (data_low_read = '1') then 	
				hdout_reg <= dout_mux(7 downto 0); 	-- Read LSB
			else
				hdout_reg <= hdout_reg;
			end if;
		end if;
	end process;

	wrdyn_o <= wbusy_reg;
	rrdyn_o <= not rrdy_reg;
	hdout_o <= hdout_reg;


	-- Algorithm specific
	data_out_o 	<= din_reg;
	data_valid_o <= data_valid;
	address <= addr;
	operation <= oper;



end behavioral;

