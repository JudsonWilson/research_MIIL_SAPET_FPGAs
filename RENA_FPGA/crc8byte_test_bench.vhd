----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson
--
-- Create Date:    11/08/2013 
-- Design Name:
-- Module Name:    crc8_test_bench - behavior
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--
-- Tests a crc8byte component by feeding it a chain of bytes:
--     0x12, 0x34, ..., 0xEF, 0x01, 0x02, 0xDE
-- Compare the simulation results to the output of one of many online crc8
-- calculators, but be sure that it uses the same crc polynomial.
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

entity crc8_test_bench is
end crc8_test_bench;

architecture behavior of crc8_test_bench is 

	-- Component Declaration
   component crc8byte is
		Port (
			new_byte : in  std_logic_vector(7 downto 0);
			prev_crc : in  std_logic_vector(7 downto 0);
			next_crc : out std_logic_vector(7 downto 0)
		);
	end component;

	signal new_byte: std_logic_vector(7 downto 0);
	signal prev_crc: std_logic_vector(7 downto 0);
	signal next_crc: std_logic_vector(7 downto 0);


begin


	uut: crc8byte port map(
		new_byte => new_byte,
		prev_crc => prev_crc,
		next_crc => next_crc
	);


	-- Test Bench Process
	tb : process
	begin
		wait for 10 ns; -- wait until global set/reset completes
		
		new_byte <= x"12";
		prev_crc <= x"00";
		wait for 10 ns;
		
		prev_crc <= next_crc;
		new_byte <= x"34";
		wait for 10 ns;
		
		prev_crc <= next_crc;
		new_byte <= x"56";
		wait for 10 ns;
		
		prev_crc <= next_crc;
		new_byte <= x"78";
		wait for 10 ns;
		
		prev_crc <= next_crc;
		new_byte <= x"90";
		wait for 10 ns;
		
		prev_crc <= next_crc;
		new_byte <= x"AB";
		wait for 10 ns;
		
		prev_crc <= next_crc;
		new_byte <= x"CD";
		wait for 10 ns;
		
		prev_crc <= next_crc;
		new_byte <= x"EF";
		wait for 10 ns;

		prev_crc <= next_crc;
		new_byte <= x"01";
		wait for 10 ns;

		prev_crc <= next_crc;
		new_byte <= x"23";
		wait for 10 ns;

		prev_crc <= next_crc;
		new_byte <= x"45";
		wait for 10 ns;

		prev_crc <= next_crc;
		new_byte <= x"67";
		wait for 10 ns;

		prev_crc <= next_crc;
		new_byte <= x"89";
		wait for 10 ns;

		prev_crc <= next_crc;
		new_byte <= x"0A";
		wait for 10 ns;

		prev_crc <= next_crc;
		new_byte <= x"BC";
		wait for 10 ns;

		prev_crc <= next_crc;
		new_byte <= x"DE";
		wait for 10 ns;

		wait; -- will wait forever
	end process tb;
	-- End Test Bench Process

end;
