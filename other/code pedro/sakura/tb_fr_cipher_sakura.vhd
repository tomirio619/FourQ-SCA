----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:04:28 07/20/2016 
-- Design Name: 
-- Module Name:    tb_sakura_main_ecp - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_fr_cipher_sakura is
    Generic (
        PERIOD : time := 666.672 ns;
        data_values_size : integer := 128
    );
end tb_fr_cipher_sakura;

architecture Behavioral of tb_fr_cipher_sakura is

component fr_cipher_sakura
    Port(
    -- lbus
        lbus_rstn : in STD_LOGIC;                     -- Reset from Control FPGA
        lbus_clk : in STD_LOGIC;                      -- Clock from Control FPGA
    
        lbus_rdy : out STD_LOGIC;                     -- Device ready
        lbus_wd : in STD_LOGIC_VECTOR(7 downto 0);    -- Local bus data input
        lbus_we : in STD_LOGIC;                       -- Data write enable
        lbus_ful : out STD_LOGIC;                     -- Data write ready low
        lbus_aful : out STD_LOGIC;                    -- Data near write end
        lbus_rd : out STD_LOGIC_VECTOR(7 downto 0);   -- Data output
        lbus_re : in STD_LOGIC;                       -- Data read enable
        lbus_emp : out STD_LOGIC;                     -- Data read ready low
        lbus_aemp : out STD_LOGIC;                    -- Data near read end
        TRGOUTn : out STD_LOGIC;                      -- Start trigger (SAKURA-G Only)
        led : out STD_LOGIC_VECTOR(9 downto 0);       -- M_LED (led[8], led[9] SAKURA-G Only)
  -- Trigger output
        M_HEADER : out STD_LOGIC_VECTOR(2 downto 0);  -- User Header Pin (SAKURA-G Only)
        M_CLK_EXT0_P : out STD_LOGIC;                 -- J4 SMA  AES start (SAKURA-G Only)

  -- FTDI USB interface portB (SAKURA-G Only)
  -- FTDI side
        FTDI_BCBUS0_RXF_B : in STD_LOGIC;
        FTDI_BCBUS1_TXE_B : in STD_LOGIC;
        FTDI_BCBUS2_RD_B : out STD_LOGIC; 
        FTDI_BCBUS3_WR_B : out STD_LOGIC; 
        FTDI_BDBUS_D : inout STD_LOGIC_VECTOR(7 downto 0);

  -- FTDI USB interface portB (SAKURA-G Only)
  -- Control FPGA side
        PORT_B_RXF : out STD_LOGIC;
        PORT_B_TXE : out STD_LOGIC;
        PORT_B_RD : in STD_LOGIC;
        PORT_B_WR : in STD_LOGIC;
        PORT_B_DIN : in STD_LOGIC_VECTOR(7 downto 0);
        PORT_B_DOUT : out STD_LOGIC_VECTOR(7 downto 0);
        PORT_B_OEn : in STD_LOGIC
  );
end component;

signal test_lbus_rstn : STD_LOGIC;
signal test_lbus_rdy : STD_LOGIC; 
signal test_lbus_wd : STD_LOGIC_VECTOR(7 downto 0);
signal test_lbus_we : STD_LOGIC;
signal test_lbus_ful : STD_LOGIC;
signal test_lbus_aful : STD_LOGIC;
signal test_lbus_rd : STD_LOGIC_VECTOR(7 downto 0);
signal test_lbus_re : STD_LOGIC;
signal test_lbus_emp : STD_LOGIC;
signal test_lbus_aemp : STD_LOGIC;
signal test_TRGOUTn : STD_LOGIC;
signal test_led : STD_LOGIC_VECTOR(9 downto 0);
signal test_M_HEADER : STD_LOGIC_VECTOR(2 downto 0);
signal test_M_CLK_EXT0_P : STD_LOGIC;
signal test_FTDI_BCBUS0_RXF_B : STD_LOGIC;
signal test_FTDI_BCBUS1_TXE_B : STD_LOGIC;
signal test_FTDI_BCBUS2_RD_B : STD_LOGIC;
signal test_FTDI_BCBUS3_WR_B : STD_LOGIC;
signal test_FTDI_BDBUS_D : STD_LOGIC_VECTOR(7 downto 0);
signal test_PORT_B_RXF : STD_LOGIC;
signal test_PORT_B_TXE : STD_LOGIC;
signal test_PORT_B_RD : STD_LOGIC;
signal test_PORT_B_WR : STD_LOGIC;
signal test_PORT_B_DIN : STD_LOGIC_VECTOR(7 downto 0);
signal test_PORT_B_DOUT : STD_LOGIC_VECTOR(7 downto 0);
signal test_PORT_B_OEn : STD_LOGIC;

signal clk : STD_LOGIC := '0';
signal testbench_finish : boolean := false;
constant testbench_delay : time := 2*PERIOD/4;
signal test_error : STD_LOGIC;

type values is array (integer range <>) of STD_LOGIC_VECTOR((data_values_size - 1) downto 0);

signal response_test : STD_LOGIC_VECTOR((data_values_size - 1) downto 0);
signal response_ciphertext1 : STD_LOGIC_VECTOR((data_values_size - 1) downto 0);
signal response_ciphertext2 : STD_LOGIC_VECTOR((data_values_size - 1) downto 0);
signal response_ciphertext3 : STD_LOGIC_VECTOR((data_values_size - 1) downto 0);

signal response_fault_detection : STD_LOGIC_VECTOR(7 downto 0);

signal processor_free : STD_LOGIC_VECTOR(7 downto 0);

signal original_data : values(0 to 1) := ("00011010000000101111111110110000110100110111011110001011110010100010010101111011010001001001110000101011011001000011101100110010",
"00011010000000101111111110110000110100110111011110001011110010100010010101111011010001001001110000101011011001000011101100110010");

signal original_key1 : values(0 to 1) := ("00100010000110110100010110100001110110111011000111110011010001011110000001001100010111001001110110111001101001011100000101011100",
"00100010000110110100010110100001110110111011000111110011010001011110000001001100010111001001110110111001101001011100000101011100");

signal original_key2 : values(0 to 1) := ("00100100000101100101000010101111100100010111101111100001100000111010000101100001001101010100000010010010001010110001001011011011",
"00100100000101100101000010101111100100010111101111100001100000111010000101100001001101010100000010010010001010110001001011011011");

signal original_ciphertext1 : values(0 to 1) := ("10101101010001111110001010010101111100011100111011001001000110100011110111001001101111000110010001011010110101110011101100111001",
"10101101010001111110001010010101111100011100111011001001000110100011110111001001101111000110010001011010110101110011101100111001");

signal original_ciphertext2 : values(0 to 1) := ("10101110010110101110011110001101101001100100100011010101000000011111000100000111011001011001011011011010110100010110011100011111",
"10101110010110101110011110001101101001100100100011010101000000011111000100000111011001011001011011011010110100010110011100011111");

signal original_ciphertext3 : values(0 to 1) := ("01011100010100110100110100001110001001000011111110011010000111010010001011011100000100111101111000110110111111110010000110101010",
"01011100010100110100110100001110001001000011111110011010000111010010001011011100000100111101111000110110111111110010000110101010");

signal all_zeros : STD_LOGIC_VECTOR((data_values_size - 1) downto 0) := (others => '0');

procedure read_value(
    address : in STD_LOGIC_VECTOR(7 downto 0);
    signal received_value : out STD_LOGIC_VECTOR((data_values_size - 1) downto 0);
    signal test_lbus_rd : in STD_LOGIC_VECTOR(7 downto 0);
    signal test_lbus_re : out STD_LOGIC;
    signal test_lbus_wd : out STD_LOGIC_VECTOR(7 downto 0);
    signal test_lbus_we : out STD_LOGIC) is
    variable i : integer;
begin
    test_lbus_re <= '0';
    test_lbus_wd <= X"01";
    test_lbus_we <= '1';
    wait for PERIOD;
    test_lbus_we <= '0';
    wait for PERIOD*4;
    test_lbus_we <= '1';
    test_lbus_wd <= address;
    wait for PERIOD;
    test_lbus_we <= '0';
    wait for PERIOD*4;
    test_lbus_re <= '1';
    test_lbus_wd <= X"00";
    wait for PERIOD;
    i := 7;
    while(i /= (data_values_size + 7)) loop
        received_value(i downto (i-7)) <= test_lbus_rd;
        wait for PERIOD;
        i := i + 8;
    end loop;
    test_lbus_re <= '0';
    wait for PERIOD;
end read_value;

procedure write_value(
    address : in STD_LOGIC_VECTOR(7 downto 0);
    signal written_value : in STD_LOGIC_VECTOR((data_values_size - 1) downto 0);
    signal test_lbus_wd : out STD_LOGIC_VECTOR(7 downto 0);
    signal test_lbus_we : out STD_LOGIC) is
    variable i : integer;
begin  
    test_lbus_wd <= X"02";
    test_lbus_we <= '1';
    wait for PERIOD;
    test_lbus_we <= '0';
    wait for PERIOD*4;
    test_lbus_we <= '1';
    test_lbus_wd <= address;
    wait for PERIOD;
    i := 7;
    while(i /= (data_values_size + 7)) loop
        test_lbus_we <= '0';
        wait for PERIOD*4;
        test_lbus_we <= '1';
        test_lbus_wd <= written_value(i downto (i-7));
        wait for PERIOD;
        i := i + 8;
    end loop;
    test_lbus_we <= '0';
    wait for PERIOD;
end write_value;

procedure is_free(
    signal current_value : out STD_LOGIC_VECTOR(7 downto 0);
    signal test_lbus_rd : in STD_LOGIC_VECTOR(7 downto 0);
    signal test_lbus_re : out STD_LOGIC;
    signal test_lbus_wd : out STD_LOGIC_VECTOR(7 downto 0);
    signal test_lbus_we : out STD_LOGIC) is
begin
    test_lbus_wd <= X"04";
    test_lbus_we <= '1';
    wait for PERIOD;
    test_lbus_we <= '0';
    wait for PERIOD*3;
    test_lbus_re <= '1';
    current_value <= test_lbus_rd;
    test_lbus_wd <= X"00";
    wait for PERIOD;
end is_free;

begin

test : fr_cipher_sakura
    Port Map(
        lbus_rstn => test_lbus_rstn,
        lbus_clk => clk,
        lbus_rdy => test_lbus_rdy, 
        lbus_wd => test_lbus_wd,
        lbus_we => test_lbus_we,
        lbus_ful => test_lbus_ful,
        lbus_aful => test_lbus_aful,
        lbus_rd => test_lbus_rd,
        lbus_re => test_lbus_re,
        lbus_emp => test_lbus_emp,
        lbus_aemp => test_lbus_aemp,
        TRGOUTn => test_TRGOUTn,
        led => test_led,
        M_HEADER => test_M_HEADER,
        M_CLK_EXT0_P => test_M_CLK_EXT0_P,
        FTDI_BCBUS0_RXF_B => test_FTDI_BCBUS0_RXF_B,
        FTDI_BCBUS1_TXE_B => test_FTDI_BCBUS1_TXE_B,
        FTDI_BCBUS2_RD_B => test_FTDI_BCBUS2_RD_B,
        FTDI_BCBUS3_WR_B => test_FTDI_BCBUS3_WR_B,
        FTDI_BDBUS_D => test_FTDI_BDBUS_D,
        PORT_B_RXF => test_PORT_B_RXF,
        PORT_B_TXE => test_PORT_B_TXE,
        PORT_B_RD => test_PORT_B_RD,
        PORT_B_WR => test_PORT_B_WR,
        PORT_B_DIN => test_PORT_B_DIN,
        PORT_B_DOUT => test_PORT_B_DOUT,
        PORT_B_OEn => test_PORT_B_OEn
  );
  
clock_generation : process
    begin
        while(not testbench_finish) loop
            clk <= not clk;
            wait for PERIOD/2;
        end loop;
        wait;
    end process;

process
    variable test_number : integer;
    begin
        test_number := 0;
        
        test_error <= '0';
        test_lbus_rstn <= '0';
        test_lbus_wd <= X"00";
        test_lbus_we <= '0';
        test_lbus_re <= '0';
        
        test_FTDI_BCBUS0_RXF_B <= '0';
        test_FTDI_BCBUS1_TXE_B <= '0';
        test_PORT_B_RD <= '0';
        test_PORT_B_WR <= '0';
        test_PORT_B_DIN <= X"00";
        test_PORT_B_OEn <= '1';
        
        response_test <= (others => '0');
        
        processor_free <= (others => '0');
        
        wait for testbench_delay;
        wait for PERIOD;
        test_lbus_rstn <= '1';
        wait until test_lbus_rdy = '1';
        wait for testbench_delay;
        write_value(X"00", original_data(test_number), test_lbus_wd, test_lbus_we);
        wait for PERIOD*4;
        write_value(X"01", original_key1(test_number), test_lbus_wd, test_lbus_we);
        wait for PERIOD*4;
        write_value(X"02", original_key2(test_number), test_lbus_wd, test_lbus_we);
        wait for PERIOD*4;
        test_error <= '0';
        read_value(X"00", response_test, test_lbus_rd, test_lbus_re, test_lbus_wd, test_lbus_we);
        wait for PERIOD;
        if(response_test /= original_data(test_number)) then
            test_error <= '1';
        else
            test_error <= '0';
        end if;
        wait for PERIOD;
        test_error <= '0';
        read_value(X"01", response_test, test_lbus_rd, test_lbus_re, test_lbus_wd, test_lbus_we);
        wait for PERIOD;
        if(response_test /= original_key1(test_number)) then
            test_error <= '1';
        else
            test_error <= '0';
        end if;
        wait for PERIOD;
        test_error <= '0';
        read_value(X"02", response_test, test_lbus_rd, test_lbus_re, test_lbus_wd, test_lbus_we);
        wait for PERIOD;
        if(response_test /= original_key2(test_number)) then
            test_error <= '1';
        else
            test_error <= '0';
        end if;
        wait for PERIOD;
        test_error <= '0';
        test_lbus_wd <= X"03";
        test_lbus_we <= '1';
        wait for PERIOD;
        test_lbus_wd <= X"00";
        test_lbus_we <= '0';
        wait until test_lbus_ful = '0';
        wait for testbench_delay;
        is_free(processor_free, test_lbus_rd, test_lbus_re, test_lbus_wd, test_lbus_we);
        wait for PERIOD;
        test_lbus_re <= '0';
        test_lbus_wd <= X"04";
        test_lbus_we <= '1';
        wait for PERIOD;
        test_lbus_we <= '0';
        wait for PERIOD*2;
        test_lbus_re <= '1';
        test_lbus_wd <= X"00";
        wait until test_lbus_ful = '0';
        wait for testbench_delay;
        test_lbus_re <= '0';
        test_lbus_wd <= X"04";
        test_lbus_we <= '1';
        wait for PERIOD;
        test_lbus_we <= '0';
        wait for PERIOD*2;
        test_lbus_re <= '1';
        test_lbus_wd <= X"00";
        wait for PERIOD;
        while(processor_free = X"FE") loop
            is_free(processor_free, test_lbus_rd, test_lbus_re, test_lbus_wd, test_lbus_we);
            wait for PERIOD*10;
        end loop;
        test_lbus_re <= '0';
        test_lbus_wd <= X"04";
        test_lbus_we <= '1';
        wait for PERIOD;
        test_lbus_we <= '0';
        wait for PERIOD*2;
        test_lbus_re <= '1';
        test_lbus_wd <= X"00";
        wait until test_lbus_ful = '0';
        wait for testbench_delay;
        read_value(X"04", response_ciphertext1, test_lbus_rd, test_lbus_re, test_lbus_wd, test_lbus_we);
        wait for PERIOD;
        if(response_ciphertext1 /= original_ciphertext1(test_number)) then
            test_error <= '1';
            report "Value c1 is wrong";
        else
            test_error <= '0';
        end if;
        wait for PERIOD;
        test_error <= '0';
        read_value(X"05", response_ciphertext2, test_lbus_rd, test_lbus_re, test_lbus_wd, test_lbus_we);
        wait for PERIOD;
        if(response_ciphertext2 /= original_ciphertext2(test_number)) then
            test_error <= '1';
            report "Value c2 is wrong";
        else
            test_error <= '0';
        end if;
        wait for PERIOD;
        test_error <= '0';
        read_value(X"06", response_ciphertext3, test_lbus_rd, test_lbus_re, test_lbus_wd, test_lbus_we);
        wait for PERIOD;
        if(response_ciphertext3 /= original_ciphertext3(test_number)) then
            test_error <= '1';
            report "Value c3 is wrong";
        else
            test_error <= '0';
        end if;
        wait for PERIOD;
        test_error <= '0';
        wait for PERIOD;
        test_lbus_re <= '0';
        wait for PERIOD;
        testbench_finish <= true;
        wait;
    end process;


end Behavioral;