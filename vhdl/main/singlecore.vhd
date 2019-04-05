library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.constants.all;


entity singlecore is
	port(
		clk  : in  std_logic;
		rst  : in  std_logic;
		oper : in  std_logic_vector(7 downto 0);
		we   : in  std_logic;
		addr : in  std_logic_vector(8 downto 0);
		di   : in  std_logic_vector(63 downto 0);
		busy : out std_logic;
		do   : out std_logic_vector(63 downto 0);
		trigger_signals : out std_logic_vector(NR_OF_TRIGGERS - 1 downto 0)
	);
end singlecore;

architecture structural of singlecore is

	component scalar_unit is
		port(
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
	end component scalar_unit;

	component core is
		port(
			clk       : in  std_logic;
			rst       : in  std_logic;
			oper      : in  std_logic_vector(7 downto 0);
			digit_in  : in  std_logic_vector(3 downto 0);
			we        : in  std_logic;
			addr      : in  std_logic_vector(8 downto 0);
			di        : in  std_logic_vector(63 downto 0);
			req_digit : out std_logic;
			busy      : out std_logic;
			do        : out std_logic_vector(63 downto 0);
			trigger_signals: out STD_LOGIC_VECTOR(NR_OF_TRIGGERS - 1 downto 0)
		);
	end component core;

	signal req_digit, done  : std_logic;
	signal digit, digit_reg : std_logic_vector(3 downto 0);
	signal trigger_signals_tmp : std_logic_vector(NR_OF_TRIGGERS - 1 downto 0);

begin

	i_scalar_unit : scalar_unit
		port map(clk, rst, oper, we, addr, req_digit, di, digit, done);

	i_digit_reg : process(clk, rst)
	begin
		if rst = '1' then
			digit_reg <= (others => '0');
		elsif rising_edge(clk) then
			digit_reg <= digit;
		end if;
	end process i_digit_reg;

	i_core : core
		port map(
			clk       => clk,
			rst       => rst,
			oper      => oper,
			digit_in  => digit_reg,
			we        => we,
			addr      => addr,
			di        => di,
			req_digit => req_digit,
			busy      => busy,
			do        => do,
			trigger_signals => trigger_signals_tmp
		);

		trigger_signals <= trigger_signals_tmp;

end structural;
