----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.02.2024 18:33:59
-- Design Name: 
-- Module Name: test_integrator - Behavioral
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

--package fun_def1 is new work.fun_def generic map (M => 3, R => 8, N => 2, BIN_width => 1);
--use work.fun_def1.all;

----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.02.2024 18:33:59
-- Design Name: 
-- Module Name: test_integrator - Behavioral
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

--package fun_def1 is new work.fun_def generic map (M => 3, R => 8, N => 2, BIN_width => 1);
--use work.fun_def1.all;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

use std.textio.all;

use IEEE.std_logic_arith.all;
use IEEE.std_logic_signed.all;


entity test_sound is
    Generic (   BIN_width : integer := 1;       -- input size register 
                        BOUT_width :integer := 16;      -- output size register 
                        M :         integer := 3;       -- number of integer and comb stages
                        R :         integer := 8;       -- decimation factor
                        N :         integer := 2;       -- diferential delay
                        NUM_COEF :  integer := 26;      -- number of coeficients in halfband filters
                        FIXED_LEN : integer := 8;       -- length of fixed point for multiplication
                        RH :        integer := 2);      -- decimation factor 
end test_sound;

architecture Behavioral of test_sound is

    --Declare components
    component sound_combiner is
        Generic (   BIN_width : integer := 1;       -- input size register 
                    BOUT_width :integer := 16;      -- output size register 
                    M :         integer := 3;       -- number of integer and comb stages
                    R :         integer := 8;       -- decimation factor
                    N :         integer := 2;       -- diferential delay
                    NUM_COEF :  integer := 14;      -- number of coeficients in halfband filters
                    FIXED_LEN : integer := 5;       -- length of fixed point for multiplication
                    RH :        integer := 2);      -- decimation factor 
        Port (      clk_i : in STD_LOGIC;           -- input clock 33.33 MHz
                    clk_o : out STD_LOGIC;          -- output clock for system
                    nrst :  in STD_LOGIC;
                    D_in :  in STD_LOGIC_VECTOR (BIN_width-1 downto 0);
                    D_out : out STD_LOGIC_VECTOR (BIN_width-1 downto 0);
                    D_out_F : out STD_LOGIC_VECTOR (BOUT_width-1 downto 0));
    end component;
    
    CONSTANT period : TIME := 1 ns;
    signal D_in     : std_logic_vector(BIN_width-1 downto 0);
    signal D_out    : std_logic_vector(BIN_width-1 downto 0);
    signal D_out_F  : std_logic_vector(BOUT_width-1 downto 0);
    signal clk_i    : std_logic;
    signal clk_o    : std_logic;
    signal nrst     : std_logic;
    
    signal buff     : std_logic_vector(BIN_width-1 downto 0) := (others => '0');
    
    signal en       : std_logic := '0';
    
    signal o_valid  : std_logic := '0';
    signal o_add    : std_logic_vector(BIN_width-1 downto 0) := (others => '0');
    signal o_add_F  : std_logic_vector(BOUT_width-1 downto 0) := (others => '0');
    
    
begin

    dut: sound_combiner
    generic map(
        BIN_width   => BIN_width,
        BOUT_width  => BOUT_width,
        M           => M,
        R           => R,
        N           => N,
        NUM_COEF    => NUM_COEF,
        FIXED_LEN   => FIXED_LEN,
        RH          => RH
    )
    port map(
       clk_i    => clk_i,
       clk_o    => clk_o,
       nrst     => nrst,
       D_in     => D_in,
       D_out    => D_out,
       D_out_F  => D_out_F
    );
    
    clk_process : process
    begin
        clk_i <= '0';
        wait for period/2;  --for 0.5 ns signal is '0'.
        clk_i <= '1';
        wait for period/2;  --for next 0.5 ns signal is '1'.
    end process;
   
    file_read_process : process(clk_i, nrst)
        constant NUM_COL : integer := 1;
        type t_integer_array is array(integer range <>) of integer;
        file test_vector : text open read_mode is "D:\faks\2_letnik\mikroelektronski_sistemi\lab vaje\vaja09\VAJA10\TestData.txt";
        --file test_vector : text open read_mode is "C:\Users\mpolj\Downloads\laData_signal.csv";
        variable row : line;
        variable v_data_read : t_integer_array(1 to NUM_COL);
        variable v_data_row_counter : integer := 0;
    begin
        if (nrst = '0') then
            v_data_read := (others => -1);
            v_data_row_counter := 0;
        elsif (rising_edge(clk_i)) then
            if (en = '1') then
                if (not endfile(test_vector)) then
                    v_data_row_counter := v_data_row_counter+1;
                    readline(test_vector, row);
                end if;
                for kk in 1 to NUM_COL loop
                    read(row, v_data_read(kk));
                end loop;
                buff <= conv_std_logic_vector(v_data_read(1), BIN_width);
            end if;
        end if;
    end process;
    
    file_write_process: process(clk_i, nrst)
        file test_vectorw : text open write_mode is "D:\faks\2_letnik\mikroelektronski_sistemi\lab vaje\vaja09\VAJA10\PWM_converted_data.txt";
        variable roww : line;
    begin
        if (rising_edge(clk_i)) then
            if (o_valid = '1') then
                write(roww, conv_integer(o_add), right, 10);
                writeline(test_vectorw, roww); 
            end if;
        end if;
    end process;
    
    file_write_process2: process(clk_o, nrst)
        file test_vectorw : text open write_mode is "D:\faks\2_letnik\mikroelektronski_sistemi\lab vaje\vaja09\VAJA10\PWM_converted_data2.txt";
        variable roww : line;
    begin
        if (rising_edge(clk_o)) then
            if (o_valid = '1') then
                write(roww, conv_integer(o_add_F), right, 10);
                writeline(test_vectorw, roww); 
            end if;
        end if;
    end process;

    testprocess : process 
        variable count :    integer     := 0;
    begin	
        nrst    <= '1';
        --buff    <= TO_SIGNED(0, 2);
        D_in    <= (others => '0'); --resize(buff, BIN_width);
        --first   <= '1';
        
        wait for 10 ns;
        
        nrst    <= '0';
        wait for 6 ns;
        nrst    <= '1';
        en      <= '1';
--        o_valid <= '1';
        
        for i in 0 to 200000000 loop
--            if (count > 50) then
--                count := 0;
--                if (D_in(0) = '1') then
--                    D_in    <= (0 => '0', others => '0');
--                    wait for period;
--                else
--                    D_in    <= (0 => '1', others => '0');
--                    wait for period;
--                end if;
--            else 
--                count := count+1;
--                wait for period;
--            end if; 
            if ((count = 0) and not(D_in(0) = '0')) then
                o_valid <= '1';
                count := 1;
            end if;
            D_in <= buff;
            o_add <= D_out;
            o_add_F <= D_out_F;
            wait for period/2;
        end loop;
        
        wait for 1000 ns;
        
        nrst    <= '0';
        
        wait for 20 ns;
	wait;
end process;
end Behavioral;

