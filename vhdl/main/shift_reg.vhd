library ieee;

use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_1164.all;
use work.constants.all;

entity SPR_Reg is

	generic(n : integer := 8; shift_width : integer := 4; out_width : integer := 4);

	port(clk          : in  std_logic;
	     rst          : in  std_logic;
	     clear        : in  std_logic;
	     en           : in  std_logic;
	     parallel_in  : in  unsigned(shift_width - 1 downto 0);
	     parallel_out : out unsigned(out_width - 1 downto 0)
	    );
end SPR_Reg;

architecture Behavioral of SPR_Reg is

	signal temp_reg : unsigned(n - 1 downto 0) := (Others => '0');

begin
	process(clk, rst, en, clear)
	begin
		if (rst = '1') then
			temp_reg <= (others => '0');
		elsif (rising_edge(clk)) then
			if clear = '1' then
				temp_reg <= (others => '0');
			elsif (en = '1') then
				temp_reg(n - shift_width - 1 downto 0) <= temp_reg(n - 1 downto shift_width);
				temp_reg(n - 1 downto n - shift_width) <= parallel_in;
			else
				temp_reg <= temp_reg;
			end if;
		else
			temp_reg <= temp_reg;
		end if;

	end process;
	parallel_out <= temp_reg(out_width - 1 downto 0);
end Behavioral;
