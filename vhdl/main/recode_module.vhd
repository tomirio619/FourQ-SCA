library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.constants.all;

entity recode_module is
	port(
		clk  : in  std_logic;
		rst  : in  std_logic;
		en   : in  std_logic;
		k    : in  unsigned(255 downto 0);
		sd   : out signdigit_array;
		done : out std_logic
	);
end entity;

architecture Behavioral of recode_module is
	signal en_d        : std_logic;
	signal en_r        : std_logic;
	signal done_d      : std_logic;
	signal done_r      : std_logic;
	signal scalars_t   : scalar_type;
	signal scalars_in  : scalar_type;
	signal scalars_buf : scalar_type;

	type state_type is (reset, start, decompose, recode, finish);
	signal current_s, next_s : state_type; --current and next state declaration.
begin
	done <= done_r;
	DE : entity work.decompose(Behavioral)
		port map(
			clk   => clk, rst => rst, en => en_d, k => k, scals => scalars_t, done => done_d
		);
	RE : entity work.recode(Behavioral)
		port map(
			clk     => clk,
			rst     => rst,
			en      => en_r,
			scalars => scalars_buf,
			sd      => sd,
			done    => done_r
		);

	process(clk, rst)
	begin
		if (rst = '1') then
			current_s <= reset;         --default state on reset.
			for j in RES_WORDS - 1 downto 0 loop
				scalars_buf(j) <= (others => '0');
			end loop;
		elsif (rising_edge(clk)) then
			current_s   <= next_s;      --state change.
			scalars_buf <= scalars_in;
		end if;
	end process;

	process(current_s, en, done_r, done_d, scalars_t, scalars_buf, scalars_t)
	begin
		scalars_in <= scalars_buf;
		case current_s is
			when reset =>
				for j in RES_WORDS - 1 downto 0 loop
					scalars_in(j) <= (others => '0');
				end loop;
				en_r <= '0';
				en_d <= '0';
				next_s <= start;
			when start =>
				en_r <= '0';
				en_d <= '0';
				if en = '1' then
					next_s <= decompose;
				else
					next_s <= start;
				end if;
			when decompose =>
				en_r <= '0';
				en_d <= '1';
				if (done_d = '1') then
					-- As scalar_type is a custom type, you must split this in an if/else statement, otherwise it will not work
					
					if SCALAR_IS_DECOMPOSED = true then
						-- The secret scalar now contains the multiscalar (a1, a2, a3, a4) with a1 being the lower 64 bits and a4 the upper 64 bits
						scalars_in(0) <= k(63 downto 0);
						scalars_in(1) <= k(127 downto 64);
						scalars_in(2) <= k(191 downto 128);
						scalars_in(3) <= k(255 downto 192);
					else scalars_in <= scalars_t;
					end if;
					next_s     <= recode;
				else
					next_s <= decompose;
				end if;
			when recode =>
				en_r <= '1';
				en_d <= '0';
				if (done_r = '1') then
					next_s <= finish;
				else
					next_s <= recode;
				end if;
			when finish =>
				en_r   <= '0';
				en_d   <= '0';
				next_s <= start;
		end case;
	end process;

end Behavioral;
