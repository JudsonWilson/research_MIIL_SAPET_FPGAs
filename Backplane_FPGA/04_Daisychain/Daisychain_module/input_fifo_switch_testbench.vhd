----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson
--
-- Create Date:    01/05/2013 
-- Design Name:
-- Module Name:    input_fifo_switch_testbench - Behavioral
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--     Simulation test for input_fifo_switch.
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

entity input_fifo_switch_testbench is
end input_fifo_switch_testbench;

architecture Behavioral of input_fifo_switch_testbench is 

	-- Component Declaration
	component input_fifo_switch is
	port (
		reset         : in std_logic;
		clk           : in std_logic;
		-- control logic
		in_rd_en      : in std_logic;
		in_use_input_1 : in std_logic; -- one-hot source selectors, act immediately
		in_use_input_2 : in std_logic;
		in_use_input_3 : in std_logic;
		-- fifo interfaces
		fifo_dout_1    : in std_logic_vector(15 downto 0);
		fifo_dout_2    : in std_logic_vector(15 downto 0);
		fifo_dout_3    : in std_logic_vector(15 downto 0);
		fifo_rd_en_1   : out std_logic;
		fifo_rd_en_2   : out std_logic;
		fifo_rd_en_3   : out std_logic;
		fifo_dout_empty_notready_1 : in std_logic;
		fifo_dout_empty_notready_2 : in std_logic;
		fifo_dout_empty_notready_3 : in std_logic;
		fifo_dout_end_of_packet_1  : in std_logic;
		fifo_dout_end_of_packet_2  : in std_logic;
		fifo_dout_end_of_packet_3  : in std_logic;
		-- output data
		dout  : out std_logic_vector(15 downto 0);
		dout_empty_notready   : out std_logic; -- Indicates the user should not try and read (rd_en). May happen mid-packet! Always check this!
		dout_end_of_packet    : out std_logic
	);
	end component;

	signal reset           : std_logic;
	signal clk             : std_logic;
	signal in_rd_en        : std_logic;
	signal in_use_input_1  : std_logic;
	signal in_use_input_2  : std_logic;
	signal in_use_input_3  : std_logic;
	signal fifo_dout_1     : std_logic_vector(15 downto 0);
	signal fifo_dout_2     : std_logic_vector(15 downto 0);
	signal fifo_dout_3     : std_logic_vector(15 downto 0);
	signal fifo_rd_en_1    : std_logic;
	signal fifo_rd_en_2    : std_logic;
	signal fifo_rd_en_3    : std_logic;
	signal fifo_dout_empty_notready_1 : std_logic;
	signal fifo_dout_empty_notready_2 : std_logic;
	signal fifo_dout_empty_notready_3 : std_logic;
	signal fifo_dout_end_of_packet_1  : std_logic;
	signal fifo_dout_end_of_packet_2  : std_logic;
	signal fifo_dout_end_of_packet_3  : std_logic;
	signal dout                  : std_logic_vector(15 downto 0);
	signal dout_empty_notready   : std_logic;
	signal dout_end_of_packet    : std_logic;

	constant test1_length : integer := 20;
	type   integer_sequence is array(integer range <>) of integer;
	type   bit_sequence     is array(integer range <>) of std_logic;
	type   uint16_sequence  is array(integer range <>) of std_logic_vector(15 downto 0);
	signal step_index_seq             : integer_sequence(0 to test1_length-1);
	signal in_rd_en_seq               : bit_sequence    (0 to test1_length-1);
	signal in_use_input_1_seq         : bit_sequence    (0 to test1_length-1);
	signal in_use_input_2_seq         : bit_sequence    (0 to test1_length-1);
	signal in_use_input_3_seq         : bit_sequence    (0 to test1_length-1);
	signal fifo_dout_1_seq            : uint16_sequence (0 to test1_length-1);
	signal fifo_dout_2_seq            : uint16_sequence (0 to test1_length-1);
	signal fifo_dout_3_seq            : uint16_sequence (0 to test1_length-1);
	signal fifo_rd_en_1_seq           : bit_sequence    (0 to test1_length-1);
	signal fifo_rd_en_2_seq           : bit_sequence    (0 to test1_length-1);
	signal fifo_rd_en_3_seq           : bit_sequence    (0 to test1_length-1);
	signal fifo_dout_empty_notready_1_seq : bit_sequence    (0 to test1_length-1);
	signal fifo_dout_empty_notready_2_seq : bit_sequence    (0 to test1_length-1);
	signal fifo_dout_empty_notready_3_seq : bit_sequence    (0 to test1_length-1);
	signal fifo_dout_end_of_packet_1_seq  : bit_sequence    (0 to test1_length-1);
	signal fifo_dout_end_of_packet_2_seq  : bit_sequence    (0 to test1_length-1);
	signal fifo_dout_end_of_packet_3_seq  : bit_sequence    (0 to test1_length-1);
	signal dout_seq                   : uint16_sequence (0 to test1_length-1);
	signal dout_empty_notready_seq    : bit_sequence    (0 to test1_length-1);
	signal dout_end_of_packet_seq     : bit_sequence    (0 to test1_length-1);

begin

	uut: input_fifo_switch port map (
		reset => reset,
		clk   => clk,
		-- control logic
		in_rd_en       => in_rd_en,
		in_use_input_1 => in_use_input_1, -- one-hot source selectors, act immediately
		in_use_input_2 => in_use_input_2,
		in_use_input_3 => in_use_input_3,
		-- fifo interfaces
		fifo_dout_1 => fifo_dout_1,
		fifo_dout_2 => fifo_dout_2,
		fifo_dout_3 => fifo_dout_3,
		fifo_rd_en_1 => fifo_rd_en_1,
		fifo_rd_en_2 => fifo_rd_en_2,
		fifo_rd_en_3 => fifo_rd_en_3,
		fifo_dout_empty_notready_1 => fifo_dout_empty_notready_1,
		fifo_dout_empty_notready_2 => fifo_dout_empty_notready_2,
		fifo_dout_empty_notready_3 => fifo_dout_empty_notready_3,
		fifo_dout_end_of_packet_1  => fifo_dout_end_of_packet_1,
		fifo_dout_end_of_packet_2  => fifo_dout_end_of_packet_2,
		fifo_dout_end_of_packet_3  => fifo_dout_end_of_packet_3,
		-- output data
		dout  => dout,
		dout_empty_notready => dout_empty_notready, -- Indicates the user should not try and read (rd_en). May happen mid-packet! Always check this!
		dout_end_of_packet  => dout_end_of_packet
	);


	-- Test Bench Process
	tb : process
	begin
	
		reset      <= '0';
		clk        <= '0';
		in_rd_en       <= '0';
		in_use_input_1 <= '0';
		in_use_input_2 <= '0';
		in_use_input_3 <= '0';
		fifo_dout_1 <= x"0000";
		fifo_dout_2 <= x"0000";
		fifo_dout_3 <= x"0000";

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
		step_index_seq                  <= (       1,       2,       3,       4,       5,       6,       7,       8,       9,      10,      11,      12,      13,      14,      15,      16,      17,      18,      19,      20);
		in_rd_en_seq                    <= (     '0',     '1',     '0',     '1',     '0',     '1',     '1',     '1',     '0',     '1',     '1',     '0',     '1',     '0',     '1',     '0',     '1',     '0',     '1',     '0');
		in_use_input_1_seq              <= (     '0',     '1',     '0',     '0',     '1',     '0',     '1',     '0',     '0',     '0',     '0',     '1',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0');
		in_use_input_2_seq              <= (     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '1',     '0',     '0',     '0',     '0',     '0',     '1',     '0',     '0',     '0',     '0',     '0',     '0');
		in_use_input_3_seq              <= (     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '1',     '0',     '0',     '0',     '0');
		fifo_dout_1_seq                 <= ( x"1011", x"1021", x"1031", x"1041", x"1051", x"1061", x"1071", x"1081", x"1091", x"1101", x"1111", x"1121", x"1131", x"1141", x"1151", x"1161", x"1171", x"1181", x"1191", x"1201");
		fifo_dout_2_seq                 <= ( x"2012", x"2022", x"2032", x"2042", x"2052", x"2062", x"2072", x"2082", x"2092", x"2102", x"2112", x"2122", x"2132", x"2142", x"2152", x"2162", x"2172", x"2182", x"2192", x"2202");
		fifo_dout_3_seq                 <= ( x"3013", x"3023", x"3033", x"3043", x"3053", x"3063", x"3073", x"3083", x"3093", x"3103", x"3113", x"3123", x"3133", x"3143", x"3153", x"3163", x"3173", x"3183", x"3193", x"3203");
		fifo_dout_end_of_packet_1_seq   <= (     '1',     '1',     '0',     '0',     '0',     '0',     '1',     '1',     '0',     '0',     '0',     '0',     '1',     '1',     '0',     '0',     '0',     '0',     '1',     '1');
		fifo_dout_end_of_packet_2_seq   <= (     '0',     '0',     '1',     '1',     '0',     '0',     '0',     '0',     '1',     '1',     '0',     '0',     '0',     '0',     '1',     '1',     '0',     '0',     '0',     '0');
		fifo_dout_end_of_packet_3_seq   <= (     '0',     '0',     '0',     '0',     '1',     '1',     '0',     '0',     '0',     '0',     '1',     '1',     '0',     '0',     '0',     '0',     '1',     '1',     '0',     '0');
		fifo_dout_empty_notready_1_seq  <= (     '1',     '0',     '0',     '1',     '0',     '0',     '1',     '0',     '0',     '1',     '0',     '0',     '1',     '0',     '0',     '1',     '0',     '0',     '1',     '0');
		fifo_dout_empty_notready_2_seq  <= (     '0',     '1',     '0',     '0',     '1',     '0',     '0',     '1',     '0',     '0',     '1',     '0',     '0',     '1',     '0',     '0',     '1',     '0',     '0',     '1');
		fifo_dout_empty_notready_3_seq  <= (     '0',     '0',     '1',     '0',     '0',     '1',     '0',     '0',     '1',     '0',     '0',     '1',     '0',     '0',     '1',     '0',     '0',     '1',     '0',     '0');

		-- outputs
		dout_seq                        <= ( x"3013", x"3023", x"1031", x"1041", x"1051", x"1061", x"1071", x"1081", x"2092", x"2102", x"2112", x"2122", x"1131", x"1141", x"2152", x"2162", x"3173", x"3183", x"3193", x"3203");
		fifo_rd_en_1_seq                <= (     '0',     '1',     '0',     '1',     '0',     '1',     '1',     '0',     '0',     '0',     '0',     '0',     '1',     '0',     '0',     '0',     '0',     '0',     '0',     '0');
		fifo_rd_en_2_seq                <= (     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '1',     '0',     '1',     '1',     '0',     '0',     '0',     '1',     '0',     '0',     '0',     '0',     '0');
		fifo_rd_en_3_seq                <= (     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '1',     '0',     '1',     '0');
		dout_end_of_packet_seq          <= (     '0',     '0',     '0',     '0',     '0',     '0',     '1',     '1',     '1',     '1',     '0',     '0',     '1',     '1',     '1',     '1',     '1',     '1',     '0',     '0');
		dout_empty_notready_seq         <= (     '0',     '0',     '0',     '1',     '0',     '0',     '1',     '1',     '0',     '0',     '1',     '0',     '1',     '1',     '0',     '0',     '0',     '1',     '0',     '0');

		-- Let changes take effect
		wait for 1 ps;

		for I in 0 to test1_length-1 loop
			wait for 3 ns;
			-- input
			in_rd_en <= in_rd_en_seq(I);
			in_use_input_1 <= in_use_input_1_seq(I);
			in_use_input_2 <= in_use_input_2_seq(I);
			in_use_input_3 <= in_use_input_3_seq(I);
			fifo_dout_1 <= fifo_dout_1_seq(I);
			fifo_dout_2 <= fifo_dout_2_seq(I);
			fifo_dout_3 <= fifo_dout_3_seq(I);
			fifo_dout_end_of_packet_1 <= fifo_dout_end_of_packet_1_seq(I);
			fifo_dout_end_of_packet_2 <= fifo_dout_end_of_packet_2_seq(I);
			fifo_dout_end_of_packet_3 <= fifo_dout_end_of_packet_3_seq(I);
			fifo_dout_empty_notready_1 <= fifo_dout_empty_notready_1_seq(I);
			fifo_dout_empty_notready_2 <= fifo_dout_empty_notready_2_seq(I);
			fifo_dout_empty_notready_3 <= fifo_dout_empty_notready_3_seq(I);

			wait for 3 ns;

			--check output
			assert dout = dout_seq(I)
				report "Error dout @ " & integer'image(step_index_seq(I)) severity failure;
			assert fifo_rd_en_1 = fifo_rd_en_1_seq(I)
				report "Error fifo_rd_en_1_seq @ " & integer'image(step_index_seq(I)) severity failure;
			assert fifo_rd_en_2 = fifo_rd_en_2_seq(I)
				report "Error fifo_rd_en_2_seq @ " & integer'image(step_index_seq(I)) severity failure;
			assert fifo_rd_en_3 = fifo_rd_en_3_seq(I)
				report "Error fifo_rd_en_3_seq @ " & integer'image(step_index_seq(I)) severity failure;
			assert dout_end_of_packet = dout_end_of_packet_seq(I)
				report "Error dout_end_of_packet @ " & integer'image(step_index_seq(I)) severity failure;
			assert dout_empty_notready = dout_empty_notready_seq(I)
				report "Error dout_empty_notready @ " & integer'image(step_index_seq(I)) severity failure;
			
			--clock sequence
			wait for 4 ns; clk <= '0'; wait for 10 ns; clk <= '1';
		end loop;

		-- Done
		report "Successfully completed tests!";

		wait; -- will wait forever
	end process;

end Behavioral;
