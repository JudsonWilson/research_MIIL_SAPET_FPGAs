----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson
--
-- Create Date:    02/12/2014 
-- Design Name:
-- Module Name:    deserializer_testbench - Behavioral
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--     Simulation test for deserializer. Currently you have to check the output
-- by hand. Note that the deserializer splices a source (in this case x"05") and
-- destination (x"00") into the packet as received from the serializer.
--     To make testing easier, I feed parallel data into a Serializing_module
-- to feed this deserializer.
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

entity deserializer_testbench is
end deserializer_testbench;

architecture Behavioral of deserializer_testbench is 

	-- Component Declaration
	component deserializer is
		port(
			reset         : in std_logic;
			clk_50MHz     : in std_logic;
			boardid       : in std_logic_vector(2 downto 0);
			-- Interface, serial input, parallel output
			s_in          : in std_logic;
			p_out_wr      : out std_logic;
			p_out_data    : out std_logic_vector(15 downto 0)
	);
	end component;

	component Serializing_module is
		port (
			reset 				: in std_logic;
			clk_50MHz			: in std_logic;
			-- configure data of the current board from Daisychain
			din_from_Daisychain_to_serialzing_wr : in std_logic;
				  din_from_Daisychain_to_serialzing   : in std_logic_vector(15 downto 0);
				  -- Serialing pin
			Tx				: out std_logic
		);
	end component;

	signal reset:                 std_logic;
	signal clk:                   std_logic;
	signal boardid    : std_logic_vector(2 downto 0) := "101";
	signal din_wr:             std_logic;
	signal din:                   std_logic_vector(15 downto 0);
	signal serial             : std_logic;
	signal p_out_wr:            std_logic;
	signal p_out_data: std_logic_vector(15 downto 0);

	constant test1_length : integer := 30;
	type   integer_sequence is array(integer range <>) of integer;
	type   bit_sequence     is array(integer range <>) of std_logic;
	type   uint4_sequence   is array(integer range <>) of std_logic_vector( 3 downto 0);
	type   uint16_sequence  is array(integer range <>) of std_logic_vector(15 downto 0);
	signal step_index_seq            : integer_sequence(0 to test1_length-1);
	signal din_seq                   : uint16_sequence (0 to test1_length-1);
	signal din_wr_seq             : bit_sequence    (0 to test1_length-1);
--	signal dout_packet_available_seq : bit_sequence    (0 to test1_length-1);
--	signal dout_empty_notready_seq   : bit_sequence    (0 to test1_length-1);
--	signal dout_seq                  : uint16_sequence (0 to test1_length-1);
--	signal dout_end_of_packet_seq    : bit_sequence    (0 to test1_length-1);
--	signal dout_rd_en_seq            : bit_sequence    (0 to test1_length-1);

	constant TC : std_logic_vector(7 downto 0) := packet_start_token_frontend_config; -- acronym for "Token Config"
	constant TE : std_logic_vector(7 downto 0) := packet_end_token;  -- acronym for "Token End"

begin


	serializer_inst: Serializing_module port map(
		reset 		=> reset,
		clk_50MHz	=> clk,
		din_from_Daisychain_to_serialzing_wr => din_wr,
		din_from_Daisychain_to_serialzing  => din,
		Tx => serial
	);


	uut_deserializer: deserializer port map(
		reset       => reset,
		clk_50MHz   => clk,
		boardid     => boardid,
		s_in        => serial,
		p_out_wr    => p_out_wr,
		p_out_data  => p_out_data
	);

	-- Test Bench Process
	tb : process
	begin
		reset      <= '0';
		clk        <= '0';
		din_wr  <= '0';
		din        <= x"0000";
		boardid    <= "101";
		
		----------------------------------------------------------------------------
		-- Test 1 - reset behavior - not much should happen, really.
		-- - Not a very robust test.
		----------------------------------------------------------------------------
		
		reset <= '1';
		din <= x"0102";
		din_wr <= '0';

		for I in 0 to 7 loop
			clk <= '0';
			wait for 0.5 ns;
			clk <= '1';
			wait for 0.5 ns;
		end loop;
		
		wait for 1 ps;
		
		reset <= '0';

		-- Lowest level FIFO needs clocks to wake up. Otherwise holds the full flag.
		for I in 0 to 15 loop
			clk <= '0';
			wait for 0.25 ns;
			clk <= '1';
			wait for 0.25 ns;
		end loop;

		----------------------------------------------------------------------------
		-- Test 2 
		-- Run two packets through with no gap. 
		----------------------------------------------------------------------------

		-- FIFO Input Stuff
		-- inputs
		step_index_seq             <= (       1,        2,        3,        4,        5,        6,        7,        8,       9,      10,       11,      12,      13,      14,      15,       16,      17,      18,      19,      20,      21,      22,      23,      24,      25,      26,      27,      28,      29,      30);
		din_seq                    <= (TC&x"01", TC&x"02",  x"0304",  x"05FF", TC&x"04",  x"1718",  x"FF00",  x"0000", x"0000", x"0000",  x"0000", x"0000", x"0000", x"0000", x"0000",  x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000", x"0000");
		din_wr_seq                 <= (     '0',      '1',      '1',      '1',      '1',      '1',      '1',      '0',     '0',     '0',      '0',     '0',     '0',     '0',     '0',      '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0');
		
		wait for 1 ps;

		for I in 0 to test1_length-1 loop
			wait for 0.15 ns;
			-- input to put data into FIFO
			din <= din_seq(I);
			din_wr <= din_wr_seq(I);
			wait for 0.15 ns;
			-- reactionary inputs to control FIFO output
	--		dout_rd_en <= dout_rd_en_seq(I);

	--		assert dout_packet_available = dout_packet_available_seq(I)
	--			report "Test 2, Error dout_packet_available " & integer'image(step_index_seq(I)) severity failure;
	--		assert dout_empty_notready = dout_empty_notready_seq(I)
	--			report "Test 2, Error dout_empty_notready " & integer'image(step_index_seq(I)) severity failure;
	--		assert dout_end_of_packet = dout_end_of_packet_seq(I)
	--			report "Test 2, Error dout_end_of_packet " & integer'image(step_index_seq(I)) severity failure;
	--		
	--		assert dout = dout_seq(I)
	--			report "Test 2, Error dout " & integer'image(step_index_seq(I)) severity failure;
	--		
			--clock sequence
			wait for 0.2 ns; clk <= '0'; wait for 0.5 ns; clk <= '1';
		end loop;

		-- no more input data, so keep checking output
		for I in 0 to 1000 loop
			wait for 0.15 ns;
			din_wr <= '0';
			wait for 0.15 ns;
			-- reactionary inputs to control FIFO output
	--		dout_rd_en <= dout_rd_en_seq(I);

	--		assert dout_packet_available = dout_packet_available_seq(I)
	--			report "Test 2, Error dout_packet_available " & integer'image(step_index_seq(I)) severity failure;
	--		assert dout_empty_notready = dout_empty_notready_seq(I)
	--			report "Test 2, Error dout_empty_notready " & integer'image(step_index_seq(I)) severity failure;
	--		assert dout_end_of_packet = dout_end_of_packet_seq(I)
	--			report "Test 2, Error dout_end_of_packet " & integer'image(step_index_seq(I)) severity failure;
	--		
	--		assert dout = dout_seq(I)
	--			report "Test 2, Error dout " & integer'image(step_index_seq(I)) severity failure;
	--		
			--clock sequence
			wait for 0.2 ns; clk <= '0'; wait for 0.5 ns; clk <= '1';
		end loop;

		wait; -- will wait forever
	end process;

end Behavioral;


