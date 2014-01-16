----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson
--
-- Create Date:    01/10/2014 
-- Design Name:
-- Module Name:    packet_source_destination_swapper_testbench - Behavioral
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
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

use work.sapet_packets.all;

entity packet_source_destination_swapper_testbench is
end packet_source_destination_swapper_testbench;

architecture Behavioral of packet_source_destination_swapper_testbench is 

	-- Component Declaration
	component packet_source_destination_swapper is
	port (
		reset   : in  std_logic;
		clk     : in  std_logic;
		din     : in  std_logic_vector(15 downto 0);
		din_wr  : in  std_logic;
		swap_en : in  std_logic;
		dout    : out std_logic_vector(15 downto 0);
		dout_wr : out std_logic
	);	
	end component;	

	signal reset    : std_logic := '0';
	signal clk      : std_logic := '0';
	signal din      : std_logic_vector(15 downto 0) := x"0000";
	signal din_wr   : std_logic := '0';
	signal swap_en  : std_logic := '0';
	signal dout     : std_logic_vector(15 downto 0);
	signal dout_wr  : std_logic := '0';

	constant test1_length : integer := 30;
	type   integer_sequence is array(integer range <>) of integer;
	type   bit_sequence     is array(integer range <>) of std_logic;
	type   uint4_sequence   is array(integer range <>) of std_logic_vector( 3 downto 0);
	type   uint16_sequence  is array(integer range <>) of std_logic_vector(15 downto 0);
	signal step_index_seq  : integer_sequence(0 to test1_length-1);
	signal din_seq         : uint16_sequence (0 to test1_length-1);
	signal din_wr_en_seq   : bit_sequence    (0 to test1_length-1);
	signal din_wr_seq      : bit_sequence    (0 to test1_length-1);
	signal swap_en_seq     : bit_sequence    (0 to test1_length-1);
	signal dout_seq        : uint16_sequence (0 to test1_length-1);
	signal dout_wr_seq     : bit_sequence    (0 to test1_length-1);

	constant TC : std_logic_vector(7 downto 0) := packet_start_token_frontend_config; -- acronym for "Token Config"
	constant TD : std_logic_vector(7 downto 0) := packet_start_token_data_AND_mode;   -- acronym for "Token Data"
begin

	uut: packet_source_destination_swapper port map(
		reset       => reset,
		clk         => clk,
		din         => din,
		din_wr      => din_wr,
		swap_en     => swap_en,
		dout        => dout,
		dout_wr     => dout_wr
	);

	-- Test Bench Process
	tb : process
	begin
	
		reset    <= '0';
		clk      <= '0';
		din      <= x"0000";
		din_wr   <= '0';
		swap_en  <= '0';

		----------------------------------------------------------------------------
		-- Test 1 - reset behavior - not much should happen, really.
		-- - Not a very robust test.
		----------------------------------------------------------------------------
		
		reset  <= '1';
		din    <= x"0102";
		din_wr <= '0';

		for I in 0 to 3 loop
			clk <= '0';
			wait for 2.5 ns;
			clk <= '1';
			wait for 2.5 ns;
		end loop;
		
		wait for 1 ps;
		
		reset <= '0';

		-- Lowest level FIFO needs clocks to wake up. Otherwise holds the full flag.
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

		-- FIFO Input Stuff
		-- inputs
		step_index_seq             <= (        1,        2,        3,       4,        5,        6,       7,       8,       9,      10,      11,      12,       13,       14,      15,      16,      17,      18,       19,      20,       21,      22,      23,      24,      25,      26,      27,      28,      29,      30);
		din_seq                    <= ( TC&x"01", TC&x"02",  x"0304", x"05FF", TC&x"04",  x"1718", x"FF00", x"1010", x"1111", x"1212", x"1313", x"1414", TC&x"01",  x"1515", x"0304", x"1616", x"05FF", x"1717", TC&x"04", x"1818",  x"5566", x"1919", x"FF00", x"2121", x"2222", x"2323", x"2424", x"2525", x"2626", x"2727");
		din_wr_seq                 <= (      '0',      '1',      '1',     '1',      '1',      '1',     '1',     '0',     '0',     '0',     '0',     '0',      '1',      '0',     '1',     '0',     '1',     '0',      '1',     '0',      '1',     '0',     '1',     '0',     '0',     '0',     '0',     '0',     '0',     '0');
		swap_en_seq                <= (      '0',      '1',      '1',     '1',      '0',      '0',     '0',     '0',     '0',     '0',     '0',     '0',      '0',      '0',     '0',     '0',     '0',     '0',      '1',     '1',      '1',     '1',     '1',     '1',     '0',     '0',     '0',     '0',     '0',     '0');
		-- outputs
		dout_seq                   <= (  x"0102", TC&x"01", TC&x"03", x"0204",  x"05FF", TC&x"04", x"1718", x"FF00", x"1010", x"1111", x"1212", x"1313",  x"1414", TC&x"01", x"1515", x"0304", x"1616", x"05FF",  x"1717", x"0000", TC&x"55", x"0466", x"1919", x"FF00", x"2121", x"2222", x"2323", x"2424", x"2525", x"2626");
		dout_wr_seq                <= (      '0',      '0',      '1',     '1',      '1',      '1',     '1',     '1',     '0',     '0',     '0',     '0',      '0',      '1',     '0',     '1',     '0',     '1',      '0',     '0',      '1',     '1',     '0',     '1',     '0',     '0',     '0',     '0',     '0',     '0');

		wait for 1 ps;

		for I in 0 to test1_length-1 loop
			wait for 3 ns;
			-- input to put data into FIFO
			din <= din_seq(I);
			din_wr <= din_wr_seq(I);
			swap_en <= swap_en_seq(I);
			wait for 3 ns;

			assert dout = dout_seq(I)
				report "Test 2, Error dout " & integer'image(step_index_seq(I)) severity failure;
			assert dout_wr = dout_wr_seq(I)
				report "Test 2, Error dout_wr " & integer'image(step_index_seq(I)) severity failure;
			
			--clock sequence
			wait for 4 ns; clk <= '0'; wait for 10 ns; clk <= '1';
		end loop;


		report "Successfully completed tests!";

		wait; -- will wait forever
	end process;

end Behavioral;
