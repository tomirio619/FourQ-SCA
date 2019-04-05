library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package tb_sakura_g_main_constants is
	
	shared variable bus_size         	: integer := 8;
	shared variable data_values_size 	: integer := 64;
	shared variable address_size     	: integer := 16; --2 * bus_size;
	shared variable data_size        	: integer := 16; -- 2 * bus_size
	shared variable PERIOD				: time    := 333.334 ns;


	type values is array (integer range <>) of STD_LOGIC_VECTOR((data_values_size - 1) downto 0);
	type address_values is array (integer range <>) of STD_LOGIC_VECTOR((address_size - 1) downto 0);
	type data_values is array (integer range <>) of STD_LOGIC_VECTOR((data_size - 1) downto 0);
	type addresses is array (integer range <>) of STD_LOGIC_VECTOR((data_size - 1) downto 0);
	type partial_addresses is array (integer range <>) of STD_LOGIC_VECTOR(7 downto 0); 

	constant keys : values(0 to 39) := (
		x"4d9c7722e582ee6d", x"b8f48118358a215d", x"200bbfa6a8b72032", x"5150c5d41fb74053",
		x"bf5d4db549fbbfea", x"4f2b5760231d06a3", x"58b710597c51b4da", x"fb2d12151fff5cb2",
		x"f9e8890b25c53cef", x"532978160c34ec08", x"1bbac561fd61861d", x"8144c7aefcd4eee6",
		x"4ac2500b675e33c3", x"721a83688fa20ed1", x"562ce7cf9507e700", x"0f5348effc115293",
		x"82e0743d57a8808c", x"957aff70ee89fbdd", x"10f16ce077aec74a", x"8874142a241ac600",
		x"a2ebcc27e44a1f9d", x"adf6611e52639aae", x"b32dfcb639f0be47", x"fa6bad9d20fb6799",
		x"2e0ae94d92c0ebf1", x"ee8b0f75448cf68c", x"10c9f2e5899f8afd", x"047f1d0683ed5947",
		x"ba5db420883941eb", x"499201193654e357", x"53242b04d2ce7f11", x"805ea2187c6d0a56",
		x"a98b5002e505278b", x"2be68720e203182b", x"62991bf52390f36c", x"5acaabff0c336ef1",
		x"de1301ccdaa25afc", x"7a04be82c536ac53", x"1e28c6d28775ebbf", x"70174da2f94b475e");

	constant keys_decomp : values (0 to 39) := (
		x"8b8e05ff76fe90a5", x"6261ed79303c3feb", x"780e38de51089170", x"5f055848a6493e4f", 
		x"b9ae0e8bc9480ec7", x"855dee784bdd9802", x"5a958634b4007543", x"89a2495263964678", 
		x"89fc2dd3713be2e7", x"7be57794f39aa219", x"74e3fd40261afb66", x"61c81b025852b5fd", 
		x"b5ab8f342ee894e3", x"a2548bfcd909738a", x"5a609f768f4a13d8", x"48982dc1c02d4d52", 
		x"90137f2c5c45fdcd", x"6bc6ad94dca2123b", x"73ed9c7d3d84aa4a", x"7a191767e2c37056", 
		x"9ffd2564ef00a11d", x"6e614f823f17499a", x"72f2b8ce670503a9", x"891d7bf4244c7fbe", 
		x"aebaf29ecc3ddaef", x"a4800d48df3691f7", x"5de659e0730d555a", x"4c3ed165bd63d07c", 
		x"9869864ce874be77", x"6cb48c7d7f6cebac", x"63755e0a7dcd51f1", x"6bd34d6598c34516", 
		x"9b495e3e029a5019", x"5ca85b8aed3e57b7", x"65ad0184b29573b2", x"91f4c6d33264c237", 
		x"82e0b8343b7eee7b", x"58917579af4976d4", x"663e9cd022aeecd7", x"7acb97fdfe9db814");

	constant b_xcoords : values(0 to 39)  := (
		x"f85c61a796a17623", x"03380ead2cedd09d", x"c6d7f8f8b501fe5f", x"61bc5c4179251636",
		x"f1bc0a430758056d", x"58f15a220408b046", x"fd184247de7d5ee3", x"362a216a60910055",
		x"55ebdaf149bb26c7", x"047076fe6b898bdb", x"2c71d491a08e1245", x"012b562c17cf5a97",
		x"86b4de7790fcb710", x"0b7bfa7a04d35c33", x"5688a953bff07410", x"7d3c86d337ae0829",
		x"0211447ce1eb4559", x"2a93ded27f71e9ab", x"811501a096ae399e", x"5a9be92827f9b785",
		x"f76f2e9f644efc5e", x"31c4e5c7416d207b", x"d57c1a9f45d55843", x"6b5ce7deeebde525",
		x"83e6dd9991e9d1e1", x"60e912403d6ad87d", x"5c198585e5d48be3", x"519ad4f5077e496e",
		x"e4cb68a34aaa0b87", x"73eb6dba8808232d", x"dc8d74bb713a015e", x"5e0796811771dfbf",
		x"6a5db9282f55ea6a", x"6d364b1ad1146710", x"2d49c28a4966fa4b", x"3b196e4763a56976",
		x"e74a3fc72b5345f6", x"1bc2fb828c66b05b", x"b504e0a792caa3ae", x"6cc503a481f420a5");
	
	constant b_ycoords : values(0 to 39)  := (
		x"321d66be8d6da159", x"0db39ae2d9a96d12", x"134696c3a3f25608", x"2064d02912d52505",
		x"d3354f6b5ad84329", x"718403a415a94e2e", x"435debed7fa7b1ab", x"60a9e489dc76cf6a",
		x"569dd0c5512e638e", x"4f5179c5eb32e573", x"2a7a70825280f648", x"732cbc97563ed750",
		x"5e4d2de8b007d81e", x"4e7b03fa3eeb5e29", x"dd5a9ab187d923b8", x"48a00237438ac809",
		x"98c770a8ea97930f", x"528b615b97163e2c", x"c58ec73dd0f44758", x"36fd243f15a56a7f",
		x"46c917bfac4f120f", x"56e44e50715771d8", x"e9b31bf402430102", x"41bd34bf99065f50",
		x"cda0d93b92f9c715", x"3bc4004377557b35", x"e09532e3cf04df2d", x"706288c211989854",
		x"1a75507b947c4fc7", x"41e140f65782c3e6", x"020e3deaf69abc6b", x"2338ff8882986cf3",
		x"247dfa16f05966d4", x"7321fd3d4ccac5c0", x"60608b7ca7848508", x"4b012557e614b0d8",
		x"69cfe83122d8d815", x"08df3cd439958ddc", x"93a8bc144480e877", x"6bde7d539a3f1996");

	constant r_xcoords : values(0 to 39)  := (
		x"eb62b848ddf31bfe", x"34de553eb9e7e931", x"393733229cd76cbb", x"005175f24bca9976",
		x"1ee493a7b7fe36dd", x"798b35ff7e9246d0", x"3185df9ecf7c21e0", x"5faced51a05002a8",
		x"69711409fb4ba015", x"453777b6a639e638", x"c0a80208a5fbfb75", x"340e7701b73079bf",
		x"24ecac8caeba79c0", x"668b2b35f20c883c", x"a47bab5a07b2ff4f", x"1d22ae41159dc944",
		x"eca6bef0cdac688a", x"2519a940f21ed077", x"4db56c4db049ad0c", x"7b9b0be6b5f5a426",
		x"65e9f316cf1bdb61", x"191b8262b21900a3", x"6420baed7c0afcde", x"2b11b1acd4baf4ab",
		x"7d5bf2cb148882ab", x"3914910db89f330d", x"352b63c5e1a2cd6e", x"4a4ceb622b12e95e",
		x"7ca605654bc581cf", x"5a0509f660d67798", x"c5af22e461a9e4ed", x"238b32a0f2a079f5",
		x"f1d6d848dffffd90", x"4a77f08a659f9b76", x"014c32c9d8d02fa2", x"55d277fa5ddf6ad2",
		x"d6010a9bbaa8b197", x"2bd4858cf308d02d", x"8b593f3c18433367", x"58df7c1b722d24d4");
	
	constant r_ycoords : values(0 to 39)  := (
		x"aee75e4b2308d709", x"58c9fa19bfab644e", x"b6e30695ce6775a9", x"4258a4802d1b79e3",
		x"aa780486e3ea9693", x"35da16a2640ea639", x"ee2384be0561362d", x"5ffc68ca4cd6f639",
		x"6f675ace54c5ee6a", x"121a6cffa6bf9f90", x"bf9ff3852b158266", x"300b5ce5296b9cce",
		x"4d86e385c3775beb", x"430175188d9c3ac3", x"18d9a8f5bbe10fdd", x"4e479d7abc5667fe",
		x"e985b01137aa054e", x"00e094bfeedf92e9", x"a74814b02ce25ae2", x"498a533abab557cb",
		x"d78e8f0ec5764ead", x"16d757d3726036ca", x"ebab5c109a39b024", x"05221f03f82d8996",
		x"e567dc47af20a8a6", x"0efe106ae4f33765", x"07c57e8468ed349a", x"069ee856c923e82f",
		x"750b05daf9547d11", x"031c5574b5eb944f", x"febabf499f41b297", x"539cacf6a6a09bc1",
		x"3fb718bf6199953d", x"3fa6b310c0128f78", x"75f02ed03bae821f", x"27bc9dbc4cf05fc8",
		x"814dc2bb209d1a2a", x"3d67cd1ec5ae517c", x"490324405396f63b", x"2133067c2db0b7cd");

	constant keys_cf : values(0 to 39)  := (
		x"936dfe5bf0b6402e", x"8fbf5fe61cd2405c", x"554a36c959e911f4", x"a54e14fef2949d25",
		x"aa4b4ca56c60dd15", x"5ed13e24fe41c810", x"01571fc60d409a18", x"00ce1944a6d7d017",
		x"a3e49f852ebabed7", x"0a6d3746fb650877", x"9abf9ee557259422", x"141b3a0f1de8cef0",
		x"cf590ba46dfda1a1", x"e87a55f2d27a20c6", x"cd6457978852debb", x"9350a4eb29afd244",
		x"32e34ac1bed2637a", x"24c0ab0d216f143a", x"092518b6a7321188", x"e218c83f94a1af85",
		x"1117de6f060e7482", x"c6e472d991a41f8f", x"9fbe92f7512bdbe2", x"b94214a791f51f3d",
		x"1a40692048d8abdb", x"ba9852a10acc02c5", x"b84a3a1a2f593e98", x"da33cbe08f9b7538",
		x"217c005ad577da4f", x"550e2979d43127b0", x"3b85bebb0f9bf8c5", x"b0c07796ec4fca4a",
		x"a2f4f00dff9d2f83", x"78b2a0ff32c14734", x"2840995cbaeaf81b", x"6816c3df9da0b1bf",
		x"0f9a806e45c661c9", x"2330bb00eb35b174", x"81d2bdc3f8c3aaed", x"72a8f445ac929c06");

	constant b_xcoords_cf : values(0 to 39)  := (
		x"49e971d69fad3252", x"16e46ac91db5ae63", x"aac35ed5842ad52f", x"56d50ccd99714dbb",
		x"8db0bdff63dc173b", x"74651b70c7c4d42e", x"7884e318b3460c38", x"7b5a52f297b4cc54",
		x"3077116bfd9984c6", x"045b6c746ec78262", x"a57ff3010edcf4f4", x"4177c727cf69c6ea",
		x"073e1d04abd3777c", x"0d34b4d05b67229f", x"c9afb6c6ecafb346", x"44e8386740e39087",
		x"2ff95ff49f0378b3", x"2269243018783743", x"e71c9bcc7cd7368d", x"56be7fd2e4073891",
		x"c36b3e5afb20c18e", x"38b13449318c676e", x"d98d6531ee7431bd", x"5f3b9b9c41c84741",
		x"925ea832c55c607a", x"030ea0ec3686ff15", x"64d326c911457999", x"3b9d99637d337881",
		x"34ab79932f305ea8", x"47c682c1d462c30a", x"b5774273a1b4f11d", x"0769bd604b1af25f",
		x"33d12a149bc450ce", x"6115306b86357463", x"7f04abdee426f64a", x"0afc0f32ca4670bf",
		x"94112aa15d903cbe", x"77f3f2f1aec13d51", x"dded839dc540eabf", x"2c4b2ffe8bb0c3db");

	constant b_ycoords_cf : values(0 to 39)  := (
		x"c8e14c17d02f97f9", x"02f8edb21dc5d33f", x"8c68a3591d73f998", x"052972cea24bc326",
		x"54ade7fa6d0568f8", x"153fe38f1296ed50", x"dff6aef6a482c545", x"4c8f4b7d6938c175",
		x"88639b94e4c7fbcc", x"2e109c3ff59845c3", x"2a98781c1a2fa670", x"6a1bccbd91fd4d59",
		x"d56c2f1b81c78c02", x"52aeb6c7fe99831b", x"e126518c95ef3a91", x"52ea6f6df91bd657",
		x"a67fe614d97fdaec", x"34152d173da46c98", x"43e9a4b5f580cd8e", x"6e6bc01895626775",
		x"2c2a7918fe2cb976", x"46006deaf241b934", x"fd476db346e8f050", x"2d809e320f8d7cd3",
		x"1765b3d8c648b552", x"0516cd4ca8d2da4f", x"dadcc6cd65e20098", x"6342bff94c841370",
		x"16de6b6d4d26bdb1", x"5506759b76acfcdd", x"cba7cac963379088", x"74bf26e998b32cb2",
		x"7e0e0771c684c1ae", x"7b24e2e3f8cb240a", x"89e8121fc9c6dc8d", x"2e8a0e54dad2ba13",
		x"cba908d23c06a3b8", x"28d2921a41affe5b", x"a0e102bf50160245", x"17aa2710318fbb4a");

	constant r_xcoords_cf : values(0 to 39)  := (
		x"3fe12724ba597608", x"2325bb213f68b930", x"7378eaef50377c12", x"5bdc73134d2b687f",
		x"8ac486a48c88c09f", x"2cd69e901eb93261", x"e787e0495cc02b05", x"435208878d0aef6e",
		x"0db6be0adaab8f43", x"39a8f994dc24e230", x"289490a9cdac0c2f", x"3090f5a8c0d8c8bd",
		x"89bd9a330e0d66d4", x"7ec8f7c21c3be91c", x"36c6484a954e590f", x"034f8caa06bd18c9",
		x"02ed8abcc9353506", x"7f2b66dbeabc6826", x"ad06da354e1178de", x"60260690c9277f36",
		x"a77b649ecc733a52", x"7939ad3bda767a5b", x"89b37f5460de53e2", x"548d6126a1919df0",
		x"b894cde6cb11099c", x"687ebeab80c28a9a", x"aa35706d624033e6", x"31e87dfb7a77f487",
		x"780f219034e30320", x"324c07c5f63d6a24", x"07ab8f8f2f3f14e6", x"3ef3e320ee91069c",
		x"7315e310e9b24027", x"0b117fac2d381126", x"75474c83e68fcd59", x"68d9432eb603f40b",
		x"9c3623e704be8f60", x"6988a983f39f3aaa", x"b1fafef5a2b29874", x"60d2e1355d425858");

	constant r_ycoords_cf : values(0 to 39)  := (
		x"49c20f9966c879f0", x"5c43325cc1ce55fd", x"b3a9bc29407096d2", x"63664e520503ae57",
		x"8bef673c8fdfdd7d", x"0069a51a24dbf551", x"7c31b9033807ea31", x"4dcdaf6b3d17e587",
		x"6312b5af717e3aa4", x"73bdc9ceb924203b", x"284dd02186cfb129", x"7a602dd83d3215fb",
		x"2126e8e7af6a4beb", x"412f22966acf2394", x"9c936d235bac199f", x"3ad902ef8a56a2c8",
		x"b17cc7adb99fe6e5", x"56fb1b4499a10681", x"898b125cafd1658d", x"2d216e4925aaea67",
		x"6982ad2987b398ab", x"56de75789536caa3", x"f6e553eb8c37aead", x"481a1c74d591e4b1",
		x"5501024beb1224f5", x"4831449edcbbff59", x"420984a8103971e2", x"641b779d5a31f45c",
		x"92e3ea4e38090324", x"5b980441830da7e6", x"a044bb0878408b46", x"6f01d33f0e6eff8c",
		x"a720933d2ee68d6a", x"2aea6812ea165d37", x"80c718160232415d", x"1b0852c7cb105271",
		x"288f8b43aca98f6d", x"4808e5f063b4c290", x"6874aa00aac7993e", x"4b0568cf8742689f");

	constant fourq_ram_constants_values_lower_64 : values(0 to 35) := (
	x"0000000000000000",
	x"0000000000000001",
	x"0000000000000142",
	x"b3821488f1fc0c8d",
	x"74dcd57cebce74c3",
	x"0000000000000012",
	x"9ecaa6d9decdf034",
	x"0000000000000011",
	x"edf07f4767e346ef",
	x"000000000000013a",
	x"0000000000000143",
	x"4c7deb770e03f372",
	x"0000000000000009",
	x"3a6e6abe75e73a61",
	x"fffffffffffffff6",
	x"c59195418a18c59e",
	x"fffffffffffffff7",
	x"4f65536cef66f81a",
	x"0000000000000007",
	x"334d90e9e28296f9",
	x"0000000000000015",
	x"2c2cb7154f1df391",
	x"0000000000000003",
	x"92440457a7962ea4",
	x"0000000000000003",
	x"a1098c923aec6855",
	x"000000000000000f",
	x"669b21d3c5052df3",
	x"0000000000000018",
	x"cd3643a78a0a5be7",
	x"0000000000000023",
	x"66c183035f48781a",
	x"00000000000000f0",
	x"44e251582b5d0ef0",
	x"0000000000000bef",
	x"014d3e48976e2505"
	);

	constant fourq_ram_constants_values_upper_64 : values(0 to 35) := (
	x"0000000000000000",
	x"0000000000000000",
	x"00000000000000e4",
	x"5e472f846657e0fc",
	x"1964de2c3afad20c",
	x"000000000000000c",
	x"4aa740eb23058652",
	x"7ffffffffffffff4",
	x"2af99e9a83d54a02",
	x"00000000000000de",
	x"00000000000000e4",
	x"21b8d07b99a81f03",
	x"0000000000000006",
	x"4cb26f161d7d6906",
	x"7ffffffffffffff9",
	x"334d90e9e28296f9",
	x"0000000000000005",
	x"2553a0759182c329",
	x"0000000000000005",
	x"62c8caa0c50c62cf",
	x"000000000000000f",
	x"78df262b6c9b5c98",
	x"0000000000000002",
	x"5084c6491d76342a",
	x"0000000000000003",
	x"12440457a7962ea4",
	x"000000000000000a",
	x"459195418a18c59e",
	x"0000000000000012",
	x"0b232a8314318b3c",
	x"0000000000000018",
	x"3963bc1c99e2ea1a",
	x"00000000000000aa",
	x"1f529f860316cbe5",
	x"0000000000000870",
	x"0fd52e9cfe00375b"
	);

	constant fourq_ram_constants_addresses : partial_addresses(0 to 35) := (
	x"60",
	x"61",
	x"1e",
	x"1f",
	x"20",
	x"21",
	x"22",
	x"23",
	x"24",
	x"25",
	x"26",
	x"27",
	x"28",
	x"29",
	x"2a",
	x"2b",
	x"2c",
	x"2d",
	x"2e",
	x"2f",
	x"30",
	x"31",
	x"32",
	x"33",
	x"34",
	x"35",
	x"36",
	x"37",
	x"38",
	x"39",
	x"3a",
	x"3b",
	x"3c",
	x"3d",
	x"3e",
	x"3f"
	);

	constant scalar_and_base_point_addresses : partial_addresses (0 to 5) := (
		x"00", -- k0 / k1
		x"01", -- k2 / k3
		-- # Base point
		x"02", -- x0
		x"03", -- x1
		x"04", -- y0
		x"05"  -- y1
	);

end tb_sakura_g_main_constants;  -- package body contains the function body
