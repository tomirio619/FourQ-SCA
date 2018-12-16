library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.STD_LOGIC_MISC.all;

entity host_if_state_machine is
	Port(
			rstn_i   					: in STD_LOGIC;							-- Reset input	
			clk_i    					: in STD_LOGIC;							-- Clock input
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
end host_if_state_machine;


architecture behavioral of host_if_state_machine is


type state is (
	CMD, 
	READ1, 	-- Address High write
	READ2, 	-- Address Low write
	READ3, 	-- Data High read
	READ4, 	-- Data Low read
	WAIT_READ_EFFECTIVE, -- It takes some cycles before we can read from BRAM, this is a padding state which simulates this wait
	WRITE1, -- Address High write
	WRITE2, -- Address Low write
	WRITE3, -- Data High write
	WRITE4	-- Data Low write
);

signal next_state 			: state;			
signal actual_state  		: state;

-- Control signals
signal next_write_ena     				: STD_LOGIC;
signal next_wbusy_reg     				: STD_LOGIC;
signal next_rrdy_reg      				: STD_LOGIC;

signal next_address_high_write 			: STD_LOGIC;
signal next_address_low_write 			: STD_LOGIC;
signal next_data_high_read				: STD_LOGIC;
signal next_data_low_read				: STD_LOGIC;
signal next_data_high_write				: STD_LOGIC;
signal next_data_low_write				: STD_LOGIC;
signal next_wait_read_effective_done	: STD_LOGIC;

signal lbus_we_reg 						: STD_LOGIC;
signal wait_read_effective_ctr 			: unsigned (2 downto 0);

constant WAIT_READ_EFFECTIVE_DELAY 		: integer := 5;




begin

	-- Update internal registers
	update_internal_registers : process(clk_i, rstn_i)
	begin
		if (rstn_i = '0') then
			actual_state 				<= CMD;
			write_ena 					<= '0';		
			wbusy_reg 					<= '0'; 			
			rrdy_reg  					<= '0'; 

			address_high_write 			<= '0';
			address_low_write 			<= '0';		
			data_high_read				<= '0';	
			data_low_read				<= '0';
			data_high_write				<= '0';
			data_low_write				<= '0';

			wait_read_effective_done	<= '0';	

			lbus_we_reg					<= '0';	
	

		elsif (rising_edge(clk_i)) then
			actual_state 				<= next_state; 				
			write_ena 					<= next_write_ena; 					
			wbusy_reg 					<= next_wbusy_reg; 					
			rrdy_reg  				    <= next_rrdy_reg; 

			address_high_write 			<= next_address_high_write; 
			address_low_write 			<= next_address_low_write; 
			data_high_read				<= next_data_high_read;	
			data_low_read				<= next_data_low_read;	
			data_high_write				<= next_data_high_write;	
			data_low_write				<= next_data_low_write;	

			wait_read_effective_done 	<= next_wait_read_effective_done;

			lbus_we_reg 				<= hwe_i;		 
		end if;
	end process;

	-- Update output
	update_output : process(actual_state, lbus_din_reg, hre_i, lbus_we_reg, hwe_i, wait_read_effective_ctr)
	begin
		next_wbusy_reg <= '0';
		next_rrdy_reg <= '0';
		next_write_ena <= '0';
		next_address_high_write <= '0';
		next_address_low_write <= '0';
		next_data_high_read <= '0';
		next_data_low_read <= '0';
		next_data_high_write <= '0';
		next_data_low_write <= '0';
		next_wait_read_effective_done <= '0';

		case actual_state is
			when CMD => 
				if lbus_we_reg = '1' then
					if to_integer(unsigned(lbus_din_reg)) = 1 or to_integer(unsigned(lbus_din_reg)) = 2 then 
						next_address_high_write <= '1';
					end if;
				end if;
			when READ1 =>
				if lbus_we_reg = '1' then 
					next_address_low_write <= '1'; 
				else 
					next_address_high_write <= '1'; 
				end if;
			when READ2 =>
				if hwe_i = '1' then
					next_wbusy_reg <= '1';
				end if;
				if lbus_we_reg = '1' then 
					null;					
					-- next_data_high_read <= '1';
				else
					next_address_low_write <= '1';
				end if;
			
			when WAIT_READ_EFFECTIVE =>
				if wait_read_effective_ctr = 0 then
					next_wbusy_reg <= '1';
				elsif wait_read_effective_ctr = WAIT_READ_EFFECTIVE_DELAY then
					next_wait_read_effective_done <= '1';
					next_data_high_read <= '1';
				end if;	

			when READ3 =>
				next_rrdy_reg <= '1';
				-- next_wbusy_reg <= '1';
				if hre_i = '1' then
					next_data_low_read <= '1';
				else
					next_data_high_read <= '1';
				end if;

			when READ4 =>
				if hre_i = '1' then
					next_write_ena <= '1';
				else
					-- next_wbusy_reg <= '1';
					next_rrdy_reg <= '1';
					next_data_low_read <= '1';
				end if;

			when WRITE1 =>
				if lbus_we_reg = '1' then 
					next_address_low_write <= '1'; 
				else 
					next_address_high_write <= '1'; 
				end if;
			
			when WRITE2 =>
				if lbus_we_reg = '1' then
					next_data_high_write <= '1';
				else
					next_address_low_write <= '1';
				end if;

			when WRITE3 =>
				if lbus_we_reg = '1' then
					next_data_low_write <= '1';
				else
					next_data_high_write <= '1';
				end if;

			when WRITE4 =>
				if lbus_we_reg = '1' then
					next_write_ena <= '1';
				else
					next_data_low_write <= '1';
				end if;

			when others => null;
		end case;
	end process;

	-- Update state
	update_state : process(actual_state, lbus_din_reg, hre_i, lbus_we_reg, wait_read_effective_ctr)
		begin
			case actual_state is
				when CMD =>
					if(lbus_we_reg = '1') then
						if (to_integer(unsigned(lbus_din_reg)) = 1)  then
							next_state <= READ1;
						elsif (to_integer(unsigned(lbus_din_reg)) = 2) then
							next_state <= WRITE1;
						else
							next_state <= CMD;
						end if;
					else
						next_state <= CMD;
					end if;
				-- READ
				when READ1 =>
					if (lbus_we_reg = '1') then next_state <= READ2;			-- Address High write
					else next_state <= READ1;
					end if;
				when READ2 =>
					if (lbus_we_reg = '1') then next_state <= WAIT_READ_EFFECTIVE;	-- Address Low wite
					else next_state <= READ2;
					end if;
					-- wait (at least) five cycles for the data to read become available
				when WAIT_READ_EFFECTIVE =>
					if wait_read_effective_ctr = WAIT_READ_EFFECTIVE_DELAY then next_state <= READ3;
					else next_state <= WAIT_READ_EFFECTIVE;
					end if;
				when READ3 =>
					if (hre_i = '1') then next_state <= READ4;				-- Data High read
					else next_state <= READ3;
					end if;
				when READ4 => 
					if (hre_i = '1') then next_state <= CMD;				-- Data Low read
					else next_state <= READ4;
					end if;
				-- WRITE
				when WRITE1 =>										
					if (lbus_we_reg = '1') then next_state <= WRITE2;		-- Address High write
					else next_state <= WRITE1; 
					end if;
				when WRITE2 =>
					if (lbus_we_reg = '1') then next_state <= WRITE3;		-- Address Low write
					else next_state <= WRITE2; 
					end if;
				when WRITE3 =>
					if (lbus_we_reg = '1') then next_state <= WRITE4;		-- Data High write	
					else next_state <= WRITE3; 
					end if;
				when WRITE4 =>
					if (lbus_we_reg = '1') then next_state <= CMD;			-- Data Low write
					else next_state <= WRITE4; 
					end if;
				when others => next_state <= CMD;
			end case;			
		end process;

	-- Wait read effective counter
	update_read_effective_ctr : process(clk_i, rstn_i)
		begin
			if rstn_i = '0' then
				wait_read_effective_ctr <= to_unsigned(0, wait_read_effective_ctr'length);
			elsif rising_edge(clk_i) then
				case actual_state is
					when WAIT_READ_EFFECTIVE => 
						if wait_read_effective_ctr < WAIT_READ_EFFECTIVE_DELAY then
							wait_read_effective_ctr <= wait_read_effective_ctr + 1;
						end if;
					when others => wait_read_effective_ctr <= to_unsigned(0, wait_read_effective_ctr'length);
				end case;
			end if;				
		end process;

end behavioral;