library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package common is
   function sel(n : natural) return natural;
   constant clock_period : time := 1 sec / 32000000;

   constant num_regs : natural := 16;
   subtype sel_word is std_logic_vector(sel(num_regs) downto 0);
end common;  -- package body contains the function body