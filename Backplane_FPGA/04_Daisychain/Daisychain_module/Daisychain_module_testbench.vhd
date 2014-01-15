----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson
--
-- Create Date:    01/10/2014 
-- Design Name:
-- Module Name:    Daisychain_module_testbench - Behavioral
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

entity Daisychain_module_testbench is
end Daisychain_module_testbench;

architecture Behavioral of Daisychain_module_testbench is 

	-- Component Declaration
	component Daisychain_module
		port (
		     acquisition_data_receive_data_number : out std_logic_vector(15 downto 0);
				bug_out_put_from_Acquisition_to_Daisychain			: out std_logic;
			     reset				: in std_logic;
			     clk_50MHz				: in std_logic;
			     boardid				: in std_logic_vector(2 downto 0);
		     -- to get the config data and acquisition data from GTP interface for serializing
		     -- data receiving from GTP interface
			     din_from_GTP			: in std_logic_vector(15 downto 0);
			     din_from_GTP_wr			: in std_logic;
		     -- to send the config data and acquisition data to GTP interface for transfer
			     dout_to_GTP			: out std_logic_vector(15 downto 0);
			     dout_to_GTP_wr			: out std_logic;
			     is_GTP_ready			: in std_logic;
		     -- data to UDP interface
			     dout_to_UDP			: out std_logic_vector(15 downto 0);
			     dout_to_UDP_wr			: out std_logic;
		     -- config_data_from_UDP_to_GTP
			     config_data_from_UDP_to_GTP	: in std_logic_vector(15 downto 0);
			     config_data_from_UDP_to_GTP_wr	: in std_logic;
		     -- acquisition_data_from_local_to_GTP
			     din_from_acquisition_wr            : in std_logic;
			     din_from_acquisition               : in std_logic_vector(15 downto 0);
		     -- current board configing data
			     dout_to_serializing_wr		: out std_logic;
			     dout_to_serializing		: out std_logic_vector(15 downto 0)
		     );
	end component;

	signal reset     : std_logic := '0';
	signal clk_50MHz : std_logic := '0';
	signal boardid   : std_logic_vector(2 downto 0) := "001";
	signal din_from_GTP     : std_logic_vector(15 downto 0);
	signal din_from_GTP_wr  : std_logic := '0';
	signal dout_to_GTP     : std_logic_vector(15 downto 0);
	signal dout_to_GTP_wr  : std_logic := '0';
	signal is_GTP_ready  : std_logic := '1';
	signal dout_to_UDP     : std_logic_vector(15 downto 0);
	signal dout_to_UDP_wr  : std_logic := '0';
	signal config_data_from_UDP_to_GTP     : std_logic_vector(15 downto 0);
	signal config_data_from_UDP_to_GTP_wr  : std_logic := '0';
	signal din_from_acquisition_wr  : std_logic := '0';
	signal din_from_acquisition     : std_logic_vector(15 downto 0);
	signal dout_to_serializing_wr  : std_logic := '0';
	signal dout_to_serializing     : std_logic_vector(15 downto 0);
	
	constant test1_length : integer := 30;
	type   integer_sequence is array(integer range <>) of integer;
	type   bit_sequence     is array(integer range <>) of std_logic;
	type   uint4_sequence   is array(integer range <>) of std_logic_vector( 3 downto 0);
	type   uint16_sequence  is array(integer range <>) of std_logic_vector(15 downto 0);
	signal step_index_seq      : integer_sequence (0 to test1_length-1);
	signal din_from_GTP_seq    : uint16_sequence (0 to test1_length-1);
	signal din_from_GTP_wr_seq : bit_sequence    (0 to test1_length-1);
	signal config_data_from_UDP_to_GTP_seq    : uint16_sequence (0 to test1_length-1);
	signal config_data_from_UDP_to_GTP_wr_seq : bit_sequence    (0 to test1_length-1);
	signal din_from_acquisition_seq     : uint16_sequence (0 to test1_length-1);
	signal din_from_acquisition_wr_seq  : bit_sequence    (0 to test1_length-1);

begin

	uut: Daisychain_module port map(
		acquisition_data_receive_data_number => open,
		bug_out_put_from_Acquisition_to_Daisychain => open,
		reset           => reset,
		clk_50MHz       => clk_50MHz,
		boardid         => boardid,
		-- to get the config data and acquisition data from GTP interface for serializing
		-- data receiving from GTP interface
		din_from_GTP    => din_from_GTP,
		din_from_GTP_wr => din_from_GTP_wr,
		-- to send the config data and acquisition data to GTP interface for transfer
		dout_to_GTP     => dout_to_GTP,
		dout_to_GTP_wr  => dout_to_GTP_wr,
		is_GTP_ready    => is_GTP_ready,
		-- data to UDP interface
		dout_to_UDP     => dout_to_UDP,
		dout_to_UDP_wr  => dout_to_UDP_wr,
		-- config_data_from_UDP_to_GTP
		config_data_from_UDP_to_GTP    => config_data_from_UDP_to_GTP,
		config_data_from_UDP_to_GTP_wr => config_data_from_UDP_to_GTP_wr,
		-- acquisition_data_from_local_to_GTP
		din_from_acquisition_wr  => din_from_acquisition_wr,
		din_from_acquisition     => din_from_acquisition,
		-- current board configing data
		dout_to_serializing_wr  => dout_to_serializing_wr,
		dout_to_serializing     => dout_to_serializing
	);

	-- Test Bench Process
	tb : process
	begin
	
		reset     <= '0';
		clk_50MHz <= '0';
		boardid   <= "001";
		din_from_GTP     <= x"0000";
		din_from_GTP_wr  <= '0';
		is_GTP_ready <= '1';
		config_data_from_UDP_to_GTP     <= x"0000";
		config_data_from_UDP_to_GTP_wr  <= '0';
		din_from_acquisition     <= x"0000";
		din_from_acquisition_wr  <= '0';

		----------------------------------------------------------------------------
		-- Test 1 - reset behavior - not much should happen, really.
		-- - Not a very robust test.
		----------------------------------------------------------------------------
		
		reset  <= '1';

		for I in 0 to 3 loop
			clk_50MHz <= '0';
			wait for 2.5 ns;
			clk_50MHz <= '1';
			wait for 2.5 ns;
		end loop;
		
		wait for 1 ps;
		
		reset <= '0';

		-- Let the reset flush through.
		for I in 0 to 11 loop
			clk_50MHz <= '0';
			wait for 2.5 ns;
			clk_50MHz <= '1';
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
		step_index_seq                      <= (       1,       2,       3,       4,       5,       6,       7,       8,       9,      10,      11,      12,      13,      14,      15,      16,      17,      18,      19,      20,      21,      22,      23,      24,      25,      26,      27,      28,      29,      30);
		din_from_GTP_seq                    <= ( x"8101", x"8100", x"01CA", x"FF00", x"8104", x"1718", x"FF00", x"1010", x"1111", x"1212", x"1313", x"1414", x"8101", x"1515", x"0304", x"1616", x"05FF", x"1717", x"8104", x"1818", x"5566", x"1919", x"FF00", x"2121", x"2222", x"2323", x"2424", x"2525", x"2626", x"2727");
		din_from_GTP_wr_seq                 <= (     '0',     '1',     '1',     '1',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0');
		config_data_from_UDP_to_GTP_seq     <= ( x"8101", x"8100", x"01C0", x"FF00", x"8104", x"1718", x"FF00", x"1010", x"1111", x"1212", x"1313", x"1414", x"8101", x"1515", x"0304", x"1616", x"05FF", x"1717", x"8104", x"1818", x"5566", x"1919", x"FF00", x"2121", x"2222", x"2323", x"2424", x"2525", x"2626", x"2727");
		config_data_from_UDP_to_GTP_wr_seq  <= (     '0',     '1',     '1',     '1',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0');
		din_from_acquisition_seq            <= ( x"8101", x"8101", x"00A0", x"FF00", x"8104", x"1718", x"FF00", x"1010", x"1111", x"1212", x"1313", x"1414", x"8101", x"1515", x"0304", x"1616", x"05FF", x"1717", x"8104", x"1818", x"5566", x"1919", x"FF00", x"2121", x"2222", x"2323", x"2424", x"2525", x"2626", x"2727");
		din_from_acquisition_wr_seq         <= (     '0',     '1',     '1',     '1',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0',     '0');

		-- outputs

		wait for 1 ps;

		for I in 0 to test1_length-1 loop
			wait for 3 ns;
			-- input to put data into FIFO
			din_from_GTP <= din_from_GTP_seq(I);
			din_from_GTP_wr <= din_from_GTP_wr_seq(I);
			config_data_from_UDP_to_GTP <= config_data_from_UDP_to_GTP_seq(I);
			config_data_from_UDP_to_GTP_wr <= config_data_from_UDP_to_GTP_wr_seq(I);
			din_from_acquisition <= din_from_acquisition_seq(I);
			din_from_acquisition_wr <= din_from_acquisition_wr_seq(I);
			wait for 3 ns;

--			assert dout = dout_seq(I)
--				report "Test 2, Error dout " & integer'image(step_index_seq(I)) severity failure;
--			assert dout_wr = dout_wr_seq(I)
--				report "Test 2, Error dout_wr " & integer'image(step_index_seq(I)) severity failure;
			
			--clock sequence
			wait for 4 ns; clk_50MHz <= '0'; wait for 10 ns; clk_50MHz <= '1';
		end loop;


		report "Successfully completed tests!";

		wait; -- will wait forever
	end process;

end Behavioral;
