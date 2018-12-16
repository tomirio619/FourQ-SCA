library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use work.constants.all;

use IEEE.NUMERIC_STD.ALL;

entity scalar_unit is
	Port(
		clk       : in  std_logic;
		rst       : in  std_logic;
		oper      : in  std_logic_vector(7 downto 0);
		we        : in  std_logic;
		addr      : in  std_logic_vector(8 downto 0);
		req_digit : in  std_logic;
		di        : in  std_logic_vector(63 downto 0);
		digit_out : out std_logic_vector(3 downto 0);
		done      : out std_logic
	);
end scalar_unit;

architecture structural of scalar_unit is

	component recode_module is
		port(
			clk  : in  std_logic;
			rst  : in  std_logic;
			en   : in  std_logic;
			k    : in  unsigned(255 downto 0);
			sd   : out signdigit_array;
			done : out std_logic
		);
	end component recode_module;

	signal key_reg    : unsigned(255 downto 0);
	signal digit_cntr : integer range 0 to 64 := 64;

	signal en : std_logic;
	signal sd : signdigit_array;

begin

	input_handling : process(clk, rst)
	begin
		if rst = '1' then
			key_reg <= (others => '0');
		elsif rising_edge(clk) then
			if we = '1' and addr(7 downto 2) = "000000" then
				case addr(1 downto 0) is
					when "00"   => key_reg(63 downto 0) <= unsigned(di);
					when "01"   => key_reg(127 downto 64) <= unsigned(di);
					when "10"   => key_reg(191 downto 128) <= unsigned(di);
					when "11"   => key_reg(255 downto 192) <= unsigned(di);
					when others => null;
				end case;
			end if;
		end if;
	end process input_handling;

	en <= '1' when oper = x"01" else '0';

	i_recode_module : recode_module
		port map(clk, rst, en, key_reg, sd, done);

	output_handling : process(clk, rst)
	begin
		if rst = '1' then
			digit_out  <= (others => '0');
			digit_cntr <= 64;
		elsif rising_edge(clk) then
			if req_digit = '1' then
				if digit_cntr > 0 then
					digit_cntr <= digit_cntr - 1;
				else
					digit_cntr <= 64;
				end if;
			end if;
			digit_out <= std_logic_vector(sd(digit_cntr));
		end if;
	end process output_handling;

end structural;
