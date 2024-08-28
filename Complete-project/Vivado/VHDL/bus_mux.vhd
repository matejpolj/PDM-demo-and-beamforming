----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05.07.2024 14:11:08
-- Design Name: 
-- Module Name: bus_mux - Behavioral
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

entity bus_mux is
    Port ( SEL : in STD_LOGIC_VECTOR (1 downto 0);
           A : in STD_LOGIC_VECTOR (15 downto 0);
           B : in STD_LOGIC_VECTOR (15 downto 0);
           C : in STD_LOGIC_VECTOR (15 downto 0);
           D : in STD_LOGIC_VECTOR (15 downto 0);
           O : out STD_LOGIC_VECTOR (15 downto 0);
           clk_A : in std_logic;
           clk_B : in std_logic;
           clk_C : in std_logic;
           clk_D : in std_logic;
           clk_O : out std_logic);
end bus_mux;

architecture Behavioral of bus_mux is

begin

    with SEL select
        O <= A when b"00",
            B when b"01",
            C when b"10",
            D when others;
            
    with SEL select
        clk_O <= clk_A when b"00",
            clk_B when b"01",
            clk_C when b"10",
            clk_D when others;

end Behavioral;
