library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.constants.all;
use work.MAD;
use work.counter;
entity ROW_MUL is
	port(
		clk    : in  std_logic;
		rst    : in  std_logic;
		en     : in  std_logic;
		x      : in  unsigned(X_WIDTH - 1 downto 0);
		y_mad  : in  unsigned(MAD_Y_WIDTH - 1 downto 0);
		rounds : in  unsigned(ROUND_BITS - 1 downto 0);
		z      : out unsigned(X_WIDTH + MAD_Y_WIDTH - 1 downto 0);
		done   : out std_logic
	);
end entity ROW_MUL;

architecture Behavioral of ROW_MUL is
	type low_res_array is array (0 to NMADDS - 1) of unsigned(MAD_X_WIDTH - 1 downto 0);
	type high_res_array is array (0 to NMADDS - 1) of unsigned(MAD_Y_WIDTH downto 0);
	signal res_low           : low_res_array;
	signal res_high          : high_res_array;
	signal count             : unsigned(ROUND_BITS - 1 downto 0);
	type state_type is (reset, running, start, finish);
	signal current_s, next_s : state_type;
	signal clear             : std_logic;
	signal run               : std_logic;
begin

	COUNTER : entity work.counter(Behavioral)
		generic map(n => ROUND_BITS)
		port map(clock => clk, clear => clear, count => run, Q => count);

	GEN_MAD : for i in 0 to NMADDS - 1 generate

		FIRST : if i = 0 generate
			MAD0 : entity work.MAD(Behavioral)
				port map(
					clk                                       => clk, rst => rst, x => x(MAD_X_WIDTH - 1 downto 0), y => y_mad, z => (others => '0'),
					res(MAD_RES_WIDTH - 1 downto MAD_X_WIDTH) => res_high(0),
					res(MAD_X_WIDTH - 1 downto 0)             => res_low(0)
				);
		end generate FIRST;

		OTH : if (i > 0) generate
			MADX : entity work.MAD(Behavioral)
				port map(
					clk                                       => clk,
					rst                                       => rst,
					x                                         => (x(MAD_X_WIDTH*(i + 1) - 1 downto MAD_X_WIDTH*i)),
					y                                         => y_mad,
					z                                         => (res_high(i - 1)),
					res(MAD_RES_WIDTH - 1 downto MAD_X_WIDTH) => res_high(i),
					res(MAD_X_WIDTH - 1 downto 0)             => res_low(i)
				);
		end generate OTH;

	end generate;

	process(clk, rst)
	begin
		if (rst = '1') then
			current_s <= reset;         --default state on reset.
		elsif (rising_edge(clk)) then
			current_s <= next_s;        --state change.
		else
			current_s <= current_s;
		end if;
	end process;

	process(current_s, en, count, rounds, res_high, res_low)
	begin
		case current_s is
			when reset =>
				done   <= '0';
				clear  <= '1';
				run    <= '0';
				next_s <= start;
			when start =>
				done  <= '0';
				clear <= '1';
				run   <= '0';
				if (en = '1') then
					next_s <= running;
				else
					next_s <= start;
				end if;
			when running =>
				if count = rounds + 1 then
					next_s <= finish;
				else
					next_s <= running;
				end if;
				done <= '0';
				clear <= '0';
				run <= '1';
			when finish =>
				done   <= '1';
				clear  <= '1';
				run    <= '0';
				next_s <= start;
		end case;
		for j in 0 to (NMADDS - 1) loop
			z(MAD_X_WIDTH*(j + 1) - 1 downto MAD_X_WIDTH*j) <= res_low(j);
		end loop;
		z(X_WIDTH + MAD_Y_WIDTH - 1 downto X_WIDTH) <= res_high(NMADDS - 1)(MAD_Y_WIDTH - 1 downto 0);
	end process;
end architecture;
