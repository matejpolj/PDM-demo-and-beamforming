----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08.07.2024 13:41:54
-- Design Name: 
-- Module Name: clock_divider - Behavioral
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

entity clock_divider is
    Port ( clk_in : in STD_LOGIC;
           clk_out : out STD_LOGIC;
           nrst : in std_logic);
end clock_divider;

architecture Behavioral of clock_divider is

begin

process(clk_in)
    variable count : integer range 0 to 63 := 0;
begin
    
    if (nrst = '0') then
        count := 0;
        clk_out <= '0'; 
    elsif (falling_edge(clk_in)) then
        if (count = 63) then
            count := 0;
            clk_out <= '1';
        else
            count := count + 1;
            clk_out <= '0';
        end if;                
    end if;
    
end process;


end Behavioral;
