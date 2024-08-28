----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 13.04.2024 13:02:36
-- Design Name: 
-- Module Name: combiner - Behavioral
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

entity combiner is
    Port ( bus_in : in STD_LOGIC_VECTOR (15 downto 0);
           clk_in : in STD_LOGIC;
           d_in : std_logic;
           bus_out : out STD_LOGIC_VECTOR (17 downto 0);
           d_out : out STD_LOGIC);
end combiner;

architecture Behavioral of combiner is

    signal buff : std_logic_vector(17 downto 0) := (others => '0');

begin

    --bus_out <= clk_in & bus_in;
    buff(15 downto 0) <= bus_in;
    buff(16) <= clk_in;
    buff(17) <= d_in;
    
    d_out <= buff(16);

end Behavioral;
