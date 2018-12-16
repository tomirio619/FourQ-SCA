library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity add_sub_w is
	generic (
        W        : integer := 32);
    port (
        a        : in  std_logic_vector(W-1 downto 0);
        b        : in  std_logic_vector(W-1 downto 0);
        sel      : in  std_logic; -- 0 = add, 1 = sub
        c_in     : in  std_logic; -- carry in
        s        : out std_logic_vector(W-1 downto 0);
        c_out    : out std_logic); --carry out
end add_sub_w;

architecture rtl of add_sub_w is

    signal opb : std_logic_vector(W-1 downto 0);
    
    component adder_w is
        generic (
            W        : integer := 32);
        port (
            a        : in  std_logic_vector(W-1 downto 0);
            b        : in  std_logic_vector(W-1 downto 0);
            c_in     : in  std_logic;
            s        : out std_logic_vector(W-1 downto 0);
            c_out    : out std_logic);        
    end component adder_w;

begin

    opb <= b when sel = '0' else not b;

    i_adder : adder_w
        generic map (W)
        port map (a,opb,c_in,s,c_out);

end rtl;
