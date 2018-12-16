library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use IEEE.NUMERIC_STD.all;

entity counter is

  generic (n : natural := 2);
  port (
    clock : in std_logic;
    clear : in std_logic;
    count : in std_logic;
    Q : out unsigned(n - 1 downto 0)
  );
end counter;
architecture Behavioral of counter is 

  signal Pre_Q : unsigned(n - 1 downto 0);

begin
  process (clock, count, clear)
  begin
    if clear = '1' then
      Pre_Q <= (others => '0');
    elsif (clock = '1' and clock'event) then
      if count = '1' then
        Pre_Q <= Pre_Q + 1;
      end if;
    end if;
  end process; 

  Q <= Pre_Q;

end Behavioral;