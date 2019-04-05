library ieee;
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

package constants is

	-- Number of triggers
	constant NR_OF_TRIGGERS		: integer := 2;

	-- Whether we should print the values during each iteration to easily determine the offests
	constant DETERMINE_OFFSETS : boolean := false;

	-- When applying the Online Template Attack, we feed the decomposed scalar as the secret scalar instaed of the secret scalar itself
	constant SCALAR_IS_DECOMPOSED : boolean := true; 

	constant MAD_X_WIDTH        : integer := 24;
	constant MAD_Y_WIDTH        : integer := 17;
	constant MAD_RES_WIDTH      : integer := MAD_X_WIDTH + MAD_Y_WIDTH + 1;
	constant MAD_Z_WIDTH        : integer := MAD_Y_WIDTH + 1;
	constant NMADDS             : integer := 11;
	constant NMADDS_Y           : integer := 16;
	constant X_WIDTH            : integer := MAD_X_WIDTH*NMADDS;
	constant Y_WIDTH            : integer := MAD_Y_WIDTH*NMADDS_Y;
	constant ROW_MUL_WORD_WIDTH : integer := X_WIDTH + MAD_Y_WIDTH;

	constant RECODE_ROUND_BITS : integer := 6;
	constant ROUND_BITS        : integer := 5;
	constant WORD_WIDTH        : integer := 64;
	constant RES_MSB           : integer := 256;
	constant RES_WORDS         : integer := 4; --WORD_WIDTH/MAD_Y_WIDTH+1;

	constant ROUNDS_ELL     : integer := 12; --!!! USE THE FACT THE ell constants are smaller than 256 bits
	constant ROW_ROUNDS_256 : integer := NMADDS;
	constant ROUNDS_64      : integer := 4;
	constant ROW_ROUNDS_64  : integer := 3;
	-- Careful!! Again use the fact ell constants are small to save some cycles...
	constant MUL_TRUNC_LSB  : integer := 69;
	--

	type digit_array is array (0 to WORD_WIDTH) of unsigned(2 downto 0);
	type sign_array is array (0 to WORD_WIDTH) of unsigned(0 downto 0);
	type signdigit_array is array (0 to WORD_WIDTH) of unsigned(3 downto 0);
	type scalar_type is array (0 to RES_WORDS - 1) of unsigned(WORD_WIDTH - 1 downto 0);
	type sdarray_array is array (0 to 9) of signdigit_array;
	--Constants for decomposition
	-- The four curve constants $\ell_i := \floor{\hat{\alpha} \cdot \mu / N}# for i \in \{1,2,3,4\}
	constant ell1 : unsigned(255 downto 0)            := X"0000000000000007FC5BB5C5EA2BE5DFF75682ACE6A6BD66259686E09D1A7D4F";
	constant ell2 : unsigned(255 downto 0)            := X"00000000000000038FD4B04CAA6C0F8A2BD235580F468D8DD1BA1D84DD627AFB";
	constant ell3 : unsigned(255 downto 0)            := X"0000000000000000D038BF8D0BFFBAF6C42BD6C965DCA9029B291A33678C203C";
	constant ell4 : unsigned(255 downto 0)            := X"00000000000000031B073877A22D841081CBDC3714983D8212E5666B77E7FDC0";
	-- See Proposition 5, this is probably the vector $c = 5b_2 - 3b_3 + 2b_4$ (probably no need to store c', as it only requires you to add b4 to this vector)
	constant c1   : unsigned(WORD_WIDTH - 1 downto 0) := X"72482C5251A4559C";
	constant c2   : unsigned(WORD_WIDTH - 1 downto 0) := X"59F95B0ADD276F6C";
	constant c3   : unsigned(WORD_WIDTH - 1 downto 0) := X"7DD2D17C4625FA78";
	constant c4   : unsigned(WORD_WIDTH - 1 downto 0) := X"6BC57DEF56CE8877";
	-- Babai optimal Basis (per column), values b22 and b23 are missing because they have trivial values: -8 and 8 respectively (assuming a scalar of 8 as in the original paper)
	constant b11  : unsigned(WORD_WIDTH - 1 downto 0) := X"0906FF27E0A0A196";
	constant b21  : unsigned(WORD_WIDTH - 1 downto 0) := X"1D495BEA84FCC2D4";
	constant b31  : unsigned(WORD_WIDTH - 1 downto 0) := X"17ABAD1D231F0302";
	constant b41  : unsigned(WORD_WIDTH - 1 downto 0) := X"136E340A9108C83F";
	constant b12  : unsigned(WORD_WIDTH - 1 downto 0) := X"1363E862C22A2DA0";
	constant b32  : unsigned(WORD_WIDTH - 1 downto 0) := X"02C4211AE388DA51";
	constant b42  : unsigned(WORD_WIDTH - 1 downto 0) := X"3122DF2DC3E0FF32";
	constant b13  : unsigned(WORD_WIDTH - 1 downto 0) := X"07426031ECC8030F";
	constant b33  : unsigned(WORD_WIDTH - 1 downto 0) := X"2E4D21C98927C49F";
	constant b43  : unsigned(WORD_WIDTH - 1 downto 0) := X"068A49F02AA8A9B5";
	constant b14  : unsigned(WORD_WIDTH - 1 downto 0) := X"084F739986B9E651";
	constant b24  : unsigned(WORD_WIDTH - 1 downto 0) := X"25DBC5BC8DD167D0";
	constant b34  : unsigned(WORD_WIDTH - 1 downto 0) := X"0A9E6F44C02ECD97";
	constant b44  : unsigned(WORD_WIDTH - 1 downto 0) := X"18D5087896DE0AEA";

	constant xx        : unsigned(WORD_WIDTH - 1 downto 0) := X"259686E09D1A7D4E";
	constant yy        : unsigned(WORD_WIDTH - 1 downto 0) := X"1363E862C22A2DA0";
	constant sd_test_0 : signdigit_array                   := (
		X"1", X"4", X"f", X"4", X"f", X"5", X"4", X"3", X"0", X"d", X"f", X"9", X"8", X"4", X"2", X"1", X"8", X"d", X"9", X"3", X"2", X"9", X"2", X"3", X"3", X"c", X"4", X"a", X"e", X"4", X"9", X"d", X"f", X"d", X"2", X"a", X"f", X"c", X"6", X"f", X"9", X"1", X"c", X"f", X"2", X"2", X"1", X"8", X"d", X"e", X"7", X"5", X"1", X"9", X"7", X"3", X"f", X"3", X"5", X"9", X"2", X"f", X"1", X"f", X"7"
	);
	constant sd_test_1 : signdigit_array                   := (
		X"f", X"7", X"0", X"8", X"d", X"5", X"9", X"b", X"c", X"3", X"d", X"1", X"8", X"f", X"c", X"0", X"8", X"4", X"4", X"9", X"4", X"6", X"8", X"3", X"7", X"7", X"9", X"3", X"8", X"1", X"7", X"1", X"c", X"9", X"9", X"8", X"a", X"8", X"9", X"b", X"a", X"a", X"c", X"d", X"7", X"7", X"e", X"1", X"8", X"a", X"e", X"8", X"d", X"5", X"e", X"5", X"5", X"c", X"9", X"e", X"4", X"b", X"0", X"f", X"7"
	);
	constant sd_test_2 : signdigit_array                   := (
		X"3", X"9", X"6", X"9", X"9", X"7", X"7", X"5", X"c", X"e", X"0", X"3", X"f", X"c", X"7", X"a", X"7", X"7", X"c", X"3", X"8", X"1", X"e", X"7", X"2", X"f", X"9", X"c", X"9", X"7", X"0", X"1", X"8", X"d", X"2", X"f", X"1", X"7", X"d", X"e", X"e", X"3", X"7", X"8", X"0", X"7", X"4", X"2", X"1", X"d", X"c", X"3", X"1", X"f", X"4", X"3", X"0", X"8", X"0", X"e", X"f", X"2", X"3", X"d", X"5"
	);
	constant sd_test_3 : signdigit_array                   := (
		X"9", X"6", X"5", X"4", X"7", X"2", X"7", X"c", X"9", X"9", X"4", X"3", X"4", X"d", X"2", X"8", X"3", X"2", X"c", X"7", X"d", X"f", X"9", X"4", X"5", X"1", X"c", X"2", X"d", X"6", X"8", X"e", X"c", X"b", X"7", X"f", X"e", X"0", X"d", X"3", X"4", X"5", X"a", X"9", X"5", X"6", X"c", X"5", X"8", X"1", X"0", X"f", X"1", X"e", X"5", X"9", X"6", X"0", X"8", X"f", X"4", X"a", X"0", X"f", X"7"
	);
	constant sd_test_4 : signdigit_array                   := (
		X"d", X"6", X"6", X"8", X"2", X"6", X"1", X"b", X"6", X"5", X"e", X"5", X"c", X"6", X"a", X"4", X"b", X"0", X"0", X"7", X"1", X"a", X"4", X"c", X"2", X"4", X"7", X"4", X"5", X"2", X"8", X"7", X"9", X"7", X"2", X"d", X"a", X"a", X"6", X"4", X"6", X"f", X"e", X"f", X"6", X"1", X"f", X"5", X"d", X"4", X"4", X"7", X"4", X"6", X"d", X"4", X"2", X"5", X"1", X"f", X"3", X"a", X"0", X"f", X"7"
	);
	constant sd_test_5 : signdigit_array                   := (
		X"e", X"8", X"a", X"f", X"2", X"2", X"0", X"c", X"2", X"b", X"b", X"6", X"a", X"1", X"3", X"c", X"b", X"4", X"3", X"5", X"9", X"a", X"9", X"6", X"2", X"d", X"6", X"a", X"0", X"e", X"f", X"5", X"a", X"5", X"9", X"a", X"5", X"1", X"8", X"2", X"1", X"a", X"0", X"7", X"1", X"c", X"d", X"d", X"c", X"2", X"7", X"a", X"4", X"4", X"6", X"7", X"7", X"0", X"7", X"c", X"2", X"9", X"2", X"d", X"5"
	);
	constant sd_test_6 : signdigit_array                   := (
		X"1", X"4", X"7", X"c", X"7", X"8", X"d", X"6", X"3", X"2", X"0", X"9", X"4", X"6", X"b", X"0", X"e", X"3", X"5", X"e", X"b", X"6", X"d", X"8", X"8", X"5", X"d", X"6", X"a", X"c", X"4", X"8", X"0", X"7", X"f", X"5", X"4", X"8", X"d", X"7", X"4", X"f", X"3", X"3", X"6", X"3", X"2", X"5", X"6", X"2", X"e", X"f", X"f", X"8", X"a", X"6", X"7", X"9", X"0", X"4", X"a", X"9", X"5", X"b", X"3"
	);
	constant sd_test_7 : signdigit_array                   := (
		X"0", X"5", X"c", X"9", X"d", X"f", X"1", X"b", X"1", X"4", X"c", X"f", X"8", X"4", X"7", X"f", X"2", X"b", X"8", X"6", X"d", X"f", X"1", X"d", X"3", X"d", X"b", X"1", X"f", X"5", X"4", X"9", X"5", X"d", X"6", X"0", X"6", X"c", X"c", X"3", X"6", X"2", X"3", X"6", X"5", X"8", X"7", X"1", X"1", X"7", X"e", X"7", X"f", X"2", X"e", X"9", X"7", X"f", X"b", X"2", X"a", X"9", X"0", X"f", X"7"
	);
	constant sd_test_8 : signdigit_array                   := (
		X"5", X"5", X"d", X"e", X"d", X"e", X"7", X"d", X"d", X"5", X"b", X"c", X"b", X"3", X"5", X"6", X"e", X"9", X"5", X"a", X"0", X"9", X"1", X"b", X"3", X"8", X"0", X"4", X"b", X"2", X"d", X"2", X"a", X"e", X"c", X"e", X"9", X"4", X"b", X"f", X"6", X"4", X"8", X"2", X"b", X"6", X"a", X"c", X"c", X"e", X"2", X"4", X"b", X"e", X"9", X"e", X"8", X"3", X"c", X"f", X"0", X"f", X"1", X"f", X"7"
	);
	constant sd_test_9 : signdigit_array                   := (
		X"d", X"1", X"6", X"3", X"a", X"6", X"f", X"5", X"b", X"e", X"7", X"5", X"a", X"1", X"d", X"9", X"f", X"9", X"d", X"9", X"2", X"9", X"b", X"7", X"a", X"5", X"3", X"8", X"e", X"e", X"6", X"d", X"5", X"b", X"6", X"e", X"5", X"a", X"a", X"3", X"0", X"1", X"b", X"3", X"7", X"b", X"c", X"6", X"a", X"7", X"3", X"3", X"d", X"e", X"c", X"3", X"2", X"b", X"e", X"5", X"9", X"e", X"0", X"f", X"7"
	);
end package;
