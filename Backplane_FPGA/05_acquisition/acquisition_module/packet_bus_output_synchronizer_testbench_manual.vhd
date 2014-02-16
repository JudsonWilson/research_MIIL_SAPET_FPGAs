----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson
--
-- Create Date:    02/16/2014 
-- Design Name:
-- Module Name:    packet_bus_output_synchronizer_testbench_manual_input - Behavioral
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--     Simulation test for packet_bus_output_synchronizer_testbench_manual_input.
-- This uses manual input. Should also test against input from a real
-- packet-fifo to make sure it's fully compatible, although that will be more
-- difficult to test corner cases.
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

entity packet_bus_output_synchronizer_testbench_manual is
end packet_bus_output_synchronizer_testbench_manual;

architecture Behavioral of packet_bus_output_synchronizer_testbench_manual is 

	-- Component Declaration
	component packet_bus_output_synchronizer is
	port (
		reset       : in std_logic;
		clk         : in std_logic;
		-- Input, Source Port
		din_rd_en  : out std_logic;
		din_packet_available : in std_logic; -- Goes to '1' before first word of packet is read, goes to '0' immediately afterwards.
		din_empty_notready   : in std_logic; -- Indicates the user should not try and read (rd_en). May happen mid-packet! Always check this!
		din        : in std_logic_vector(15 downto 0);
		din_end_of_packet : in std_logic;
		-- Output Port
		dout_rd_en  : in std_logic;
		dout_packet_available : out std_logic; -- Goes to '1' before first word of packet is read, goes to '0' immediately afterwards.
		dout_empty_notready   : out std_logic; -- Indicates the user should not try and read (rd_en). May happen mid-packet! Always check this!
		dout        : out std_logic_vector(15 downto 0);
		dout_end_of_packet : out std_logic
	);
	end component;

	signal reset                 : std_logic;
	signal clk                   : std_logic;
	signal din_rd_en             : std_logic;
	signal din_packet_available  : std_logic;
	signal din_empty_notready    : std_logic;
	signal din                   : std_logic_vector(15 downto 0);
	signal din_end_of_packet     : std_logic;
	signal dout_rd_en            : std_logic;
	signal dout_packet_available : std_logic;
	signal dout_empty_notready   : std_logic;
	signal dout                  : std_logic_vector(15 downto 0);
	signal dout_end_of_packet    : std_logic;
	
	constant test1_length : integer := 30;
	type   integer_sequence is array(integer range <>) of integer;
	type   bit_sequence     is array(integer range <>) of std_logic;
	type   uint4_sequence   is array(integer range <>) of std_logic_vector( 3 downto 0);
	type   uint16_sequence  is array(integer range <>) of std_logic_vector(15 downto 0);
	signal step_index_seq            : integer_sequence(0 to test1_length-1);

	signal din_rd_en_seq             : bit_sequence    (0 to test1_length-1);
	signal din_packet_available_seq  : bit_sequence    (0 to test1_length-1);
	signal din_empty_notready_seq    : bit_sequence    (0 to test1_length-1);
	signal din_seq                   : uint16_sequence (0 to test1_length-1);
	signal din_end_of_packet_seq     : bit_sequence    (0 to test1_length-1);

	signal dout_rd_en_seq            : bit_sequence    (0 to test1_length-1);
	signal dout_packet_available_seq : bit_sequence    (0 to test1_length-1);
	signal dout_empty_notready_seq   : bit_sequence    (0 to test1_length-1);
	signal dout_seq                  : uint16_sequence (0 to test1_length-1);
	signal dout_end_of_packet_seq    : bit_sequence    (0 to test1_length-1);

	constant TC : std_logic_vector(7 downto 0) := packet_start_token_frontend_config; -- acronym for "Token Config"
	constant TE : std_logic_vector(7 downto 0) := packet_end_token;  -- acronym for "Token End"

begin

	uut: packet_bus_output_synchronizer port map (
		reset       => reset,
		clk         => clk,
		-- Input, Source Port
		din_rd_en  => din_rd_en,
		din_packet_available => din_packet_available,
		din_empty_notready   => din_empty_notready,
		din        => din,
		din_end_of_packet => din_end_of_packet,
		-- Output Port
		dout_rd_en  => dout_rd_en,
		dout_packet_available => dout_packet_available,
		dout_empty_notready   => dout_empty_notready,
		dout        => dout,
		dout_end_of_packet => dout_end_of_packet
	);

	-- Test Bench Process
	tb : process
	begin
	
		reset      <= '0';
		clk        <= '0';
		din_packet_available <= '0';
		din_empty_notready   <= '1';
		din        <= x"0000";
		din_end_of_packet    <= '1';
		dout_rd_en <= '0';

		----------------------------------------------------------------------------
		-- Test 1 - reset behavior - not much should happen, really.
		-- - Not a very robust test.
		----------------------------------------------------------------------------
		
		reset <= '1';
		din <= x"0102";

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
		----------------------------------------------------------------------------

		step_index_seq              <= (       1,        2,        3,        4,        5,        6,        7,        8,        9,       10,       11,       12,       13,       14,       15,       16,       17,       18,       19,       20,       21,       22,       23,       24,       25,       26,       27,       28,       29,       30);
		-- Input Port Related
		-- input
		din_packet_available_seq    <= (     '1',      '0',      '0',      '1',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0');
		din_empty_notready_seq      <= (     '0',      '0',      '0',      '0',      '0',      '0',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1');
		din_seq                     <= (TE&x"00", TC&x"02",  x"0304",  x"05FF", TC&x"04",  x"1718", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00");
		din_end_of_packet_seq       <= (     '0',      '0',      '0',      '1',      '0',      '0',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1');
		-- outputs - check against these!
		din_rd_en_seq               <= (     '1',      '1',      '1',      '1',      '1',      '1',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0');

		-- Input Port Related
		-- input
		dout_rd_en_seq              <= (     '0',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0');
		-- outputs - check against these!
		dout_packet_available_seq   <= (     '0',      '1',      '0',      '0',      '1',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0');
		dout_empty_notready_seq     <= (     '1',      '0',      '0',      '0',      '0',      '0',      '0',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1');
		dout_seq                    <= ( x"0000",  x"0000", TC&x"02",  x"0304",  x"05FF", TC&x"04",  x"1718", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00");
		dout_end_of_packet_seq      <= (     '1',      '1',      '0',      '0',      '1',      '0',      '0',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1');
		
		wait for 1 ps;

		for I in 0 to test1_length-1 loop
			wait for 3 ns;
			-- input to simulate the output of a packet_fifo
			din_packet_available <= din_packet_available_seq(I);
			din_empty_notready <= din_empty_notready_seq(I);
			din <= din_seq(I);
			din_end_of_packet <= din_end_of_packet_seq(I);
			wait for 2 ns;
			-- reactionary inputs, from something reacting to this components outputs
			dout_rd_en <= dout_rd_en_seq(I);
			-- wait for outputs (din_rd_en) to respond
			wait for 1 ns;

			assert din_rd_en = din_rd_en_seq(I)
				report "Test 2, Error din_rd_en " & integer'image(step_index_seq(I)) severity failure;
			assert dout_packet_available = dout_packet_available_seq(I)
				report "Test 2, Error dout_packet_available " & integer'image(step_index_seq(I)) severity failure;
			assert dout_empty_notready = dout_empty_notready_seq(I)
				report "Test 2, Error dout_empty_notready " & integer'image(step_index_seq(I)) severity failure;
			assert dout = dout_seq(I)
				report "Test 2, Error dout " & integer'image(step_index_seq(I)) severity failure;
			assert dout_end_of_packet = dout_end_of_packet_seq(I)
				report "Test 2, Error dout_end_of_packet " & integer'image(step_index_seq(I)) severity failure;
			
			--clock sequence
			wait for 4 ns; clk <= '0'; wait for 10 ns; clk <= '1';
		end loop;


		----------------------------------------------------------------------------
		-- Test 3
		-- Run two packets through with lots of gaps 
		----------------------------------------------------------------------------

		step_index_seq              <= (       1,        2,        3,        4,        5,        6,        7,        8,        9,       10,       11,       12,       13,       14,       15,       16,       17,       18,       19,       20,       21,       22,       23,       24,       25,       26,       27,       28,       29,       30);
		-- Input Port Related
		-- input
		din_packet_available_seq    <= (     '1',      '0',      '0',      '0',      '0',      '0',      '1',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0');
		din_empty_notready_seq      <= (     '0',      '1',      '0',      '0',      '1',      '1',      '0',      '1',      '1',      '0',      '0',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1');
		din_seq                     <= (TE&x"00", TC&x"02", TC&x"02",  x"0304",  x"05FF",  x"05FF",  x"05FF", TC&x"04", TC&x"04", TC&x"04",  x"1718", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00");
		din_end_of_packet_seq       <= (     '1',      '0',      '0',      '0',      '1',      '1',      '1',      '0',      '0',      '0',      '0',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1');
		-- outputs - check against these!
		din_rd_en_seq               <= (     '1',      '0',      '1',      '1',      '0',      '0',      '1',      '0',      '0',      '1',      '1',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0');

		-- Input Port Related
		-- input
		dout_rd_en_seq              <= (     '0',      '1',      '0',      '1',      '1',      '0',      '0',      '1',      '0',      '0',      '1',      '1',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0');
		-- outputs - check against these!
		dout_packet_available_seq   <= (     '0',      '1',      '0',      '0',      '0',      '0',      '0',      '1',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0');
		dout_empty_notready_seq     <= (     '1',      '0',      '1',      '0',      '0',      '1',      '1',      '0',      '1',      '1',      '0',      '0',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1');
		dout_seq                    <= (TE&x"00", TE&x"00", TC&x"02", TC&x"02",  x"0304",  x"05FF",  x"05FF",  x"05FF", TC&x"04", TC&x"04", TC&x"04",  x"1718", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00", TE&x"00");
		dout_end_of_packet_seq      <= (     '1',      '1',      '0',      '0',      '0',      '1',      '1',      '1',      '0',      '0',      '0',      '0',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1');
		
		wait for 1 ps;

		for I in 0 to test1_length-1 loop
			wait for 3 ns;
			-- input to simulate the output of a packet_fifo
			din_packet_available <= din_packet_available_seq(I);
			din_empty_notready <= din_empty_notready_seq(I);
			din <= din_seq(I);
			din_end_of_packet <= din_end_of_packet_seq(I);
			wait for 2 ns;
			-- reactionary inputs, from something reacting to this components outputs
			dout_rd_en <= dout_rd_en_seq(I);
			-- wait for outputs (din_rd_en) to respond
			wait for 1 ns;

			assert din_rd_en = din_rd_en_seq(I)
				report "Test 3, Error din_rd_en " & integer'image(step_index_seq(I)) severity failure;
			assert dout_packet_available = dout_packet_available_seq(I)
				report "Test 3, Error dout_packet_available " & integer'image(step_index_seq(I)) severity failure;
			assert dout_empty_notready = dout_empty_notready_seq(I)
				report "Test 3, Error dout_empty_notready " & integer'image(step_index_seq(I)) severity failure;
			assert dout = dout_seq(I)
				report "Test 3, Error dout " & integer'image(step_index_seq(I)) severity failure;
			assert dout_end_of_packet = dout_end_of_packet_seq(I)
				report "Test 3, Error dout_end_of_packet " & integer'image(step_index_seq(I)) severity failure;
			
			--clock sequence
			wait for 4 ns; clk <= '0'; wait for 10 ns; clk <= '1';
		end loop;




		report "Successfully completed tests!";

		wait; -- will wait forever
	end process;

end Behavioral;
