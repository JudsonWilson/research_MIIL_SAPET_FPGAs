----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson
--
-- Create Date:    01/09/2014
-- Design Name:
-- Module Name:    output_fifo_switch_testbench - Behavioral
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--     Simulation test for output_fifo_switch.
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity output_fifo_switch_testbench is
end output_fifo_switch_testbench;

architecture Behavioral of output_fifo_switch_testbench is 

	-- Component Declaration
	component output_fifo_switch is
	port (
		reset         : in std_logic;
		clk           : in std_logic;
		-- control logic
		en_ch_1 : in std_logic; -- one-hot source selectors, act immediately
		en_ch_2 : in std_logic;
		en_ch_3 : in std_logic;
		set_channels : in std_logic;
		-- input signal
		in_wr_en      : in std_logic;
		-- output signal
		out_wr_en_1    : out std_logic;
		out_wr_en_2    : out std_logic;
		out_wr_en_3    : out std_logic
	);
	end component;

	signal reset         : std_logic;
	signal clk           : std_logic;
	signal in_rd_en      : std_logic;
	signal en_ch_1       : std_logic;
	signal en_ch_2       : std_logic;
	signal en_ch_3       : std_logic;
	signal set_channels  : std_logic;
	signal in_wr_en      : std_logic;
	signal out_wr_en_1   : std_logic;
	signal out_wr_en_2   : std_logic;
	signal out_wr_en_3   : std_logic;

	constant test1_length : integer := 23;
	type   integer_sequence is array(integer range <>) of integer;
	type   bit_sequence     is array(integer range <>) of std_logic;
	signal step_index_seq    : integer_sequence(0 to test1_length-1);
	signal in_rd_en_seq      : bit_sequence    (0 to test1_length-1);
	signal en_ch_1_seq       : bit_sequence    (0 to test1_length-1);
	signal en_ch_2_seq       : bit_sequence    (0 to test1_length-1);
	signal en_ch_3_seq       : bit_sequence    (0 to test1_length-1);
	signal set_channels_seq  : bit_sequence    (0 to test1_length-1);
	signal in_wr_en_seq      : bit_sequence    (0 to test1_length-1);
	signal out_wr_en_1_seq   : bit_sequence    (0 to test1_length-1);
	signal out_wr_en_2_seq   : bit_sequence    (0 to test1_length-1);
	signal out_wr_en_3_seq   : bit_sequence    (0 to test1_length-1);

begin

	uut: output_fifo_switch port map (
		reset => reset,
		clk   => clk,
		-- control logic
		en_ch_1 => en_ch_1, -- one-hot source selectors, act immediately
		en_ch_2 => en_ch_2,
		en_ch_3 => en_ch_3,
		set_channels => set_channels,
		-- input signal
		in_wr_en     => in_wr_en,
		-- output signal
		out_wr_en_1  => out_wr_en_1,
		out_wr_en_2  => out_wr_en_2,
		out_wr_en_3  => out_wr_en_3
	);


	-- Test Bench Process
	tb : process
	begin
	
		reset        <= '0';
		clk          <= '0';
		en_ch_1      <= '0';
		en_ch_2      <= '0';
		en_ch_3      <= '0';
		set_channels <= '0';
		in_wr_en     <= '0';

		----------------------------------------------------------------------------
		-- Reset
		----------------------------------------------------------------------------
		
		reset <= '1';

		for I in 0 to 3 loop
			clk <= '0';
			wait for 2.5 ns;
			clk <= '1';
			wait for 2.5 ns;
		end loop;
		
		wait for 1 ps;
		
		reset <= '0';

		for I in 0 to 3 loop
			clk <= '0';
			wait for 2.5 ns;
			clk <= '1';
			wait for 2.5 ns;
		end loop;

		----------------------------------------------------------------------------
		-- Test 2 
		-- Run two packets through with no gap. 
		-- Actually bends the rules a bit by continuing to assert rd_en between
		-- packets, which will not break anything, but obviously no new data
		-- comes out until the next packet is ready. Things work as they should.
		----------------------------------------------------------------------------

		-- inputs
		step_index_seq    <= (       1,       2,       3,       4,       5,       6,       7,       8,       9,      10,      11,      12,      13,      14,      15,      16,      17,      18,      19,      20,      21,      22,      23);
		en_ch_1_seq       <= (     '0',     '1',     '0',     '0',     '0',     '0',     '0',     '1',     '0',     '1',     '0',     '1',     '0',     '1',     '0',     '0',     '0',     '1',     '0',     '1',     '0',     '0',     '1');
		en_ch_2_seq       <= (     '0',     '0',     '0',     '1',     '0',     '0',     '0',     '1',     '0',     '1',     '0',     '0',     '0',     '1',     '1',     '0',     '1',     '0',     '1',     '0',     '0',     '1',     '1');
		en_ch_3_seq       <= (     '0',     '0',     '0',     '0',     '0',     '1',     '0',     '0',     '0',     '0',     '0',     '1',     '0',     '1',     '1',     '0',     '1',     '0',     '0',     '0',     '0',     '0',     '0');
		set_channels_seq  <= (     '0',     '0',     '0',     '0',     '0',     '1',     '0',     '0',     '0',     '1',     '0',     '1',     '0',     '1',     '0',     '0',     '1',     '0',     '0',     '1',     '0',     '0',     '1');
		in_wr_en_seq      <= (     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '0',     '1',     '1',     '1',     '1',     '1',     '1',     '0',     '1',     '1',     '0',     '0',     '0',     '1',     '1',     '0');
		-- outputs
		out_wr_en_1_seq   <= (     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '1',     '1',     '1',     '1',     '1',     '0',     '1',     '0',     '0',     '0',     '0',     '1',     '1',     '0');
		out_wr_en_2_seq   <= (     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '1',     '1',     '0',     '0',     '1',     '0',     '1',     '1',     '0',     '0',     '0',     '0',     '0',     '0');
		out_wr_en_3_seq   <= (     '0',     '0',     '0',     '0',     '0',     '1',     '1',     '0',     '1',     '0',     '0',     '1',     '1',     '1',     '0',     '1',     '1',     '0',     '0',     '0',     '0',     '0',     '0');

		-- Let changes take effect
		wait for 1 ps;

		for I in 0 to test1_length-1 loop
			wait for 3 ns;
			-- input
			en_ch_1 <= en_ch_1_seq(I);
			en_ch_2 <= en_ch_2_seq(I);
			en_ch_3 <= en_ch_3_seq(I);
			set_channels <= set_channels_seq(I);
			in_wr_en <= in_wr_en_seq(I);
			wait for 3 ns;

			--check output
			assert out_wr_en_1 = out_wr_en_1_seq(I)
				report "Error out_wr_en_1 @ " & integer'image(step_index_seq(I)) severity failure;
			assert out_wr_en_2 = out_wr_en_2_seq(I)
				report "Error out_wr_en_2 @ " & integer'image(step_index_seq(I)) severity failure;
			assert out_wr_en_3 = out_wr_en_3_seq(I)
				report "Error out_wr_en_3 @ " & integer'image(step_index_seq(I)) severity failure;
			
			--clock sequence
			wait for 4 ns; clk <= '0'; wait for 10 ns; clk <= '1';
		end loop;

		-- Done
		report "Successfully completed tests!";

		wait; -- will wait forever
	end process;

end Behavioral;
