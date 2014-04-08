----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson
--
-- Create Date:    04/08/2014
-- Design Name:
-- Module Name:    packet_source_changer_testbench - Behavioral
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--     Simulation test for packet_source_changer.
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

entity packet_source_changer_testbench is
end packet_source_changer_testbench;

architecture Behavioral of packet_source_changer_testbench is 

	-- Component Declaration
	component packet_source_changer is
	port (
		reset   : in  std_logic;
		clk     : in  std_logic;
		from_node_addr  : in std_logic_vector(7 downto 0);
		from_board_addr : in std_logic_vector(7 downto 0); -- Usually this is ('0' & board & rena), where board is 6 bits and rena is 1.
		din     : in  std_logic_vector(15 downto 0);
		din_wr  : in  std_logic;
		dout    : out std_logic_vector(15 downto 0);
		dout_wr : out std_logic
	);
	end component;

	signal reset           : std_logic;
	signal clk             : std_logic;
	signal din             : std_logic_vector(15 downto 0);
	signal din_wr          : std_logic;
	signal dout            : std_logic_vector(15 downto 0);
	signal dout_wr         : std_logic;

	constant test1_length : integer := 20;
	type   integer_sequence is array(integer range <>) of integer;
	type   bit_sequence     is array(integer range <>) of std_logic;
	type   uint16_sequence  is array(integer range <>) of std_logic_vector(15 downto 0);
	signal step_index_seq             : integer_sequence(0 to test1_length-1);
	signal din_seq                    : uint16_sequence (0 to test1_length-1);
	signal din_wr_seq                 : bit_sequence    (0 to test1_length-1);
	signal dout_seq                   : uint16_sequence (0 to test1_length-1);
	signal dout_wr_seq                : bit_sequence    (0 to test1_length-1);

begin

	uut: packet_source_changer port map (
		reset   => reset,
		clk     => clk,
		from_node_addr  => x"AB",
		from_board_addr => x"CD",
		din     => din,
		din_wr  => din_wr,
		dout    => dout,
		dout_wr => dout_wr
	);

	-- Test Bench Process
	tb : process
	begin
	
		reset      <= '0';
		clk        <= '0';
		din        <= x"0000";
		din_wr     <= '0';

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
		-- Test 1 
		-- Try different packet headers
		----------------------------------------------------------------------------

		-- inputs
		step_index_seq                  <= (       1,       2,       3,       4,       5,       6,       7,       8,       9,      10,      11,      12,      13,      14,      15,      16,      17,      18,      19,      20);
		din_wr_seq                      <= (     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '0',     '0',     '1',     '1',     '0',     '0',     '0',     '1',     '0',     '1',     '0',     '1',     '0');
		din_seq                         <= ( x"C000", x"C101", x"C202", x"CC0C", x"1234", x"5678", x"CCEE", x"1234", x"5678", x"9ABC", x"DEF0", x"CC21", x"CC31", x"1141", x"1151", x"1161", x"1171", x"1181", x"1191", x"1201");
		-- outputs
		dout_wr_seq                     <= (     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '0',     '0',     '1',     '1',     '0',     '0',     '0',     '1',     '0',     '1',     '0',     '1',     '0');
		dout_seq                        <= ( x"C000", x"C101", x"C202", x"CCAB", x"12CD", x"5678", x"CCAB", x"1234", x"5678", x"9ACD", x"DEF0", x"CC21", x"CC31", x"1141", x"1151", x"1161", x"1171", x"1181", x"1191", x"1201");

		-- Let changes take effect
		wait for 1 ps;

		for I in 0 to test1_length-1 loop
			wait for 3 ns;
			-- input
			din        <= din_seq(I);
			din_wr     <= din_wr_seq(I);

			wait for 3 ns;

			--check output
			assert dout = dout_seq(I)
				report "Error dout @ " & integer'image(step_index_seq(I)) severity failure;
			assert dout_wr = dout_wr_seq(I)
				report "Error dout_wr @ " & integer'image(step_index_seq(I)) severity failure;
			
			--clock sequence
			wait for 4 ns; clk <= '0'; wait for 10 ns; clk <= '1';
		end loop;

		-- Done
		report "Successfully completed tests!";

		wait; -- will wait forever
	end process;

end Behavioral;
