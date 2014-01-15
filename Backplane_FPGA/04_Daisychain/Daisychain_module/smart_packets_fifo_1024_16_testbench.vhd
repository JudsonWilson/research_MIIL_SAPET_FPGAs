----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson
--
-- Create Date:    01/05/2013 
-- Design Name:
-- Module Name:    smart_packets_fifo_1024_16_testbench - Behavioral
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--     Simulation test for smart_packets_fifo_1024_16. Run at least 2 us, until
--     you see a report message output saying failure or success.
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

entity smart_packets_fifo_1024_16_testbench is
end smart_packets_fifo_1024_16_testbench;

architecture Behavioral of smart_packets_fifo_1024_16_testbench is 

	-- Component Declaration
	component smart_packets_fifo_1024_16 is
	port (
		reset       : in std_logic;
		clk         : in std_logic;
		din_wr_en   : in std_logic;
		din         : in std_logic_vector(15 downto 0);
		dout_source_node      : out std_logic_vector(2 downto 0); -- 0 to 4, valid from start word through end word
		dout_destination_node : out std_logic_vector(2 downto 0); -- 0 to 4
		dout_rd_en  : in std_logic;
		dout_packet_available : out std_logic; -- Goes to '1' before first word of packet is read, goes to '0' immediately afterwards.
		dout_empty_notready   : out std_logic; -- Indicates the user should not try and read (rd_en). May happen mid-packet! Always check this!
		dout        : out std_logic_vector(15 downto 0);
		dout_end_of_packet : out std_logic;
		bytes_received     : out std_logic_vector(63 downto 0) -- includes those that are thrown away to preempt buffer overflow
	);	
	end component;	

	signal reset:                 std_logic;
	signal clk:                   std_logic;
	signal din_wr_en:             std_logic;
	signal din:                   std_logic_vector(15 downto 0);
	signal dout_source_node:      std_logic_vector(2 downto 0);
	signal dout_destination_node: std_logic_vector(2 downto 0);
	signal dout_rd_en:            std_logic;
	signal dout_packet_available: std_logic;
	signal dout_empty_notready:   std_logic;
	signal dout:                  std_logic_vector(15 downto 0);
	signal dout_end_of_packet:    std_logic;
	signal bytes_received:        std_logic_vector(63 downto 0); -- includes those that are thrown away to preempt buffer overflow

	constant test1_length : integer := 30;
	type   integer_sequence is array(integer range <>) of integer;
	type   bit_sequence     is array(integer range <>) of std_logic;
	type   uint4_sequence   is array(integer range <>) of std_logic_vector( 3 downto 0);
	type   uint16_sequence  is array(integer range <>) of std_logic_vector(15 downto 0);
	signal step_index_seq            : integer_sequence(0 to test1_length-1);
	signal din_seq                   : uint16_sequence (0 to test1_length-1);
	signal din_wr_en_seq             : bit_sequence    (0 to test1_length-1);
	signal dout_packet_available_seq : bit_sequence    (0 to test1_length-1);
	signal dout_empty_notready_seq   : bit_sequence    (0 to test1_length-1);
	signal dout_seq                  : uint16_sequence (0 to test1_length-1);
	signal dout_end_of_packet_seq    : bit_sequence    (0 to test1_length-1);
	signal dout_source_node_seq      : uint4_sequence  (0 to test1_length-1);
	signal dout_destination_node_seq : uint4_sequence  (0 to test1_length-1);
	signal dout_rd_en_seq            : bit_sequence    (0 to test1_length-1);

begin

	uut: smart_packets_fifo_1024_16 port map(
		reset       => reset,
		clk         => clk,
		din_wr_en   => din_wr_en,
		din         => din,
		dout_source_node       => dout_source_node,
		dout_destination_node  => dout_destination_node,
		dout_rd_en  => dout_rd_en,
		dout_packet_available  => dout_packet_available,
		dout_empty_notready    => dout_empty_notready,
		dout        => dout,
		dout_end_of_packet     => dout_end_of_packet,
		bytes_received         => bytes_received
	);


	-- Test Bench Process
	tb : process
	begin
	
		reset      <= '0';
		clk        <= '0';
		din_wr_en  <= '0';
		din        <= x"0000";
		dout_rd_en <= '0';

		----------------------------------------------------------------------------
		-- Test 1 - reset behavior - not much should happen, really.
		-- - Not a very robust test.
		----------------------------------------------------------------------------
		
		reset <= '1';
		din <= x"0102";
		din_wr_en <= '0';

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
		step_index_seq             <= (      1,       2,       3,       4,       5,       6,       7,       8,       9,      10,      11,      12,      13,      14,      15,      16,      17,      18,      19,      20,      21,      22,      23,      24,      25,      26,      27,      28,      29,      30);
		din_seq                    <= (x"8101", x"8102", x"0304", x"05FF", x"8104", x"1718", x"FF00", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000");
		din_wr_en_seq              <= (    '0',     '1',     '1',     '1',     '1',     '1',     '1',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0');
		-- outputs
		dout_packet_available_seq  <= (    '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '1',     '0',     '0',     '0',     '0',     '1',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0');
		dout_empty_notready_seq    <= (    '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '0',     '0',     '0',     '1',     '1',     '0',     '0',     '0',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1');

		-- FIFO Output Stuff
		-- inputs
		dout_rd_en_seq             <= (    '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0');
		-- outputs
		dout_seq                   <= (x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"8102", x"0304", x"05FF", x"05FF", x"05FF", x"8104", x"1718", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00");
		dout_end_of_packet_seq     <= (    '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '0',     '0',     '1',     '1',     '1',     '0',     '0',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1');
		dout_source_node_seq       <= (   x"0",    x"0",    x"0",    x"0",    x"0",    x"0",    x"0",    x"0",    x"0",    x"2",    x"2",    x"2",    x"2",    x"2",    x"4",    x"4",    x"4",    x"4",    x"4",    x"4",    x"4",    x"4",    x"4",    x"4",    x"4",    x"4",    x"4",    x"4",    x"4",    x"4");
		dout_destination_node_seq  <= (   x"0",    x"0",    x"0",    x"0",    x"0",    x"0",    x"0",    x"0",    x"0",    x"3",    x"3",    x"3",    x"3",    x"3",    x"7",    x"7",    x"7",    x"7",    x"7",    x"7",    x"7",    x"7",    x"7",    x"7",    x"7",    x"7",    x"7",    x"7",    x"7",    x"7");
		
		wait for 1 ps;

		for I in 0 to test1_length-1 loop
			wait for 3 ns;
			-- input to put data into FIFO
			din <= din_seq(I);
			din_wr_en <= din_wr_en_seq(I);
			wait for 3 ns;
			-- reactionary inputs to control FIFO output
			dout_rd_en <= dout_rd_en_seq(I);

			assert dout_packet_available = dout_packet_available_seq(I)
				report "Test 2, Error dout_packet_available " & integer'image(step_index_seq(I)) severity failure;
			assert dout_empty_notready = dout_empty_notready_seq(I)
				report "Test 2, Error dout_empty_notready " & integer'image(step_index_seq(I)) severity failure;
			assert dout_end_of_packet = dout_end_of_packet_seq(I)
				report "Test 2, Error dout_end_of_packet " & integer'image(step_index_seq(I)) severity failure;
			assert "0" & dout_source_node       = dout_source_node_seq(I)
				and "0" & dout_destination_node  = dout_destination_node_seq(I)
				report "Test 2, Error source/destination " & integer'image(step_index_seq(I)) severity failure;
			
			
			assert dout = dout_seq(I)
				report "Test 2, Error dout " & integer'image(step_index_seq(I)) severity failure;
			
			--clock sequence
			wait for 4 ns; clk <= '0'; wait for 10 ns; clk <= '1';
		end loop;

		assert bytes_received = x"000000000000000B" report "Test 2, Error bytes_recieved." severity failure;

		----------------------------------------------------------------------------
		-- Test 3 
		-- Run two packets through with gaps in various reads.
		-- Fetch using (kind of) the delayless-response model.
		----------------------------------------------------------------------------

		-- FIFO Input Stuff
		-- inputs
		step_index_seq             <= (      1,       2,       3,       4,       5,       6,       7,       8,       9,      10,      11,      12,      13,      14,      15,      16,      17,      18,      19,      20,      21,      22,      23,      24,      25,      26,      27,      28,      29,      30);
		din_seq                    <= (x"8101", x"8102", x"FFFF", x"0304", x"FFFF", x"05FF", x"FFFF", x"8104", x"FFFF", x"1718", x"FFFF", x"FF00", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000");
		din_wr_en_seq              <= (    '0',     '1',     '0',     '1',     '0',     '1',     '0',     '1',     '0',     '1',     '0',     '1',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0');
		-- outputs
		dout_packet_available_seq  <= (    '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '1',     '1',     '0',     '0',     '0',     '0',     '0',     '0',     '1',     '1',     '1',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0');
		dout_empty_notready_seq    <= (    '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '0',     '0',     '0',     '0',     '0',     '0',     '1',     '1',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '1',     '1',     '1',     '1',     '1');

		-- FIFO Output Stuff
		-- inputs
		dout_rd_en_seq             <= (    '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '1',     '0',     '1',     '0',     '1',     '0',     '0',     '0',     '0',     '1',     '0',     '1',     '0',     '1',     '0',     '0',     '0',     '0',     '0');
		-- outputs
		dout_seq                   <= (x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"8102", x"8102", x"0304", x"0304", x"05FF", x"05FF", x"05FF", x"05FF", x"05FF", x"8104", x"8104", x"1718", x"1718", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00");
		dout_end_of_packet_seq     <= (    '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '0',     '0',     '0',     '0',     '1',     '1',     '1',     '1',     '1',     '0',     '0',     '0',     '0',     '1',     '1',     '1',     '1',     '1');
		dout_source_node_seq       <= (   x"4",    x"4",    x"4",    x"4",    x"4",    x"4",    x"4",    x"4",    x"4",    x"4",    x"2",    x"2",    x"2",    x"2",    x"2",    x"2",    x"2",    x"2",    x"4",    x"4",    x"4",    x"4",    x"4",    x"4",    x"4",    x"4",    x"4",    x"4",    x"4",    x"4");
		dout_destination_node_seq  <= (   x"7",    x"7",    x"7",    x"7",    x"7",    x"7",    x"7",    x"7",    x"7",    x"7",    x"3",    x"3",    x"3",    x"3",    x"3",    x"3",    x"3",    x"3",    x"7",    x"7",    x"7",    x"7",    x"7",    x"7",    x"7",    x"7",    x"7",    x"7",    x"7",    x"7");
		
		wait for 1 ps;

		for I in 0 to test1_length-1 loop
			wait for 3 ns;
			-- input to put data into FIFO
			din <= din_seq(I);
			din_wr_en <= din_wr_en_seq(I);
			wait for 3 ns;
			-- reactionary inputs to control FIFO output
			dout_rd_en <= dout_rd_en_seq(I);

			assert dout_packet_available = dout_packet_available_seq(I)
				report "Test 3, Error dout_packet_available " & integer'image(step_index_seq(I)) severity failure;
			assert dout_empty_notready = dout_empty_notready_seq(I)
				report "Test 3, Error dout_empty_notready " & integer'image(step_index_seq(I)) severity failure;
			assert dout_end_of_packet = dout_end_of_packet_seq(I)
				report "Test 3, Error dout_end_of_packet " & integer'image(step_index_seq(I)) severity failure;
			assert "0" & dout_source_node       = dout_source_node_seq(I)
				and "0" & dout_destination_node  = dout_destination_node_seq(I)
				report "Test 3, Error source/destination " & integer'image(step_index_seq(I)) severity failure;
			assert dout = dout_seq(I)
				report "Test 3, Error dout " & integer'image(step_index_seq(I)) severity failure;
			
			--clock sequence
			wait for 4 ns; clk <= '0'; wait for 10 ns; clk <= '1';
		end loop;

		assert bytes_received = x"0000000000000016" report "Test 3, Error bytes_recieved." severity failure;



		report "Successfully completed tests!";


		wait; -- will wait forever
	end process;

end Behavioral;
