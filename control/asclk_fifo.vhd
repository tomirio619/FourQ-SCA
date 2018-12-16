library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_MISC.ALL;
use Work.common.all;

entity asclk_fifo is
	-- See https://stackoverflow.com/questions/20072851/how-to-use-a-constant-calculated-from-generic-parameter-in-a-port-declaration-in, 
	-- won't touch this anymore for now as there is no need to change this
	Generic(
		DATA_WIDTH : INTEGER := 8; 
		-- constant FIFO_DEPTH = 128
		ADDR_WIDTH : INTEGER := 7
	);
	port (
		rstn_i   : in STD_LOGIC; 										-- Reset
		wclk_i   : in STD_LOGIC; 										-- Write clock
		rclk_o   : in STD_LOGIC; 										-- Read clock
		d_i      : in STD_LOGIC_VECTOR(sel(DATA_WIDTH) - 1 downto 0); 	-- Data inpute
		we_i     : in STD_LOGIC; 										-- Write enable
		re_i     : in STD_LOGIC; 										-- Rasd enable
		q_o      : out STD_LOGIC_VECTOR(sel(DATA_WIDTH) - 1 downto 0); -- Data output
		full_o   : out STD_LOGIC; 										-- full_o flag
		empty_o  : out STD_LOGIC 										-- empty_o flag
	);
end asclk_fifo;


architecture behavioral of asclk_fifo is


constant COUNTER_WIDTH : INTEGER := (ADDR_WIDTH + 1);

-- https://stackoverflow.com/questions/9701456/multidimensional-array-of-signals-in-vhdl
type mem_array is array (0 to 2**ADDR_WIDTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);

-- Internal signals

signal mem                  : mem_array;
signal data_out             : STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
signal write_enable         : STD_LOGIC;
signal read_enable          : STD_LOGIC;

signal next_waddr           : STD_LOGIC_VECTOR(COUNTER_WIDTH - 1 downto 0); -- Binary next write address 
signal next_wptr            : STD_LOGIC_VECTOR(COUNTER_WIDTH - 1 downto 0); -- Gray code next write pointer
signal write_addr           : STD_LOGIC_VECTOR(COUNTER_WIDTH - 1 downto 0); -- Memory write address
signal write_pointer        : STD_LOGIC_VECTOR(COUNTER_WIDTH - 1 downto 0); -- Gray code pointer
signal wsync_rp1            : STD_LOGIC_VECTOR(COUNTER_WIDTH - 1 downto 0); -- Read pointer sync register
signal wsync_rp2            : STD_LOGIC_VECTOR(COUNTER_WIDTH - 1 downto 0); 

signal next_raddr           : STD_LOGIC_VECTOR(COUNTER_WIDTH - 1 downto 0); -- Binary next read address
signal next_rptr            : STD_LOGIC_VECTOR(COUNTER_WIDTH - 1 downto 0); -- Gray code next write pointer
signal read_addr            : STD_LOGIC_VECTOR(COUNTER_WIDTH - 1 downto 0); -- memory read address
signal read_pointer         : STD_LOGIC_VECTOR(COUNTER_WIDTH - 1 downto 0); -- Gray code pointer
signal rsync_wp1, rsync_wp2 : STD_LOGIC_VECTOR(COUNTER_WIDTH - 1 downto 0); -- Write pointer sync register
signal full_flag            : STD_LOGIC;
signal empty_flag           : STD_LOGIC;

begin

write_enable <= re_i and (not full_flag);
read_enable <= we_i and (not empty_flag);

-- Memory block
mem_block_reg : process(wclk_i)
begin
	if (rising_edge(wclk_i)) then
		if (write_enable = '1') then
			mem(to_integer(unsigned(write_addr(ADDR_WIDTH-1 downto 0)))) <= d_i;
		else null;
		end if;
	else null;
	end if;
end process;

data_out_reg : process(rclk_o)
begin
	if (rising_edge(rclk_o)) then
		if (read_enable = '1') then
			data_out <= mem(to_integer(unsigned(read_addr(ADDR_WIDTH-1 downto 0))));
		else null;
		end if;
	else null;
	end if;
end process;

-- Write Address and Pointer

write_addr_and_pointer: process (wclk_i, rstn_i) 
begin
	if (rising_edge(wclk_i)) then
		if (rstn_i = '0') then
			write_addr <= (others => '0');
			write_pointer <= (others => '0');
		else
			if (write_enable = '1') then
				write_addr <= next_waddr;
				write_pointer <= next_wptr;
			else
				write_addr <= write_addr;
				write_pointer <= write_pointer;
			end if;
		end if;
	else null;
	end if;
end process;

next_waddr <= std_logic_vector(to_unsigned(to_integer(unsigned( write_addr )) + 1, write_addr'length));
next_wptr <= next_waddr(COUNTER_WIDTH-1) & ( next_waddr(COUNTER_WIDTH-2 downto 0) xor next_waddr(COUNTER_WIDTH-1 downto 1) );

-- Sync read pointer
-- read_pointer -> wsync_rp1 -> wsync_rp2
sync_read_pointer : process(wclk_i, rstn_i)
begin
	if (rising_edge(wclk_i)) then
		if (rstn_i = '0') then
			wsync_rp1 <= (others => '0');
			wsync_rp2 <= (others => '0');
		else
			wsync_rp1 <= read_pointer;
			wsync_rp2 <= wsync_rp1;
		end if;
	else null;
	end if;
end process;

process(wclk_i, rstn_i)
begin
	if (rising_edge(wclk_i)) then
		if (rstn_i = '0') then
			full_flag <= '0';
		elsif ((( next_wptr = not wsync_rp2(COUNTER_WIDTH-1 downto COUNTER_WIDTH-2) & wsync_rp2(COUNTER_WIDTH-3 downto 0) and (we_i = '1') )
				or (write_pointer = not wsync_rp2(COUNTER_WIDTH-1 downto COUNTER_WIDTH-2) & wsync_rp2(COUNTER_WIDTH-3 downto 0)))) 
		then full_flag <= '1';
		else full_flag <= '0';
		end if;
	else null;
	end if;
end process;

-- Read address and pointer
process(rclk_o, rstn_i)
begin
	if (rising_edge(wclk_i)) then
		if (rstn_i = '0') then
			read_addr <= (others => '0');
			read_pointer <= (others => '0');
		elsif(read_enable = '1') then
			read_addr <= next_raddr;
			read_pointer <= next_rptr;
		else
			read_addr <= read_addr;
			read_pointer <= read_pointer;
		end if;
	else null;
	end if;
end process;


next_raddr <= std_logic_vector(to_unsigned(to_integer(unsigned( read_addr )) + 1, read_addr'length));
next_rptr <= next_raddr(COUNTER_WIDTH-1) & next_raddr(COUNTER_WIDTH-2 downto 0) xor next_raddr(COUNTER_WIDTH-1 downto 1);

-- Sync writer pointer
-- write_pointer -> rsync_wp1 -> rsync_wp2
process(rclk_o, rstn_i)
begin
	if (rising_edge(wclk_i)) then
		if (rstn_i = '0') then
			rsync_wp1 <= (others => '0');
			rsync_wp2 <= (others => '0');
		else
			rsync_wp1 <= write_pointer;
			rsync_wp2 <= rsync_wp1;
		end if;
	else null;
	end if;
end process;

process(rclk_o, rstn_i)
begin
	if (rising_edge(wclk_i)) then
		if (rstn_i = '0') then empty_flag <= '1';
		elsif ((( next_rptr = rsync_wp2(COUNTER_WIDTH-1 downto 0) ) and ( re_i = '1' ))
           or ( read_pointer = rsync_wp2(COUNTER_WIDTH-1 downto 0) )) then
			empty_flag <= '1';
		else empty_flag <= '0';	
		end if;
	else null;
	end if;
end process;

q_o <= data_out;
full_o <= full_flag;
empty_o <= empty_flag;

end behavioral;