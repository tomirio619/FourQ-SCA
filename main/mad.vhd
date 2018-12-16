library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
use work.constants.all;

entity MAD is
	port(
		clk : in  std_logic;
		rst : in  std_logic;
		x   : in  unsigned((MAD_X_WIDTH) - 1 downto 0);
		y   : in  unsigned((MAD_Y_WIDTH) - 1 downto 0);
		z   : in  unsigned((MAD_Z_WIDTH) - 1 downto 0);
		res : out unsigned((MAD_RES_WIDTH - 1) downto 0)
	);
end entity MAD;

architecture Behavioral of MAD is
begin
	process(rst, clk) is
	begin
		if rst = '1' then
			res <= (others => '0');
		elsif (clk'EVENT and clk = '1') then
			res <= unsigned(resize(x * y + z, res'length));
		end if;
	end process;
end architecture Behavioral;
