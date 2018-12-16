library ieee;
use IEEE.NUMERIC_STD.all;
use ieee.std_logic_1164.all;
use work.constants.all;

entity AdderShift is

	generic(
		n           : integer := MAD_X_WIDTH * NMADDS;
		shift_width : integer := MAD_Y_WIDTH;
		out_width   : integer := WORD_WIDTH
	);

	port(
		clk          : in  std_logic;
		rst          : in  std_logic;
		en           : in  std_logic;   --ens shifting
		clear        : in  std_logic;   --ens shifting
		parallel_in  : in  unsigned(n + shift_width - 1 downto 0);
		low_out      : out unsigned(shift_width - 1 downto 0);
		parallel_out : out unsigned(out_width - 1 downto 0);
		done         : out std_logic
	);
end AdderShift;

architecture Behavioral of AdderShift is
	type state_type is (reset, lo, hi, mid, cl, finish);
	signal current_s, next_s : state_type; --current and next state declaration.
	signal temp_reg          : unsigned(n - 1 + shift_width downto 0);
	signal temp_reg_in       : unsigned(n - 1 + shift_width downto 0);
	signal carry             : unsigned(0 downto 0);
	signal carry_in          : unsigned(0 downto 0);

begin
	process(clk, rst)
	begin
		if (rst = '1') then
			current_s <= reset;         --default state on reset.
			carry     <= "0";
			temp_reg  <= (others => '0');
		elsif (rising_edge(clk)) then
			current_s <= next_s;        --state change.
			carry     <= carry_in;
			temp_reg  <= temp_reg_in;
		end if;
	end process;

	process(current_s, en, carry, clear, temp_reg, parallel_in)
		variable temp_low  : unsigned(94 downto 0) := (others => '0');
		variable temp_high : unsigned(92 downto 0) := (others => '0');
	begin
		temp_reg_in <= temp_reg;
		case current_s is
			when reset =>
				temp_reg_in <= (others => '0');
				carry_in    <= "0";
				done        <= '0';
				if (en = '1') then
					next_s <= lo;
				else
					next_s <= reset;
				end if;
			when lo =>
				temp_low                     := resize("0" & temp_reg(94 + 17 - 1 downto 17), 95) + resize("0" & parallel_in(94 - 1 downto 0), 95);
				temp_reg_in(94 - 1 downto 0) <= temp_low(94 - 1 downto 0);
				done                         <= '0';
				carry_in                     <= temp_low(94 downto 94);
				next_s                       <= mid;
			when mid =>
				temp_low                          := resize("0" & temp_reg(2 * 94 + 17 - 1 downto 94 + 17), 95) + resize("0" & parallel_in(2 * 94 - 1 downto 94), 95) + resize(carry, 95);
				temp_reg_in(2 * 94 - 1 downto 94) <= temp_low(94 - 1 downto 0);
				done                              <= '0';
				carry_in                          <= temp_low(94 downto 94);
				next_s                            <= hi;
			when hi =>
				temp_high                                        := resize("00000000000000000" & temp_reg((n + shift_width) - 1 downto 2 * 94 + 17) + parallel_in((n + shift_width) - 1 downto 2 * 94) + carry, temp_high'length);
				temp_reg_in((n + shift_width) - 1 downto 2 * 94) <= temp_high;
				done                                             <= '1';
				carry_in                                         <= carry;
				next_s                                           <= finish;
			when finish =>
				temp_reg_in <= temp_reg;
				done        <= '0';
				carry_in    <= "0";
				if (clear = '1') then
					next_s <= cl;
				elsif (en = '1') then
					next_s <= lo;
				else
					next_s <= finish;
				end if;
			when cl =>
				temp_reg_in <= (others => '0');
				done        <= '0';
				carry_in    <= "0";
				if (clear = '1') or (en = '0') then
					next_s <= cl;
				else
					next_s <= lo;
				end if;
		end case;
	end process;
	parallel_out <= temp_reg(WORD_WIDTH + MUL_TRUNC_LSB - 1 downto MUL_TRUNC_LSB);
	low_out <= temp_reg(shift_width - 1 downto 0);

end Behavioral;
