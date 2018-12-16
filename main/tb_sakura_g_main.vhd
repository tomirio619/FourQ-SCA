library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.constants.all;
use WORK.tb_sakura_g_main_constants.all;
use WORK.tb_sakura_g_main_procedures.all;
use WORK.image_pkg.all;

entity tb_sakura_g_main is

end tb_sakura_g_main;

architecture behavioral of tb_sakura_g_main is

component sakura_g_main
Port(
        lbus_rstn_i                 : in STD_LOGIC;                         -- Reset from Control FPGA                                                              
        lbus_clk_i                  : in STD_LOGIC;                         -- Clock from Control FPGA                                                              
                                                                                            
        lbus_rdy_io                 : inout STD_LOGIC;                      -- Device ready                                         
        lbus_wd_i                   : in STD_LOGIC_VECTOR(7 downto 0);      -- Local bus data input                                                         
        lbus_we_i                   : in STD_LOGIC;                         -- Data write enable 
        wait_read_effective_done    : out STD_LOGIC;                                       
        lbus_full_o                 : out STD_LOGIC;                        -- Data write ready low                                         
        lbus_afull_o                : out STD_LOGIC;                        -- Data near write end                                          
        lbus_rd_o                   : out STD_LOGIC_VECTOR(7 downto 0);     -- Data output                                                          
        lbus_re_i                   : in STD_LOGIC;                         -- Data read enable                           
        lbus_emp_o                  : out STD_LOGIC;                        -- Data read ready low                                          
        lbus_aemp_o                 : out STD_LOGIC;                        -- Data near read end                                           
        trgoutn_o                   : out STD_LOGIC;                        -- AES start trigger (SAKURA-G Only)                                            
            
        -- led_o display                                                                        
        led_o                       : out STD_LOGIC_VECTOR(9 downto 0);     -- M_LED (led_o[8], led_o[9] SAKURA-G Only)                                                         
            
        -- Trigger output                                                           
        m_header_o                  : out STD_LOGIC_VECTOR(2 downto 0);     -- User Header Pin (SAKURA-G Only)                                                          
        m_clk_ext0_p_o              : out STD_LOGIC;                        -- J4 SMA AES start (SAKURA-G Only)                                         
            
        -- FTDI USB interface portB (SAKURA-G Only)
        -- FTDI side                                                        
        ftdi_bcbus0_rxf_b_i         : in STD_LOGIC;                                                                 
        ftdi_bcbus1_txe_b_i         : in STD_LOGIC;                                                                 
        ftdi_bcbus2_rd_b_o          : out STD_LOGIC;                                                                    
        ftdi_bcbus3_wr_b_o          : out STD_LOGIC;                                                                    
        ftdi_bdbus_d_io             : inout STD_LOGIC_VECTOR(7 downto 0);                                                                   
            
        -- FTDI USB interface portB (SAKURA-G Only)
        -- Control FPGA side                                                                
        port_b_rxf_o                : out STD_LOGIC;                                                                    
        port_b_txe_o                : out STD_LOGIC;                                                                    
        port_b_rd_i                 : in STD_LOGIC;                                                                 
        port_b_wr_i                 : in STD_LOGIC;                                                                 
        port_b_din_i                : in STD_LOGIC_VECTOR(7 downto 0);                                                                  
        port_b_dout_o               : out STD_LOGIC_VECTOR(7 downto 0);                                                                 
        port_b_oen_i                : in STD_LOGIC                                                               
    );
end component;

signal test_lbus_rstn_i                        : STD_LOGIC;                                     
signal test_lbus_rdy_io                        : STD_LOGIC;                   
signal test_lbus_wd_i                          : STD_LOGIC_VECTOR(7 downto 0);   
signal test_lbus_we_i                          : STD_LOGIC; 
signal wait_read_effective_done                : STD_LOGIC;
signal test_lbus_full_o                        : STD_LOGIC;                     
signal test_lbus_afull_o                       : STD_LOGIC;                     
signal test_lbus_rd_o                          : STD_LOGIC_VECTOR(7 downto 0);  
signal test_lbus_re_i                          : STD_LOGIC;                                          
signal test_lbus_emp_o                         : STD_LOGIC;                     
signal test_lbus_aemp_o                        : STD_LOGIC;                     
signal test_trgoutn_o                          : STD_LOGIC;                                                                    
signal test_led_o                              : STD_LOGIC_VECTOR(9 downto 0);                                                 
signal test_m_header_o                         : STD_LOGIC_VECTOR(2 downto 0);  
signal test_m_clk_ext0_p_o                     : STD_LOGIC;                                                           
signal test_ftdi_bcbus0_rxf_b_i                : STD_LOGIC;                      
signal test_ftdi_bcbus1_txe_b_i                : STD_LOGIC;                      
signal test_ftdi_bcbus2_rd_b_o                 : STD_LOGIC;                     
signal test_ftdi_bcbus3_wr_b_o                 : STD_LOGIC;                     
signal test_ftdi_bdbus_d_io                    : STD_LOGIC_VECTOR(7 downto 0);                                             
signal test_port_b_rxf_o                       : STD_LOGIC;                     
signal test_port_b_txe_o                       : STD_LOGIC;                     
signal test_port_b_rd_i                        : STD_LOGIC;                      
signal test_port_b_wr_i                        : STD_LOGIC;                      
signal test_port_b_din_i                       : STD_LOGIC_VECTOR(7 downto 0);   
signal test_port_b_dout_o                      : STD_LOGIC_VECTOR(7 downto 0);  
signal test_port_b_oen_i                       : STD_LOGIC;                       

signal clk : STD_LOGIC := '0';
signal testbench_finish : boolean := false;
constant testbench_delay : time := 2*PERIOD/4;
signal test_error : STD_LOGIC := '0';

signal input_test       : STD_LOGIC_VECTOR(15 downto 0);
signal response_test    : STD_LOGIC_VECTOR((data_size - 1) downto 0);
signal expected_response_test : STD_LOGIC_VECTOR(data_size - 1 downto 0);
signal response_d_bytes : STD_LOGIC_VECTOR((data_values_size - 1) downto 0);
signal response_fault_detection : STD_LOGIC_VECTOR(7 downto 0);

signal test_vectors : values(0 to 1) := (x"AABBCCDDEEFF1122", x"1122334455667788");

-- FourQ (wrapper) specific signals
signal rom_value_upper, rom_value_lower : STD_LOGIC_VECTOR((data_values_size - 1) downto 0) := (others => '0');

signal internal_write_addresses : address_values(0 to 3) := (x"0140", x"0142", x"0144", x"0146");
signal internal_read_input_reg_addresses : address_values(0 to 3) := (x"0296", x"0298", x"029a", x"029c");
signal internal_read_output_reg_addresses: address_values (0 to 3) := (x"0186", x"0188", x"018a", x"018c");
signal internal_read_control_signals_address  : STD_LOGIC_VECTOR((address_size - 1) downto 0);

signal internal_we_address : STD_LOGIC_VECTOR((address_size - 1) downto 0);
signal internal_oper_address : STD_LOGIC_VECTOR((address_size - 1) downto 0);
signal internal_rom_address : STD_LOGIC_VECTOR((address_size - 1) downto 0);
signal internal_data_starting_address : STD_LOGIC_VECTOR((address_size - 1) downto 0);

signal internal_we_address_value : STD_LOGIC_VECTOR((data_size - 1) downto 0);
signal internal_rom_address_value : STD_LOGIC_VECTOR((data_size - 1) downto 0);

signal cur_addr, next_addr : STD_LOGIC_VECTOR((bus_size - 1) downto 0);
signal address : STD_LOGIC_VECTOR((address_size - 1) downto 0);
signal table_value : STD_LOGIC_VECTOR((data_values_size - 1) downto 0);
signal data_to_write : STD_LOGIC_VECTOR((data_size - 1) downto 0);
signal tmp_data_read : STD_LOGIC_VECTOR((data_size -1) downto 0);
signal data_read_all : STD_LOGIC_VECTOR((data_values_size - 1) downto 0);
signal expected_data_read_all : STD_LOGIC_VECTOR((data_values_size - 1) downto 0);
signal all_zeros : STD_LOGIC_VECTOR((data_values_size - 1) downto 0) := (others => '0');


type debug_state is (INIT, INIT_RAM, WRITE_TABLE_VALUES, READ_RESULTS);
type iter_state is (NONE, ITER0, ITER1, ITER2, ITER3, ITER4, ITER5, ITER6, ITER7, ITER8);
signal cur_debug_state : debug_state;
signal cur_iter_state : iter_state;

begin

---------
-- UUT --
---------

test : sakura_g_main
    Port Map(
    lbus_rstn_i             => test_lbus_rstn_i,          
    lbus_clk_i              => clk,           
    lbus_rdy_io             => test_lbus_rdy_io,          
    lbus_wd_i               => test_lbus_wd_i,            
    lbus_we_i               => test_lbus_we_i,
    wait_read_effective_done => wait_read_effective_done,          
    lbus_full_o             => test_lbus_full_o,          
    lbus_afull_o            => test_lbus_afull_o,         
    lbus_rd_o               => test_lbus_rd_o,            
    lbus_re_i               => test_lbus_re_i,                     
    lbus_emp_o              => test_lbus_emp_o,           
    lbus_aemp_o             => test_lbus_aemp_o,          
    trgoutn_o               => test_trgoutn_o,                    
    led_o                   => test_led_o,                      
    m_header_o              => test_m_header_o,           
    m_clk_ext0_p_o          => test_m_clk_ext0_p_o,            
    ftdi_bcbus0_rxf_b_i     => test_ftdi_bcbus0_rxf_b_i,  
    ftdi_bcbus1_txe_b_i     => test_ftdi_bcbus1_txe_b_i,  
    ftdi_bcbus2_rd_b_o      => test_ftdi_bcbus2_rd_b_o,   
    ftdi_bcbus3_wr_b_o      => test_ftdi_bcbus3_wr_b_o,   
    ftdi_bdbus_d_io         => test_ftdi_bdbus_d_io,          
    port_b_rxf_o            => test_port_b_rxf_o,         
    port_b_txe_o            => test_port_b_txe_o,         
    port_b_rd_i             => test_port_b_rd_i,          
    port_b_wr_i             => test_port_b_wr_i,          
    port_b_din_i            => test_port_b_din_i,         
    port_b_dout_o           => test_port_b_dout_o,        
    port_b_oen_i            => test_port_b_oen_i        
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
    variable test_number : integer := 0;
    variable i : integer := 0;
    variable ctr : integer := 0;
    variable test_case_nr : integer := 0;
    variable table : values(0 to 39);
    variable time_begin : time;
    variable time_end : time;
    variable test_read_write : boolean := false;
    begin
        test_number := 0;
        
        test_error <= '0';
        test_lbus_rstn_i <= '0';
        test_lbus_wd_i <= X"00";
        test_lbus_we_i <= '0';
        test_lbus_re_i <= '0';
        
        test_ftdi_bcbus0_rxf_b_i <= '0';
        test_ftdi_bcbus1_txe_b_i <= '0';
        test_port_b_rd_i <= '0';
        test_port_b_wr_i <= '0';
        test_port_b_din_i <= X"00";
        test_port_b_oen_i <= '1';
        
        input_test <= (others => '0');
        response_test <= (others => '0');
        
        wait for testbench_delay;
        wait for PERIOD;
        test_lbus_rstn_i <= '1';
        wait until test_lbus_rdy_io = '1';
        wait for testbench_delay;

        -----------------------------------------
        -- Test basic read/write functionality --
        -----------------------------------------
        if test_read_write then
            report "[*] Test basic read/write functionality" severity note;
            -- Write test value
            report "[*] Testing write and read of value" severity note;
            i := data_values_size;
            ctr := 0;
            while (i /= 0) loop
                write_value(internal_write_addresses(ctr), test_vectors(test_case_nr)((i - 1) downto (i - 16)), test_lbus_wd_i, test_lbus_we_i);
                wait for PERIOD*4;
                i := i - 16;
                ctr := ctr + 1;
            end loop;
            -- Read test value
            i := data_values_size;
            ctr := 0;
            while(i /= 0) loop
                read_value(internal_read_input_reg_addresses(ctr), response_test, test_lbus_rd_o, test_lbus_re_i, test_lbus_wd_i, test_lbus_we_i, wait_read_effective_done);
                expected_response_test <= test_vectors(test_case_nr)((i - 1) downto (i - 16));
                wait for PERIOD*4;
                if (response_test /= expected_response_test) then
                    report "Response did not match expected value:" severity note;
                    report "response:" & HexImage(response_test) severity note;
                    report "expected:" & HexImage(expected_response_test) severity note;
                    test_error <= '1';
                    wait for PERIOD;
                end if;
                i := i - 16;
                ctr := ctr + 1;
                test_error <= '0';
            end loop;
            test_lbus_re_i <= '0';
            wait for PERIOD;
            report "[*] End of test" severity note;

            -- 64 bits writing test
            report "[*] Testing write and read of value (64 bits)" severity note;
            rom_value_lower <= test_vectors(test_case_nr);
            rom_value_upper <= (others => '0');
            internal_rom_address_value <= (others => '0');
            wait for PERIOD;
            write_value64(internal_write_addresses, rom_value_lower, internal_rom_address, internal_rom_address_value, internal_we_address, internal_we_address_value, test_lbus_wd_i, test_lbus_we_i);

            -- 64 bits reading test
            read_value64(internal_read_input_reg_addresses, tmp_data_read, data_read_all, test_lbus_rd_o, test_lbus_re_i, test_lbus_wd_i, test_lbus_we_i, wait_read_effective_done);
            if data_read_all /= rom_value_lower then
                report "Response did not match expected value:" severity note;
                report "response:" & HexImage(data_read_all) severity note;
                report "expected:" & HexImage(rom_value_lower) severity note;
            end if;
             report "[*] End of test" severity note;

            -- Testing done
            testbench_finish <= true;
            wait for PERIOD;
        end if;

        cur_debug_state <= INIT;
        cur_iter_state <= NONE;

        -- Reset
        test_lbus_rstn_i <= '0';
        wait for PERIOD*5;
        test_lbus_rstn_i <= '1';
        wait until test_lbus_rdy_io = '1';
        wait for PERIOD;

        -------------------------
        -- Test FourQ instance --
        -------------------------

        -- Set internal addresses
        internal_we_address  <= x"0002";            -- internal address for writing the Write enable (i.e. data valid) signal
        internal_oper_address <= x"0136";           -- internal address for writing the operand signal
        internal_rom_address <= x"0138";            -- internal address for writing the rom address signal
        internal_data_starting_address <= x"0140";  -- internal starting address for writing the data register (from 0x0140 to 0x0146)
        internal_read_control_signals_address <= x"0001";
        internal_we_address_value <= x"0002";

        -- Init RAM constants (OK)
        cur_debug_state <= INIT_RAM;
        
        for i in 0 to 35 loop
            -- Lower part
            internal_rom_address_value <= fourq_ram_constants_addresses(i) & x"00";
            rom_value_lower <= fourq_ram_constants_values_lower_64(i);
            wait for PERIOD;
            write_value64(internal_write_addresses, rom_value_lower, internal_rom_address, internal_rom_address_value, internal_we_address, internal_we_address_value, test_lbus_wd_i, test_lbus_we_i);
            -- Upper part
            internal_rom_address_value <= fourq_ram_constants_addresses(i) & x"01";
            rom_value_upper <= fourq_ram_constants_values_upper_64(i);
            wait for PERIOD;
            write_value64(internal_write_addresses, rom_value_upper, internal_rom_address, internal_rom_address_value, internal_we_address, internal_we_address_value, test_lbus_wd_i, test_lbus_we_i);
        end loop;

        -- Enter main loop
        report "Start of test without CFK " severity note;
        for i in 0 to 9 loop
            report "Start of test using test vector " & integer'image(i) severity note;
            time_begin := now;

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
                    when 0 => 
                        if SCALAR_IS_DECOMPOSED = true then
                            table := keys_decomp;
                        else
                            table := keys;
                        end if;
                    when 2 => table := b_xcoords;
                    when 4 => table := b_ycoords;
                    when others => null;
                end case;
                cur_addr <= scalar_and_base_point_addresses(ctr);
                next_addr <= scalar_and_base_point_addresses(ctr + 1);

                wait for PERIOD;
                table_value <= table(4*i);
                internal_rom_address_value <= cur_addr & x"00";
                wait for PERIOD;
                write_value64(internal_write_addresses, table_value, internal_rom_address, internal_rom_address_value, internal_we_address, internal_we_address_value, test_lbus_wd_i, test_lbus_we_i);
               
                wait for PERIOD;
                table_value <= table(4*i + 1);
                internal_rom_address_value <= cur_addr & x"01";
                wait for PERIOD;
                write_value64(internal_write_addresses, table_value, internal_rom_address, internal_rom_address_value, internal_we_address, internal_we_address_value, test_lbus_wd_i, test_lbus_we_i);
                
                wait for PERIOD;
                table_value <= table(4*i + 2);
                internal_rom_address_value <= next_addr & x"00";
                wait for PERIOD;
                write_value64(internal_write_addresses, table_value, internal_rom_address, internal_rom_address_value, internal_we_address, internal_we_address_value, test_lbus_wd_i, test_lbus_we_i);
                
                wait for PERIOD;
                table_value <= table(4*i + 3);
                internal_rom_address_value <= next_addr & x"01";
                wait for PERIOD;
                write_value64(internal_write_addresses, table_value, internal_rom_address, internal_rom_address_value, internal_we_address, internal_we_address_value, test_lbus_wd_i, test_lbus_we_i);
                
                ctr := ctr + 2;
            end loop;

            -- Set values to zero and wait for five periods
            internal_rom_address_value <= (others => '0');
            rom_value_lower <= (others => '0');
            rom_value_upper <= (others => '0');
            wait for PERIOD;
            -- write_value64(internal_write_addresses, all_zeros, internal_rom_address, internal_rom_address_value, internal_we_address, internal_we_address_value, test_lbus_wd_i, test_lbus_we_i);
            wait for PERIOD*10;
            
            -- Initialize (changes internal operation to 0x01)
            data_to_write <= x"0001";
            wait for PERIOD;
            write_value(internal_oper_address, data_to_write, test_lbus_wd_i, test_lbus_we_i);

            -- Wait until ready
            wait_until_ready(internal_read_control_signals_address, tmp_data_read, test_lbus_rd_o, test_lbus_re_i, test_lbus_wd_i, test_lbus_we_i, wait_read_effective_done);
            
            -- Precomputation + Scalar multiplication + Affine
            -- Internal operation to 0x02
            data_to_write <= x"0002";       
            wait for PERIOD;
            write_value(internal_oper_address, data_to_write, test_lbus_wd_i, test_lbus_we_i);
                      
            -- Wait until ready
            wait_until_ready(internal_read_control_signals_address, tmp_data_read, test_lbus_rd_o, test_lbus_re_i, test_lbus_wd_i, test_lbus_we_i, wait_read_effective_done);

            table := r_xcoords;
            cur_debug_state <= READ_RESULTS;

            -- Read result point and compare
            -- X0(0)
            data_to_write <= x"02" & x"00";
            wait for PERIOD;
            write_value(internal_rom_address, data_to_write, test_lbus_wd_i, test_lbus_we_i);
            read_value64(internal_read_output_reg_addresses, tmp_data_read, data_read_all, test_lbus_rd_o, test_lbus_re_i, test_lbus_wd_i, test_lbus_we_i, wait_read_effective_done);
            expected_data_read_all <= table(4 * i);
            wait for PERIOD; 
            if data_read_all /= expected_data_read_all then
                report "Incorrect x-coord[0,0]!" severity note; test_error <= '1'; wait for PERIOD; test_error <= '0';
                report "response:" & HexImage(data_read_all) severity note;
                report "expected:" & HexImage(expected_data_read_all) severity note;
            end if;

            -- X0(1)
            data_to_write <= x"02" & x"01";
            wait for PERIOD;
            write_value(internal_rom_address, data_to_write, test_lbus_wd_i, test_lbus_we_i); 
            read_value64(internal_read_output_reg_addresses, tmp_data_read, data_read_all, test_lbus_rd_o, test_lbus_re_i, test_lbus_wd_i, test_lbus_we_i, wait_read_effective_done);
            expected_data_read_all <= table(4 * i + 1);
            wait for PERIOD; 
            if data_read_all /= expected_data_read_all then
                report "Incorrect x-coord[0,1]!" severity note; test_error <= '1'; wait for PERIOD; test_error <= '0';
                report "response:" & HexImage(data_read_all) severity note;
                report "expected:" & HexImage(expected_data_read_all) severity note;
            end if;
            
            -- X1(0)
            data_to_write <= x"03" & x"00";
            wait for PERIOD;
            write_value(internal_rom_address, data_to_write, test_lbus_wd_i, test_lbus_we_i);
            read_value64(internal_read_output_reg_addresses, tmp_data_read, data_read_all, test_lbus_rd_o, test_lbus_re_i, test_lbus_wd_i, test_lbus_we_i, wait_read_effective_done);
            expected_data_read_all <= table(4 * i + 2);
            wait for PERIOD; 
            if data_read_all /= expected_data_read_all then
                report "Incorrect x-coord[1,0]!" severity note; test_error <= '1'; wait for PERIOD; test_error <= '0';
                report "response:" & HexImage(data_read_all) severity note;
                report "expected:" & HexImage(expected_data_read_all) severity note;
            end if;
            
            -- X1(1)
            data_to_write <= x"03" & x"01";
            wait for PERIOD;
            write_value(internal_rom_address, data_to_write, test_lbus_wd_i, test_lbus_we_i);  
            read_value64(internal_read_output_reg_addresses, tmp_data_read, data_read_all, test_lbus_rd_o, test_lbus_re_i, test_lbus_wd_i, test_lbus_we_i, wait_read_effective_done);
            expected_data_read_all <= table(4 * i + 3);
            wait for PERIOD;
            if data_read_all /= expected_data_read_all then
                report "Incorrect x-coord[1,1]!" severity note; test_error <= '1'; wait for PERIOD; test_error <= '0';
                report "response:" & HexImage(data_read_all) severity note;
                report "expected:" & HexImage(expected_data_read_all) severity note;
            end if;
            wait for PERIOD;

            table := r_ycoords;

             -- Y0[0]
            data_to_write <= x"04" & x"00";
            wait for PERIOD;
            write_value(internal_rom_address, data_to_write, test_lbus_wd_i, test_lbus_we_i);  
            read_value64(internal_read_output_reg_addresses, tmp_data_read, data_read_all, test_lbus_rd_o, test_lbus_re_i, test_lbus_wd_i, test_lbus_we_i, wait_read_effective_done);
            if data_read_all /= table(4 * i) then
                report "Incorrect y-coord[0,0]!" severity note;
                report "response:" & HexImage(data_read_all) severity note;
                report "expected:" & HexImage(expected_data_read_all) severity note;
            end if;
            
            -- Y0[1]
            data_to_write <= x"04" & x"01";
            wait for PERIOD;
            write_value(internal_rom_address, data_to_write, test_lbus_wd_i, test_lbus_we_i);  
            read_value64(internal_read_output_reg_addresses, tmp_data_read,  data_read_all, test_lbus_rd_o, test_lbus_re_i, test_lbus_wd_i, test_lbus_we_i, wait_read_effective_done);
            if data_read_all /= table(4 * i + 1) then
                report "Incorrect y-coord[0,1]!" severity note;
                report "response:" & HexImage(data_read_all) severity note;
                report "expected:" & HexImage(expected_data_read_all) severity note;
            end if;

            
            -- Y1[0]
            data_to_write <= x"05" & x"00";
            wait for PERIOD;
            write_value(internal_rom_address, data_to_write, test_lbus_wd_i, test_lbus_we_i);  
            read_value64(internal_read_output_reg_addresses, tmp_data_read, data_read_all, test_lbus_rd_o, test_lbus_re_i, test_lbus_wd_i, test_lbus_we_i, wait_read_effective_done);
            if data_read_all /= table(4 * i + 2) then
                report "Incorrect y-coord[1,0]!" severity note;
                report "response:" & HexImage(data_read_all) severity note;
                report "expected:" & HexImage(expected_data_read_all) severity note;
            end if;

            -- Y1[1]
            data_to_write <= x"05" & x"01";
            wait for PERIOD;
            write_value(internal_rom_address, data_to_write, test_lbus_wd_i, test_lbus_we_i);  
            read_value64(internal_read_output_reg_addresses, tmp_data_read, data_read_all, test_lbus_rd_o, test_lbus_re_i, test_lbus_wd_i, test_lbus_we_i, wait_read_effective_done);
            if data_read_all /= table(4 * i + 3) then
                report "Incorrect y-coord[1,1]!" severity note;
                report "response:" & HexImage(data_read_all) severity note;
                report "expected:" & HexImage(expected_data_read_all) severity note;
            end if;

            -- Reset reading address
            data_to_write <= x"00" & x"00";
            wait for PERIOD;
            write_value(internal_rom_address, data_to_write, test_lbus_wd_i, test_lbus_we_i);  

            time_end :=  now;
            report "End of test vector " & integer'image(i) severity note;
            report "Elapsed time: " & time'image(time_end - time_begin) severity note;
        end loop;


        report "End of test without CFK" severity note;

        testbench_finish <= true;
        report "Test finished" severity note;
        wait;
    end process;


end behavioral;