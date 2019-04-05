library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.tb_sakura_g_main_constants.all;

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
	begin
		wait for PERIOD;

		rst <= '1';

		wait for 5 * PERIOD;

		rst <= '0';

		wait for PERIOD;


		--See "core.vhd", and the Memory interface part on how this works.
		--In short, by setting the Write Enable (WE) to 1, the program reads from "di"
		--Depending on whether the first bit is set or not in addr, the value gets written to the upper or lower 64 bit of the 
		--corresponding signal (see core.vhd) (first bit 1 is writing to upper half, first bit 0 is writing to lower half). 
		--The data being written to the data input (di) is stored at the corresponding addres in the Dual Port RAM (blk_mem_gen_0 in core)
		--You can open the Block Memory Generator to see how it works, but in short Dual-ported RAM (DPRAM) is a type of random-access memory that 
		--allows multiple reads or writes to occur at the same time, or nearly the same time, unlike single-ported RAM which only allows one access at a time.

		-- zero
		we   <= '1';
		addr <= x"60" & '0';
		di   <= x"0000000000000000";
		wait for PERIOD;

		we   <= '1';
		addr <= x"60" & '1';
		di   <= x"0000000000000000";
		wait for PERIOD;

		-- one
		we   <= '1';
		addr <= x"61" & '0';
		di   <= x"0000000000000001";
		wait for PERIOD;

		we   <= '1';
		addr <= x"61" & '1';
		di   <= x"0000000000000000";
		wait for PERIOD;

		-- d (writing in addresses from LSB to MSB)
		-- Imaginary part (e40000000000000142_16)
		we   <= '1';
		addr <= x"1e" & '0';
		di   <= x"0000000000000142";
		wait for PERIOD;

		we   <= '1';
		addr <= x"1e" & '1';
		di   <= x"00000000000000e4";
		wait for PERIOD;

		-- Real part (5e472f846657e0fcb3821488f1fc0c8d_16)
		we   <= '1';
		addr <= x"1f" & '0';
		di   <= x"b3821488f1fc0c8d";
		wait for PERIOD;

		we   <= '1';
		addr <= x"1f" & '1';
		di   <= x"5e472f846657e0fc";
		wait for PERIOD;

		-- ctau1
		we   <= '1';
		addr <= x"20" & '0';
		di   <= x"74dcd57cebce74c3";
		wait for PERIOD;

		we   <= '1';
		addr <= x"20" & '1';
		di   <= x"1964de2c3afad20c";
		wait for PERIOD;

		we   <= '1';
		addr <= x"21" & '0';
		di   <= x"0000000000000012";
		wait for PERIOD;

		we   <= '1';
		addr <= x"21" & '1';
		di   <= x"000000000000000c";
		wait for PERIOD;

		-- d stands for dual
		-- ctaud1 =  0x4aa740eb230586529ecaa6d9decdf034L 0x7ffffffffffffff40000000000000011L
		we   <= '1';
		addr <= x"22" & '0';
		di   <= x"9ecaa6d9decdf034";
		wait for PERIOD;

		we   <= '1';
		addr <= x"22" & '1';
		di   <= x"4aa740eb23058652";
		wait for PERIOD;

		we   <= '1';
		addr <= x"23" & '0';
		di   <= x"0000000000000011";
		wait for PERIOD;

		we   <= '1';
		addr <= x"23" & '1';
		di   <= x"7ffffffffffffff4";
		wait for PERIOD;

		-- cpsi1 =  0x2af99e9a83d54a02edf07f4767e346efL 0xde000000000000013aL
		we   <= '1';
		addr <= x"24" & '0';
		di   <= x"edf07f4767e346ef";
		wait for PERIOD;

		we   <= '1';
		addr <= x"24" & '1';
		di   <= x"2af99e9a83d54a02";
		wait for PERIOD;

		we   <= '1';
		addr <= x"25" & '0';
		di   <= x"000000000000013a";
		wait for PERIOD;

		we   <= '1';
		addr <= x"25" & '1';
		di   <= x"00000000000000de";
		wait for PERIOD;

		-- cpsi2 =  0xe40000000000000143L 0x21b8d07b99a81f034c7deb770e03f372L
		we   <= '1';
		addr <= x"26" & '0';
		di   <= x"0000000000000143";
		wait for PERIOD;

		we   <= '1';
		addr <= x"26" & '1';
		di   <= x"00000000000000e4";
		wait for PERIOD;

		we   <= '1';
		addr <= x"27" & '0';
		di   <= x"4c7deb770e03f372";
		wait for PERIOD;

		we   <= '1';
		addr <= x"27" & '1';
		di   <= x"21b8d07b99a81f03";
		wait for PERIOD;

		-- cpsi3 =  0x60000000000000009L 0x4cb26f161d7d69063a6e6abe75e73a61L
		we   <= '1';
		addr <= x"28" & '0';
		di   <= x"0000000000000009";
		wait for PERIOD;

		we   <= '1';
		addr <= x"28" & '1';
		di   <= x"0000000000000006";
		wait for PERIOD;

		we   <= '1';
		addr <= x"29" & '0';
		di   <= x"3a6e6abe75e73a61";
		wait for PERIOD;

		we   <= '1';
		addr <= x"29" & '1';
		di   <= x"4cb26f161d7d6906";
		wait for PERIOD;

		-- cpsi4 =  0x7ffffffffffffff9fffffffffffffff6L 0x334d90e9e28296f9c59195418a18c59eL
		we   <= '1';
		addr <= x"2a" & '0';
		di   <= x"fffffffffffffff6";
		wait for PERIOD;

		we   <= '1';
		addr <= x"2a" & '1';
		di   <= x"7ffffffffffffff9";
		wait for PERIOD;

		we   <= '1';
		addr <= x"2b" & '0';
		di   <= x"c59195418a18c59e";
		wait for PERIOD;

		we   <= '1';
		addr <= x"2b" & '1';
		di   <= x"334d90e9e28296f9";
		wait for PERIOD;

		-- Root of d_hat. Instead of storing the original imaginary value, they store the remainder after subtracting 2^127 - 1 from this value (which is ofcourse the same value but requires less storage space)
		-- cphi0 =  0x5fffffffffffffff7L 0x2553a0759182c3294f65536cef66f81aL
		we   <= '1';
		addr <= x"2c" & '0';
		di   <= x"fffffffffffffff7";
		wait for PERIOD;

		we   <= '1';
		addr <= x"2c" & '1';
		di   <= x"0000000000000005";
		wait for PERIOD;

		we   <= '1';
		addr <= x"2d" & '0';
		di   <= x"4f65536cef66f81a";
		wait for PERIOD;

		we   <= '1';
		addr <= x"2d" & '1';
		di   <= x"2553a0759182c329";
		wait for PERIOD;

		-- cphi1 =  0x50000000000000007L 0x62c8caa0c50c62cf334d90e9e28296f9L
		we   <= '1';
		addr <= x"2e" & '0';
		di   <= x"0000000000000007";
		wait for PERIOD;

		we   <= '1';
		addr <= x"2e" & '1';
		di   <= x"0000000000000005";
		wait for PERIOD;

		we   <= '1';
		addr <= x"2f" & '0';
		di   <= x"334d90e9e28296f9";
		wait for PERIOD;

		we   <= '1';
		addr <= x"2f" & '1';
		di   <= x"62c8caa0c50c62cf";
		wait for PERIOD;

		-- cphi2 =  0xf0000000000000015L 0x78df262b6c9b5c982c2cb7154f1df391L
		we   <= '1';
		addr <= x"30" & '0';
		di   <= x"0000000000000015";
		wait for PERIOD;

		we   <= '1';
		addr <= x"30" & '1';
		di   <= x"000000000000000f";
		wait for PERIOD;

		we   <= '1';
		addr <= x"31" & '0';
		di   <= x"2c2cb7154f1df391";
		wait for PERIOD;

		we   <= '1';
		addr <= x"31" & '1';
		di   <= x"78df262b6c9b5c98";
		wait for PERIOD;

		-- cphi3 =  0x20000000000000003L 0x5084c6491d76342a92440457a7962ea4L
		we   <= '1';
		addr <= x"32" & '0';
		di   <= x"0000000000000003";
		wait for PERIOD;

		we   <= '1';
		addr <= x"32" & '1';
		di   <= x"0000000000000002";
		wait for PERIOD;

		we   <= '1';
		addr <= x"33" & '0';
		di   <= x"92440457a7962ea4";
		wait for PERIOD;

		we   <= '1';
		addr <= x"33" & '1';
		di   <= x"5084c6491d76342a";
		wait for PERIOD;

		-- cphi4 =  0x30000000000000003L 0x12440457a7962ea4a1098c923aec6855L
		we   <= '1';
		addr <= x"34" & '0';
		di   <= x"0000000000000003";
		wait for PERIOD;

		we   <= '1';
		addr <= x"34" & '1';
		di   <= x"0000000000000003";
		wait for PERIOD;

		we   <= '1';
		addr <= x"35" & '0';
		di   <= x"a1098c923aec6855";
		wait for PERIOD;

		we   <= '1';
		addr <= x"35" & '1';
		di   <= x"12440457a7962ea4";
		wait for PERIOD;

		-- cphi5 =  0xa000000000000000fL 0x459195418a18c59e669b21d3c5052df3L
		we   <= '1';
		addr <= x"36" & '0';
		di   <= x"000000000000000f";
		wait for PERIOD;

		we   <= '1';
		addr <= x"36" & '1';
		di   <= x"000000000000000a";
		wait for PERIOD;

		we   <= '1';
		addr <= x"37" & '0';
		di   <= x"669b21d3c5052df3";
		wait for PERIOD;

		we   <= '1';
		addr <= x"37" & '1';
		di   <= x"459195418a18c59e";
		wait for PERIOD;

		-- cphi6 =  0x120000000000000018L 0xb232a8314318b3ccd3643a78a0a5be7L
		we   <= '1';
		addr <= x"38" & '0';
		di   <= x"0000000000000018";
		wait for PERIOD;

		we   <= '1';
		addr <= x"38" & '1';
		di   <= x"0000000000000012";
		wait for PERIOD;

		we   <= '1';
		addr <= x"39" & '0';
		di   <= x"cd3643a78a0a5be7";
		wait for PERIOD;

		we   <= '1';
		addr <= x"39" & '1';
		di   <= x"0b232a8314318b3c";
		wait for PERIOD;

		-- cphi7 =  0x180000000000000023L 0x3963bc1c99e2ea1a66c183035f48781aL
		we   <= '1';
		addr <= x"3a" & '0';
		di   <= x"0000000000000023";
		wait for PERIOD;

		we   <= '1';
		addr <= x"3a" & '1';
		di   <= x"0000000000000018";
		wait for PERIOD;

		we   <= '1';
		addr <= x"3b" & '0';
		di   <= x"66c183035f48781a";
		wait for PERIOD;

		we   <= '1';
		addr <= x"3b" & '1';
		di   <= x"3963bc1c99e2ea1a";
		wait for PERIOD;

		-- cphi8 =  0xaa00000000000000f0L 0x1f529f860316cbe544e251582b5d0ef0L
		we   <= '1';
		addr <= x"3c" & '0';
		di   <= x"00000000000000f0";
		wait for PERIOD;

		we   <= '1';
		addr <= x"3c" & '1';
		di   <= x"00000000000000aa";
		wait for PERIOD;

		we   <= '1';
		addr <= x"3d" & '0';
		di   <= x"44e251582b5d0ef0";
		wait for PERIOD;

		we   <= '1';
		addr <= x"3d" & '1';
		di   <= x"1f529f860316cbe5";
		wait for PERIOD;

		-- cphi9 =  0x8700000000000000befL 0xfd52e9cfe00375b014d3e48976e2505L
		we   <= '1';
		addr <= x"3e" & '0';
		di   <= x"0000000000000bef";
		wait for PERIOD;

		we   <= '1';
		addr <= x"3e" & '1';
		di   <= x"0000000000000870";
		wait for PERIOD;

		we   <= '1';
		addr <= x"3f" & '0';
		di   <= x"014d3e48976e2505";
		wait for PERIOD;

		we   <= '1';
		addr <= x"3f" & '1';
		di   <= x"0fd52e9cfe00375b";
		wait for PERIOD;

		if TEST_WITHOUT_CFK = true then
			report "Start of test without CFK " severity note;
			for i in 0 to 9 loop
				report "Start of iteration " & integer'image(i) severity note;
				-- The secret multiscalar 
				-- k0     
				we   <= '1';
				addr <= x"00" & '0';
				di   <= keys(4*i);
				wait for PERIOD;
				-- k1     
				we   <= '1';
				addr <= x"00" & '1';
				di   <= keys(4*i + 1);
				wait for PERIOD;
				-- k2     
				we   <= '1';
				addr <= x"01" & '0';
				di   <= keys(4*i + 2);
				wait for PERIOD;
				-- k3     
				we   <= '1';
				addr <= x"01" & '1';
				di   <= keys(4*i + 3);
				wait for PERIOD;

				-- BASE POINT

				-- x0     
				we   <= '1';
				addr <= x"02" & '0';
				di   <= b_xcoords(4*i);
				wait for PERIOD;

				we   <= '1';
				addr <= x"02" & '1';
				di   <= b_xcoords(4*i + 1);
				wait for PERIOD;

				-- x1     
				we   <= '1';
				addr <= x"03" & '0';
				di   <= b_xcoords(4*i + 2);
				wait for PERIOD;

				we   <= '1';
				addr <= x"03" & '1';
				di   <= b_xcoords(4*i + 3);
				wait for PERIOD;

				-- y0
				we   <= '1';
				addr <= x"04" & '0';
				di   <= b_ycoords(4*i);
				wait for PERIOD;

				we   <= '1';
				addr <= x"04" & '1';
				di   <= b_ycoords(4*i + 1);
				wait for PERIOD;

				-- y1
				we   <= '1';
				addr <= x"05" & '0';
				di   <= b_ycoords(4*i + 2);
				wait for PERIOD;

				we   <= '1';
				addr <= x"05" & '1';
				di   <= b_ycoords(4*i + 3);
				wait for PERIOD;

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
				assert do = r_xcoords(4*i) report "Incorrect x-coord[0,0]!" severity error;
				addr <= x"04" & '1';
				wait for PERIOD;        -- Y0[1]
				assert do = r_xcoords(4*i + 1) report "Incorrect x-coord[0,1]!" severity error;
				addr <= x"05" & '0';
				wait for PERIOD;        -- Y1[0]
				assert do = r_xcoords(4*i + 2) report "Incorrect x-coord[1,0]!" severity error;
				addr <= x"05" & '1';
				wait for PERIOD;        -- Y1[1]
				assert do = r_xcoords(4*i + 3) report "Incorrect x-coord[1,1]!" severity error;
				addr <= x"00" & '0';
				wait for PERIOD;
				assert do = r_ycoords(4*i) report "Incorrect y-coord[0,0]!" severity error;
				wait for PERIOD;
				assert do = r_ycoords(4*i + 1) report "Incorrect y-coord[0,0]!" severity error;
				wait for PERIOD;
				assert do = r_ycoords(4*i + 2) report "Incorrect y-coord[0,0]!" severity error;
				wait for PERIOD;
				assert do = r_ycoords(4*i + 3) report "Incorrect y-coord[0,0]!" severity error;
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
