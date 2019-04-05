library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.constants.all;

entity recode is
	port(
		clk     : in  std_logic;
		rst     : in  std_logic;
		en      : in  std_logic;
		scalars :     scalar_type;
		sd      : out signdigit_array;
		done    : out std_logic
	);
end entity;

architecture Behavioral of recode is
	signal done_in       : std_logic;
	signal done_buf      : std_logic;
	signal clear         : std_logic;
	signal done_iter     : std_logic;
	signal i             : unsigned(RECODE_ROUND_BITS - 1 downto 0);
	signal rst_t         : std_logic;
	signal digits        : digit_array;
	signal sign_masks    : sign_array;
	signal digits_in     : digit_array;
	signal sign_masks_in : sign_array;
	signal scalars_buf   : scalar_type;
	signal scalars_in    : scalar_type;

	type state_type is (reset, start, recode1, recode2, recode3, recode4, add1, add2, end_iter, finish);
	signal current_s, next_s : state_type; --current and next state declaration.
begin

	COUNTER : entity work.counter(Behavioral)
		generic map(n => RECODE_ROUND_BITS)
		port map(clock => clk, clear => clear, count => done_iter, Q => i);

	process(clk, rst)
	begin
		if (rst = '1') then
			done_buf  <= '0';
			current_s <= reset;         --default state on reset.
			for j in WORD_WIDTH downto 0 loop
				digits(j) <= (others => '0');
			end loop;
			for j in WORD_WIDTH downto 0 loop
				sign_masks(j) <= (others => '0');
			end loop;
			for j in RES_WORDS - 1 downto 0 loop
				scalars_buf(j) <= (others => '0');
			end loop;
		elsif (rising_edge(clk)) then
			done_buf    <= done_in;
			current_s   <= next_s;      --state change.
			digits      <= digits_in;
			sign_masks  <= sign_masks_in;
			scalars_buf <= scalars_in;
		end if;
	end process;
	done <= done_in;
	process(current_s, i, digits, sign_masks, scalars_buf, done_buf, en, scalars)
		variable bbit  : unsigned(0 downto 0);
		variable carry : unsigned(0 downto 0);
	begin
		for j in WORD_WIDTH downto 0 loop
			sd(j) <= sign_masks(j) & digits(j);
		end loop;
		done_in <= done_buf;
		sign_masks_in <= sign_masks;
		digits_in <= digits;
		scalars_in <= scalars_buf;
		case current_s is
			when reset =>
				for j in WORD_WIDTH downto 0 loop
					digits_in(j) <= (others => '0');
				end loop;
				for j in WORD_WIDTH downto 0 loop
					sign_masks_in(j) <= (others => '0');
				end loop;
				for j in RES_WORDS - 1 downto 0 loop
					scalars_in(j) <= (others => '0');
				end loop;
				done_in <= '0';
				rst_t <= '1';
				clear <= '1';
				done_iter <= '0';
				if (en = '1') then
					next_s <= start;
				else
					next_s <= reset;
				end if;
			when start =>
				sign_masks_in(WORD_WIDTH) <= "0";
				scalars_in                <= scalars;
				rst_t                     <= '0';
				clear                     <= '1';
				done_in                   <= '0';
				done_iter                 <= '0';
				if (en = '1') then
					next_s <= recode1;
				else
					next_s <= start;
				end if;
			when recode1 =>
				clear         <= '0';
				rst_t         <= '0';
				done_iter     <= '0';
				scalars_in(0) <= "0" & scalars_buf(0)(WORD_WIDTH - 1 downto 1);
				if scalars_buf(0)(1 downto 1) = "1" then
					sign_masks_in(to_integer(i)) <= (others => '0');
				else
					sign_masks_in(to_integer(i)) <= (others => '1');
				end if;
				next_s        <= recode2;
			when recode2 =>
				done_iter                <= '0';
				clear                    <= '0';
				rst_t                    <= '0';
				bbit                     := scalars_buf(1)(0 downto 0);
				carry                    := (scalars_buf(0)(0 downto 0) or bbit) xor scalars_buf(0)(0 downto 0);
				scalars_in(1)            <= resize(("0" & scalars_buf(1)(WORD_WIDTH - 1 downto 1)) + carry, WORD_WIDTH);
				digits_in(to_integer(i)) <= resize(bbit, digits_in(to_integer(i))'length);
				next_s                   <= recode3;
			when recode3 =>
				done_iter                <= '0';
				clear                    <= '0';
				rst_t                    <= '0';
				bbit                     := scalars_buf(2)(0 downto 0);
				carry                    := (scalars_buf(0)(0 downto 0) or bbit) xor (scalars_buf(0)(0 downto 0));
				scalars_in(2)            <= resize((scalars_buf(2)(WORD_WIDTH - 1 downto 1)) + carry, WORD_WIDTH);
				digits_in(to_integer(i)) <= resize(digits(to_integer(i)) + (bbit & "0"), digits_in(to_integer(i))'length);
				next_s                   <= recode4;
			when recode4 =>
				done_iter                <= '0';
				clear                    <= '0';
				rst_t                    <= '0';
				bbit                     := scalars_buf(3)(0 downto 0);
				carry                    := (scalars_buf(0)(0 downto 0) or bbit) xor (scalars_buf(0)(0 downto 0));
				scalars_in(3)            <= resize((scalars_buf(3)(WORD_WIDTH - 1 downto 1)) + carry, WORD_WIDTH);
				digits_in(to_integer(i)) <= resize(digits(to_integer(i)) + (bbit & "00"), digits_in(to_integer(i))'length);
				next_s                   <= end_iter;
			when end_iter =>
				clear     <= '0';
				rst_t     <= '0';
				done_iter <= '1';
				if (i = WORD_WIDTH - 1) then
					next_s <= add1;
				else
					next_s <= recode1;
				end if;
			when add1 =>
				done_iter             <= '0';
				clear                 <= '0';
				rst_t                 <= '0';
				digits_in(WORD_WIDTH) <= scalars_buf(1)(2 downto 0) + (scalars_buf(2)(1 downto 0) & "0");
				next_s                <= add2;
			when add2 =>
				done_iter             <= '0';
				clear                 <= '0';
				rst_t                 <= '0';
				digits_in(WORD_WIDTH) <= resize(digits(WORD_WIDTH) + (scalars_buf(3)(0) & "00"), digits_in(WORD_WIDTH)'length);
				next_s                <= finish;
			when finish =>
				clear     <= '0';
				rst_t     <= '0';
				done_in   <= '1';
				done_iter <= '0';
				next_s    <= start;
		end case;
	end process;

end Behavioral;
