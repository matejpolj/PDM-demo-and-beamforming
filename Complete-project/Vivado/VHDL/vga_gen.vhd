---------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 19.07.2024 20:10:32
-- Design Name: 
-- Module Name: vga_gen - Behavioral
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

entity vga_gen is
    Generic (   HEIGHT  :       INTEGER := 480;     -- screen hight
                WIDTH   :       INTEGER := 640;     -- screen width
                PCM_WIDTH :     INTEGER := 16;      -- input pcm data width
                VGA_WIDTH :     INTEGER := 12;      -- VGA data width
                FIXED_LEN :     INTEGER := 8;       -- size of fixed decimal place
                COEF_NUM :      INTEGER := 55;      -- number of gauss coeficients
                AVG_NUM :       INTEGER := 64;      -- lowpass average number
                AVG_2_NUM :     INTEGER := 6;       -- log2 of lowpass average number
                LINE_BUF :      INTEGER := 40;      -- space of vertical line
                MIC_WIDTH :     INTEGER := 55;      -- microphone width
                SPACING :       INTEGER := 17;      -- spacing between microphones
                V_SPACE :       INTEGER := 20;      -- vertical space before first microphone
                H_SPACE :       INTEGER := 120;
                MAX_BUFF :      INTEGER := 10);    -- horisontal space before first microphone
    Port ( clk_p : in STD_LOGIC;                                    -- pixel clock
           clk_d : in STD_LOGIC;                                    -- data clock
           nrst : in STD_LOGIC;                                     -- reset
           sound_1 : in STD_LOGIC_VECTOR (PCM_WIDTH-1 downto 0);    -- sound signal 1
           sound_2 : in STD_LOGIC_VECTOR (PCM_WIDTH-1 downto 0);    -- sound signal 2
           sound_3 : in STD_LOGIC_VECTOR (PCM_WIDTH-1 downto 0);    -- sound signal 3
           sound_4 : in STD_LOGIC_VECTOR (PCM_WIDTH-1 downto 0);    -- sound signal 4
           row : in unsigned (9 downto 0);                          -- row number
           col : in unsigned (9 downto 0);                          -- column number
           en : in STD_LOGIC;                                       -- dispaly enable
           video : out STD_LOGIC_VECTOR (VGA_WIDTH-1 downto 0));    -- VGA video output
end vga_gen;

architecture Behavioral of vga_gen is

    subtype POWER_IN_T is   signed(PCM_WIDTH*2-1 downto 0);
    subtype POWER_T is      signed(PCM_WIDTH*2+AVG_2_NUM-1 downto 0);
    subtype FIXED_T is      signed(PCM_WIDTH*2-1+FIXED_LEN downto 0);
    subtype OUTPUT_T is     signed(PCM_WIDTH*6-1+FIXED_LEN*2 downto 0);
    
    type BUFF_ARRAY is array (0 to AVG_NUM-1) of POWER_T;
    type COEF_ARRAY is array (0 to COEF_NUM-1) of FIXED_T;
    
    -- gauss coeficinets
    constant COEFFICIENTS : COEF_ARRAY := (x"0000000105",   
                                            x"0000000107",   
                                            x"0000000109",   
                                            x"000000010b",   
                                            x"000000010f",   
                                            x"0000000112",   
                                            x"0000000117",   
                                            x"000000011c",   
                                            x"0000000122",   
                                            x"0000000128",   
                                            x"0000000130",   
                                            x"0000000139",   
                                            x"0000000142",   
                                            x"000000014d",   
                                            x"0000000158",   
                                            x"0000000163",   
                                            x"0000000170",   
                                            x"000000017c",   
                                            x"0000000188",   
                                            x"0000000194",   
                                            x"00000001a0",   
                                            x"00000001ab",   
                                            x"00000001b4",   
                                            x"00000001bd",   
                                            x"00000001c3",   
                                            x"00000001c8",   
                                            x"00000001cb",   
                                            x"00000001cc",   
                                            x"00000001cb",   
                                            x"00000001c8",   
                                            x"00000001c3",   
                                            x"00000001bd",   
                                            x"00000001b4",   
                                            x"00000001ab",   
                                            x"00000001a0",   
                                            x"0000000194",   
                                            x"0000000188",   
                                            x"000000017c",   
                                            x"0000000170",   
                                            x"0000000163",   
                                            x"0000000158",   
                                            x"000000014d",   
                                            x"0000000142",   
                                            x"0000000139",   
                                            x"0000000130",   
                                            x"0000000128",   
                                            x"0000000122",   
                                            x"000000011c",   
                                            x"0000000117",   
                                            x"0000000112",   
                                            x"000000010f",   
                                            x"000000010b",   
                                            x"0000000109",   
                                            x"0000000107",   
                                            x"0000000105");
    
    -- input power signals
    signal sound_pow1 : POWER_IN_T := (others => '0');
    signal sound_pow2 : POWER_IN_T := (others => '0');
    signal sound_pow3 : POWER_IN_T := (others => '0');
    signal sound_pow4 : POWER_IN_T := (others => '0');
    
    -- input buffer arrays
    signal input_buffer1 :  BUFF_ARRAY := (others => (others => '0'));
    signal input_buffer2 :  BUFF_ARRAY := (others => (others => '0'));
    signal input_buffer3 :  BUFF_ARRAY := (others => (others => '0'));
    signal input_buffer4 :  BUFF_ARRAY := (others => (others => '0'));
    
    -- buffer arrays after lowpass filter
    signal input_buffer_sel1 :  POWER_IN_T  := (others => '0');
    signal input_buffer_sel2 :  POWER_IN_T  := (others => '0');
    signal input_buffer_sel3 :  POWER_IN_T  := (others => '0');
    signal input_buffer_sel4 :  POWER_IN_T  := (others => '0');
    
    -- output buffer for resizing
    signal output_bufer :   OUTPUT_T := (others => '0');
    
    -- pixel location indexes
    signal ind_x :  integer range 0 to WIDTH-1  := 0;
    signal ind_y :  integer range 0 to HEIGHT-1 := 0;

begin

    ind_x <= TO_INTEGER(col);
    ind_y <= TO_INTEGER(row);
    
    sound_pow1 <= signed(sound_1)*signed(sound_1);
    sound_pow2 <= signed(sound_2)*signed(sound_2);
    sound_pow3 <= signed(sound_3)*signed(sound_3);
    sound_pow4 <= signed(sound_4)*signed(sound_4);
    
    -- lowpass input buffer
input_buffer: process(clk_d, nrst)
    begin
        if (nrst = '0') then
            input_buffer1 <= (others => (others => '0'));
            input_buffer2 <= (others => (others => '0'));
            input_buffer3 <= (others => (others => '0'));
            input_buffer4 <= (others => (others => '0'));
        elsif (rising_edge(clk_d)) then
            for ii in 0 to AVG_NUM-2 loop
                input_buffer1(ii) <= input_buffer1(ii+1) + sound_pow1;
                input_buffer2(ii) <= input_buffer2(ii+1) + sound_pow2;
                input_buffer3(ii) <= input_buffer3(ii+1) + sound_pow3;
                input_buffer4(ii) <= input_buffer4(ii+1) + sound_pow4;
            end loop;
            input_buffer1(AVG_NUM-1) <= resize(sound_pow1, PCM_WIDTH*2+AVG_2_NUM);
            input_buffer2(AVG_NUM-1) <= resize(sound_pow2, PCM_WIDTH*2+AVG_2_NUM);
            input_buffer3(AVG_NUM-1) <= resize(sound_pow3, PCM_WIDTH*2+AVG_2_NUM);
            input_buffer4(AVG_NUM-1) <= resize(sound_pow4, PCM_WIDTH*2+AVG_2_NUM);
        end if;
    end process;
    
    -- pixel generation process
pixel_gen: process(clk_p, nrst)
    begin   
        if (nrst = '0') then
        
            input_buffer_sel1 <= (others => '0');
            input_buffer_sel2 <= (others => '0');
            input_buffer_sel3 <= (others => '0');
            input_buffer_sel4 <= (others => '0');
            
            output_bufer <= (others => '0');
            
        elsif(rising_edge(clk_p)) then
        
                -- reset if input state is (0,0)
            if ((row = to_unsigned(0, 10)) and (col = to_unsigned(0, 10))) then
                input_buffer_sel1 <= resize(shift_right(input_buffer1(0), AVG_2_NUM), PCM_WIDTH*2);
                input_buffer_sel2 <= resize(shift_right(input_buffer2(0), AVG_2_NUM), PCM_WIDTH*2);
                input_buffer_sel3 <= resize(shift_right(input_buffer3(0), AVG_2_NUM), PCM_WIDTH*2);
                input_buffer_sel4 <= resize(shift_right(input_buffer4(0), AVG_2_NUM), PCM_WIDTH*2);
                
            end if;
            
            if (en = '1') then
                --if (ind_x < WIDTH-H_SPACE) then
--                if (ind_y < LINE_BUF) then
                if (ind_x < LINE_BUF) then
                
                                --position line
                    output_bufer <= (others => '1');
                elsif (ind_x < (LINE_BUF+H_SPACE)) then
                
                                -- blank space
                    output_bufer <= (others => '0');
                elsif (ind_x < (LINE_BUF+H_SPACE+MIC_WIDTH)) then
                
                                -- microphone 4 x space
                    if (ind_y < (V_SPACE+MIC_WIDTH+SPACING)) then
                    
                                -- blank space
                        output_bufer <= (others => '0');
                    elsif (ind_y < (V_SPACE+2*MIC_WIDTH+SPACING)) then
                    
                                -- microphone 4 y space
                         output_bufer <= input_buffer_sel4*COEFFICIENTS(ind_x-(LINE_BUF+H_SPACE))*COEFFICIENTS(ind_y-(V_SPACE+MIC_WIDTH+SPACING));
                    else 
                                -- blank space
                         output_bufer <= (others => '0');
                    end if;
                                
                elsif (ind_x < (LINE_BUF+H_SPACE+MIC_WIDTH+SPACING)) then
                
                                -- blank space
                    output_bufer <= (others => '0');
                elsif (ind_x < (LINE_BUF+H_SPACE+2*MIC_WIDTH+SPACING)) then
                
                                -- microphone 2 and 3 x space
                    if (ind_y < (V_SPACE)) then
                    
                                -- blank space
                        output_bufer <= (others => '0');
                    elsif (ind_y < (V_SPACE+MIC_WIDTH)) then
                    
                                -- microphone 2 y space
                         output_bufer <= input_buffer_sel2*COEFFICIENTS(ind_x-(LINE_BUF+H_SPACE+MIC_WIDTH+SPACING))*COEFFICIENTS(ind_y-(V_SPACE));
                    elsif (ind_y < (V_SPACE+2*MIC_WIDTH+2*SPACING)) then
                    
                                -- blank space 
                         output_bufer <= (others => '0');
                    elsif (ind_y < (V_SPACE+3*MIC_WIDTH+2*SPACING)) then
                    
                                -- microphone 3 y space
                         output_bufer <= input_buffer_sel3*COEFFICIENTS(ind_x-(LINE_BUF+H_SPACE+MIC_WIDTH+SPACING))*COEFFICIENTS(ind_y-(V_SPACE+2*MIC_WIDTH+2*SPACING));
                    else 
   
                                -- blank space                             
                         output_bufer <= (others => '0');
                    end if;
                    
                elsif (ind_x < (LINE_BUF+H_SPACE+2*MIC_WIDTH+2*SPACING)) then
                
                                -- blank space
                    output_bufer <= (others => '0');
                elsif (ind_x < (LINE_BUF+H_SPACE+3*MIC_WIDTH+2*SPACING)) then
                
                            -- microphone 1 blank space
                    if (ind_y < (V_SPACE+MIC_WIDTH+SPACING)) then
                    
                            -- blank space
                        output_bufer <= (others => '0');
                    elsif (ind_y < (V_SPACE+2*MIC_WIDTH+SPACING)) then
                    
                            -- microphone 1 y space
                         output_bufer <= input_buffer_sel1*COEFFICIENTS(ind_x-(LINE_BUF+H_SPACE+2*MIC_WIDTH+2*SPACING))*COEFFICIENTS(ind_y-(V_SPACE+MIC_WIDTH+SPACING));
                    else 
                    
                            -- blank space
                         output_bufer <= (others => '0');
                    end if;
                else        
                            -- blank space
                    output_bufer <= (others => '0');
                end if;
--            output_bufer <= (others => '1'); 
--            else 
--            output_bufer <= (others => '0');
--            end if;
--            --output_bufer <= (others => '0'); 
--            --end if;
--            else
--            output_bufer <= (others => '0'); 
            end if;
            
        end if;
    end process;
    
        -- output logic resizing 
    video <= std_logic_vector(output_bufer(VGA_WIDTH-1+FIXED_LEN*2+MAX_BUFF downto FIXED_LEN*2+MAX_BUFF));

end Behavioral;

--architecture Behavioral of vga_gen is

--    subtype POWER_IN_T is   signed(PCM_WIDTH*2-1 downto 0);
--    subtype POWER_T is      signed(PCM_WIDTH*2+AVG_2_NUM-1 downto 0);
--    subtype FIXED_T is      signed(PCM_WIDTH*2-1+FIXED_LEN downto 0);
--    subtype OUTPUT_T is     signed(PCM_WIDTH*6-1+FIXED_LEN*2 downto 0);
    
--    type BUFF_ARRAY is array (0 to AVG_NUM-1) of POWER_T;
--    type COEF_ARRAY is array (0 to COEF_NUM-1) of FIXED_T;
    
--    -- gauss coeficinets
--    constant COEFFICIENTS : COEF_ARRAY := (x"0000000105",   
--                                            x"0000000107",   
--                                            x"0000000109",   
--                                            x"000000010b",   
--                                            x"000000010f",   
--                                            x"0000000112",   
--                                            x"0000000117",   
--                                            x"000000011c",   
--                                            x"0000000122",   
--                                            x"0000000128",   
--                                            x"0000000130",   
--                                            x"0000000139",   
--                                            x"0000000142",   
--                                            x"000000014d",   
--                                            x"0000000158",   
--                                            x"0000000163",   
--                                            x"0000000170",   
--                                            x"000000017c",   
--                                            x"0000000188",   
--                                            x"0000000194",   
--                                            x"00000001a0",   
--                                            x"00000001ab",   
--                                            x"00000001b4",   
--                                            x"00000001bd",   
--                                            x"00000001c3",   
--                                            x"00000001c8",   
--                                            x"00000001cb",   
--                                            x"00000001cc",   
--                                            x"00000001cb",   
--                                            x"00000001c8",   
--                                            x"00000001c3",   
--                                            x"00000001bd",   
--                                            x"00000001b4",   
--                                            x"00000001ab",   
--                                            x"00000001a0",   
--                                            x"0000000194",   
--                                            x"0000000188",   
--                                            x"000000017c",   
--                                            x"0000000170",   
--                                            x"0000000163",   
--                                            x"0000000158",   
--                                            x"000000014d",   
--                                            x"0000000142",   
--                                            x"0000000139",   
--                                            x"0000000130",   
--                                            x"0000000128",   
--                                            x"0000000122",   
--                                            x"000000011c",   
--                                            x"0000000117",   
--                                            x"0000000112",   
--                                            x"000000010f",   
--                                            x"000000010b",   
--                                            x"0000000109",   
--                                            x"0000000107",   
--                                            x"0000000105");
    
--    -- input power signals
--    signal sound_pow1 : POWER_IN_T := (others => '0');
--    signal sound_pow2 : POWER_IN_T := (others => '0');
--    signal sound_pow3 : POWER_IN_T := (others => '0');
--    signal sound_pow4 : POWER_IN_T := (others => '0');
    
--    -- input buffer arrays
--    signal input_buffer1 :  BUFF_ARRAY := (others => (others => '0'));
--    signal input_buffer2 :  BUFF_ARRAY := (others => (others => '0'));
--    signal input_buffer3 :  BUFF_ARRAY := (others => (others => '0'));
--    signal input_buffer4 :  BUFF_ARRAY := (others => (others => '0'));
    
--    -- buffer arrays after lowpass filter
--    signal input_buffer_sel1 :  POWER_IN_T  := (others => '0');
--    signal input_buffer_sel2 :  POWER_IN_T  := (others => '0');
--    signal input_buffer_sel3 :  POWER_IN_T  := (others => '0');
--    signal input_buffer_sel4 :  POWER_IN_T  := (others => '0');
    
--    -- pixel location indexes
--    signal ind_x :  integer range 0 to WIDTH-1  := 0;
--    signal ind_y :  integer range 0 to HEIGHT-1 := 0;

--begin

--    ind_x <= TO_INTEGER(col);
--    ind_y <= TO_INTEGER(row);
    
--    sound_pow1 <= signed(sound_1)*signed(sound_1);
--    sound_pow2 <= signed(sound_2)*signed(sound_2);
--    sound_pow3 <= signed(sound_3)*signed(sound_3);
--    sound_pow4 <= signed(sound_4)*signed(sound_4);
    
--    -- lowpass input buffer
--input_buffer: process(clk_d, nrst)
--    begin
--        if (nrst = '0') then
--            input_buffer1 <= (others => (others => '0'));
--            input_buffer2 <= (others => (others => '0'));
--            input_buffer3 <= (others => (others => '0'));
--            input_buffer4 <= (others => (others => '0'));
--        elsif (rising_edge(clk_d)) then
--            for ii in 0 to AVG_NUM-2 loop
--                input_buffer1(ii) <= input_buffer1(ii+1) + sound_pow1;
--                input_buffer2(ii) <= input_buffer2(ii+1) + sound_pow2;
--                input_buffer3(ii) <= input_buffer3(ii+1) + sound_pow3;
--                input_buffer4(ii) <= input_buffer4(ii+1) + sound_pow4;
--            end loop;
--            input_buffer1(AVG_NUM-1) <= resize(sound_pow1, PCM_WIDTH*2+AVG_2_NUM);
--            input_buffer2(AVG_NUM-1) <= resize(sound_pow2, PCM_WIDTH*2+AVG_2_NUM);
--            input_buffer3(AVG_NUM-1) <= resize(sound_pow3, PCM_WIDTH*2+AVG_2_NUM);
--            input_buffer4(AVG_NUM-1) <= resize(sound_pow4, PCM_WIDTH*2+AVG_2_NUM);
--        end if;
--    end process;
    
--    -- pixel generation process
--pixel_gen: process(clk_p, nrst, en)
--    begin   
----        if (rising_edge(en)) then
            
----            ind_x <= 0;
----            if (ind_y < HEIGHT) then
----                ind_y <= ind_y + 1;
----            else 
----                ind_y <= 0;
----            end if;
            
----        end if;
--        if (nrst = '0') then
        
--            input_buffer_sel1 <= (others => '0');
--            input_buffer_sel2 <= (others => '0');
--            input_buffer_sel3 <= (others => '0');
--            input_buffer_sel4 <= (others => '0');
            
----            ind_x <= 0;
----            ind_y <= 0;
            
--        elsif(rising_edge(clk_p)) then
        
--                -- reset if input state is (0,0)
--            if ((row = to_unsigned(0, 10)) and (col = to_unsigned(0, 10))) then
--                input_buffer_sel1 <= resize(shift_right(input_buffer1(0), AVG_2_NUM), PCM_WIDTH*2);
--                input_buffer_sel2 <= resize(shift_right(input_buffer2(0), AVG_2_NUM), PCM_WIDTH*2);
--                input_buffer_sel3 <= resize(shift_right(input_buffer3(0), AVG_2_NUM), PCM_WIDTH*2);
--                input_buffer_sel4 <= resize(shift_right(input_buffer4(0), AVG_2_NUM), PCM_WIDTH*2);
                
----                ind_x <= 0;
----                ind_y <= 0;
--            end if;
            
--            if (en = '1') then
            
----                    -- index control
----                if (ind_x = WIDTH) then
----                    if (ind_y = HEIGHT) then
----                        ind_y <= 0;
----                    end if;
----                    ind_y <= ind_y + 1;
----                    ind_x <= 0;
----                else
----                    ind_x <= ind_x + 1;
----                end if;
                
----                if (ind_y < (V_SPACE+MIC_WIDTH+SPACING)) then
                    
----                            -- blank space
----                    video <= x"fff";
----                elsif (ind_y < (V_SPACE+2*MIC_WIDTH+SPACING)) then
                
----                            -- microphone 4 y space
----                    video <= x"f0f";
----                else 
----                            -- blank space
----                    video <= x"0ff";
----                end if;
                
--                if (ind_x < LINE_BUF) then
                
--                                --position line
--                    video <= x"f0f";
--                elsif (ind_x < (LINE_BUF+H_SPACE)) then
                
--                                -- blank space
--                    video <= (others => '0');
--                elsif (ind_x < (LINE_BUF+H_SPACE+MIC_WIDTH)) then
                
--                                -- microphone 4 x space
--                    if (ind_y < (V_SPACE+MIC_WIDTH+SPACING)) then
                    
--                                -- blank space
--                        video <= (others => '0');
--                    elsif (ind_y < (V_SPACE+2*MIC_WIDTH+SPACING)) then
                    
--                                -- microphone 4 y space
--                         video <= x"f00";
--                    else 
--                                -- blank space
--                         video <= (others => '0');
--                    end if;
----                    video <= x"ff0";            
--                elsif (ind_x < (LINE_BUF+H_SPACE+MIC_WIDTH+SPACING)) then
                
--                                -- blank space
--                    video <= (others => '0');
--                elsif (ind_x < (LINE_BUF+H_SPACE+2*MIC_WIDTH+SPACING)) then
                
--                                -- microphone 2 and 3 x space
--                    if (ind_y < (V_SPACE)) then
                    
--                                -- blank space
--                        video <= (others => '0');
--                    elsif (ind_y < (V_SPACE+MIC_WIDTH)) then
                    
--                                -- microphone 2 y space
--                         video <= x"ff0";
--                    elsif (ind_y < (V_SPACE+2*MIC_WIDTH+2*SPACING)) then
                    
--                                -- blank space 
--                         video <= (others => '0');
--                    elsif (ind_y < (V_SPACE+3*MIC_WIDTH+2*SPACING)) then
                    
--                                -- microphone 3 y space
--                         video <= x"fff";
--                    else 
   
--                                -- blank space                             
--                         video <= (others => '0');
--                    end if;
----                    video <= x"0ff";
--                elsif (ind_x < (LINE_BUF+H_SPACE+2*MIC_WIDTH+2*SPACING)) then
                
--                                -- blank space
--                    video <= (others => '0');
--                elsif (ind_x < (LINE_BUF+H_SPACE+3*MIC_WIDTH+2*SPACING)) then
                
--                            -- microphone 1 blank space
--                    if (ind_y < (V_SPACE+MIC_WIDTH+SPACING)) then
                    
--                            -- blank space
--                        video <= (others => '0');
--                    elsif (ind_y < (V_SPACE+2*MIC_WIDTH+SPACING)) then
                    
--                            -- microphone 1 y space
--                         video <= x"0ff";
--                    else 
                    
--                            -- blank space
--                         video <= (others => '0');
--                    end if;
----                    video <= x"00f";
--                else        
--                            -- blank space
--                    video <= (others => '0');
--                end if;
--            end if;
            
--        end if;
--    end process;

--end Behavioral;
