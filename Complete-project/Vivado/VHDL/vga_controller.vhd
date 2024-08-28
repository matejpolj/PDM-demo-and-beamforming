----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 18.07.2024 15:09:21
-- Design Name: 
-- Module Name: vga_controller - Behavioral
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

entity vga_controller is
    GENERIC(
        h_pulse     : INTEGER := 96;     --horiztonal sync pulse width in pixels
        h_bp        : INTEGER := 48;     --horiztonal back porch width in pixels
        h_pixels    : INTEGER := 640;    --horiztonal display width in pixels
        h_fp        : INTEGER := 16;     --horiztonal front porch width in pixels
        v_pulse     : INTEGER := 2;      --vertical sync pulse width in rows
        v_bp        : INTEGER := 33;     --vertical back porch width in rows
        v_pixels    : INTEGER := 480;    --vertical display width in rows
        v_fp        : INTEGER := 10);     --vertical front porch width in rows
    PORT(
        pixel_clk   : IN    STD_LOGIC;  --pixel clock at frequency of VGA mode being used
        reset_n     : IN    STD_LOGIC;  --active low asycnchronous reset
        h_sync      : OUT   STD_LOGIC;  --horiztonal sync pulse
        v_sync      : OUT   STD_LOGIC;  --vertical sync pulse
        disp_ena    : OUT   STD_LOGIC;  --display enable ('1' = display time, '0' = blanking time)
        column      : OUT   unsigned(9 downto 0);    --horizontal pixel coordinate
        row         : OUT   unsigned(9 downto 0));    --vertical pixel coordinate
end vga_controller;

architecture Behavioral of vga_controller is

    CONSTANT h_period : INTEGER := h_pulse + h_bp + h_pixels + h_fp; --total number of pixel clocks in a row
    CONSTANT v_period : INTEGER := v_pulse + v_bp + v_pixels + v_fp; --total number of rows in column

BEGIN
      
    PROCESS(pixel_clk, reset_n)
        VARIABLE h_count : INTEGER RANGE 0 TO h_period - 1 := 0;  --horizontal counter (counts the columns)
        VARIABLE v_count : INTEGER RANGE 0 TO v_period - 1 := 0;  --vertical counter (counts the rows)
    BEGIN
      
        IF(reset_n = '0') THEN          --reset asserted
            h_count := 0;               --reset horizontal counter
            v_count := 0;               --reset vertical counter
            h_sync <= '1';
            v_sync <= '1';              --deassert vertical sync
            disp_ena <= '0';            --disable display
            column <= (others => '0');                --reset column pixel coordinate
            row <= (others => '0');                   --reset row pixel coordinate
        ELSIF(rising_edge(pixel_clk)) THEN
            --counters
            IF(h_count < h_period - 1) THEN    --horizontal counter (pixels)
                h_count := h_count + 1;
            ELSE
                h_count := 0;
                IF(v_count < v_period - 1) THEN  --veritcal counter (rows)
                    v_count := v_count + 1;
                ELSE
                    v_count := 0;
                END IF;
            END IF;
        
            --horizontal sync signal
            IF(h_count < h_pixels + h_fp OR h_count >= h_pixels + h_fp + h_pulse) THEN
                h_sync <= '1';    --deassert horiztonal sync pulse
                column <= (others => '1');
            ELSE
                h_sync <= '0';        --assert horiztonal sync pulse
                column <= (others => '0');
            END IF;
              
            --vertical sync signal
            IF(v_count < v_pixels + v_fp OR v_count >= v_pixels + v_fp + v_pulse) THEN
                v_sync <= '0';    --deassert vertical sync pulse
                row <= (others => '1');
            ELSE
                v_sync <= '1';        --assert vertical sync pulse
                row <= (others => '0');
            END IF;
              
            --set pixel coordinates
            IF(h_count < h_pixels) THEN  --horiztonal display time
                column <= to_unsigned(h_count, 10);           --set horiztonal pixel coordinate
            END IF;
            IF(v_count < v_pixels) THEN  --vertical display time
                row <= to_unsigned(v_count, 10);              --set vertical pixel coordinate
            END IF;
        
            --set display enable output
            IF(h_count < h_pixels AND v_count < v_pixels) THEN  --display time
                disp_ena <= '1';                                    --enable display
            ELSE                                                --blanking time
                disp_ena <= '0';                                    --disable display
            END IF;
        
        END IF;
END PROCESS;

END Behavioral;
