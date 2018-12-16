library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.constants.all;

entity decompose is
	port(
		clk   : in  std_logic;
		rst   : in  std_logic;
		en    : in  std_logic;
		k     : in  unsigned(255 downto 0);	-- This is the 256 bit scalar?
		scals : out scalar_type;
		done  : out std_logic
	);
end entity;

architecture Behavioral of decompose is
	signal rounds            : unsigned(ROUND_BITS - 1 downto 0);
	signal row_rounds        : unsigned(ROUND_BITS - 1 downto 0);
	signal en_t              : std_logic;
	signal rst_t             : std_logic;
	signal done_m            : std_logic;
	signal done_buf          : std_logic;
	signal done_in           : std_logic;
	-- See Section 3.2
	signal x_t               : unsigned(x_width - 1 downto 0);
	signal x_t_in            : unsigned(x_width - 1 downto 0);
	signal y_t               : unsigned(y_width - 1 downto 0);
	signal zlow_t            : unsigned(WORD_WIDTH - 1 downto 0);
	signal zhigh_t           : unsigned(WORD_WIDTH - 1 downto 0);
	-- a1,a2,a3,a4 is the computed multiscalar
	signal a1                : unsigned(WORD_WIDTH - 1 downto 0);
	signal a2                : unsigned(WORD_WIDTH - 1 downto 0);
	signal a3                : unsigned(WORD_WIDTH - 1 downto 0);
	signal a4                : unsigned(WORD_WIDTH - 1 downto 0);
	signal temp              : unsigned(WORD_WIDTH - 1 downto 0);
	signal aux               : unsigned(WORD_WIDTH - 1 downto 0);
	-- "The scalar decomposition described in Proposition 5 outputs two multiscalars. Our decomposition
	-- routine uses a bitmask to select and output the one with an odd first coordinate in constant time."
	signal mask              : unsigned(WORD_WIDTH - 1 downto 0);
	signal a1_in             : unsigned(WORD_WIDTH - 1 downto 0);
	signal a2_in             : unsigned(WORD_WIDTH - 1 downto 0);
	signal a3_in             : unsigned(WORD_WIDTH - 1 downto 0);
	signal a4_in             : unsigned(WORD_WIDTH - 1 downto 0);
	signal temp_in           : unsigned(WORD_WIDTH - 1 downto 0);
	signal aux_in            : unsigned(WORD_WIDTH - 1 downto 0);
	signal mask_in           : unsigned(WORD_WIDTH - 1 downto 0);
	signal scalars_in        : scalar_type;
	signal scalars           : scalar_type;
	signal k_t               : unsigned(255 downto 0);
	type state_type is (reset, mt1, mt2, mt3, mt4,
	                    temp11, temp21, temp31, temp41, tempc1, scalar0,
	                    temp12, temp32, tempp2, temp42, tempc2, scalar1,
	                    temp33, temp13, tempm2, temp43, tempc3, scalar2,
	                    temp14, temp24, temp34, temp44, tempc4, scalar3,
	                    finish, start);
	signal current_s, next_s : state_type; --current and next state declaration.
begin
	scals <= scalars;
	done  <= done_buf;
	MULT : entity work.MUL_TRUNCATE(Behavioral) -- This is the truncated multiplication instance 'done_m' indicates whether the multiplication is done
	-- I tend to forget how port maps works, so here I explain it again
	-- You first specify the port signal of the subcomponent, and then to which signal it should be mapped in the current component
		port map(
			clk => clk, 
			rst => rst_t, 
			en => en_t, 
			rounds => rounds, 
			row_rounds => row_rounds, 
			x => x_t, 
			y => y_t, 
			z_high => zhigh_t,
			z_low => zlow_t, 
			done => done_m
		);
		-- "zhigh_t" and "zlow_t" are the two outputs from the multiplier

	process(clk, rst)
	begin
		if (rst = '1') then
			current_s <= reset;         --default state on reset.
			done_buf  <= '0';
			k_t       <= (others => '0');
			x_t       <= (others => '0');
			a1        <= (others => '0');
			a2        <= (others => '0');
			a3        <= (others => '0');
			a4        <= (others => '0');
			temp      <= (others => '0');
			aux       <= (others => '0');
			mask      <= (others => '0');
			for j in RES_WORDS - 1 downto 0 loop
				scalars(j) <= (others => '0');
			end loop;
		elsif (rising_edge(clk)) then
			done_buf  <= done_in;
			k_t       <= k;
			x_t       <= x_t_in;
			a1        <= a1_in;
			a2        <= a2_in;
			a3        <= a3_in;
			a4        <= a4_in;
			temp      <= temp_in;
			aux       <= aux_in;
			mask      <= mask_in;
			scalars   <= scalars_in;
			current_s <= next_s;        --state change.
		end if;
	end process;

	process(current_s, done_m, a1, a2, a3, a4, aux, temp, mask, scalars, k, zhigh_t, zlow_t, temp_in, x_t, done_buf, en, k_t)
	begin
		done_in    <= done_buf;
		x_t_in     <= x_t;
		temp_in    <= temp;
		mask_in    <= mask;
		a1_in      <= a1;
		a2_in      <= a2;
		a3_in      <= a3;
		a4_in      <= a4;
		aux_in     <= aux;
		scalars_in <= scalars;
		rounds     <= (others => '0');
		row_rounds <= (others => '0');
		y_t        <= (others => '0');
		case current_s is
			when reset =>
				rst_t   <= '1';
				en_t    <= '0';
				done_in <= '0';
				temp_in <= temp;
				mask_in <= mask;
				x_t_in  <= (others => '0');
				a1_in   <= a1;
				a2_in   <= a2;
				a3_in   <= a2;
				a4_in   <= a4;
				aux_in  <= aux;
				for j in RES_WORDS - 1 downto 0 loop
					scalars_in(j) <= (others => '0');
				end loop;
				if (en = '1') then
					next_s <= start;
				else
					next_s <= reset;
				end if;
			when start =>
				for j in RES_WORDS - 1 downto 0 loop
					scalars_in(j) <= (others => '0');
				end loop;
				done_in <= '0';
				rst_t   <= '1';
				en_t    <= '0';
				temp_in <= temp;
				mask_in <= mask;
				x_t_in  <= (others => '0');
				a1_in   <= a1;
				a2_in   <= a2;
				a3_in   <= a2;
				a4_in   <= a4;
				aux_in  <= aux;
				if (en = '1') then
					next_s <= mt1;
				else
					next_s <= start;
				end if;
			when mt1 =>		-- Multiplication 1 (calculate a1)
				rst_t      <= '0';
				en_t       <= '1';
				rounds     <= to_unsigned(ROUNDS_ELL, rounds'length);			-- https://www.csee.umbc.edu/portal/help/VHDL/attribute.html
				row_rounds <= to_unsigned(ROW_ROUNDS_256, rounds'length);
				x_t_in     <= resize(k_t, x_t_in'length);
				y_t        <= resize(ell1, y_t'length);
				a1_in      <= zhigh_t;
				if (done_m = '1') then	-- If the multiplication is done, signal "a1" will have the corret result and will not be changed later on (same for other a_i 's)
					next_s <= mt2;
				else
					next_s <= mt1;
				end if;
			when mt2 =>		-- Multiplication 2 (calculate a2)
				rst_t      <= '0';
				en_t       <= '1';
				rounds     <= to_unsigned(ROUNDS_ELL, rounds'length);
				row_rounds <= to_unsigned(ROW_ROUNDS_256, rounds'length);
				x_t_in     <= resize(k, x_t'length);
				y_t        <= resize(ell2, y_t'length);
				a2_in      <= zhigh_t;
				if (done_m = '1') then
					next_s <= mt3;
				else
					next_s <= mt2;
				end if;
			when mt3 =>		-- Multiplication 3 (calculate a3)
				rst_t      <= '0';
				en_t       <= '1';
				rounds     <= to_unsigned(ROUNDS_ELL, rounds'length);
				row_rounds <= to_unsigned(ROW_ROUNDS_256, rounds'length);
				x_t_in     <= resize(k, x_t'length);
				y_t        <= resize(ell3, y_t'length);
				a3_in      <= zhigh_t;
				if (done_m = '1') then
					next_s <= mt4;
				else
					next_s <= mt3;
				end if;
			when mt4 =>		-- Multiplication 4 (calculate a4)
				rst_t      <= '0';
				en_t       <= '1';
				rounds     <= to_unsigned(ROUNDS_ELL, rounds'length);
				row_rounds <= to_unsigned(ROW_ROUNDS_256, rounds'length);
				x_t_in     <= resize(k, x_t'length);
				y_t        <= resize(ell4, y_t'length);
				a4_in      <= zhigh_t;
				if (done_m = '1') then
					next_s <= temp11;
				else
					next_s <= mt4;
				end if;
				-- In the following "tempxy" states (with x, y \in {1,2,3,4}), we calculate the "vector multiplition" (See Proposition 5)
				-- Calculate (a_1, a_2, a_3, a_4_ = (m, 0, 0, 0) - \sum_{i=1}^{4}[\alpha_i] \cdot b_i (See Section 4.1)
			when temp11 =>	-- a1 * b1[1]
				rst_t      <= '0';
				en_t       <= '1';
				rounds     <= to_unsigned(ROUNDS_64, rounds'length);
				row_rounds <= to_unsigned(ROW_ROUNDS_64, rounds'length);
				x_t_in     <= resize(a1, x_t'length);
				y_t        <= resize(b11, y_t'length);
				temp_in    <= k(WORD_WIDTH - 1 downto 0) - zlow_t;
				if (done_m = '1') then
					next_s <= temp21;
				else
					next_s <= temp11;
				end if;
			when temp21 => -- a2 * b2[1]
				rst_t      <= '0';
				en_t       <= '1';
				rounds     <= to_unsigned(ROUNDS_64, rounds'length);
				row_rounds <= to_unsigned(ROW_ROUNDS_64, rounds'length);
				x_t_in     <= resize(a2, x_t'length);
				y_t        <= resize(b21, y_t'length);
				aux_in     <= temp - zlow_t;	-- In previous state, a1 * b1[1] was calculated, which is stored in "temp"
				if (done_m = '1') then
					next_s <= temp31;
				else
					next_s <= temp21;
				end if;
			when temp31 => -- a3 * b3[1]
				rst_t      <= '0';
				en_t       <= '1';
				rounds     <= to_unsigned(ROUNDS_64, rounds'length);
				row_rounds <= to_unsigned(ROW_ROUNDS_64, rounds'length);
				x_t_in     <= resize(a3, x_t'length);
				y_t        <= resize(b31, y_t'length);
				temp_in    <= aux - zlow_t;	-- Not sure why they iterate between the "temp_in" and "aux" signals
				if (done_m = '1') then
					next_s <= temp41;
				else
					next_s <= temp31;
				end if;
			when temp41 => -- a4 * b4[1]
				rst_t      <= '0';
				en_t       <= '1';
				rounds     <= to_unsigned(ROUNDS_64, rounds'length);
				row_rounds <= to_unsigned(ROW_ROUNDS_64, rounds'length);
				x_t_in     <= resize(a4, x_t'length);
				y_t        <= resize(b41, y_t'length);
				aux_in     <= temp - zlow_t;
				if (done_m = '1') then
					next_s <= tempc1;
				else
					next_s <= temp41;
				end if;
			when tempc1 =>
				rst_t   <= '0';
				en_t    <= '0';
				temp_in <= aux + c1;  	-- Both of the multiscalars $(a_1, a_2, a_3, a_4) + c $ and $(a_1, a_2, a_3, a_4) + c'$ are valid decompositions of m. So here we add the first element in the vector of c
				if (temp_in(0) = '0') then
					mask_in <= (others => '1');
				else
					mask_in <= (others => '0');
				end if;
				next_s  <= scalar0;
			when scalar0 =>				-- "Our decomposition routine uses a bitmask to select and output the one with an odd first coordinate in constant time."
				rst_t         <= '0';
				en_t          <= '0';
				scalars_in(0) <= resize(temp + (mask and b41), WORD_WIDTH);
				next_s        <= temp12;
			when temp12 =>	-- a1 * b1[2]
				rst_t      <= '0';
				en_t       <= '1';
				rounds     <= to_unsigned(ROUNDS_64, rounds'length);
				row_rounds <= to_unsigned(ROW_ROUNDS_64, rounds'length);
				x_t_in     <= resize(a1, x_t'length);
				y_t        <= resize(b12, y_t'length);
				temp_in    <= zlow_t;
				if (done_m = '1') then
					next_s <= tempp2;
				else
					next_s <= temp12;
				end if;
			when tempp2 =>	-- a2 * b2[2], but b2[2] = -1. Note that we calculate (a_1, a_2, a_3, a_4_ = (m, 0, 0, 0) - \sum_{i=1}^{4}[\alpha_i] \cdot b_i, so we have to add instead of substract!
				rst_t  <= '0';
				en_t   <= '0';
				aux_in <= temp + a2;
				next_s <= temp32;
			when temp32 => -- a3 * b3[2]
				rst_t      <= '0';
				en_t       <= '1';
				rounds     <= to_unsigned(ROUNDS_64, rounds'length);
				row_rounds <= to_unsigned(ROW_ROUNDS_64, rounds'length);
				x_t_in     <= resize(a3, x_t'length);
				y_t        <= resize(b32, y_t'length);
				temp_in    <= aux - zlow_t;
				if (done_m = '1') then
					next_s <= temp42;
				else
					next_s <= temp32;
				end if;
			when temp42 => -- a4 * b4[2]
				rst_t      <= '0';
				en_t       <= '1';
				rounds     <= to_unsigned(ROUNDS_64, rounds'length);
				row_rounds <= to_unsigned(ROW_ROUNDS_64, rounds'length);
				x_t_in     <= resize(a4, x_t'length);
				y_t        <= resize(b42, y_t'length);
				aux_in     <= temp - zlow_t;
				if (done_m = '1') then
					next_s <= tempc2;
				else
					next_s <= temp42;
				end if;
			when tempc2 => -- Add the "c" component such that the decomposition becomes valid
				rst_t   <= '0';
				en_t    <= '0';
				temp_in <= aux + c2;
				next_s  <= scalar1;
			when scalar1 =>
				rst_t         <= '0';
				en_t          <= '0';
				scalars_in(1) <= resize(temp + (mask and b42), WORD_WIDTH);
				next_s        <= temp33;
			when temp33 =>	-- a3 * b3[3]	(weird that they do not follow the order they did previously, but hey its a proof of concept..)
				rst_t      <= '0';
				en_t       <= '1';
				rounds     <= to_unsigned(ROUNDS_64, rounds'length);
				row_rounds <= to_unsigned(ROW_ROUNDS_64, rounds'length);
				x_t_in     <= resize(a3, x_t'length);
				y_t        <= resize(b33, y_t'length);
				temp_in    <= zlow_t;
				if (done_m = '1') then
					next_s <= temp13;
				else
					next_s <= temp33;
				end if;
			when temp13 =>	-- a1 * b1[3]
				rst_t      <= '0';
				en_t       <= '1';
				rounds     <= to_unsigned(ROUNDS_64, rounds'length);
				row_rounds <= to_unsigned(ROW_ROUNDS_64, rounds'length);
				x_t_in     <= resize(a1, x_t'length);
				y_t        <= resize(b13, y_t'length);
				aux_in     <= temp - zlow_t;
				if (done_m = '1') then
					next_s <= tempm2;
				else
					next_s <= temp13;
				end if;
			when tempm2 =>	-- a2 * b2[3] (again trivial because b2[3] = 1)
				rst_t   <= '0';
				en_t    <= '1';
				temp_in <= aux - a2;
				next_s  <= temp43;
			when temp43 =>	-- a4 * b4[3]
				rst_t      <= '0';
				en_t       <= '1';
				rounds     <= to_unsigned(ROUNDS_64, rounds'length);
				row_rounds <= to_unsigned(ROW_ROUNDS_64, rounds'length);
				x_t_in     <= resize(a4, x_t'length);
				y_t        <= resize(b43, y_t'length);
				aux_in     <= temp + zlow_t;
				if (done_m = '1') then
					next_s <= tempc3;
				else
					next_s <= temp43;
				end if;
			when tempc3 => -- Add "c" component to make decomposition valid
				rst_t   <= '0';
				en_t    <= '0';
				temp_in <= aux + c3;
				next_s  <= scalar2;
			when scalar2 =>
				rst_t         <= '0';
				en_t          <= '0';
				scalars_in(2) <= resize(temp - (mask and b43), WORD_WIDTH);
				next_s        <= temp14;
			when temp14 =>	-- a1 * b1[4]
				rst_t      <= '0';
				en_t       <= '1';
				rounds     <= to_unsigned(ROUNDS_64, rounds'length);
				row_rounds <= to_unsigned(ROW_ROUNDS_64, rounds'length);
				x_t_in     <= resize(a1, x_t'length);
				y_t        <= resize(b14, y_t'length);
				temp_in    <= zlow_t;
				if (done_m = '1') then
					next_s <= temp24;
				else
					next_s <= temp14;
				end if;
			when temp24 =>	-- a2 * b2[4]
				rst_t      <= '0';
				en_t       <= '1';
				rounds     <= to_unsigned(ROUNDS_64, rounds'length);
				row_rounds <= to_unsigned(ROW_ROUNDS_64, rounds'length);
				x_t_in     <= resize(a2, x_t'length);
				y_t        <= resize(b24, y_t'length);
				aux_in     <= temp - zlow_t;
				if (done_m = '1') then
					next_s <= temp34;
				else
					next_s <= temp24;
				end if;
			when temp34 =>	-- a3 * b3[4]
				rst_t      <= '0';
				en_t       <= '1';
				rounds     <= to_unsigned(ROUNDS_64, rounds'length);
				row_rounds <= to_unsigned(ROW_ROUNDS_64, rounds'length);
				x_t_in     <= resize(a3, x_t'length);
				y_t        <= resize(b34, y_t'length);
				temp_in    <= aux - zlow_t;
				if (done_m = '1') then
					next_s <= temp44;
				else
					next_s <= temp34;
				end if;
			when temp44 =>	-- a4 * b4[4]
				rst_t      <= '0';
				en_t       <= '1';
				rounds     <= to_unsigned(ROUNDS_64, rounds'length);
				row_rounds <= to_unsigned(ROW_ROUNDS_64, rounds'length);
				x_t_in     <= resize(a4, x_t'length);
				y_t        <= resize(b44, y_t'length);
				aux_in     <= temp + zlow_t;
				if (done_m = '1') then
					next_s <= tempc4;
				else
					next_s <= temp44;
				end if;
			when tempc4 =>	-- Add "c" component
				rst_t   <= '0';
				en_t    <= '0';
				temp_in <= aux + c4;
				next_s  <= scalar3;
			when scalar3 =>
				rst_t         <= '0';
				en_t          <= '0';
				scalars_in(3) <= resize(temp - (mask and b44), WORD_WIDTH);
				next_s        <= finish;
				done_in       <= '1';
			when finish =>
				rst_t <= '0';
				en_t  <= '0';
				if (en = '1') then
					next_s <= start;
				else
					next_s <= finish;
				end if;
		end case;
	end process;

end Behavioral;
