----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 18.07.2024 17:48:56
-- Design Name: 
-- Module Name: tb_vga_controller - Behavioral
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

entity tb_vga_controller is
--  Port ( );
end tb_vga_controller;

architecture Behavioral of tb_vga_controller is

    component vga_controller is
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
    end component;
    
    component vga_gen is
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
                    H_SPACE :       INTEGER := 120);    -- horisontal space before first microphone
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
    end component;
    
--    COMPONENT top_1
--        PORT (
--            video_ap_vld : OUT STD_LOGIC;
--            ap_clk : IN STD_LOGIC;
--            ap_rst_n : IN STD_LOGIC;
--            sound1 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
--            sound2 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
--            sound3 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
--            sound4 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
--            video : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
--            row : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
--            col : IN STD_LOGIC_VECTOR(9 DOWNTO 0) 
--        );
--    END COMPONENT;
    
    CONSTANT period : TIME := 1 ns;
    signal pixel_clk        : STD_LOGIC := '0';
    signal data_clk         : STD_LOGIC := '0';
    signal nrst             : STD_LOGIC := '0'; 
    signal h_sync           : STD_LOGIC := '0';  
    signal v_sync           : STD_LOGIC := '0'; 
    signal disp_ena         : STD_LOGIC := '0';  
    signal column           : unsigned(9 downto 0) := (others => '0'); 
    signal row              : unsigned(9 downto 0) := (others => '0'); 
--    signal video_ap_vld     : std_logic := '0';
    signal sound1           : std_logic_vector(15 downto 0) := (others => '0');
    signal sound2           : std_logic_vector(15 downto 0) := (others => '0');
    signal sound3           : std_logic_vector(15 downto 0) := (others => '0');
    signal sound4           : std_logic_vector(15 downto 0) := (others => '0');
    signal video            : std_logic_vector(11 downto 0) := (others => '0');   
--    signal row_std          : std_logic_vector(9 downto 0)  := (others => '0');
--    signal column_std       : std_logic_vector(9 downto 0)  := (others => '0');
    
begin

dut: vga_controller
    generic map(
        h_pulse     => 96,
        h_bp        => 48,
        h_pixels    => 640,
        h_fp        => 16,
        v_pulse     => 2,
        v_bp        => 33,
        v_pixels    => 480,
        v_fp        => 10
    )
    port map(
        pixel_clk   => pixel_clk, 
        reset_n     => nrst,
        h_sync      => h_sync,
        v_sync      => v_sync,
        disp_ena    => disp_ena,
        column      => column,
        row         => row
    );
    
dut2 : vga_gen
    generic map (
        HEIGHT      => 480,
        WIDTH       => 640,
        PCM_WIDTH   => 16,
        VGA_WIDTH   => 12,
        FIXED_LEN   => 8,
        COEF_NUM    => 55,
        AVG_NUM     => 64,
        AVG_2_NUM   => 6,
        LINE_BUF    => 40,
        MIC_WIDTH   => 55,
        SPACING     => 17,
        V_SPACE     => 20,
        H_SPACE     => 120
    )
    port map (
        clk_p       => pixel_clk,
        clk_d       => pixel_clk,
        nrst        => nrst,
        sound_1     => sound1,
        sound_2     => sound2,
        sound_3     => sound3,
        sound_4     => sound4,
        row         => row,
        col         => column,
        en          => disp_ena,
        video       => video
    );
clk_process : process
    begin
        pixel_clk     <= '0';
        wait for period/2;  --for 0.5 ns signal is '0'.
        pixel_clk     <= '1';
        wait for period/2;  --for next 0.5 ns signal is '1'.
    end process;
    
clk_process2 : process
    begin
        data_clk     <= '0';
        wait for period/2;  --for 0.5 ns signal is '0'.
        data_clk     <= '1';
        wait for period/2;  --for next 0.5 ns signal is '1'.
    end process;
    
--    row_std     <= std_logic_vector(row);
--    column_std  <= std_logic_vector(column);

testprocess : process 
begin	
    
    sound1      <= x"ffd8";
    sound2      <= x"00a5";
    sound3      <= x"00aa";
    sound4      <= x"0055";

    nrst        <= '0';
    wait for 2 ns;
    nrst        <= '1';

    wait;
    
end process;


end Behavioral;
