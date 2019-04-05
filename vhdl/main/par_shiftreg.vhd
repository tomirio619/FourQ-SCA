library ieee;

use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_1164.all;
use work.constants.all;

entity SReg is

	generic(n : integer := 8; shift_width : integer := 4; out_width : integer := 4);

	port(clk          : in  std_logic;
	     rst          : in  std_logic;
	     load         : in  std_logic;  --ens shifting 
	     en           : in  std_logic;  --ens shifting 
	     parallel_in  : in  unsigned(n - 1 downto 0);
	     parallel_out : out unsigned(out_width - 1 downto 0)
	    );
end SReg;

architecture Behavioral of SReg is

	signal temp_reg : unsigned(n - 1 downto 0)           := (Others => '0');
	signal zeros    : unsigned(shift_width - 1 downto 0) := (Others => '0');
begin
	process(clk, rst, temp_reg)
	begin
		if (rst = '1') then
			temp_reg <= (others => '0');
		elsif (clk'event and clk = '1') then
			if (load = '1') then
				temp_reg <= parallel_in;
			elsif (en = '1') then

				temp_reg(n - 1 - shift_width downto 0) <= temp_reg(n - 1 downto shift_width);
				temp_reg(n - 1 downto n - shift_width) <= (others => '0');

			end if;
		end if;
		parallel_out <= temp_reg(out_width - 1 downto 0);
	end process;

end Behavioral;
