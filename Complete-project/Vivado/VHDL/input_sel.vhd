----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08.08.2024 18:49:06
-- Design Name: 
-- Module Name: input_sel - Behavioral
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

entity input_sel is
    Port ( sel : in std_logic;
           D_A_1 : in std_logic_vector (15 downto 0);
           D_A_2 : in std_logic_vector (15 downto 0);
           D_A_3 : in std_logic_vector (15 downto 0);
           D_A_4 : in std_logic_vector (15 downto 0);
           D_B_1 : in std_logic_vector (15 downto 0);
           D_B_2 : in std_logic_vector (15 downto 0);
           D_B_3 : in std_logic_vector (15 downto 0);
           D_B_4 : in std_logic_vector (15 downto 0);
           D_O_1 : out std_logic_vector (15 downto 0);
           D_O_2 : out std_logic_vector (15 downto 0);
           D_O_3 : out std_logic_vector (15 downto 0);
           D_O_4 : out std_logic_vector (15 downto 0));
end input_sel;

architecture Behavioral of input_sel is

begin

    with sel select
        D_O_1 <= D_A_1 when '0',
                D_B_1 when '1',
                (others => '0') when others;
    with sel select
        D_O_2 <= D_A_2 when '0',
                D_B_2 when '1',
                (others => '0') when others;
    with sel select
        D_O_3 <= D_A_3 when '0',
                D_B_3 when '1',
                (others => '0') when others;
    with sel select
        D_O_4 <= D_A_4 when '0',
                D_B_4 when '1',
                (others => '0') when others;


end Behavioral;
