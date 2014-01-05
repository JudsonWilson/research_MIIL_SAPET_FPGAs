----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson
--
-- Create Date:    01/05/2013 
-- Design Name:
-- Module Name:    serializer_preprocessor_testbench - Behavioral
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--
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

entity serializer_preprocessor_testbench is
end serializer_preprocessor_testbench;

architecture Behavioral of serializer_preprocessor_testbench is 

	-- Component Declaration
	component serializer_preprocessor is
		port (
			reset   : in  std_logic;
			clk     : in  std_logic;
			din     : in  std_logic_vector(15 downto 0);
			din_wr  : in  std_logic;
			dout    : out std_logic_vector(15 downto 0);
			dout_wr : out std_logic
		);
	end component;	

	signal clk:     std_logic;
	signal reset:   std_logic;
	signal din:     std_logic_vector(15 downto 0);
	signal din_wr:  std_logic;
	signal dout:    std_logic_vector(15 downto 0);
	signal dout_wr: std_logic;

begin

	uut: serializer_preprocessor port map(
		reset => reset,
		clk => clk,
		din => din,
		din_wr => din_wr,
		dout => dout,
		dout_wr => dout_wr
	);


	-- Test Bench Process
	tb : process
	begin
		----------------------------------------------------------------------------
		-- Test 1 - reset behavior - not much should happen, really.
		-- - A slightly better test would be to try this after sending the first
		--	  byte of a packet
		----------------------------------------------------------------------------
		
		reset <= '1';
		din <= x"0102";
		din_wr <= '0';

		clk <= '0';
		wait for 10 ns;
		clk <= '1';
		wait for 1 ns;
		
		reset <= '0';

		----------------------------------------------------------------------------
		-- Test 2 
		-- Do some tests for normal conditions, i.e. not the first or second word.
		----------------------------------------------------------------------------

		din <= x"0102";
		din_wr <= '1';
		wait for 1 ns;
		assert dout_wr = '1' and dout = x"0102" report "Test 2, Error 1" severity failure;

		wait for 8 ns;	clk <= '0'; wait for 10 ns; clk <= '1'; wait for 1 ns;
		assert dout_wr = '1' and dout = x"0102" report "Test 2, Error 2" severity failure;

		din <= x"0304";
		din_wr <= '1';
		wait for 1 ns;
		assert dout_wr = '1' and dout = x"0304" report "Test 2, Error 3" severity failure;

		wait for 8 ns;	clk <= '0'; wait for 10 ns; clk <= '1'; wait for 1 ns;
		assert dout_wr = '1' and dout = x"0304" report "Test 2, Error 4" severity failure;

		din <= x"0506";
		din_wr <= '0';
		wait for 1 ns;
		assert dout_wr = '0' and dout = x"0506" report "Test 2, Error 5" severity failure;

		wait for 8 ns;	clk <= '0'; wait for 10 ns; clk <= '1'; wait for 1 ns;
		assert dout_wr = '0' and dout = x"0506" report "Test 2, Error 6" severity failure;

		----------------------------------------------------------------------------
		-- Test 3 
		-- Test a back-to-back first and second word of the packet.
		----------------------------------------------------------------------------

		-- First lead in with the wr signal deasserted
		din <= x"8106";
		din_wr <= '0';
		wait for 1 ns;
		assert dout_wr = '0' and dout = x"8106" report "Test 3, Error 1" severity failure;

		wait for 8 ns;	clk <= '0'; wait for 10 ns; clk <= '1'; wait for 1 ns;
		assert dout_wr = '0' and dout = x"8106" report "Test 3, Error 2" severity failure;
		
		-- continue with another firt word, assert the write signal
		din <= x"8107";
		din_wr <= '1';
		wait for 1 ns;
		assert dout_wr = '0' and dout = x"0000" report "Test 3, Error 3" severity failure;

		wait for 8 ns;	clk <= '0'; wait for 10 ns; clk <= '1'; wait for 1 ns;
		assert dout_wr = '0' and dout = x"0000" report "Test 3, Error 4" severity failure;

		-- send second word
		din <= x"3456";
		din_wr <= '1';
		wait for 1 ns;
		assert dout_wr = '1' and dout = x"8156" report "Test 3, Error 5" severity failure;

		wait for 8 ns;	clk <= '0'; wait for 10 ns; clk <= '1'; wait for 1 ns;
		assert dout_wr = '1' and dout = x"3456" report "Test 3, Error 6" severity failure;

		----------------------------------------------------------------------------
		-- Test 4 
		-- Test a first and second word of the packet with a no-send gap between.
		----------------------------------------------------------------------------
		
		-- send new first word, asserted
		din <= x"8108";
		din_wr <= '1';
		wait for 1 ns;
		assert dout_wr = '0' and dout = x"0000" report "Test 4, Error 1" severity failure;

		wait for 8 ns;	clk <= '0'; wait for 10 ns; clk <= '1'; wait for 1 ns;
		assert dout_wr = '0' and dout = x"0000" report "Test 4, Error 2" severity failure;

		-- send new second word, deasserted
		din <= x"7890";
		din_wr <= '0';
		wait for 1 ns;
		assert dout_wr = '0' and dout = x"7890" report "Test 4, Error 3" severity failure;

		wait for 8 ns;	clk <= '0'; wait for 10 ns; clk <= '1'; wait for 1 ns;
		assert dout_wr = '0' and dout = x"7890" report "Test 4, Error 4" severity failure;
	
		-- send new second word, asserted
		din <= x"ABCD";
		din_wr <= '1';
		wait for 1 ns;
		assert dout_wr = '1' and dout = x"81CD" report "Test 4, Error 5" severity failure;

		wait for 8 ns;	clk <= '0'; wait for 10 ns; clk <= '1'; wait for 1 ns;
		assert dout_wr = '1' and dout = x"ABCD" report "Test 4, Error 6" severity failure;
		

		wait; -- will wait forever
	end process tb;
	-- End Test Bench Process

end;
