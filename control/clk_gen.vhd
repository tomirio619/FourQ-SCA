library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.STD_LOGIC_MISC.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;


------------------------------
-- Reset and Clock generator--
------------------------------

entity clk_generator is
	Port(
		rstnin_i		: in STD_LOGIC;
		clkin_i			: in STD_LOGIC;
		frequency_sel	: in STD_LOGIC_VECTOR(2 downto 0);
		clk				: inout STD_LOGIC;		-- CHANGED
		usbclk			: out STD_LOGIC; 
		rstnout			: out STD_LOGIC
	);
end clk_generator;

architecture behavioral of clk_generator is


----------------
-- Components --
----------------

----------------------
-- Internal signals --
----------------------

signal clkin_i_buf	: STD_LOGIC;		
signal clk_fbin		: STD_LOGIC;	
signal clk_fbout	: STD_LOGIC;	
signal clkout0		: STD_LOGIC;
signal clkout1		: STD_LOGIC;
signal locked		: STD_LOGIC;
signal dev0_count	: STD_LOGIC_VECTOR(3 downto 0);	
signal sysclk		: STD_LOGIC;
signal count_out	: STD_LOGIC_VECTOR(3 downto 0);	
signal count		: STD_LOGIC_VECTOR(7 downto 0);

begin

u0 : IBUFG
	Port Map(
		i => clkin_i,
		o => clkin_i_buf
	);

-- See https://forums.xilinx.com/t5/Spartan-Family-FPGAs/Spartan6-PLL-BASE-Phase-aligned-Clocks/td-p/169116
-- input  clock : 48.0 MHz
-- output clock0: 48.0 MHz (48 * 10 / 10)  System clock*N
-- output clock1: 24.0 MHz (48 * 10 / 20)  USB clock
-- divide sysclk: 1.5~24.0 MHz (48 / N)    clock0/N
pll_base_inst: PLL_BASE
    generic map (
        BANDWIDTH            => "OPTIMIZED",
        CLK_FEEDBACK         => "CLKFBOUT",
        COMPENSATION         => "SYSTEM_SYNCHRONOUS",
        DIVCLK_DIVIDE        => 1,
        CLKFBOUT_MULT        => 10,		-- 480MHz Input clock(48MHz) * 10
        CLKFBOUT_PHASE       => 0.000,

        CLKOUT0_DIVIDE       => 10,		-- 48MHz System clock * (2~32)
        CLKOUT0_PHASE        => 0.000,
        CLKOUT0_DUTY_CYCLE   => 0.500,

        CLKOUT1_DIVIDE       => 20,		-- 24MHz USB interface clock
        CLKOUT1_PHASE        => 0.000,
        CLKOUT1_DUTY_CYCLE   => 0.500,

        CLKOUT2_DIVIDE       => 10,
        CLKOUT2_PHASE        => 0.000,
        CLKOUT2_DUTY_CYCLE   => 0.500,

        CLKOUT3_DIVIDE       => 10,
        CLKOUT3_PHASE        => 0.000,
        CLKOUT3_DUTY_CYCLE   => 0.500,

        CLKOUT4_DIVIDE       => 32,
        CLKOUT4_PHASE        => 0.000,
        CLKOUT4_DUTY_CYCLE   => 0.500,

        CLKOUT5_DIVIDE       => 32,
        CLKOUT5_PHASE        => 0.000,
        CLKOUT5_DUTY_CYCLE   => 0.500,

        CLKIN_PERIOD	     => 20.833,
        REF_JITTER           => 0.010
    )
    port map (
        CLKFBOUT            => clk_fbout,
        CLKOUT0             => clkout0,
        CLKOUT1             => clkout1,
        CLKOUT2             => open,
        CLKOUT3             => open,
        CLKOUT4             => open,
        CLKOUT5             => open,
        -- Status and control signals
        LOCKED              => locked,
        RST                 => '0',
        -- Input clock control
        CLKFBIN             => clk_fbin,
        CLKIN               => clkin_i_buf
    );

-- Clock divide selecter
clk_divide_selecter: process(frequency_sel)
	begin
		if (frequency_sel(0) = '0') then
			count_out <= x"f";					-- 1.5MHz
		else
			case frequency_sel(2 downto 1) is
				when "00" => count_out <= x"7";	-- 3MHz
				when "01" => count_out <= x"3";	-- 6MHz
				when "10" => count_out <= x"1";	-- 12MHz
				when "11" => count_out <= x"0";	-- 24MHz
			end case;
		end if;
	end process;
	
-- Clock divider
clk_divider: process(clkout0, rstnin_i)
	begin
		if (rising_edge(clkout0)) then
			if (rstnin_i = '0') then
				dev0_count <= (others => '0');
				sysclk <= '0';
			else
				if (dev0_count = count_out) then
					dev0_count <= (others => '0');
				else
					dev0_count <= std_logic_vector(to_unsigned(to_integer(unsigned( dev0_count )) + 1, dev0_count'length));
				end if;
				if (dev0_count = (dev0_count'range => '0')) then
					sysclk <= not sysclk;
				else
					sysclk <= sysclk;
				end if;
			end if;
		else
			null;
		end if;
	end process;

-- Feedback clock buffer
u1 : BUFG
	Port Map(
		i => clk_fbout,
		o => clk_fbin
	);

-- System clock 1.5~24MHz
u2 : BUFH
	Port Map(
		i => sysclk,
		o => clk
	);

-- USB clock 24MHz
u3 : BUFH
	Port Map(
		i => clkout1,
		o => usbclk
	);

-- Delay Reset
delay_reset : process(clk, rstnin_i)
	begin
		if (rising_edge(clk)) then
			if (rstnin_i = '0') then
				count <= (others => '0');
				rstnout <= '0';
			else
				if (locked = '0') then
					count <= (others => '0');
				elsif (and_reduce(count) = '0') then
					count <= std_logic_vector(to_unsigned(to_integer(unsigned( count )) + 1, count'length));
				else
					count <= count;
				end if;
				rstnout <= and_reduce(count);
			end if;
		else
			null;
		end if;					
	end process;

end behavioral;

