library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.constants.all;

entity MUL_TRUNCATE is
	generic(x_width : integer := MAD_X_WIDTH*NMADDS; y_width : integer := MAD_Y_WIDTH*NMADDS_Y);
	port(
		clk        : in  std_logic;
		rst        : in  std_logic;
		en         : in  std_logic;
		rounds     : in  unsigned(ROUND_BITS - 1 downto 0);
		row_rounds : in  unsigned(ROUND_BITS - 1 downto 0);
		x          : in  unsigned(x_width - 1 downto 0);
		y          : in  unsigned(y_width - 1 downto 0);
		z_high     : out unsigned(WORD_WIDTH - 1 downto 0);
		z_low      : out unsigned(WORD_WIDTH - 1 downto 0);
		done       : out std_logic
	);
end entity MUL_TRUNCATE;

architecture Behavioral of MUL_TRUNCATE is

	signal rst_t             : std_logic;
	signal done_t            : std_logic;
	signal done_add          : std_logic;
	signal load_y            : std_logic;
	signal en_y              : std_logic;
	signal en_r              : std_logic;
	signal en_low            : std_logic;
	signal en_m              : std_logic;
	signal y_mad             : unsigned(MAD_Y_WIDTH - 1 downto 0);
	signal done_row          : std_logic;
	signal addend            : unsigned(ROW_MUL_WORD_WIDTH - 1 downto 0);
	signal temp_res          : unsigned(WORD_WIDTH - 1 downto 0);
	signal low_w             : unsigned(MAD_Y_WIDTH - 1 downto 0);
	signal temp_low          : unsigned(WORD_WIDTH - 1 downto 0);
	signal count             : unsigned(ROUND_BITS - 1 downto 0);
	signal clear             : std_logic;
	signal clear_add         : std_logic := '0';
	signal row_rounds_t      : unsigned(ROUND_BITS - 1 downto 0);
	signal row_rounds_in     : unsigned(ROUND_BITS - 1 downto 0);
	type state_type is (reset, running, start, loading, add, next_row, low_shift, finish);
	signal current_s, next_s : state_type; --current and next state declaration.
begin
	COUNTER : entity work.counter(Behavioral)
		generic map(n => ROUND_BITS)
		port map(clock => clk, clear => clear, count => done_row, Q => count);
	LOWREG : entity work.SPR_Reg(Behavioral)
		generic map(n => MAD_Y_WIDTH*RES_WORDS, shift_width => MAD_Y_WIDTH, out_width => WORD_WIDTH)
		port map(clk => clk, rst => rst_t, en => en_low, clear => clear_add, parallel_in => low_w, parallel_out => temp_low);
	YREG : entity work.Sreg(Behavioral)
		generic map(n => MAD_Y_WIDTH*NMADDS_Y, shift_width => MAD_Y_WIDTH, out_width => MAD_Y_WIDTH)
		port map(clk => clk, rst => rst_t, load => load_y, en => en_y, parallel_in => unsigned(y), parallel_out => y_mad);
	ADDER : entity work.AdderShift(Behavioral)
		generic map(n => MAD_X_WIDTH*NMADDS, shift_width => MAD_Y_WIDTH, out_width => WORD_WIDTH)
		port map(clk => clk, rst => rst_t, en => en_r, clear => clear_add, parallel_in => unsigned(addend), parallel_out => temp_res, low_out => low_w, done => done_add);
	ROW : entity work.ROW_MUL(Behavioral)
		port map(clk => clk, rst => rst_t, en => en_m, x => x, y_mad => y_mad, rounds => row_rounds_t, z => addend, done => done_row);

	z_high <= temp_res;
	z_low  <= temp_low;

	process(clk, rst)
	begin
		if (rst = '1') then
			current_s    <= reset;      --default state on reset.
			row_rounds_t <= (others => '0');
		elsif (rising_edge(clk)) then
			current_s    <= next_s;     --state change.
			row_rounds_t <= row_rounds_in;
		end if;
	end process;

	done <= done_t;
	process(current_s, en, done_row, count, rounds, done_add, row_rounds_t, row_rounds)
	begin
		clear_add     <= '0';
		row_rounds_in <= row_rounds_t;
		case current_s is
			when reset =>
				row_rounds_in <= row_rounds;
				en_low        <= '0';
				done_t        <= '0';
				clear         <= '1';
				clear_add     <= '1';
				rst_t         <= '1';
				en_r          <= '0';
				en_m          <= '0';
				en_y          <= '0';
				load_y        <= '0';
				if (en = '1') then
					next_s <= start;
				else
					next_s <= reset;
				end if;
			when start =>
				en_low <= '0';
				done_t <= '0';
				clear  <= '1';
				rst_t  <= '0';
				en_r   <= '0';
				en_m   <= '0';
				en_y   <= '0';
				load_y <= '0';
				if (en = '1') then
					next_s <= loading;
				else
					next_s <= start;
				end if;
			when loading =>
				row_rounds_in <= row_rounds;
				en_low        <= '0';
				clear_add     <= '1';
				clear         <= '0';
				done_t        <= '0';
				rst_t         <= '0';
				en_r          <= '0';
				en_m          <= '0';
				en_y          <= '0';
				load_y        <= '1';
				next_s        <= running;
			when running =>
				clear_add <= '0';
				en_low    <= '0';
				done_t    <= '0';
				clear     <= '0';
				rst_t     <= '0';
				en_r      <= '0';
				en_m      <= '1';
				en_y      <= '0';
				load_y    <= '0';
				if done_row = '1' then
					next_s <= add;
				else
					next_s <= running;
				end if;
			when add =>
				clear_add <= '0';
				en_low    <= '0';
				done_t    <= '0';
				clear     <= '0';
				rst_t     <= '0';
				en_r      <= '1';
				en_m      <= '0';
				en_y      <= '0';
				load_y    <= '0';
				if done_add = '1' then
					next_s <= next_row;
				else
					next_s <= add;
				end if;
			when next_row =>
				done_t <= '0';
				en_low <= '0';
				clear  <= '0';
				rst_t  <= '0';
				en_r   <= '0';
				en_y   <= '1';
				en_m   <= '0';
				load_y <= '0';
				if (count <= ROUNDS_64) then
					next_s <= low_shift;
				else
					if (count < rounds) then
						row_rounds_in <= row_rounds - (count - ROUNDS_64);
						next_s        <= running;
					else
						next_s <= finish;
					end if;
				end if;
			when low_shift =>
				done_t <= '0';
				clear  <= '0';
				rst_t  <= '0';
				en_r   <= '0';
				en_y   <= '0';
				en_low <= '1';
				en_m   <= '0';
				load_y <= '0';
				if (count < rounds) then
					next_s <= running;
				else
					next_s <= finish;
				end if;
			when finish =>
				en_low <= '0';
				done_t <= '1';
				clear  <= '1';
				rst_t  <= '0';
				en_r   <= '0';
				en_m   <= '0';
				en_y   <= '0';
				load_y <= '0';
				next_s <= start;
		end case;
	end process;
end architecture;
