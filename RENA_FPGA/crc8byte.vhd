----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson
--
-- Create Date:    11:36:52 11/08/2013 
-- Design Name:
-- Module Name:    crc8byte - Structural
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--     Produces the next crc8 update in a sequence of data bytes. The inputs are
-- the previous crc8 and the next byte in the data sequence.
--
--     Uses the standard polynomial: x^8 + x^2 + x + 1
--
--     Idea came from a random implementation on the internet. If you try hard, you
-- can derive it from the methods in this article:
--   http://en.wikipedia.org/wiki/Computation_of_CRC
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity crc8byte is
	Port (
		new_byte : in  STD_LOGIC_VECTOR(7 downto 0);
		prev_crc : in  STD_LOGIC_VECTOR(7 downto 0);
		next_crc : out STD_LOGIC_VECTOR(7 downto 0)
	);
end crc8byte;

architecture Structural of crc8byte is
	signal nwb : STD_LOGIC_VECTOR(7 downto 0);
	signal prv : STD_LOGIC_VECTOR(7 downto 0);
begin
	nwb <= new_byte;
	prv <= prev_crc;

	--x^8 + x^2 + x + 1 polynomial
	next_crc(0) <= (nwb(0) xor nwb(6) xor nwb(7))            xor (prv(0) xor prv(6) xor prv(7));
	next_crc(1) <= (nwb(0) xor nwb(1) xor nwb(6))            xor (prv(0) xor prv(1) xor prv(6));
	next_crc(2) <= (nwb(0) xor nwb(1) xor nwb(2) xor nwb(6)) xor (prv(0) xor prv(1) xor prv(2) xor prv(6));
	next_crc(3) <= (nwb(1) xor nwb(2) xor nwb(3) xor nwb(7)) xor (prv(1) xor prv(2) xor prv(3) xor prv(7));
	next_crc(4) <= (nwb(2) xor nwb(3) xor nwb(4))            xor (prv(2) xor prv(3) xor prv(4));
	next_crc(5) <= (nwb(3) xor nwb(4) xor nwb(5))            xor (prv(3) xor prv(4) xor prv(5));
	next_crc(6) <= (nwb(4) xor nwb(5) xor nwb(6))            xor (prv(4) xor prv(5) xor prv(6));
	next_crc(7) <= (nwb(5) xor nwb(6) xor nwb(7))            xor (prv(5) xor prv(6) xor prv(7));
end Structural;

	