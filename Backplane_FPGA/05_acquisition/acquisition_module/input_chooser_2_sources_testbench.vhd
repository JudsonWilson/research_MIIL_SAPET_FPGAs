----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson
--
-- Create Date:    01/20/2014 
-- Design Name:
-- Module Name:    input_chooser_2_sources_testbench - Behavioral
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--     Simulation test for input_chooser_2_sources_testbench. Right now it's
-- meant to be run by hand and inspected by eye.
--     In the future, maybe use a standard FIFO (not our custom packet FIFO) to
-- catch all the output, and then after the first stage, do a second stage that
-- quickly empties the FIFO and compares it to what is expected.
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

entity input_chooser_2_sources_testbench is
end input_chooser_2_sources_testbench;

architecture Behavioral of input_chooser_2_sources_testbench is 

	component input_chooser_2_sources is
	port (
		reset       : in std_logic;
		clk         : in std_logic;
		-- Input, Source Port 0
		din_0_rd_en  : out std_logic;
		din_0_packet_available : in std_logic; -- Goes to '1' before first word of packet is read, goes to '0' immediately afterwards.
		din_0_empty_notready   : in std_logic; -- Indicates the user should not try and read (rd_en). May happen mid-packet! Always check this!
		din_0        : in std_logic_vector(15 downto 0);
		din_0_end_of_packet : in std_logic;
		-- Input, Source Port 1
		din_1_rd_en  : out std_logic;
		din_1_packet_available : in std_logic; -- Goes to '1' before first word of packet is read, goes to '0' immediately afterwards.
		din_1_empty_notready   : in std_logic; -- Indicates the user should not try and read (rd_en). May happen mid-packet! Always check this!
		din_1        : in std_logic_vector(15 downto 0);
		din_1_end_of_packet : in std_logic;
		-- Output Port
		dout_rd_en  : in std_logic;
		dout_packet_available : out std_logic; -- Goes to '1' before first word of packet is read, goes to '0' immediately afterwards.
		dout_empty_notready   : out std_logic; -- Indicates the user should not try and read (rd_en). May happen mid-packet! Always check this!
		dout        : out std_logic_vector(15 downto 0);
		dout_end_of_packet : out std_logic
	);
	end component;

	component packets_fifo_1024_16 is
	port (
		reset       : in std_logic;
		clk         : in std_logic;
		din_wr_en   : in std_logic;
		din         : in std_logic_vector(15 downto 0);
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

	signal fifo_0_din_wr_en              : std_logic;
	signal fifo_0_din                    : std_logic_vector(15 downto 0);
	signal fifo_0_dout_rd_en             : std_logic;
	signal fifo_0_dout_packet_available  : std_logic;
	signal fifo_0_dout_empty_notready    : std_logic;
	signal fifo_0_dout                   : std_logic_vector(15 downto 0);
	signal fifo_0_dout_end_of_packet     : std_logic;
	signal fifo_0_bytes_received         : std_logic_vector(63 downto 0); -- includes those that are thrown away to preempt buffer overflow

	signal fifo_1_din_wr_en              : std_logic;
	signal fifo_1_din                    : std_logic_vector(15 downto 0);
	signal fifo_1_dout_rd_en             : std_logic;
	signal fifo_1_dout_packet_available  : std_logic;
	signal fifo_1_dout_empty_notready    : std_logic;
	signal fifo_1_dout                   : std_logic_vector(15 downto 0);
	signal fifo_1_dout_end_of_packet     : std_logic;
	signal fifo_1_bytes_received         : std_logic_vector(63 downto 0); -- includes those that are thrown away to preempt buffer overflow

	signal dout_rd_en             : std_logic;
	signal dout_packet_available  : std_logic;
	signal dout_empty_notready    : std_logic;
	signal dout                   : std_logic_vector(15 downto 0);
	signal dout_end_of_packet     : std_logic;

	constant test1_length : integer := 30;
	type   integer_sequence is array(integer range <>) of integer;
	type   bit_sequence     is array(integer range <>) of std_logic;
	type   uint4_sequence   is array(integer range <>) of std_logic_vector( 3 downto 0);
	type   uint16_sequence  is array(integer range <>) of std_logic_vector(15 downto 0);
	signal step_index_seq            : integer_sequence(0 to test1_length-1);
	signal fifo_0_din_seq            : uint16_sequence (0 to test1_length-1);
	signal fifo_0_din_wr_en_seq      : bit_sequence    (0 to test1_length-1);
	signal fifo_1_din_seq            : uint16_sequence (0 to test1_length-1);
	signal fifo_1_din_wr_en_seq      : bit_sequence    (0 to test1_length-1);
	--signal dout_packet_available_seq : bit_sequence    (0 to test1_length-1);
	--signal dout_empty_notready_seq   : bit_sequence    (0 to test1_length-1);
	--signal dout_seq                  : uint16_sequence (0 to test1_length-1);
	--signal dout_end_of_packet_seq    : bit_sequence    (0 to test1_length-1);
	signal dout_rd_en_seq            : bit_sequence    (0 to test1_length-1);

	constant TC : std_logic_vector(7 downto 0) := packet_start_token_frontend_config; -- acronym for "Token Config"
	constant TE : std_logic_vector(7 downto 0) := packet_end_token;  -- acronym for "Token End"

begin

	fifo_source_0: packets_fifo_1024_16 port map(
		reset       => reset,
		clk         => clk,
		din_wr_en   => fifo_0_din_wr_en,
		din         => fifo_0_din,
		dout_rd_en  => fifo_0_dout_rd_en,
		dout_packet_available  => fifo_0_dout_packet_available,
		dout_empty_notready    => fifo_0_dout_empty_notready,
		dout        => fifo_0_dout,
		dout_end_of_packet     => fifo_0_dout_end_of_packet,
		bytes_received         => fifo_0_bytes_received
	);

	fifo_source_1: packets_fifo_1024_16 port map(
		reset       => reset,
		clk         => clk,
		din_wr_en   => fifo_1_din_wr_en,
		din         => fifo_1_din,
		dout_rd_en  => fifo_1_dout_rd_en,
		dout_packet_available  => fifo_1_dout_packet_available,
		dout_empty_notready    => fifo_1_dout_empty_notready,
		dout        => fifo_1_dout,
		dout_end_of_packet     => fifo_1_dout_end_of_packet,
		bytes_received         => fifo_1_bytes_received
	);

	uut: input_chooser_2_sources port map(
		reset       => reset,
		clk         => clk,
		-- Input, Source Port 0
		din_0_rd_en  => fifo_0_dout_rd_en,
		din_0_packet_available => fifo_0_dout_packet_available,
		din_0_empty_notready   => fifo_0_dout_empty_notready,
		din_0        => fifo_0_dout,
		din_0_end_of_packet => fifo_0_dout_end_of_packet,
		-- Input, Source Port 1
		din_1_rd_en  => fifo_1_dout_rd_en,
		din_1_packet_available => fifo_1_dout_packet_available,
		din_1_empty_notready   => fifo_1_dout_empty_notready,
		din_1        => fifo_1_dout,
		din_1_end_of_packet => fifo_1_dout_end_of_packet,
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
		fifo_0_din_wr_en  <= '0';
		fifo_0_din        <= x"0000";
		fifo_1_din_wr_en  <= '0';
		fifo_1_din        <= x"0000";
		dout_rd_en <= '0';

		----------------------------------------------------------------------------
		-- Test 1 - reset behavior - not much should happen, really.
		-- - Not a very robust test.
		----------------------------------------------------------------------------
		
		reset <= '1';
		fifo_0_din <= x"0102";
		fifo_0_din_wr_en <= '1';
		fifo_1_din <= x"0304";
		fifo_1_din_wr_en <= '1';

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
		-- Run two packets through with no gap, both input channels simultaneously.
		----------------------------------------------------------------------------

		-- FIFO Input Stuff
		-- inputs
		step_index_seq             <= (       1,        2,        3,        4,        5,        6,        7,        8,       9,      10,       11,      12,      13,      14,      15,       16,      17,      18,      19,      20,      21,      22,      23,      24,      25,      26,      27,      28,      29,      30);
		fifo_0_din_seq             <= (TC&x"03", TC&x"00",  x"0304",  x"05FF", TC&x"00",  x"1718",  x"FF00",  x"0000", x"0000", x"0000",  x"0000", x"0000", x"0000", x"0000", x"0000",  x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000");
		fifo_0_din_wr_en_seq       <= (     '0',      '1',      '1',      '1',      '1',      '1',      '1',      '0',     '0',     '0',      '0',     '0',     '0',     '0',     '0',      '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0');
		fifo_1_din_seq             <= (TC&x"04", TC&x"01",  x"0304",  x"05FF", TC&x"01",  x"1718",  x"FF00",  x"0000", x"0000", x"0000",  x"0000", x"0000", x"0000", x"0000", x"0000",  x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000");
		fifo_1_din_wr_en_seq       <= (     '0',      '1',      '1',      '1',      '1',      '1',      '1',      '0',     '0',     '0',      '0',     '0',     '0',     '0',     '0',      '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0');
		-- output related                                                                                         Read as soon as possible
		dout_rd_en_seq             <= (     '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',     '0',      '1',     '1',     '1',     '0',     '1',     '1',      '1',     '0',     '1',     '1',     '1',     '0',     '1',     '1',     '1',     '0',     '0',     '0',     '0',     '0',     '0');

--		-- outputs
--		dout_packet_available_seq  <= (     '0',      '0',      '0',      '0',      '0',      '0',      '0',      '1',     '0',     '0',      '1',     '0',     '0',     '0',     '0',      '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0');
--		dout_empty_notready_seq    <= (     '1',      '1',      '1',      '1',      '1',      '1',      '1',      '0',     '0',     '0',      '0',     '0',     '0',     '1',     '1',      '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1');
--
--		-- FIFO Output Stuff
--		-- inputs
--		dout_rd_en_seq             <= (     '0',      '0',      '0',      '0',      '0',      '0',      '0',      '1',     '1',     '1',      '1',     '1',     '1',     '1',     '1',      '1',     '1',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0');
--		-- outputs
--		dout_seq                   <= (x"00"&TE, x"00"&TE, x"00"&TE, x"00"&TE, x"00"&TE, x"00"&TE, x"00"&TE, x"00"&TE, TC&x"02", x"0304", x"05FF", TC&x"04", x"1718", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00");
--		dout_end_of_packet_seq     <= (     '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',     '0',     '0',      '1',      '0',     '0',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1');
		
		wait for 1 ps;

		for I in 0 to test1_length-1 loop
			wait for 3 ns;
			-- input to put data into FIFO
			fifo_0_din       <= fifo_0_din_seq(I);
			fifo_0_din_wr_en <= fifo_0_din_wr_en_seq(I);
			fifo_1_din       <= fifo_1_din_seq(I);
			fifo_1_din_wr_en <= fifo_1_din_wr_en_seq(I);
			dout_rd_en       <= dout_rd_en_seq(I);
			
			wait for 3 ns;
			-- reactionary inputs to control FIFO output
--			dout_rd_en <= dout_rd_en_seq(I);

--			assert dout_packet_available = dout_packet_available_seq(I)
--				report "Test 2, Error dout_packet_available " & integer'image(step_index_seq(I)) severity failure;
--			assert dout_empty_notready = dout_empty_notready_seq(I)
--				report "Test 2, Error dout_empty_notready " & integer'image(step_index_seq(I)) severity failure;
--			assert dout_end_of_packet = dout_end_of_packet_seq(I)
--				report "Test 2, Error dout_end_of_packet " & integer'image(step_index_seq(I)) severity failure;
--			
--			assert dout = dout_seq(I)
--				report "Test 2, Error dout " & integer'image(step_index_seq(I)) severity failure;
			
			--clock sequence
			wait for 4 ns; clk <= '0'; wait for 10 ns; clk <= '1';
		end loop;


		----------------------------------------------------------------------------
		-- Test 3 
		-- Run three packets through with no gap on one channel.
		----------------------------------------------------------------------------

		-- FIFO Input Stuff
		-- inputs
		step_index_seq             <= (       1,        2,        3,        4,        5,        6,        7,        8,       9,      10,       11,      12,      13,      14,      15,       16,      17,      18,      19,      20,      21,      22,      23,      24,      25,      26,      27,      28,      29,      30);
		fifo_0_din_seq             <= (TC&x"03", TC&x"00",  x"0304",  x"05FF", TC&x"00",  x"1718",  x"FF00", TC&x"00", x"0405", x"0607", TE&x"00", x"0000", x"0000", x"0000", x"0000",  x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000");
		fifo_0_din_wr_en_seq       <= (     '0',      '1',      '1',      '1',      '1',      '1',      '1',      '1',     '1',     '1',      '1',     '0',     '0',     '0',     '0',      '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0');
		-- output related                                                                                         Read as soon as possible
		dout_rd_en_seq             <= (     '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',     '0',     '1',      '1',     '1',     '0',     '1',     '1',      '1',     '0',     '1',     '1',     '1',     '1',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0');

--		-- outputs
--		dout_packet_available_seq  <= (     '0',      '0',      '0',      '0',      '0',      '0',      '0',      '1',     '0',     '0',      '1',     '0',     '0',     '0',     '0',      '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0');
--		dout_empty_notready_seq    <= (     '1',      '1',      '1',      '1',      '1',      '1',      '1',      '0',     '0',     '0',      '0',     '0',     '0',     '1',     '1',      '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1');
--
--		-- FIFO Output Stuff
--		-- inputs
--		dout_rd_en_seq             <= (     '0',      '0',      '0',      '0',      '0',      '0',      '0',      '1',     '1',     '1',      '1',     '1',     '1',     '1',     '1',      '1',     '1',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0');
--		-- outputs
--		dout_seq                   <= (x"00"&TE, x"00"&TE, x"00"&TE, x"00"&TE, x"00"&TE, x"00"&TE, x"00"&TE, x"00"&TE, TC&x"02", x"0304", x"05FF", TC&x"04", x"1718", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00");
--		dout_end_of_packet_seq     <= (     '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',     '0',     '0',      '1',      '0',     '0',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1');
		
		wait for 1 ps;

		for I in 0 to test1_length-1 loop
			wait for 3 ns;
			-- input to put data into FIFO
			fifo_0_din       <= fifo_0_din_seq(I);
			fifo_0_din_wr_en <= fifo_0_din_wr_en_seq(I);
			fifo_1_din       <= x"3246";
			fifo_1_din_wr_en <= '0';
			dout_rd_en       <= dout_rd_en_seq(I);
			
			wait for 3 ns;
			-- reactionary inputs to control FIFO output
--			dout_rd_en <= dout_rd_en_seq(I);

--			assert dout_packet_available = dout_packet_available_seq(I)
--				report "Test 2, Error dout_packet_available " & integer'image(step_index_seq(I)) severity failure;
--			assert dout_empty_notready = dout_empty_notready_seq(I)
--				report "Test 2, Error dout_empty_notready " & integer'image(step_index_seq(I)) severity failure;
--			assert dout_end_of_packet = dout_end_of_packet_seq(I)
--				report "Test 2, Error dout_end_of_packet " & integer'image(step_index_seq(I)) severity failure;
--			
--			assert dout = dout_seq(I)
--				report "Test 2, Error dout " & integer'image(step_index_seq(I)) severity failure;
			
			--clock sequence
			wait for 4 ns; clk <= '0'; wait for 10 ns; clk <= '1';
		end loop;


		----------------------------------------------------------------------------
		-- Test 4
		-- Basically run test 2 again, with fewer packets, but since test 3 last
		-- used channel 0, this should output channel 1 first. Output channel 0 last
		-- in this test so we can then run test 3 again but on channel 1 instead of
		-- channel 0.
		----------------------------------------------------------------------------

		-- FIFO Input Stuff
		-- inputs
		step_index_seq             <= (       1,        2,        3,        4,        5,        6,        7,        8,       9,      10,       11,      12,      13,      14,      15,       16,      17,      18,      19,      20,      21,      22,      23,      24,      25,      26,      27,      28,      29,      30);
		fifo_0_din_seq             <= (TC&x"03", TC&x"00",  x"0304",  x"05FF", TC&x"00",  x"1718",  x"FF00",  x"0000", x"0000", x"0000",  x"0000", x"0000", x"0000", x"0000", x"0000",  x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000");
		fifo_0_din_wr_en_seq       <= (     '0',      '1',      '1',      '1',      '1',      '1',      '1',      '0',     '0',     '0',      '0',     '0',     '0',     '0',     '0',      '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0');
		fifo_1_din_seq             <= (TC&x"04", TC&x"01",  x"0304",  x"05FF", TC&x"01",  x"1718",  x"FF00",  x"0000", x"0000", x"0000",  x"0000", x"0000", x"0000", x"0000", x"0000",  x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000");
		fifo_1_din_wr_en_seq       <= (     '0',      '1',      '1',      '1',      '1',      '1',      '1',      '0',     '0',     '0',      '0',     '0',     '0',     '0',     '0',      '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0');
		-- output related                                                                                         Read as soon as possible
		dout_rd_en_seq             <= (     '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',     '0',     '1',      '1',     '1',     '0',     '1',     '1',      '1',     '0',     '1',     '1',     '1',     '0',     '1',     '1',     '1',     '0',     '0',     '0',     '0',     '0',     '0');

--		-- outputs
--		dout_packet_available_seq  <= (     '0',      '0',      '0',      '0',      '0',      '0',      '0',      '1',     '0',     '0',      '1',     '0',     '0',     '0',     '0',      '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0');
--		dout_empty_notready_seq    <= (     '1',      '1',      '1',      '1',      '1',      '1',      '1',      '0',     '0',     '0',      '0',     '0',     '0',     '1',     '1',      '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1');
--
--		-- FIFO Output Stuff
--		-- inputs
--		dout_rd_en_seq             <= (     '0',      '0',      '0',      '0',      '0',      '0',      '0',      '1',     '1',     '1',      '1',     '1',     '1',     '1',     '1',      '1',     '1',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0');
--		-- outputs
--		dout_seq                   <= (x"00"&TE, x"00"&TE, x"00"&TE, x"00"&TE, x"00"&TE, x"00"&TE, x"00"&TE, x"00"&TE, TC&x"02", x"0304", x"05FF", TC&x"04", x"1718", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00");
--		dout_end_of_packet_seq     <= (     '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',     '0',     '0',      '1',      '0',     '0',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1');
		
		wait for 1 ps;

		for I in 0 to test1_length-1 loop
			wait for 3 ns;
			-- input to put data into FIFO
			fifo_0_din       <= fifo_0_din_seq(I);
			fifo_0_din_wr_en <= fifo_0_din_wr_en_seq(I);
			fifo_1_din       <= fifo_1_din_seq(I);
			fifo_1_din_wr_en <= fifo_1_din_wr_en_seq(I);
			dout_rd_en       <= dout_rd_en_seq(I);
			
			wait for 3 ns;
			-- reactionary inputs to control FIFO output
--			dout_rd_en <= dout_rd_en_seq(I);

--			assert dout_packet_available = dout_packet_available_seq(I)
--				report "Test 2, Error dout_packet_available " & integer'image(step_index_seq(I)) severity failure;
--			assert dout_empty_notready = dout_empty_notready_seq(I)
--				report "Test 2, Error dout_empty_notready " & integer'image(step_index_seq(I)) severity failure;
--			assert dout_end_of_packet = dout_end_of_packet_seq(I)
--				report "Test 2, Error dout_end_of_packet " & integer'image(step_index_seq(I)) severity failure;
--			
--			assert dout = dout_seq(I)
--				report "Test 2, Error dout " & integer'image(step_index_seq(I)) severity failure;
			
			--clock sequence
			wait for 4 ns; clk <= '0'; wait for 10 ns; clk <= '1';
		end loop;



		----------------------------------------------------------------------------
		-- Test 5 
		-- Run three packets through with no gap on one channel.
		----------------------------------------------------------------------------

		-- FIFO Input Stuff
		-- inputs
		step_index_seq             <= (       1,        2,        3,        4,        5,        6,        7,        8,       9,      10,       11,      12,      13,      14,      15,       16,      17,      18,      19,      20,      21,      22,      23,      24,      25,      26,      27,      28,      29,      30);
		fifo_1_din_seq             <= (TC&x"03", TC&x"01",  x"0304",  x"05FF", TC&x"01",  x"1718",  x"FF00", TC&x"01", x"0405", x"0607", TE&x"00", x"0000", x"0000", x"0000", x"0000",  x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000");
		fifo_1_din_wr_en_seq       <= (     '0',      '1',      '1',      '1',      '1',      '1',      '1',      '1',     '1',     '1',      '1',     '0',     '0',     '0',     '0',      '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0');
		-- output related                                                                                         Read as soon as possible
		dout_rd_en_seq             <= (     '0',      '0',      '0',      '0',      '0',      '0',      '0',      '0',     '0',     '1',      '1',     '1',     '0',     '1',     '1',      '1',     '0',     '1',     '1',     '1',     '1',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0');

--		-- outputs
--		dout_packet_available_seq  <= (     '0',      '0',      '0',      '0',      '0',      '0',      '0',      '1',     '0',     '0',      '1',     '0',     '0',     '0',     '0',      '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0');
--		dout_empty_notready_seq    <= (     '1',      '1',      '1',      '1',      '1',      '1',      '1',      '0',     '0',     '0',      '0',     '0',     '0',     '1',     '1',      '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1');
--
--		-- FIFO Output Stuff
--		-- inputs
--		dout_rd_en_seq             <= (     '0',      '0',      '0',      '0',      '0',      '0',      '0',      '1',     '1',     '1',      '1',     '1',     '1',     '1',     '1',      '1',     '1',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0');
--		-- outputs
--		dout_seq                   <= (x"00"&TE, x"00"&TE, x"00"&TE, x"00"&TE, x"00"&TE, x"00"&TE, x"00"&TE, x"00"&TE, TC&x"02", x"0304", x"05FF", TC&x"04", x"1718", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00", x"FF00");
--		dout_end_of_packet_seq     <= (     '1',      '1',      '1',      '1',      '1',      '1',      '1',      '1',     '0',     '0',      '1',      '0',     '0',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1',     '1');
		
		wait for 1 ps;

		for I in 0 to test1_length-1 loop
			wait for 3 ns;
			-- input to put data into FIFO
			fifo_0_din       <= x"3246";
			fifo_0_din_wr_en <= '0';
			fifo_1_din       <= fifo_1_din_seq(I);
			fifo_1_din_wr_en <= fifo_1_din_wr_en_seq(I);
			dout_rd_en       <= dout_rd_en_seq(I);
			
			wait for 3 ns;
			-- reactionary inputs to control FIFO output
--			dout_rd_en <= dout_rd_en_seq(I);

--			assert dout_packet_available = dout_packet_available_seq(I)
--				report "Test 2, Error dout_packet_available " & integer'image(step_index_seq(I)) severity failure;
--			assert dout_empty_notready = dout_empty_notready_seq(I)
--				report "Test 2, Error dout_empty_notready " & integer'image(step_index_seq(I)) severity failure;
--			assert dout_end_of_packet = dout_end_of_packet_seq(I)
--				report "Test 2, Error dout_end_of_packet " & integer'image(step_index_seq(I)) severity failure;
--			
--			assert dout = dout_seq(I)
--				report "Test 2, Error dout " & integer'image(step_index_seq(I)) severity failure;
			
			--clock sequence
			wait for 4 ns; clk <= '0'; wait for 10 ns; clk <= '1';
		end loop;



		wait; -- will wait forever
	end process;

end Behavioral;
