library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cipher_if is
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
end cipher_if;


architecture behavioral of cipher_if is

constant CW_IDLE	: STD_LOGIC_VECTOR (1 downto 0) := x"0";
constant CW_FREAD	: STD_LOGIC_VECTOR (1 downto 0) := x"1";
constant CW_WRITE	: STD_LOGIC_VECTOR (1 downto 0) := x"2";

constant CR_IDLE	: STD_LOGIC := '0';
constant CR_READ	: STD_LOGIC := '1';

-- Internal signals
signal cw_state 	: STD_LOGIC_VECTOR(1 downto 0);			-- Main(cipher) FPGA write state machine register
signal cr_state 	: STD_LOGIC;							-- Main(cipher) FPGA read state machine register


begin 

-- Main FPGA write (Main FPGA sends input over the bus, which is received by the Controller)

receive_main_fpga_write: process(clk_i, rstn_i)
begin
	if (rising_edge(clk_i)) then
		if (rstn_i = '1') then
			hdre_o <= '0';
			cdwe_o <= '0';
			cdout_o <= (others => '0');
			cw_state <= CW_IDLE;
		else
			case cw_state is
				when CW_IDLE =>
					if (devrdy_i = '1' and hrrdyn_i = '0') then		-- Tell host that it can read (set our own WE to zero)
						hdre_o <= '1';
						cdwe_o <= '0';
						cw_state <= CW_FREAD;
					else 											-- Host or cipher not ready, so return to idle state
						cdwe_o <= '0';
						cw_state <= CW_IDLE;
					end if;
				when CW_FREAD =>									--  USB receive data FIFO read
					hdre_o <= '0';
					cw_state <= CW_WRITE;
				when CW_WRITE => 				 					-- LBUS write
					if (cwrdyn_i = '0') then						-- Cipher is ready to write, so enable WE and write input of Host to output signal
						cdwe_o <= '1';
						cdout_o <= hdin_i;							-- Data send to from the host to the cipher is stored in the corresponding output signal of the cipher
						cw_state <= CW_IDLE;
					else
						cdwe_o <= '0';
						cw_state <= CW_WRITE;
					end if;
				when others =>
					cw_state <= CW_IDLE;
			end case;
		end if;
	else
		null;
	end if;
end process;


-- Main FPGA read (Controller FPGA sends input over the bus, which is received by the Main FPGA (e.g. host))

send_main_fpga_read: process(clk_i, rstn_i)
begin
	if (rising_edge(clk_i)) then
		if (rstn_i = '1') then
			cdre_o <= '0';
			hdwe_o <= '0';
			hdout_o <= (others => '0');
			cr_state <= CR_IDLE;
		else
			case cr_state is
				when CR_IDLE =>
					if (devrdy_i = '1' and hrrdyn_i = '0' and crrdyn_i = '0') then	-- If both the host and the cipher are read-ready, and the main FPGA is ready as well, we progress
						cdre_o <= '1';
						hdwe_o <= '0';
						cr_state <= CR_READ;
					else
						cdre_o <= '0';
						hdwe_o <= '0';
						cr_state <= CR_IDLE;
					end if;
				when CR_READ =>														-- LBUS read
					cdre_o <= '0';
					hdwe_o <= '1';
					hdout_o <= cdin_i;												-- Data send to from the cipher to the host is stored in the corresponding output signal of the host
					cr_state <= CR_IDLE;
				when others =>
					cr_state <= CR_IDLE;
			end case;
		end if;
	else
		null;
	end if;
end process;


end behavioral;

			