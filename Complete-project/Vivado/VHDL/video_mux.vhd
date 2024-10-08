----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 31.07.2024 17:01:26
-- Design Name: 
-- Module Name: video_mux - Behavioral
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

entity video_mux is
    Port ( sel : in STD_LOGIC;
           video_1 : in STD_LOGIC_VECTOR (11 downto 0);
           video_2 : in STD_LOGIC_VECTOR (11 downto 0);
           video_o : out STD_LOGIC_VECTOR (11 downto 0));
end video_mux;

architecture Behavioral of video_mux is

begin

    with sel select
        video_o <= video_1 when '0',
                video_2 when '1',
                (others => '0') when others;


end Behavioral;
