library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;

entity core_ctrl is
    Port ( clk : in STD_LOGIC;
           rst : in STD_LOGIC;
           oper : in STD_LOGIC_VECTOR (7 downto 0);
           digit_in : in STD_LOGIC_VECTOR (3 downto 0);
           wr : out STD_LOGIC;
           mult_ctrl : out STD_LOGIC_VECTOR (7 downto 0);
           add_ctrl : out STD_LOGIC_VECTOR (7 downto 0);
           addra : out STD_LOGIC_VECTOR (7 downto 0);
           addrb : out STD_LOGIC_VECTOR (7 downto 0);
           req_digit : out STD_LOGIC;
           busy : out STD_LOGIC);
end core_ctrl;

architecture structural of core_ctrl is

    constant INST_LENGTH    : integer := 25;
    constant PROG_ADDR_W    : integer := 13;
    constant PROG_LENGTH    : integer := 2**PROG_ADDR_W;
    
    constant PROG_ROM_TYPE  : integer := 2; -- 1 = distributed memory, 2 = BlockRAM

    -- Program ROM
    COMPONENT dist_mem_gen_0 IS
    PORT (
        a : IN STD_LOGIC_VECTOR(12 DOWNTO 0);
        clk : IN STD_LOGIC;
        qspo : OUT STD_LOGIC_VECTOR(24 DOWNTO 0)
    );
    END COMPONENT dist_mem_gen_0;
    
    COMPONENT blk_mem_gen_1 IS
      PORT (
        clka : IN STD_LOGIC;
        ena : IN STD_LOGIC;
        addra : IN STD_LOGIC_VECTOR(12 DOWNTO 0);
        douta : OUT STD_LOGIC_VECTOR(24 DOWNTO 0)
      );
    END COMPONENT blk_mem_gen_1;    

    -- Pointers to the program
    constant PROG_NOP       : integer := 0;
    constant PROG_PREI_S    : integer := 1;
    constant PROG_PREI_E    : integer := 14;
    constant PROG_PREC_S    : integer := 15; 
    constant PROG_PREC_E    : integer := 4199;
    constant PROG_SM_S      : integer := 4200;
    constant PROG_SM_E      : integer := 4214;
    constant PROG_DA_S      : integer := 4215;
    constant PROG_DA_E      : integer := 4568;
    constant PROG_AFF_S     : integer := 4569;
    constant PROG_AFF_E     : integer := 7437;
    constant PROG_PNTVAL_S  : integer := 7438;
    constant PROG_PNTVAL_E  : integer := 7561;
    constant PROG_CFKINIT_S : integer := 7562;
    constant PROG_CFKINIT_E : integer := 7643;
    constant PROG_CFKDBL_S  : integer := 7644;
    constant PROG_CFKDBL_E  : integer := 7799;
    constant PROG_CFKADD_S  : integer := 7800;
    constant PROG_CFKADD_E  : integer := 8014;    
    
    
    -- Program counter
    signal prog_cntr : integer range 0 to PROG_LENGTH := PROG_NOP;   
    
    -- Program line signals
    signal prog_addr : std_logic_vector(PROG_ADDR_W-1 downto 0);
    signal prog_line : std_logic_vector(INST_LENGTH-1 downto 0);
    
    -- Digit counter
    signal digit_cntr : integer range 0 to 63 := 0;    
    
    -- Digit selection signals  
    signal digit : std_logic_vector(2 downto 0);
    signal sign : std_logic;
    signal recode_addr, recode_addr_t1, recode_addr_t2 : std_logic;

    -- Cofactor killing signals
    signal cfk_cntr : integer range 0 to 7 := 0;

begin


    -- Program FSM
    i_prog_fsm : process (clk,rst)
    begin
        -- Async. active-high reset
        if rst = '1' then
            prog_cntr <= 0;
            recode_addr_t1 <= '0';
            digit_cntr <= 0;
            req_digit <= '0';
        elsif rising_edge(clk) then
            case prog_cntr is
                -- WAIT    
                when PROG_NOP =>
                    
                    case oper is
                        when x"01" => prog_cntr <= PROG_PREI_S;     -- Start initialization
                        when x"02" => prog_cntr <= PROG_PREC_S;     -- Start precomputation                                      
                        when x"03" => prog_cntr <= PROG_SM_S;       -- Start scalar multiplication
                        when x"04" => prog_cntr <= PROG_AFF_S;      -- Start affine conversion
                        when x"05" => prog_cntr <= PROG_PNTVAL_S;   -- Start point validation
                        when x"06" => prog_cntr <= PROG_CFKINIT_S;  -- Start cofactor killing                    
                        when others => prog_cntr <= PROG_NOP;
                    end case;

                    recode_addr_t1 <= '0';
                    digit_cntr <= 0;
                    req_digit <= '0';
                
                -- INITIALIZATION begins
                when PROG_PREI_S =>
                    prog_cntr <= prog_cntr + 1;
                    
                -- INITIALIZATION ends
                when PROG_PREI_E =>
                    prog_cntr <= PROG_NOP;
                
                -- PRECOMPUTATION starts
                when PROG_PREC_S =>
                    prog_cntr <= prog_cntr + 1;
                
                -- PRECOMPUTATION ends
                when PROG_PREC_E =>
                    prog_cntr <= PROG_SM_S;
                
                -- SCALAR MULTIPLICATION INITIALIZATION starts
                when PROG_SM_S => 
                    prog_cntr <= prog_cntr + 1;
                    digit_cntr <= 0;
                    recode_addr_t1 <= '1';
                    --digit <= digit_in(2 downto 0);
                    --sign <= digit_in(3);
                
                -- SCALAR MULTIPLICATION INITIALIZATION ends
                when PROG_SM_E =>                     
                    prog_cntr <= PROG_DA_S;
                    req_digit <= '1';
                
                -- POINT DOUBLE-ADD starts
                when PROG_DA_S => 
                    prog_cntr <= prog_cntr + 1;
                    req_digit <= '0';
                    recode_addr_t1 <= '1';
                    digit_cntr <= digit_cntr + 1;
                    --digit <= digit_in(2 downto 0);
                    --sign <= digit_in(3);
                
                -- POINT DOUBLE-ADD ends
                when PROG_DA_E =>
                    if digit_cntr = 64 then 
                        prog_cntr <= PROG_AFF_S;
                    else
                        prog_cntr <= PROG_DA_S;
                    end if;
                    req_digit <= '1';                    
                    
                -- AFFINE MAPPING begins    
                when PROG_AFF_S =>
                    recode_addr_t1 <= '0';
                    req_digit <= '0';
                    prog_cntr <= prog_cntr + 1;

                -- AFFINE MAPPING ends                    
                when PROG_AFF_E =>
                    prog_cntr <= PROG_NOP;     
                    
                -- POINT VALIDATION begins               
                when PROG_PNTVAL_S =>
                    recode_addr_t1 <= '0';
                    req_digit <= '0';
                    prog_cntr <= prog_cntr + 1;
                
                -- POINT VALIDATION ends      
                when PROG_PNTVAL_E =>
                    prog_cntr <= PROG_NOP;                                         
                
                -- COFACTOR KILLING begins
                when PROG_CFKINIT_S =>
                    cfk_cntr <= 0;
                    recode_addr_t1 <= '0';
                    prog_cntr <= prog_cntr + 1; 

                -- COFACTOR KILLING, loop jumps or ends                    
                when PROG_CFKDBL_E =>
                    if cfk_cntr = 0 or cfk_cntr = 4 then
                        prog_cntr <= prog_cntr + 1; -- Proceed to add
                        cfk_cntr <= cfk_cntr+1;
                    elsif cfk_cntr = 7 then
                        prog_cntr <= PROG_NOP; -- Jump to wait; cofactor killing done
                        cfk_cntr <= 0;
                    else
                        prog_cntr <= PROG_CFKDBL_S; -- Jump to dbl
                        cfk_cntr <= cfk_cntr+1;
                    end if;
                    
                -- COFACTOR KILLING, add ends, jump to the next dbl
                when PROG_CFKADD_E =>
                    prog_cntr <= PROG_CFKDBL_S;                   
    
                when others => prog_cntr <= prog_cntr + 1;
            end case;
            recode_addr_t2 <= recode_addr_t1;
        end if;
    end process i_prog_fsm;
    
    recode_addr <= recode_addr_t1 when PROG_ROM_TYPE = 1 else recode_addr_t2;

    digit <= digit_in(2 downto 0);
    sign <= digit_in(3);
    
    busy <= '0' when prog_cntr = PROG_NOP else '1';
    
    -- Program ROM
    prog_addr <= std_logic_vector(to_unsigned(prog_cntr,PROG_ADDR_W));
    
    gen_prog_rom_dist : if PROG_ROM_TYPE = 1 generate
        i_prog_rom : dist_mem_gen_0
            port map (prog_addr,clk,prog_line);
    end generate gen_prog_rom_dist;
    gen_prog_rom_bram : if PROG_ROM_TYPE = 2 generate
        i_prog_rom : blk_mem_gen_1
            port map (clk,'1',prog_addr,prog_line);
    end generate gen_prog_rom_bram;
    
    
    -- MULT_CTRL recoding
    i_mult_ctrl_recode : process (clk,rst)
    begin
        if rst = '1' then
            mult_ctrl <= (others => '0');
        elsif rising_edge(clk) then
            case prog_line(24 downto 22) is
                when "000" =>  mult_ctrl <= "00000000";         -- nop
                when "001" =>  mult_ctrl <= "11000000";         -- clear, store
                when "010" =>  mult_ctrl <= "00000010";         -- shift
                when "100" =>  mult_ctrl <= "00000001";         -- a[0],b[0],+
                when "101" =>  mult_ctrl <= "00001001";         -- a[0],b[1],+
                when "110" =>  mult_ctrl <= "00000101";         -- a[1],b[0],+
                when "111" =>  mult_ctrl <= "00001101";         -- a[1],b[1],+
                when others => mult_ctrl <= (others => 'X');    -- Should not happen!
            end case;
        end if;
    end process i_mult_ctrl_recode;
    
    -- ADD_CTRL recoding
    i_add_ctrl_recode : process (clk,rst)
    begin
        if rst = '1' then
            add_ctrl <= (others => '0');
        elsif rising_edge(clk) then    
            case prog_line(20 downto 17) is -- prog_line(21) is 'store' that loads the input registers
                when "0000" => add_ctrl <= '0' & prog_line(21) & "000000"; -- nop
                when "0001" => add_ctrl <= '0' & prog_line(21) & "010101"; -- add
                when "0010" => add_ctrl <= '0' & prog_line(21) & "010111"; -- sub
                when "0011" => add_ctrl <= '0' & prog_line(21) & "010001"; -- acc,add
                when "0100" => add_ctrl <= '0' & prog_line(21) & "010011"; -- acc,sub
                when "0101" => add_ctrl <= '0' & prog_line(21) & "101001"; -- Red-1
                when "0110" => add_ctrl <= '0' & prog_line(21) & "000001"; -- Red-2
                when "0111" => add_ctrl <= '0' & prog_line(21) & "000001"; -- Red,add
                when "1000" => add_ctrl <= '0' & prog_line(21) & "000011"; -- Red,sub
                when others =>   add_ctrl <= (others => 'X');       -- Should not happen!
            end case;
        end if;            
    end process i_add_ctrl_recode;
    
    -- ADDRESS recoding
    i_addr_recode : process (clk,rst)
    begin
        if rst = '1' then
            addra <= (others => '0');
            addrb <= (others => '0');
            wr <= '0';
        elsif rising_edge(clk) then     
            -- Addr A
            if recode_addr = '1' and prog_line(15) = '1' then -- Precomputed point, change the address based on (sign,digit), prog_line(8) gives the index of the half
                case prog_line(11 downto 9) is
                    when "000" =>  addra <= prog_line(15) & digit & "00" & sign & prog_line(8);     -- XY  => XY(digit) or YX(digit) depending on the sign
                    when "001" =>  addra <= prog_line(15) & digit & "00" & not sign & prog_line(8); -- YZ  => YX(digit) or XY(digit) depending on the neg. of sign
                    when "010" =>  addra <= prog_line(15) & digit & "010" & prog_line(8);           -- 2Z  => 2Z(digit)
                    when "100" =>  addra <= prog_line(15) & digit & "10" & sign & prog_line(8);     -- 2dT => 2dT(digit) or -2dT(digit) depending on the sign  
                    when others => addra <= (others => 'X');                              -- Should not happen!
                end case;
            else
                addra <= prog_line (15 downto 8);                                          -- A fixed address, keep as it is
            end if;
            
            -- Addr B
             if recode_addr = '1' and prog_line(7) = '1' then -- Precomputed point, change the address based on (sign,digit), prog_line(0) gives the index of the half
                case prog_line(3 downto 1) is
                    when "000" =>  addrb <= prog_line(7) & digit & "00" & sign & prog_line(0);     -- XY  => XY(digit) or YX(digit) depending on the sign
                    when "001" =>  addrb <= prog_line(7) & digit & "00" & not sign & prog_line(0); -- YZ  => YX(digit) or XY(digit) depending on the neg. of sign
                    when "010" =>  addrb <= prog_line(7) & digit & "010" & prog_line(0);           -- 2Z  => 2Z(digit)
                    when "100" =>  addrb <= prog_line(7) & digit & "10" & sign & prog_line(0);     -- 2dT => 2dT(digit) or -2dT(digit) depending on the sign  
                    when others => addrb <= (others => 'X');                               -- Should not happen!
                end case;
            else
                addrb <= prog_line (7 downto 0);                                           -- A fixed address, keep as it is
            end if;
            -- Write enable
            wr <= prog_line(16);
        end if;               
    end process i_addr_recode;
    
end structural;
