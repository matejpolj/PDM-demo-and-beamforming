----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08.07.2024 10:27:43
-- Design Name: 
-- Module Name: tdm2parralel - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity tdm2parralel is
    Port ( clk_d : in STD_LOGIC;                            -- data clock, bit clock
           clk_t : in STD_LOGIC;                            -- transfer clock, frame sync clock
           nrst :  in std_logic;
           data_in : in STD_LOGIC;                          -- input TDM data
           data_A : out STD_LOGIC_VECTOR (15 downto 0);     -- output data A
           data_B : out STD_LOGIC_VECTOR (15 downto 0);     -- output data B
           data_C : out STD_LOGIC_VECTOR (15 downto 0);     -- output data C
           data_D : out STD_LOGIC_VECTOR (15 downto 0);     -- output data D
           data_P : out std_logic_vector (63 downto 0));    
end tdm2parralel;

architecture Behavioral of tdm2parralel is

    signal parallel_buff :  std_logic_vector(63 downto 0);
    
    signal count_s : integer range 0 to 63 := 63;
    
begin

transform : process(clk_d)
    variable count : integer range 0 to 63 := 63;
begin
    if (nrst = '0') then
    
        count := 63;
        count_s <= 63; 
        parallel_buff <= (others => '0'); 
        
    elsif (falling_edge(clk_d)) then
    
        if (clk_t = '1') then
            count := 63;
            count_s <= count;
        end if;
        
        parallel_buff(count) <= data_in;
        
        count := count - 1;
        count_s <= count;
    end if;
end process;

slice : process(clk_t)
begin     
    if (rising_edge(clk_t)) then
        data_A <= parallel_buff(63 downto 48);
        data_B <= parallel_buff(47 downto 32);
        data_C <= parallel_buff(31 downto 16);
        data_D <= parallel_buff(15 downto 0);
        data_P <= parallel_buff;
    end if;
end process;


end Behavioral;
