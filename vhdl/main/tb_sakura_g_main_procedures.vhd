library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use WORK.tb_sakura_g_main_constants.all;

package tb_sakura_g_main_procedures is

procedure read_value(
signal address : in STD_LOGIC_VECTOR((address_size - 1) downto 0);
signal received_value : out STD_LOGIC_VECTOR((data_size - 1) downto 0);
signal test_lbus_rd : in STD_LOGIC_VECTOR(7 downto 0);
signal test_lbus_re : out STD_LOGIC;
signal test_lbus_wd : out STD_LOGIC_VECTOR(7 downto 0);
signal test_lbus_we : out STD_LOGIC;
signal wait_read_effective_done: in STD_LOGIC);

procedure write_value(
signal address : in STD_LOGIC_VECTOR((address_size - 1) downto 0);
signal written_value : in STD_LOGIC_VECTOR((data_size - 1) downto 0);
signal test_lbus_wd : out STD_LOGIC_VECTOR(7 downto 0);
signal test_lbus_we : out STD_LOGIC);

procedure write_value64(
signal internal_data_register_addresses : in address_values(0 to 3);
signal written_value : in STD_LOGIC_VECTOR((data_values_size - 1) downto 0);
signal rom_address : in STD_LOGIC_VECTOR((address_size - 1) downto 0); 
signal rom_address_value: in STD_LOGIC_VECTOR((data_size - 1) downto 0);    
signal we_address : in STD_LOGIC_VECTOR((address_size - 1) downto 0);
signal we_address_value : in STD_LOGIC_VECTOR((address_size - 1) downto 0);
signal test_lbus_wd : out STD_LOGIC_VECTOR((bus_size - 1) downto 0);
signal test_lbus_we : out STD_LOGIC);

procedure read_value64(
signal internal_read_register_addresses : in address_values(0 to 3);
signal tmp_data_read : inout STD_LOGIC_VECTOR((data_size) - 1 downto 0);
signal received_value : out STD_LOGIC_VECTOR((data_values_size - 1) downto 0);
signal test_lbus_rd : in STD_LOGIC_VECTOR(7 downto 0);
signal test_lbus_re : out STD_LOGIC;
signal test_lbus_wd : out STD_LOGIC_VECTOR(7 downto 0);
signal test_lbus_we : out STD_LOGIC;
signal wait_read_effective_done : in STD_LOGIC);

procedure wait_until_ready(
signal address : in STD_LOGIC_VECTOR((address_size - 1) downto 0);
signal tmp_data_read : inout STD_LOGIC_VECTOR((data_size - 1) downto 0);
signal test_lbus_rd : in STD_LOGIC_VECTOR(7 downto 0);
signal test_lbus_re : out STD_LOGIC;
signal test_lbus_wd : out STD_LOGIC_VECTOR(7 downto 0);
signal test_lbus_we : out STD_LOGIC;
signal wait_read_effective_done : in STD_LOGIC);


end tb_sakura_g_main_procedures;

package body tb_sakura_g_main_procedures is

----------------
-- Procedures --
----------------

----------------------------------------------------
-- Read data from the main FPGA (default 2 bytes) --
---------------------------------------------------
procedure read_value(
    signal address : in STD_LOGIC_VECTOR((address_size - 1) downto 0);
    signal received_value : out STD_LOGIC_VECTOR((data_size - 1) downto 0);
    signal test_lbus_rd : in STD_LOGIC_VECTOR(7 downto 0);
    signal test_lbus_re : out STD_LOGIC;
    signal test_lbus_wd : out STD_LOGIC_VECTOR(7 downto 0);
    signal test_lbus_we : out STD_LOGIC;
    signal wait_read_effective_done: in STD_LOGIC
    ) is
    variable i : integer;
    variable debug_output : string(1 to 50);
begin
    -- report "Procedure 'read value' called with the following paramaters:" severity note;
    -- report "address:" & integer'image(to_integer(unsigned(address))) severity note;
    test_lbus_re <= '0';
    test_lbus_wd <= X"01";
    test_lbus_we <= '1';
    wait for PERIOD;
    test_lbus_wd <= X"FF";	-- test value, should not be taken over
    test_lbus_we <= '0';
    wait for PERIOD*4;
    i := address_size;
    -- Transfer address over bus (from MSB to LSB)
    while (i /= 0) loop
    	test_lbus_we <= '1';
        test_lbus_wd <= address((i-1) downto (i-8));
        wait for PERIOD;
        test_lbus_we <= '0';
        test_lbus_wd <= X"FF";
        wait for PERIOD*4;
        i := i - 8;
    end loop; 
    test_lbus_wd <= X"FF";
    wait until wait_read_effective_done = '1';      -- wait until lbus_emp = '0'
    wait for PERIOD;
    debug_output := "Done waiting for read becoming effective";
    i := data_size;
    -- Receive data over bus (from MSB to LSB)
    while(i /= 0) loop
        test_lbus_re <= '1';
        wait for PERIOD;
		received_value((i-1) downto (i-8)) <= test_lbus_rd;
        -- wait for PERIOD;
        i := i - 8;
    end loop;
    test_lbus_re <= '0';
    wait for PERIOD;
end read_value;

---------------------------------------------------
-- Write data to the main FPGA (default 2 bytes) --
---------------------------------------------------
procedure write_value(
    signal address : in STD_LOGIC_VECTOR((address_size - 1) downto 0);
    signal written_value : in STD_LOGIC_VECTOR((data_size - 1) downto 0);
    signal test_lbus_wd : out STD_LOGIC_VECTOR(7 downto 0);
    signal test_lbus_we : out STD_LOGIC) is
    variable i : integer;
begin 
    -- report "Procedure 'write value' called with the following paramaters:" severity note;
    -- report "address:" & integer'image(to_integer(unsigned(address))) severity note;
    -- report "written_value:" & integer'image(to_integer(unsigned(written_value))) severity note;
    test_lbus_wd <= X"02";
    test_lbus_we <= '1';
    wait for PERIOD;
    test_lbus_we <= '0';
    test_lbus_wd <= X"FF";
    wait for PERIOD*4;
    i := address_size;
    -- Transfer address over bus (from MSB to LSB)
    while (i /= 0) loop
    	test_lbus_we <= '1';
        test_lbus_wd <= address((i-1) downto (i-8));
        wait for PERIOD;
        test_lbus_we <= '0';
        test_lbus_wd <= X"FF";
        wait for PERIOD*4;
        i := i - 8;
    end loop; 
    i := data_size;
    -- Write data over bus (from MSB to LSB)
    while(i /= 0) loop
        test_lbus_we <= '1';
        test_lbus_wd <= written_value((i-1) downto (i-8));
        wait for PERIOD;
        test_lbus_we <= '0';
        test_lbus_wd <= X"FF";
        wait for PERIOD*4;
        i := i - 8;
    end loop;
    wait for PERIOD;
end write_value;


--------------------------------------------
-- Write data to the main FPGA (64 bits) --
--------------------------------------------
procedure write_value64(
signal internal_data_register_addresses : in address_values(0 to 3);
signal written_value : in STD_LOGIC_VECTOR((data_values_size - 1) downto 0);
signal rom_address : in STD_LOGIC_VECTOR((address_size - 1) downto 0); 
signal rom_address_value: in STD_LOGIC_VECTOR((data_size - 1) downto 0);    
signal we_address : in STD_LOGIC_VECTOR((address_size - 1) downto 0);
signal we_address_value : in STD_LOGIC_VECTOR((address_size - 1) downto 0);
signal test_lbus_wd : out STD_LOGIC_VECTOR((bus_size - 1) downto 0);
signal test_lbus_we : out STD_LOGIC
) is
variable i : integer := 0;
variable ctr: integer := 0;
begin
    -- Write 64 bit word to the internal register
    i := data_values_size;
    while(i /= 0) loop
        write_value(internal_data_register_addresses(ctr), written_value((i - 1) downto (i - 16)), test_lbus_wd, test_lbus_we);
        i := i - 16;
        ctr := ctr + 1;
    end loop;
    -- Write the rom addr to the internal signal
    write_value(rom_address, rom_address_value, test_lbus_wd, test_lbus_we);
    -- Set data valid
    write_value(we_address, we_address_value, test_lbus_wd, test_lbus_we);
end write_value64;

--------------------------------------------
-- Read data from the main FPGA (64 bits) --
--------------------------------------------
procedure read_value64(
signal internal_read_register_addresses : in address_values(0 to 3);
signal tmp_data_read : inout STD_LOGIC_VECTOR((data_size - 1) downto 0);
signal received_value : out STD_LOGIC_VECTOR((data_values_size - 1) downto 0);
signal test_lbus_rd : in STD_LOGIC_VECTOR(7 downto 0);
signal test_lbus_re : out STD_LOGIC;
signal test_lbus_wd : out STD_LOGIC_VECTOR(7 downto 0);
signal test_lbus_we : out STD_LOGIC;
signal wait_read_effective_done : in STD_LOGIC
) is

variable i : integer := 0;
variable ctr: integer := 0;
begin
    -- Read 64 bit word from an internal register
    i := data_values_size;
    while(i /= 0) loop
        read_value(internal_read_register_addresses(ctr), tmp_data_read, test_lbus_rd, test_lbus_re, test_lbus_wd, test_lbus_we, wait_read_effective_done);
        received_value((i-1) downto (i-16)) <= tmp_data_read;
        wait for PERIOD;
        i := i - 16;
        ctr := ctr + 1;
    end loop;
end read_value64;

-------------------------------------------------------------
-- Wait until the FourQ component is ready (i.e. not busy) --
-------------------------------------------------------------
procedure wait_until_ready(
signal address : in STD_LOGIC_VECTOR((address_size - 1) downto 0);
signal tmp_data_read : inout STD_LOGIC_VECTOR((data_size - 1) downto 0);
signal test_lbus_rd : in STD_LOGIC_VECTOR(7 downto 0);
signal test_lbus_re : out STD_LOGIC;
signal test_lbus_wd : out STD_LOGIC_VECTOR(7 downto 0);
signal test_lbus_we : out STD_LOGIC;
signal wait_read_effective_done : in STD_LOGIC
) is
begin
    report "Waiting for processor to become ready" severity note;
    while true loop
        read_value(address, tmp_data_read, test_lbus_rd, test_lbus_re, test_lbus_wd, test_lbus_we, wait_read_effective_done);
        if tmp_data_read(2) = '0' then
            report "Processor ready" severity note;
            exit;
        end if;
    end loop;
end wait_until_ready;


end tb_sakura_g_main_procedures;