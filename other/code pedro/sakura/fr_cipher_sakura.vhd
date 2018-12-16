----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    13:22:17 03/06/2018 
-- Design Name: 
-- Module Name:    fr_cipher_sakura - Behavioral 
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

library UNISIM;
use UNISIM.vcomponents.all;

entity fr_cipher_sakura is
    Port(
    -- lbus
        lbus_rstn : in std_logic;                     -- Reset from Control FPGA
        lbus_clk : in std_logic;                      -- Clock from Control FPGA
    
        lbus_rdy : out std_logic;                     -- Device ready
        lbus_wd : in std_logic_vector(7 downto 0);    -- Local bus data input
        lbus_we : in std_logic;                       -- Data write enable
        lbus_ful : out std_logic;                     -- Data write ready low
        lbus_aful : out std_logic;                    -- Data near write end
        lbus_rd : out std_logic_vector(7 downto 0);   -- Data output
        lbus_re : in std_logic;                       -- Data read enable
        lbus_emp : out std_logic;                     -- Data read ready low
        lbus_aemp : out std_logic;                    -- Data near read end
        TRGOUTn : out std_logic;                      -- Start trigger (SAKURA-G Only)
        led : out std_logic_vector(9 downto 0);       -- M_LED (led[8], led[9] SAKURA-G Only)
  -- Trigger output
        M_HEADER : out std_logic_vector(2 downto 0);  -- User Header Pin (SAKURA-G Only)
        M_CLK_EXT0_P : out std_logic;                 -- J4 SMA  AES start (SAKURA-G Only)

  -- FTDI USB interface portB (SAKURA-G Only)
  -- FTDI side
        FTDI_BCBUS0_RXF_B : in std_logic;
        FTDI_BCBUS1_TXE_B : in std_logic;
        FTDI_BCBUS2_RD_B : out std_logic; 
        FTDI_BCBUS3_WR_B : out std_logic; 
        FTDI_BDBUS_D : inout std_logic_vector(7 downto 0);

  -- FTDI USB interface portB (SAKURA-G Only)
  -- Control FPGA side
        PORT_B_RXF : out std_logic;
        PORT_B_TXE : out std_logic;
        PORT_B_RD : in std_logic;
        PORT_B_WR : in std_logic;
        PORT_B_DIN : in std_logic_vector(7 downto 0);
        PORT_B_DOUT : out std_logic_vector(7 downto 0);
        PORT_B_OEn : in std_logic
  );
end fr_cipher_sakura;

architecture behavioral of fr_cipher_sakura is

component fr_cipher
    port(data:  in std_logic_vector(127 downto 0);
         key1:   in std_logic_vector(127 downto 0);
         key2:   in std_logic_vector(127 downto 0);
         clk:    in std_logic;
         reset:  in std_logic;
         ciphertext1: out std_logic_vector(127 downto 0);
         ciphertext2: out std_logic_vector(127 downto 0);
         ciphertext3: out std_logic_vector(127 downto 0);
         fault_detected:  out std_logic;
         operation_finished : out std_logic
         );
end component;

component controller_sakura_commands
    port(
        clk : in std_logic;
        rstn : in std_logic;
        fr_cipher_operation_finished : in std_logic;
        fr_cipher_reset : in std_logic;
        fr_cipher_start_computation : out std_logic;
        fr_cipher_input_enable : out std_logic;
        fr_cipher_in_out_address_enable : out std_logic;
        lbus_wd : in std_logic_vector(7 downto 0);    
        lbus_we : in std_logic;                       
        lbus_rdy : out std_logic;                     
        lbus_ful : out std_logic;                     
        lbus_aful : out std_logic;                    
        lbus_rd : out std_logic_vector(7 downto 0);   
        lbus_re : in std_logic;                       
        lbus_emp : out std_logic;                     
        lbus_aemp : out std_logic;
        shr_data_in_enable : out std_logic;
        shr_data_out_enable : out std_logic;
        shr_data_out_load : out std_logic;
        data_from_controller : out std_logic;
        limit_count_stages : in std_logic;
        count_shr_stages_rst : out std_logic;
        count_shr_stages_enable : out std_logic;
        count_shr_stages_data_in : out std_logic
    );
end component;

signal internal_clock : std_logic;

signal fr_cipher_data : std_logic_vector(127 downto 0);
signal fr_cipher_key1 : std_logic_vector(127 downto 0);
signal fr_cipher_key2 : std_logic_vector(127 downto 0);
signal fr_cipher_clk : std_logic;
signal fr_cipher_reset : std_logic;
signal fr_cipher_ciphertext1 : std_logic_vector(127 downto 0);
signal fr_cipher_ciphertext2 : std_logic_vector(127 downto 0);
signal fr_cipher_ciphertext3 : std_logic_vector(127 downto 0);
signal fr_cipher_fault_detected : std_logic;
signal fr_cipher_operation_finished : std_logic;

signal fr_cipher_start_computation : std_logic;

signal fr_cipher_input_enable : std_logic;

signal fr_cipher_in_out_address : std_logic_vector(2 downto 0);
signal fr_cipher_in_out_address_enable : std_logic;

signal reg_fr_cipher_ciphertext1 : std_logic_vector(127 downto 0);
signal reg_fr_cipher_ciphertext2 : std_logic_vector(127 downto 0);
signal reg_fr_cipher_ciphertext3 : std_logic_vector(127 downto 0);
signal reg_fr_cipher_fault_detected : std_logic;

signal fr_cipher_output_bus : std_logic_vector(127 downto 0);

signal buf_lbus_we : std_logic;
signal buf_lbus_re : std_logic;
signal buf_lbus_wd : std_logic_vector(7 downto 0);

signal reg_lbus_rd : std_logic_vector(7 downto 0);

signal controller_lbus_rd : std_logic_vector(7 downto 0);
signal ecp_memory_addr_in_out_enable : std_logic;
signal data_from_controller : std_logic;
signal limit_count_stages : std_logic;

signal shr_data_in : std_logic_vector(127 downto 0);
signal shr_data_in_enable : std_logic;
signal shr_data_out : std_logic_vector(127 downto 8);
signal shr_data_out_enable : std_logic;
signal shr_data_out_load : std_logic;

signal count_shr_stages_rst : std_logic;
signal count_shr_stages_enable : std_logic;
signal count_shr_stages_data_in : std_logic;
signal count_stages_value : unsigned(4 downto 0);

begin

cipher : fr_cipher
    port map(
        data => fr_cipher_data,
        key1 => fr_cipher_key1,
        key2 => fr_cipher_key2,
        clk => fr_cipher_clk,
        reset => fr_cipher_reset,
        ciphertext1 => fr_cipher_ciphertext1,
        ciphertext2 => fr_cipher_ciphertext2,
        ciphertext3 => fr_cipher_ciphertext3,
        fault_detected => fr_cipher_fault_detected,
        operation_finished => fr_cipher_operation_finished
    );

fr_cipher_clk <= internal_clock;

controller : controller_sakura_commands
    port map(
        clk => internal_clock,
        rstn => lbus_rstn,
        fr_cipher_operation_finished => fr_cipher_operation_finished,
        fr_cipher_reset => fr_cipher_reset,
        fr_cipher_start_computation => fr_cipher_start_computation,
        fr_cipher_input_enable => fr_cipher_input_enable,
        fr_cipher_in_out_address_enable => fr_cipher_in_out_address_enable,
        lbus_wd => buf_lbus_wd,
        lbus_we => buf_lbus_we,
        lbus_rdy => lbus_rdy,
        lbus_ful => lbus_ful,
        lbus_aful => lbus_aful,
        lbus_rd => controller_lbus_rd,
        lbus_re => buf_lbus_re,
        lbus_emp => lbus_emp,
        lbus_aemp => lbus_aemp,
        shr_data_in_enable => shr_data_in_enable,
        shr_data_out_enable => shr_data_out_enable,
        shr_data_out_load => shr_data_out_load,
        data_from_controller => data_from_controller,
        limit_count_stages => limit_count_stages,
        count_shr_stages_rst => count_shr_stages_rst,
        count_shr_stages_enable => count_shr_stages_enable,
        count_shr_stages_data_in => count_shr_stages_data_in
    );

buf_lbus_control : process(internal_clock, lbus_rstn)
    begin
        if(lbus_rstn = '0') then
            buf_lbus_we <= '0';
            buf_lbus_re <= '0';
            buf_lbus_wd <= (others => '0');
        elsif(rising_edge(internal_clock)) then
            buf_lbus_we <= lbus_we;
            buf_lbus_re <= lbus_re;
            buf_lbus_wd <= lbus_wd;
        end if;
    end process;

reg_lbus_control : process(internal_clock, lbus_rstn)
    begin
        if(lbus_rstn = '0') then
            buf_lbus_we <= '0';
            buf_lbus_re <= '0';
        elsif(rising_edge(internal_clock)) then
            buf_lbus_we <= lbus_we;
            buf_lbus_re <= lbus_re;
        end if;
    end process;

shr_wd : process(internal_clock, lbus_rstn)
    begin
        if(lbus_rstn = '0') then
            shr_data_in <= (others => '0');
        elsif(rising_edge(internal_clock)) then
            if(shr_data_in_enable = '1' and buf_lbus_we = '1') then
                shr_data_in <= buf_lbus_wd & shr_data_in(127 downto 8);
            end if;
        end if;
    end process;
    
reg_fr_cipher_reset : process(internal_clock, lbus_rstn)
    begin
        if(lbus_rstn = '0') then
            fr_cipher_reset <= '1';
        elsif(rising_edge(internal_clock)) then
            if(fr_cipher_start_computation = '1') then
                fr_cipher_reset <= '0';
            elsif(fr_cipher_operation_finished = '1') then
                fr_cipher_reset <= '1';
            else
                null;
            end if;
        end if;
    end process;

reg_fr_cipher_input : process(internal_clock, lbus_rstn)
    begin
        if(lbus_rstn = '0') then
            fr_cipher_data <= (others => '0');
            fr_cipher_key1 <= (others => '0');
            fr_cipher_key2 <= (others => '0');
        elsif(rising_edge(internal_clock)) then
            if(fr_cipher_input_enable = '1') then
                if(fr_cipher_in_out_address = "000") then
                    fr_cipher_data <= shr_data_in;
                elsif(fr_cipher_in_out_address = "001") then
                    fr_cipher_key1 <= shr_data_in;
                elsif(fr_cipher_in_out_address = "010") then
                    fr_cipher_key2 <= shr_data_in;
                end if;
            end if;
        end if;
    end process;
    
reg_fr_cipher_output : process(internal_clock, lbus_rstn)
    begin
        if(lbus_rstn = '0') then
            reg_fr_cipher_ciphertext1 <= (others => '0');
            reg_fr_cipher_ciphertext2 <= (others => '0');
            reg_fr_cipher_ciphertext3 <= (others => '0');
            reg_fr_cipher_fault_detected <= '0';
        elsif(rising_edge(internal_clock)) then
            if(fr_cipher_operation_finished = '1') then
                reg_fr_cipher_ciphertext1 <= fr_cipher_ciphertext1;
                reg_fr_cipher_ciphertext2 <= fr_cipher_ciphertext2;
                reg_fr_cipher_ciphertext3 <= fr_cipher_ciphertext3;
                reg_fr_cipher_fault_detected <= fr_cipher_fault_detected;
            end if;
        end if;
    end process;

fr_cipher_output_bus <= fr_cipher_data when fr_cipher_in_out_address = "000" else
                        fr_cipher_key1 when fr_cipher_in_out_address = "001" else
                        fr_cipher_key2 when fr_cipher_in_out_address = "010" else
                        reg_fr_cipher_ciphertext1 when fr_cipher_in_out_address = "100" else
                        reg_fr_cipher_ciphertext2 when fr_cipher_in_out_address = "101" else
                        reg_fr_cipher_ciphertext3 when fr_cipher_in_out_address = "110" else
                        fr_cipher_ciphertext3;

shr_rd : process(internal_clock, lbus_rstn)
    begin
        if(lbus_rstn = '0') then
            shr_data_out <= (others => '0');
            reg_lbus_rd <= X"00";
        elsif(rising_edge(internal_clock)) then
            if(data_from_controller = '1') then
                shr_data_out <= (others => '0');
                reg_lbus_rd <= controller_lbus_rd;
            else
                if(shr_data_out_load = '1') then
                    if(fr_cipher_in_out_address = "111") then
                        shr_data_out <= (others => '0');
                        reg_lbus_rd(0) <= reg_fr_cipher_fault_detected;
                        reg_lbus_rd(7 downto 1) <= (others => '0');
                    else
                        shr_data_out <= fr_cipher_output_bus(127 downto 8);
                        reg_lbus_rd <= fr_cipher_output_bus(7 downto 0);
                    end if;
                elsif(shr_data_out_enable = '1' and buf_lbus_re = '1' ) then
                    shr_data_out <= X"FF" & shr_data_out(127 downto 16);
                    reg_lbus_rd <= shr_data_out(15 downto 8);
                end if;
            end if;
        end if;
    end process;
    
lbus_rd <= reg_lbus_rd;

reg_fr_cipher_in_out_address : process(internal_clock, lbus_rstn)
    begin
        if(lbus_rstn = '0') then
            fr_cipher_in_out_address <= (others => '0');
        elsif(rising_edge(internal_clock)) then
            if(fr_cipher_in_out_address_enable = '1') then
                fr_cipher_in_out_address <= buf_lbus_wd((fr_cipher_in_out_address'length - 1) downto 0);
            end if;
        end if;
    end process;
    
count_shr_stages : process(internal_clock)
    begin
        if(rising_edge(internal_clock)) then
            if(count_shr_stages_rst = '0') then
                count_stages_value <= to_unsigned(0, count_stages_value'length);
            elsif((count_shr_stages_enable = '1') and (((buf_lbus_we = '1') and (count_shr_stages_data_in = '1')) or ((buf_lbus_re = '1') and (count_shr_stages_data_in = '0')))) then
                count_stages_value <= count_stages_value + 1;
            else
                count_stages_value <= count_stages_value;
            end if;
        end if;
    end process;
    
limit_count_stages <= '1' when (count_stages_value = to_01(to_unsigned(15, count_stages_value'length))) else '0';

---------------------------------------------------------------------------------
-- Clock input driver
---------------------------------------------------------------------------------

IBUFG_inst : IBUFG
    generic map (
        IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
        IOSTANDARD => "DEFAULT")
    port map (
        O => internal_clock, -- Clock buffer output
        I => lbus_clk  -- Clock buffer input (connect directly to top-level port)
   );
--------------------------------------------------------------------------------
-- Triger signals output
--------------------------------------------------------------------------------
  
TRGOUTn <= not fr_cipher_operation_finished;
M_HEADER(0) <= fr_cipher_operation_finished;
M_HEADER(1) <= not fr_cipher_operation_finished;
M_HEADER(2) <= fr_cipher_operation_finished;
M_CLK_EXT0_P <= fr_cipher_operation_finished;


---------------------------------------------------------------------------------
-- LED display outputs
---------------------------------------------------------------------------------
led(0) <= '1';
led(1) <= '1';
led(2) <= '1';
led(3) <= '1';
led(4) <= '1';
led(5) <= '1';
led(6) <= '1';
led(7) <= '1';
led(8) <= '1';
led(9) <= '1';

---------------------------------------------------------------------------------
-- USB PORT B
---------------------------------------------------------------------------------
PORT_B_RXF <= FTDI_BCBUS0_RXF_B;
PORT_B_TXE <= FTDI_BCBUS1_TXE_B;
FTDI_BCBUS2_RD_B <= PORT_B_RD;
FTDI_BCBUS3_WR_B <= PORT_B_WR;
FTDI_BDBUS_D <= PORT_B_DIN when (PORT_B_OEn = '0') else (others => 'Z');
PORT_B_DOUT <= FTDI_BDBUS_D;

end behavioral;

