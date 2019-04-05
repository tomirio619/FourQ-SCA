library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use WORK.tb_sakura_g_main_constants.all;

entity singlecore_tb is
end singlecore_tb;

architecture Behavioral of singlecore_tb is

	constant PERIOD : time := 83.334 ns; -- 5250 ps;

	constant TEST_WITHOUT_CFK : boolean := true;
	constant TEST_WITH_CFK    : boolean := false;

	component singlecore is
		port(
			clk  : in  std_logic;
			rst  : in  std_logic;
			oper : in  std_logic_vector(7 downto 0);
			we   : in  std_logic;       -- Write Enable
			addr : in  std_logic_vector(8 downto 0);
			di   : in  std_logic_vector(63 downto 0);
			busy : out std_logic;
			do   : out std_logic_vector(63 downto 0)
		);
	end component singlecore;

	signal clk  : std_logic                     := '0';
	signal rst  : std_logic                     := '0';
	signal oper : std_logic_vector(7 downto 0)  := (others => '0');
	signal we   : std_logic                     := '0';
	signal addr : std_logic_vector(8 downto 0)  := (others => '0');
	signal di   : std_logic_vector(63 downto 0) := (others => '0');
	signal busy : std_logic;
	signal do   : std_logic_vector(63 downto 0);

	signal cur_addr, next_addr : STD_LOGIC_VECTOR(7 downto 0);
	signal table_value : STD_LOGIC_VECTOR(63 downto 0);
	signal interesting_stuff : std_logic;

	type debug_state is (INIT, INIT_RAM, WRITE_TABLE_VALUES, READ_RESULTS);
	type iter_state is (NONE, ITER0, ITER1, ITER2, ITER3, ITER4, ITER5, ITER6, ITER7, ITER8);
	signal cur_debug_state : debug_state;
	signal cur_iter_state : iter_state;

begin

	-- 200 MHz clock
	oscillator : process
	begin
		clk <= '0';
		wait for PERIOD/2;
		clk <= '1';
		wait for PERIOD/2;
	end process oscillator;

	uut : singlecore
		port map(clk, rst, oper, we, addr, di, busy, do);

	-- Testbench
	tb : process
	variable ctr : integer := 0;
    variable table : values(0 to 39);
	begin
		cur_debug_state <= INIT;
        cur_iter_state <= NONE;

		wait for PERIOD;

		rst <= '1';

		wait for 5 * PERIOD;

		rst <= '0';

		wait for PERIOD;



	    -- Init RAM constants (OK)
	  	cur_debug_state <= INIT_RAM;
        for i in 0 to 35 loop
            -- Lower part
			we <= '1';
            addr <= fourq_ram_constants_addresses(i) & '0';
            di <= fourq_ram_constants_values_lower_64(i);
            wait for 5*PERIOD;
   	       -- Upper part
            we <= '1';
            addr <= fourq_ram_constants_addresses(i) & '1';
            di <= fourq_ram_constants_values_upper_64(i);
            wait for 5*PERIOD;
 	    end loop;

		if TEST_WITHOUT_CFK = true then
			report "Start of test without CFK " severity note;
			for i in 0 to 9 loop
				report "Start of iteration " & integer'image(i) severity note;
				case i is
					when 0 => cur_iter_state <= ITER0;
					when 1 => cur_iter_state <= ITER1;
					when 2 => cur_iter_state <= ITER2;
					when 3 => cur_iter_state <= ITER3;
					when 4 => cur_iter_state <= ITER4;
					when 5 => cur_iter_state <= ITER5;
					when 6 => cur_iter_state <= ITER6;
					when 7 => cur_iter_state <= ITER7;
					when 8 => cur_iter_state <= ITER8;
            	end case;
            	cur_debug_state <= WRITE_TABLE_VALUES;
				ctr := 0;
				while (ctr <= 4) loop
					-- Loop through scalar_and_base_point_addresses array
					case ctr is
						when 0 => table := keys;
						when 2 => table := b_xcoords;
						when 4 => table := b_ycoords;
						when others => null;
					end case;
					cur_addr <= scalar_and_base_point_addresses(ctr);
					next_addr <= scalar_and_base_point_addresses(ctr + 1);
					wait for PERIOD;
					di <= table(4*i);
					addr <= cur_addr & '0';
					we <= '1';
					wait for PERIOD;
					di <= table(4*i + 1);
					addr <= cur_addr & '1';
					we <= '1';
					wait for PERIOD;
					di <= table(4*i + 2);
					addr <= next_addr & '0';
					we <= '1';
					wait for PERIOD;
					di <= table(4*i + 3);
					addr <= next_addr & '1';
					we <= '1';
					wait for PERIOD;
					ctr := ctr + 2;
            	end loop;

				we   <= '0';
				addr <= x"00" & '0';
				di   <= x"0000000000000000";

				wait for 5*PERIOD;

				oper <= x"01";
				wait for PERIOD;
				oper <= x"00";
				wait for PERIOD;

				while busy = '1' loop
					wait for PERIOD;
				end loop;

				oper <= x"02";
				wait for PERIOD;
				oper <= x"00";
				wait for PERIOD;

				while busy = '1' loop
					wait for PERIOD;
				end loop;

				-- There seems to be a problem here, cuz these waiting periods cannot be replaced by PERIOD*4
				-- Read the result point
				-- Test cases:
				-- First wait -> PERIOD*3				OK
				-- First and second wait -> PERIOD*3	NOT OK
				-- Test after how many cycles this output of the given address comes available 
				-- TRUE dual port ram Registered 
				-- https://alteraforum.com/forum/showthread.php?t=54120

				cur_debug_state <= READ_RESULTS;


				wait for PERIOD;

				addr <= x"02" & '0';
				wait for PERIOD;        -- X0[0]
				addr <= x"02" & '1';
				wait for PERIOD;        -- X0[1]
				addr <= x"03" & '0';
				wait for PERIOD;        -- X1[0]
				addr <= x"03" & '1';
				wait for PERIOD;        -- X1[1]

				addr <= x"04" & '0';
				table_value <= r_xcoords(4*i);
				wait for PERIOD;        -- Y0[0]
				if do /= table_value then
					report "Incorrect x-coord[0,0]!" severity error;
				end if;
				
				addr <= x"04" & '1';
				table_value <= r_xcoords(4*i + 1);
				wait for PERIOD;        -- Y0[1]
				if do /= table_value then
					report "Incorrect x-coord[0,1]!" severity error;
				end if;
				
				addr <= x"05" & '0';
				table_value <= r_xcoords(4*i + 2);
				wait for PERIOD;        -- Y1[0]
				if do /= table_value then
					report "Incorrect x-coord[1,0]!" severity error;
				end if;

				addr <= x"05" & '1';
				table_value <= r_xcoords(4*i + 3);
				wait for PERIOD;        -- Y1[1]
				if do /= table_value then
					report "Incorrect x-coord[1,1]!" severity error;
				end if;
				


				addr <= x"00" & '0';
				table_value <= r_ycoords(4*i);
				wait for PERIOD;
				if do /= table_value then
					report "Incorrect y-coord[0,0]!" severity error;
				end if;
				
				table_value <= r_ycoords(4*i + 1);
				wait for PERIOD;        
				if do /= table_value then
					report "Incorrect y-coord[0,1]!" severity error;
				end if;
				
				table_value <= r_ycoords(4*i + 2);
				wait for PERIOD;     
				if do /= table_value then
					report "Incorrect y-coord[1,0]!" severity error;
				end if;

				table_value <= r_ycoords(4*i + 3);
				wait for PERIOD;       
				if do /= table_value then
					report "Incorrect y-coord[1,1]!" severity error;
				end if;
				wait for PERIOD;

				report "End of iteration " & integer'image(i) severity note;
				wait for 10*PERIOD;
			end loop;
			report "End of test without CFK" severity note;
		end if;

		if TEST_WITH_CFK = true then
			report "Start of test with CFK " severity note;
			for i in 0 to 9 loop
				report "Start of iteration " & integer'image(i) severity note;
				-- k0     
				we   <= '1';
				addr <= x"00" & '0';
				di   <= keys_cf(4*i);
				wait for PERIOD;
				-- k1     
				we   <= '1';
				addr <= x"00" & '1';
				di   <= keys_cf(4*i + 1);
				wait for PERIOD;
				-- k2     
				we   <= '1';
				addr <= x"01" & '0';
				di   <= keys_cf(4*i + 2);
				wait for PERIOD;
				-- k3     
				we   <= '1';
				addr <= x"01" & '1';
				di   <= keys_cf(4*i + 3);
				wait for PERIOD;

				-- BASE POINT

				-- x0     
				we   <= '1';
				addr <= x"02" & '0';
				di   <= b_xcoords_cf(4*i);
				wait for PERIOD;

				we   <= '1';
				addr <= x"02" & '1';
				di   <= b_xcoords_cf(4*i + 1);
				wait for PERIOD;

				-- x1     
				we   <= '1';
				addr <= x"03" & '0';
				di   <= b_xcoords_cf(4*i + 2);
				wait for PERIOD;

				we   <= '1';
				addr <= x"03" & '1';
				di   <= b_xcoords_cf(4*i + 3);
				wait for PERIOD;

				-- y0
				we   <= '1';
				addr <= x"04" & '0';
				di   <= b_ycoords_cf(4*i);
				wait for PERIOD;

				we   <= '1';
				addr <= x"04" & '1';
				di   <= b_ycoords_cf(4*i + 1);
				wait for PERIOD;

				-- y1
				we   <= '1';
				addr <= x"05" & '0';
				di   <= b_ycoords_cf(4*i + 2);
				wait for PERIOD;

				we   <= '1';
				addr <= x"05" & '1';
				di   <= b_ycoords_cf(4*i + 3);
				wait for PERIOD;

				-- TODO This statement below might be the evil one, hower I don't think so
				we   <= '0';
				addr <= x"00" & '0';
				di   <= x"0000000000000000";

				wait for 5*PERIOD;

				-- Initialize
				oper <= x"01";
				wait for PERIOD;
				oper <= x"00";
				wait for PERIOD;

				while busy = '1' loop
					wait for PERIOD;
				end loop;

				-- Cofactor killing
				oper <= x"06";
				wait for PERIOD;
				oper <= x"00";
				wait for PERIOD;

				while busy = '1' loop
					wait for PERIOD;
				end loop;

				-- Precomputation + Scalar multiplication + Affine
				oper <= x"02";
				wait for PERIOD;
				oper <= x"00";
				wait for PERIOD;

				while busy = '1' loop
					wait for PERIOD;
				end loop;

				-- Read the result point
				addr <= x"02" & '0';
				wait for PERIOD;        -- X0[0]
				addr <= x"02" & '1';
				wait for PERIOD;        -- X0[1]
				addr <= x"03" & '0';
				wait for PERIOD;        -- X1[0]
				addr <= x"03" & '1';
				wait for PERIOD;        -- X1[1]
				addr <= x"04" & '0';
				wait for PERIOD;        -- Y0[0]
				assert do = r_xcoords_cf(4*i) report "Incorrect x-coord[0,0]!" severity error;
				addr <= x"04" & '1';
				wait for PERIOD;        -- Y0[1]
				assert do = r_xcoords_cf(4*i + 1) report "Incorrect x-coord[0,1]!" severity error;
				addr <= x"05" & '0';
				wait for PERIOD;        -- Y1[0]
				assert do = r_xcoords_cf(4*i + 2) report "Incorrect x-coord[1,0]!" severity error;
				addr <= x"05" & '1';
				wait for PERIOD;        -- Y1[1]
				assert do = r_xcoords_cf(4*i + 3) report "Incorrect x-coord[1,1]!" severity error;
				addr <= x"00" & '0';
				wait for PERIOD;
				assert do = r_ycoords_cf(4*i) report "Incorrect y-coord[0,0]!" severity error;
				wait for PERIOD;
				assert do = r_ycoords_cf(4*i + 1) report "Incorrect y-coord[0,1]!" severity error;
				wait for PERIOD;
				assert do = r_ycoords_cf(4*i + 2) report "Incorrect y-coord[1,0]!" severity error;
				wait for PERIOD;
				assert do = r_ycoords_cf(4*i + 3) report "Incorrect y-coord[1,1]!" severity error;
				wait for PERIOD;

				wait for 10*PERIOD;
				report "End of iteration " & integer'image(i) severity note;
				
			end loop;
			report "End of test with CFK " severity note;
		end if;

		assert false report "Simulation finished." severity note;

		wait;

	end process tb;

end Behavioral;
