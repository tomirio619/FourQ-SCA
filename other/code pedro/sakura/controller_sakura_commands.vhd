----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    16:03:06 07/18/2016 
-- Design Name: 
-- Module Name:    controller_sakura_commands - Behavioral 
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

entity controller_sakura_commands is
    Port(
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
end controller_sakura_commands;

architecture Behavioral of controller_sakura_commands is

signal next_fr_cipher_start_computation : std_logic;
signal next_fr_cipher_input_enable : std_logic;
signal next_fr_cipher_in_out_address_enable : std_logic;

signal next_lbus_rdy : std_logic;
signal next_lbus_ful : std_logic;
signal next_lbus_aful : std_logic;
signal next_lbus_rd : std_logic_vector(7 downto 0);
signal next_lbus_emp : std_logic;
signal next_lbus_aemp : std_logic;
signal next_data_from_controller : std_logic;
signal next_count_shr_stages_rst : std_logic;
signal next_count_shr_stages_enable : std_logic;
signal next_count_shr_stages_data_in : std_logic;

signal next_shr_data_in_enable : std_logic;
signal next_shr_data_out_enable : std_logic;
signal next_shr_data_out_load : std_logic;


type State is (reset,idle,
write_value_1, write_value_2, write_value_3,
read_value_1, read_value_2, read_value_3, read_value_4, read_value_5,
is_busy_1, is_busy_2, is_busy_3,
start_fr_cipher_1, start_fr_cipher_2
); 
signal actual_state, next_state : State; 

begin

update_output : process(clk, rstn)
    begin
        if(rstn = '0') then
            actual_state <= reset;
            fr_cipher_start_computation <= '0';
            fr_cipher_input_enable <= '0';
            fr_cipher_in_out_address_enable <= '0';
            lbus_rdy <= '0';
            lbus_ful <= '0';
            lbus_aful <= '0';
            lbus_rd <= X"00"; 
            lbus_emp <= '0';
            lbus_aemp <= '0';
            count_shr_stages_rst <= '0';
            count_shr_stages_enable <= '0';
            count_shr_stages_data_in <= '0';
            data_from_controller <= '0';
            shr_data_in_enable <= '0';
            shr_data_out_enable <= '0';
            shr_data_out_load <= '0';
        elsif(rising_edge(clk)) then
            actual_state <= next_state;
            fr_cipher_start_computation <= next_fr_cipher_start_computation;
            fr_cipher_input_enable <= next_fr_cipher_input_enable;
            fr_cipher_in_out_address_enable <= next_fr_cipher_in_out_address_enable;
            lbus_rdy <= next_lbus_rdy;
            lbus_ful <= next_lbus_ful;
            lbus_aful <= next_lbus_aful;
            lbus_rd <= next_lbus_rd; 
            lbus_emp <= next_lbus_emp;
            lbus_aemp <= next_lbus_aemp;
            count_shr_stages_rst <= next_count_shr_stages_rst;
            count_shr_stages_enable <= next_count_shr_stages_enable;
            count_shr_stages_data_in <= next_count_shr_stages_data_in;
            data_from_controller <= next_data_from_controller;
            shr_data_in_enable <= next_shr_data_in_enable;
            shr_data_out_enable <= next_shr_data_out_enable;
            shr_data_out_load <= next_shr_data_out_load;
        end if;
    end process;

state_output : process(actual_state, lbus_we, lbus_re, lbus_wd, fr_cipher_reset, fr_cipher_operation_finished, limit_count_stages)
    begin
        case(actual_state) is
            when reset => 
                next_fr_cipher_start_computation <= '0';
                next_fr_cipher_input_enable <= '0';
                next_fr_cipher_in_out_address_enable <= '0';
                next_lbus_rdy <= '0';
                next_lbus_ful <= '0';
                next_lbus_aful <= '0';
                next_lbus_rd <= X"00"; 
                next_lbus_emp <= '0';
                next_lbus_aemp <= '0';
                next_count_shr_stages_rst <= '0';
                next_count_shr_stages_enable <= '0';
                next_count_shr_stages_data_in <= '0';
                next_data_from_controller <= '0';
                next_shr_data_in_enable <= '0';
                next_shr_data_out_enable <= '0';
                next_shr_data_out_load <= '0';
            when idle =>
                next_fr_cipher_start_computation <= '0';
                next_fr_cipher_input_enable <= '0';
                next_fr_cipher_in_out_address_enable <= '0';
                next_lbus_rdy <= '1';
                next_lbus_ful <= '0';
                next_lbus_aful <= '1';
                next_lbus_rd <= X"00"; 
                next_lbus_emp <= '1';
                next_lbus_aemp <= '1';
                next_count_shr_stages_rst <= '1';
                next_count_shr_stages_enable <= '0';
                next_count_shr_stages_data_in <= '0';
                next_data_from_controller <= '0';
                next_shr_data_in_enable <= '0';
                next_shr_data_out_enable <= '0';
                next_shr_data_out_load <= '0';
                if(lbus_we = '1') then
                    -- Writing a new value inside the ECP processor
                    if(lbus_wd = X"01") then
                        next_fr_cipher_in_out_address_enable <= '1';
                    -- Reading a value inside the ECP processor
                    elsif(lbus_wd = X"02") then
                        next_fr_cipher_in_out_address_enable <= '1';
                    -- Start ECP computation
                    elsif(lbus_wd = X"03") then
                        next_fr_cipher_start_computation <= '1';
                        next_lbus_ful <= '1';
                    -- Ask if ECP is busy, if not stop computation
                    elsif(lbus_wd = X"04") then
                        next_lbus_ful <= '1';
                    end if;
                end if;
            -- Writing a new value inside the ECP processor
            when write_value_1 =>                          -- Load the address
                next_fr_cipher_start_computation <= '0';
                next_fr_cipher_input_enable <= '0';
                next_fr_cipher_in_out_address_enable <= '1';
                next_lbus_rdy <= '1';
                next_lbus_ful <= '0';
                next_lbus_aful <= '1';
                next_lbus_rd <= X"00"; 
                next_lbus_emp <= '1';
                next_lbus_aemp <= '1';
                next_count_shr_stages_rst <= '1';
                next_count_shr_stages_enable <= '0';
                next_count_shr_stages_data_in <= '0';
                next_data_from_controller <= '0';
                next_shr_data_in_enable <= '0';
                next_shr_data_out_enable <= '0';
                next_shr_data_out_load <= '0';
                if(lbus_we = '1') then
                    next_fr_cipher_in_out_address_enable <= '0';
                    next_count_shr_stages_enable <= '1';
                    next_count_shr_stages_data_in <= '1';
                    next_shr_data_in_enable <= '1';
                end if;
            when write_value_2 =>                          -- Start loading the shift register
                next_fr_cipher_start_computation <= '0';
                next_fr_cipher_input_enable <= '0';
                next_fr_cipher_in_out_address_enable <= '0';
                next_lbus_rdy <= '1';
                next_lbus_ful <= '0';
                next_lbus_aful <= '1';
                next_lbus_rd <= X"00"; 
                next_lbus_emp <= '1';
                next_lbus_aemp <= '1';
                next_count_shr_stages_rst <= '1';
                next_count_shr_stages_enable <= '1';
                next_count_shr_stages_data_in <= '1';
                next_data_from_controller <= '0';
                next_shr_data_in_enable <= '1';
                next_shr_data_out_enable <= '0';
                next_shr_data_out_load <= '0';
                if(limit_count_stages = '1' and lbus_we = '1') then
                    next_fr_cipher_input_enable <= '1';
                    next_lbus_ful <= '1';
                    next_count_shr_stages_rst <= '0';
                    next_count_shr_stages_enable <= '0';
                    next_count_shr_stages_data_in <= '0';
                    next_shr_data_in_enable <= '0';
                end if;
            when write_value_3 =>                         -- Perform memory writing
                next_fr_cipher_start_computation <= '0';
                next_fr_cipher_input_enable <= '1';
                next_fr_cipher_in_out_address_enable <= '0';
                next_lbus_rdy <= '1';
                next_lbus_ful <= '0';
                next_lbus_aful <= '1';
                next_lbus_rd <= X"00"; 
                next_lbus_emp <= '1';
                next_lbus_aemp <= '1';
                next_count_shr_stages_rst <= '0';
                next_count_shr_stages_enable <= '0';
                next_count_shr_stages_data_in <= '0';
                next_data_from_controller <= '0';
                next_shr_data_in_enable <= '0';
                next_shr_data_out_enable <= '0';
                next_shr_data_out_load <= '0';
            -- Reading a value stored in the ECP processor
            when read_value_1 =>
                next_fr_cipher_start_computation <= '0';
                next_fr_cipher_input_enable <= '0';
                next_fr_cipher_in_out_address_enable <= '1';
                next_lbus_rdy <= '1';
                next_lbus_ful <= '0';
                next_lbus_aful <= '1';
                next_lbus_rd <= X"00"; 
                next_lbus_emp <= '1';
                next_lbus_aemp <= '1';
                next_count_shr_stages_rst <= '1';
                next_count_shr_stages_enable <= '0';
                next_count_shr_stages_data_in <= '0';
                next_data_from_controller <= '0';
                next_shr_data_in_enable <= '0';
                next_shr_data_out_enable <= '0';
                next_shr_data_out_load <= '0';
                if(lbus_we = '1') then
                    next_fr_cipher_in_out_address_enable <= '0';
                    next_lbus_ful <= '1';
                end if;
            when read_value_2 =>                          -- Loads shift register in parallel
                next_fr_cipher_start_computation <= '0';
                next_fr_cipher_input_enable <= '0';
                next_fr_cipher_in_out_address_enable <= '0';
                next_lbus_rdy <= '1';
                next_lbus_ful <= '1';
                next_lbus_aful <= '1';
                next_lbus_rd <= X"00"; 
                next_lbus_emp <= '1';
                next_lbus_aemp <= '1';
                next_count_shr_stages_rst <= '1';
                next_count_shr_stages_enable <= '1';
                next_count_shr_stages_data_in <= '0';
                next_data_from_controller <= '0';
                next_shr_data_in_enable <= '0';
                next_shr_data_out_enable <= '1';
                next_shr_data_out_load <= '1';
            when read_value_3 =>                          -- Prepare to push values into the bus
                next_fr_cipher_start_computation <= '0';
                next_fr_cipher_input_enable <= '0';
                next_fr_cipher_in_out_address_enable <= '0';
                next_lbus_rdy <= '1';
                next_lbus_ful <= '1';
                next_lbus_aful <= '1';
                next_lbus_rd <= X"00"; 
                next_lbus_emp <= '1';
                next_lbus_aemp <= '1';
                next_count_shr_stages_rst <= '1';
                next_count_shr_stages_enable <= '1';
                next_count_shr_stages_data_in <= '0';
                next_data_from_controller <= '0';
                next_shr_data_in_enable <= '0';
                next_shr_data_out_enable <= '1';
                next_shr_data_out_load <= '0';
            when read_value_4 =>                          -- Starts writing value on the bus
                next_fr_cipher_start_computation <= '0';
                next_fr_cipher_input_enable <= '0';
                next_fr_cipher_in_out_address_enable <= '0';
                next_lbus_rdy <= '1';
                next_lbus_ful <= '1';
                next_lbus_aful <= '1';
                next_lbus_rd <= X"00"; 
                next_lbus_emp <= '0';
                next_lbus_aemp <= '1';
                next_count_shr_stages_rst <= '1';
                next_count_shr_stages_enable <= '1';
                next_count_shr_stages_data_in <= '0';
                next_data_from_controller <= '0';
                next_shr_data_in_enable <= '0';
                next_shr_data_out_enable <= '1';
                next_shr_data_out_load <= '0';
                if(limit_count_stages = '1') then
                    next_count_shr_stages_enable <= '1';
                    next_shr_data_out_load <= '0';
                    next_lbus_emp <= '1';
                end if;
            when read_value_5 =>                          -- Last values on the bus
                next_fr_cipher_start_computation <= '0';
                next_fr_cipher_input_enable <= '0';
                next_fr_cipher_in_out_address_enable <= '0';
                next_lbus_rdy <= '1';
                next_lbus_ful <= '0';
                next_lbus_aful <= '1';
                next_lbus_rd <= X"00"; 
                next_lbus_emp <= '1';
                next_lbus_aemp <= '1';
                next_count_shr_stages_rst <= '0';
                next_count_shr_stages_enable <= '0';
                next_count_shr_stages_data_in <= '0';
                next_data_from_controller <= '0';
                next_shr_data_in_enable <= '0';
                next_shr_data_out_enable <= '1';
                next_shr_data_out_load <= '0';
            -- Verify if the ECP core is busy
            when is_busy_1 => 
                next_fr_cipher_start_computation <= '0';
                next_fr_cipher_input_enable <= '0';
                next_fr_cipher_in_out_address_enable <= '0';
                next_lbus_rdy <= '1';
                next_lbus_ful <= '1';
                next_lbus_aful <= '1';
                next_lbus_rd <= X"00"; 
                next_lbus_emp <= '1';
                next_lbus_aemp <= '1';
                next_count_shr_stages_rst <= '1';
                next_count_shr_stages_enable <= '0';
                next_count_shr_stages_data_in <= '0';
                next_data_from_controller <= '1';
                next_shr_data_in_enable <= '0';
                next_shr_data_out_enable <= '1';
                next_shr_data_out_load <= '0';
                if((fr_cipher_reset = '0') and (fr_cipher_operation_finished = '0')) then
                    next_lbus_rd <= X"FE"; 
                else
                    next_lbus_rd <= X"01";
                end if;
            when is_busy_2 =>                                   -- The core is not busy
                next_fr_cipher_start_computation <= '0';
                next_fr_cipher_input_enable <= '0';
                next_fr_cipher_in_out_address_enable <= '0';
                next_lbus_rdy <= '1';
                next_lbus_ful <= '1';
                next_lbus_aful <= '1';
                next_lbus_rd <= X"01"; 
                next_lbus_emp <= '0';
                next_lbus_aemp <= '1';
                next_count_shr_stages_rst <= '1';
                next_count_shr_stages_enable <= '0';
                next_count_shr_stages_data_in <= '0';
                next_data_from_controller <= '1';
                next_shr_data_in_enable <= '0';
                next_shr_data_out_enable <= '1';
                next_shr_data_out_load <= '0';
                if(lbus_re = '1') then
                    next_lbus_emp <= '1';
                    next_lbus_ful <= '0';
                end if;
            when is_busy_3 =>                                   -- The core is busy
                next_fr_cipher_start_computation <= '0';
                next_fr_cipher_input_enable <= '0';
                next_fr_cipher_in_out_address_enable <= '0';
                next_lbus_rdy <= '1';
                next_lbus_ful <= '1';
                next_lbus_aful <= '1';
                next_lbus_rd <= X"FE"; 
                next_lbus_emp <= '0';
                next_lbus_aemp <= '1';
                next_count_shr_stages_rst <= '1';
                next_count_shr_stages_enable <= '0';
                next_count_shr_stages_data_in <= '0';
                next_data_from_controller <= '1';
                next_shr_data_in_enable <= '0';
                next_shr_data_out_enable <= '1';
                next_shr_data_out_load <= '0';
                if(lbus_re = '1') then
                    next_lbus_emp <= '1';
                    next_lbus_ful <= '0';
                end if;
            when start_fr_cipher_1 =>
                next_fr_cipher_start_computation <= '1';
                next_fr_cipher_input_enable <= '0';
                next_fr_cipher_in_out_address_enable <= '0';
                next_lbus_rdy <= '1';
                next_lbus_ful <= '1';
                next_lbus_aful <= '1';
                next_lbus_rd <= X"00"; 
                next_lbus_emp <= '1';
                next_lbus_aemp <= '1';
                next_count_shr_stages_rst <= '1';
                next_count_shr_stages_enable <= '0';
                next_count_shr_stages_data_in <= '0';
                next_data_from_controller <= '0';
                next_shr_data_in_enable <= '0';
                next_shr_data_out_enable <= '0';
                next_shr_data_out_load <= '0';
            when start_fr_cipher_2 =>
                next_fr_cipher_start_computation <= '0';
                next_fr_cipher_input_enable <= '0';
                next_fr_cipher_in_out_address_enable <= '0';
                next_lbus_rdy <= '1';
                next_lbus_ful <= '0';
                next_lbus_aful <= '1';
                next_lbus_rd <= X"00"; 
                next_lbus_emp <= '1';
                next_lbus_aemp <= '1';
                next_count_shr_stages_rst <= '1';
                next_count_shr_stages_enable <= '0';
                next_count_shr_stages_data_in <= '0';
                next_data_from_controller <= '0';
                next_shr_data_in_enable <= '0';
                next_shr_data_out_enable <= '0';
                next_shr_data_out_load <= '0';
            --when others =>
            --    next_fr_cipher_start_computation <= '0';
            --    next_fr_cipher_input_enable <= '0';
            --    next_fr_cipher_in_out_address_enable <= '0';
            --    next_lbus_rdy <= '0';
            --    next_lbus_ful <= '0';
            --    next_lbus_aful <= '0';
            --    next_lbus_rd <= X"00"; 
            --    next_lbus_emp <= '0';
            --    next_lbus_aemp <= '0';
            --    next_count_shr_stages_rst <= '1';
            --    next_count_shr_stages_enable <= '0';
            --    next_count_shr_stages_data_in <= '0';
            --    next_data_from_controller <= '0';
            --    next_shr_data_in_enable <= '0';
            --    next_shr_data_out_enable <= '0';
            --    next_shr_data_out_load <= '0';
            end case;
    end process;

update_state : process(actual_state, lbus_we, lbus_wd, lbus_re, fr_cipher_reset, fr_cipher_operation_finished, limit_count_stages) 
    begin
        case(actual_state) is
        when reset => 
            next_state <= idle;
        when idle =>
            if(lbus_we = '1') then
                if(lbus_wd = X"01") then
                    next_state <= read_value_1;
                elsif(lbus_wd = X"02") then
                    next_state <= write_value_1;
                elsif(lbus_wd = X"03") then
                    next_state <= start_fr_cipher_1;
                elsif(lbus_wd = X"04") then
                    next_state <= is_busy_1;
                else
                    next_state <= idle;
                end if;
            else
                next_state <= idle;
            end if;
        when write_value_1 =>
            if(lbus_we = '1') then
                next_state <= write_value_2;
            else
                next_state <= write_value_1;
            end if;
        when write_value_2 =>
            if(limit_count_stages = '1' and lbus_we = '1') then
                next_state <= write_value_3;
            else
                next_state <= write_value_2;
            end if;
        when write_value_3 =>
            next_state <= idle;
        when read_value_1 =>
            if(lbus_we = '1') then
                next_state <= read_value_2;
            else
                next_state <= read_value_1;
            end if;
        when read_value_2 =>
            next_state <= read_value_3;
        when read_value_3 =>
            next_state <= read_value_4;
        when read_value_4 =>
            if(limit_count_stages = '1') then
                next_state <= read_value_5;
            else
                next_state <= read_value_4;
            end if;
        when read_value_5 =>
            if(lbus_re = '1') then
                next_state <= idle;
            else
                next_state <= read_value_5;
            end if;	
        when is_busy_1 =>
            if((fr_cipher_reset = '0') and (fr_cipher_operation_finished = '0')) then
                next_state <= is_busy_3;
            else
                next_state <= is_busy_2;
            end if;
        when is_busy_2 =>
            if(lbus_re = '1') then
                next_state <= idle;
            else
                next_state <= is_busy_2;
            end if;
        when is_busy_3 =>
            if(lbus_re = '1') then
                next_state <= idle;
            else
                next_state <= is_busy_3;
            end if;
        when start_fr_cipher_1 =>
            next_state <= start_fr_cipher_2;
        when start_fr_cipher_2 =>
            next_state <= idle;
        --when others =>
        --    next_state <= reset;
        end case;
    end process;
    
end Behavioral;

