library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use work.constants.all;

entity core is
    Port ( clk : in STD_LOGIC;
           rst : in STD_LOGIC;
           oper : in STD_LOGIC_VECTOR (7 downto 0);
           digit_in : in STD_LOGIC_VECTOR (3 downto 0);
           we : in STD_LOGIC;
           addr : in STD_LOGIC_VECTOR (8 downto 0);
           di : in STD_LOGIC_VECTOR (63 downto 0);
           req_digit : out STD_LOGIC;
           busy : out STD_LOGIC;
           do : out STD_LOGIC_VECTOR (63 downto 0);
           trigger_signals: out STD_LOGIC_VECTOR(NR_OF_TRIGGERS - 1 downto 0)
    );
end core;

architecture structural of core is

    component fau is
        Port ( clk : in STD_LOGIC;
            rst : in STD_LOGIC;
            mult_ctrl: in STD_LOGIC_VECTOR (7 downto 0);
            add_ctrl : in STD_LOGIC_VECTOR(7 downto 0);
            opa : in STD_LOGIC_VECTOR (126 downto 0);
            opb : in STD_LOGIC_VECTOR (126 downto 0);
            res : out STD_LOGIC_VECTOR (126 downto 0));    
    end component fau;

    component blk_mem_gen_0 IS
      PORT (
          clka : IN STD_LOGIC;
          ena : IN STD_LOGIC;
          wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
          addra : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
          dina : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
          douta : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
          clkb : IN STD_LOGIC;
          enb : IN STD_LOGIC;
          web : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
          addrb : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
          dinb : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
          doutb : OUT STD_LOGIC_VECTOR(127 DOWNTO 0)
      );
    end component blk_mem_gen_0;
    
    component core_ctrl is
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
            busy : out STD_LOGIC;
            trigger_signals: out STD_LOGIC_VECTOR(NR_OF_TRIGGERS - 1 downto 0)
            );
    end component core_ctrl;    

    -- Memory interface
    signal memio_di : std_logic_vector(127 downto 0);
    signal memio_do : std_logic_vector(127 downto 0);
    signal memio_addr, memio_addrb : std_logic_vector(7 downto 0);
    signal memio_we : std_logic;
    signal wr : std_logic;

    -- FAU signals
    signal opa, opb : std_logic_vector(127 downto 0);
    signal res : std_logic_vector(126 downto 0);
    signal mult_ctrl, add_ctrl : std_logic_vector(7 downto 0);
    signal addra, addrb : std_logic_vector(7 downto 0);
   
   signal busy_t : std_logic;
   
   signal read_delay : std_logic_vector(3 downto 0);

   -- Trigger signals
   signal trigger_signals_tmp : std_logic_vector(NR_OF_TRIGGERS - 1 downto 0);

begin

    -- Control logic
    i_core_ctrl : core_ctrl
        port map (
            clk => clk,
            rst => rst,
            oper => oper,
            digit_in => digit_in,
            wr => wr,
            mult_ctrl => mult_ctrl,
            add_ctrl => add_ctrl,
            addra => addra,
            addrb => addrb,
            req_digit => req_digit,
            busy => busy_t,
            trigger_signals => trigger_signals_tmp
        );

        trigger_signals <= trigger_signals_tmp;

    -- Memory interface
    i_mem_io : process (clk,rst)
    begin
        -- Async. active-high reset
        if rst = '1' then
        
            memio_di <= (others => '0');
            memio_do <= (others => '0');
            memio_addr <= (others => '0');
            memio_we <= '0';
        
        elsif rising_edge(clk) then
          
            -- Write
            if we = '1' then
                if addr(0) = '0' then -- Used by test bench to load lower and upper bits of address
                    memio_di(63 downto 0) <= di;                   
                else
                    memio_di(127 downto 64) <= di;
                end if;
            end if;            
            memio_addr <= addr(addr'length-1 downto 1);
            memio_we <= we and addr(0); -- Write after the higher 64-bit word has been written

            -- Read
            memio_do <= opb;
            read_delay(read_delay'length-1) <= addr(0);
            read_delay(read_delay'length-2 downto 0) <= read_delay(read_delay'length-1 downto 1); 
            if read_delay(0) = '0' then
                do <= memio_do(63 downto 0);
            else
                do <= memio_do(127 downto 64);
            end if;                
                        
        end if;
        
    end process;
            
    memio_addrb <= addrb when busy_t = '1' else memio_addr;    

    -- Memory
    i_ram : blk_mem_gen_0
        port map (
            clka => clk,
            ena => '1',
            wea(0) => wr,
            addra =>  addra,
            dina => ('0' & res),
            douta => opa,
            clkb => clk,
            enb => '1',
            web(0) => memio_we,
            addrb => memio_addrb,
            dinb => memio_di,
            doutb => opb);

    -- FAU            
    i_fau : fau
        port map (
            clk => clk,
            rst => rst,
            mult_ctrl => mult_ctrl,
            add_ctrl => add_ctrl,
            opa => opa(126 downto 0),
            opb => opb(126 downto 0),
            res => res);    

    busy <= busy_t;

end structural;
