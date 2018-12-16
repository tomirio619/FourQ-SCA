library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;

entity adder_w is
	generic (
        W        : integer := 32);
    port (
        a        : in  std_logic_vector(W-1 downto 0);
        b        : in  std_logic_vector(W-1 downto 0);
        c_in     : in  std_logic;
        s        : out std_logic_vector(W-1 downto 0);
        c_out    : out std_logic);
end adder_w;

architecture rtl of adder_w is

	signal sum : std_logic_vector(W downto 0);

	signal c_long : std_logic_vector(W downto 0);

begin

	c_long(W downto 1) <= (others => '0');
	c_long(0) <= c_in;
	sum <= std_logic_vector(unsigned('0' & a) + unsigned('0' & b) + unsigned(c_long));

	s <= sum(W-1 downto 0);
	c_out <= sum(W);

end rtl;
