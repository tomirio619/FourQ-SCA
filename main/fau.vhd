library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity fau is
    Port ( clk : in STD_LOGIC;
           rst : in STD_LOGIC;
           mult_ctrl: in STD_LOGIC_VECTOR (7 downto 0);
           add_ctrl : in STD_LOGIC_VECTOR(7 downto 0);
           opa : in STD_LOGIC_VECTOR (126 downto 0);
           opb : in STD_LOGIC_VECTOR (126 downto 0);
           res : out STD_LOGIC_VECTOR (126 downto 0));
end fau;

architecture rtl of fau is

    component mult_gen_0 is
        port (
            CLK : IN STD_LOGIC;
            A : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
            B : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
            P : OUT STD_LOGIC_VECTOR(127 DOWNTO 0)
        );
    end component mult_gen_0;
    
    component adder_w is
        generic (
            W       : integer := 32);
        port (
            a       : in  std_logic_vector(W-1 downto 0);
            b       : in  std_logic_vector(W-1 downto 0);
            c_in    : in  std_logic;
            s       : out std_logic_vector(W-1 downto 0);
            c_out   : out std_logic);        
    end component adder_w;

    component add_sub_w is
        generic (
            W        : integer := 32);
        port (
            a        : in  std_logic_vector(W-1 downto 0);
            b        : in  std_logic_vector(W-1 downto 0);
            sel      : in  std_logic; -- 0 = add, 1 = sub
            c_in     : in  std_logic;
            s        : out std_logic_vector(W-1 downto 0);
            c_out    : out std_logic);
    end component add_sub_w;

    -- Signals for full-precision multiplication
    signal mult_a_reg, mult_b_reg : std_logic_vector(126 downto 0);    
    signal mult_opa, mult_opb : std_logic_vector(63 downto 0);
    signal mult_res : std_logic_vector(127 downto 0);
    
    signal add_res : std_logic_vector(127 downto 0);
    signal add_c_in, add_c_out : std_logic;
    signal carry : std_logic; 

    -- Registers for full-precision multiplication
    signal mult_reg0, mult_reg1, mult_reg2, mult_reg3 : std_logic_vector(63 downto 0);    

    -- Control signals
    type mult_inst is record 
        acc : std_logic; -- Accumulate
        sft : std_logic; -- Shift
        clr : std_logic; -- Clear
        oaw : std_logic; -- Select a word
        obw : std_logic; -- Select b word
        reg : std_logic; -- Store inputs to input registers
    end record;
    
    type add_inst is record
        ena : std_logic; -- Enable (compute add/sub)
        sel : std_logic; -- Select add (0) or sub (1)
        opa : std_logic_vector(1 downto 0); -- Select operand a: accumulate (00), input (01) or mult res (10)
        opb : std_logic_vector(1 downto 0); -- Select operand b: zero (00), input (01) or mult res (10)
        reg : std_logic; -- Store inputs to input registers
    end record; 
        
    signal mult_ctrl_d0 : mult_inst;
    signal mult_ctrl_d1 : mult_inst;
    signal mult_ctrl_d2 : mult_inst;
    signal mult_ctrl_d3 : mult_inst;
    signal mult_ctrl_d4 : mult_inst;
    signal mult_ctrl_d5 : mult_inst;
    signal mult_ctrl_d6 : mult_inst;
    signal mult_ctrl_d7 : mult_inst;
    signal mult_ctrl_d8 : mult_inst;
    
    signal add_ctrl_d0 : add_inst;
    signal add_ctrl_d1 : add_inst;    
    
    signal sel_carry : std_logic_vector(1 downto 0);
    
    -- Adder/subtractor signals
    signal as_a, as_b, as_s : std_logic_vector(126 downto 0);
    signal as_sel, as_c_in, as_c_out : std_logic;    
    
    signal as_a_reg, as_b_reg : std_logic_vector(126 downto 0); 
    signal add_reg : std_logic_vector(126 downto 0);
    signal add_carry_reg : std_logic;


begin

    -- Instruction recoding
    mult_ctrl_d0.acc <= mult_ctrl(0);
    mult_ctrl_d0.sft <= mult_ctrl(1);
    mult_ctrl_d0.clr <= mult_ctrl(7);
    mult_ctrl_d0.oaw <= mult_ctrl(2);
    mult_ctrl_d0.obw <= mult_ctrl(3);
    mult_ctrl_d0.reg <= mult_ctrl(6);
    
    add_ctrl_d0.ena <= add_ctrl(0);
    add_ctrl_d0.sel <= add_ctrl(1);
    add_ctrl_d0.opa <= add_ctrl(3 downto 2);
    add_ctrl_d0.opb <= add_ctrl(5 downto 4);
    add_ctrl_d0.reg <= add_ctrl(6);
    
    -- Instruction pipeline
    i_ipl : process (clk,rst)
    begin
        if rst = '1' then
            mult_ctrl_d1 <= ('0','0','0','0','0','0');
            mult_ctrl_d2 <= ('0','0','0','0','0','0');
            mult_ctrl_d3 <= ('0','0','0','0','0','0');
            mult_ctrl_d4 <= ('0','0','0','0','0','0');
            mult_ctrl_d5 <= ('0','0','0','0','0','0');
            mult_ctrl_d6 <= ('0','0','0','0','0','0');
            mult_ctrl_d7 <= ('0','0','0','0','0','0');
            mult_ctrl_d8 <= ('0','0','0','0','0','0');
            add_ctrl_d1 <= ('0','0',"00","00", '0');                      
        elsif rising_edge(clk) then
            mult_ctrl_d1 <= mult_ctrl_d0;
            mult_ctrl_d2 <= mult_ctrl_d1;
            mult_ctrl_d3 <= mult_ctrl_d2;
            mult_ctrl_d4 <= mult_ctrl_d3;
            mult_ctrl_d5 <= mult_ctrl_d4;
            mult_ctrl_d6 <= mult_ctrl_d5;
            mult_ctrl_d7 <= mult_ctrl_d6;
            mult_ctrl_d8 <= mult_ctrl_d7;
            add_ctrl_d1 <= add_ctrl_d0;
        end if;
    end process i_ipl;
    
    i_mult_op_regs : process (clk,rst)
    begin
        if rst = '1' then
            mult_a_reg <= (others => '0');
            mult_b_reg <= (others => '0');
        elsif rising_edge(clk) then
            if mult_ctrl_d0.reg = '1' then
                mult_a_reg <= opa;
                mult_b_reg <= opb;
            end if;
        end if;
    end process i_mult_op_regs;
    
    -- Set multiplier inputs 
    mult_opa <= mult_a_reg(63 downto 0) when mult_ctrl_d1.oaw = '0' else '0' & mult_a_reg(126 downto 64);
    mult_opb <= mult_b_reg(63 downto 0) when mult_ctrl_d1.obw = '0' else '0' & mult_b_reg(126 downto 64);

    -- 64x64-bit multiplier
    i_multiplier : mult_gen_0
        port map (clk,mult_opa,mult_opb,mult_res);       

    -- Adder for accumulating partial multiplications
    i_adder : adder_w
        generic map (128)
        port map (mult_res, (mult_reg3 & mult_reg2), '0', add_res, add_c_out);

    -- Registers for full-precision multiplication
    i_regs : process (clk,rst)
    begin
    
        -- Async. active-high reset
        if rst = '1' then
    
            mult_reg0 <= (others => '0');
            mult_reg1 <= (others => '0');
            mult_reg2 <= (others => '0');
            mult_reg3 <= (others => '0');
            carry <= '0';
    
        -- Functionalities triggered at rising clock edge
        elsif rising_edge(clk) then
        
            if mult_ctrl_d8.sft = '1' then
            
                mult_reg0 <= mult_reg1;
                mult_reg1 <= mult_reg2;
                mult_reg2 <= mult_reg3;
                mult_reg3 <= (0 => carry, others => '0');                
                
            elsif mult_ctrl_d8.acc = '1' then
            
                mult_reg2 <= add_res(63 downto 0);
                mult_reg3 <= add_res(127 downto 64);
                carry <= add_c_out;
                
            elsif mult_ctrl_d8.clr = '1' then
            
                mult_reg0 <= (others => '0');
                mult_reg1 <= (others => '0');
                mult_reg2 <= (others => '0');
                mult_reg3 <= (others => '0');
            
            end if;
        
        end if;                        
    end process i_regs;
    
    -- Input registers for adder/subtractor 
    i_add_op_regs : process (clk,rst)
    begin
        if rst = '1' then
            as_a_reg <= (others => '0');
            as_b_reg <= (others => '0');
        elsif rising_edge(clk) then
            if add_ctrl_d0.reg = '1' then
                as_a_reg <= opa;
                as_b_reg <= opb;
            end if;
        end if;
    end process i_add_op_regs;
    
    -- Carry selection logic 
    process (clk,rst)
    begin
        if rst = '1' then
            sel_carry <= "00";
        elsif rising_edge(clk) then
            if add_ctrl_d0.ena = '1' then
                if add_ctrl_d0.opb = "00" then
                    sel_carry <= "10";                    
                else
                    sel_carry <= '0' & add_ctrl_d0.sel;
                end if;            
            end if;            
        end if;
    end process;
    
    -- Set the inputs to the adder/subtractor based on the add instruction
    as_a <= add_reg when add_ctrl_d1.opa = "00" else
            as_a_reg when add_ctrl_d1.opa = "01" else
            mult_reg1(62 downto 0) & mult_reg0 when add_ctrl_d1.opa = "10"
            else (others => 'X');
    as_b <= (others => '0') when add_ctrl_d1.opb = "00" else
            as_b_reg when add_ctrl_d1.opb = "01" else
            mult_reg3(61 downto 0) & mult_reg2 & mult_reg1(63) when add_ctrl_d1.opb = "10"
            else (others => 'X');
    as_c_in <= '0' when sel_carry = "00" else
               '1' when sel_carry = "01" else
               add_carry_reg when sel_carry = "10" else
               not add_carry_reg when sel_carry = "11" -- IS THIS NEEDED???
               else 'X';                   
    as_sel <= add_ctrl_d1.sel;    
    
    -- Adder/subtractor
    i_add_sub : add_sub_w
        generic map (127)
        port map (as_a,as_b,as_sel,as_c_in,as_s,as_c_out);       
    
    -- Register for the result of addition/subtraction
    i_add_reg : process (clk,rst)
    begin
        if rst = '1' then
            add_reg <= (others => '0');
            add_carry_reg <= '0';
        elsif rising_edge(clk) then
            if add_ctrl_d1.ena = '1' then
                add_reg <= as_s;
                add_carry_reg <= as_c_out;
            end if;
        end if;
    end process i_add_reg;

    res <= add_reg;

end rtl;
