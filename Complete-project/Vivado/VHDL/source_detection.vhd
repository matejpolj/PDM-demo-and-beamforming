----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09.08.2024 08:50:36
-- Design Name: 
-- Module Name: source_detection - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity source_detection is
    Generic ( WIDTH :   integer := 640;
              HEIGHT :  integer := 480);
    Port ( clk : in STD_LOGIC;
           nrst : in STD_LOGIC;
           row : in unsigned (9 downto 0);
           col : in unsigned (9 downto 0);
           D_in : in STD_LOGIC_VECTOR (31 downto 0);
           pos_X : out unsigned (9 downto 0);
           pos_Y : out unsigned (9 downto 0));
end source_detection;

architecture Behavioral of source_detection is

    signal input_buffer :   signed(31 downto 0) := (others => '0');
    signal compare_buffer : signed(31 downto 0) := (others => '0');
    
    signal row_buffer :     unsigned(9 downto 0) := (others => '0');
    signal col_buffer :     unsigned(9 downto 0) := (others => '0');
    signal row_buffer_u :   unsigned(9 downto 0) := (others => '0');
    signal col_buffer_u :   unsigned(9 downto 0) := (others => '0');
    
begin

    input_buffer <= signed(D_in);
    
compare: process(clk, nrst)
begin

    if (nrst = '0') then
        compare_buffer <= (others => '0');
        row_buffer <= (others => '0');
        col_buffer <= (others => '0');
        row_buffer_u <= (others => '0');
        col_buffer_u <= (others => '0');
    elsif (rising_edge(clk)) then
        
        if ((col = TO_UNSIGNED(0, 10)) and (row = TO_UNSIGNED(0, 10))) then
            compare_buffer <= (others => '0');
        end if;
        
        if (input_buffer > compare_buffer) then
            row_buffer <= row;
            col_buffer <= col;
            compare_buffer <= input_buffer;
        end if;
        
        if ((to_integer(col) = (WIDTH-1)) and (to_integer(row) = (HEIGHT-1))) then
            col_buffer_u <= col_buffer;
            row_buffer_u <= row_buffer; 
        end if;
        
    end if;
    
end process;

    pos_X <= col_buffer_u;
    pos_Y <= row_buffer_u;

end Behavioral;
