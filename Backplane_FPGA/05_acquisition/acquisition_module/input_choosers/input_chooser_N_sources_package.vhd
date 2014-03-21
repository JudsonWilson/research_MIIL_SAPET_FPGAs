----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson
--
-- Create Date:    02/15/2014
-- Design Name:
-- Module Name:    input_chooser_N_sources_package
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--     Presently holds types used by the input_chooser_N_sources. Could grow
-- in the future.
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

package input_chooser_N_sources_package is

	-- Type used for grouping several 16-bit busses together. Note that it is unconstrained.
	-- use like this for a 4-bus-wide port:  x : in multi_bus_16_bit(3 downto 0);
	type multi_bus_16_bit is array(natural range <>) of std_logic_vector(15 downto 0);

	-- Calculate the ceil(log2(N)) where N is a positive natural number.
	function ceil_log2(N : positive) return natural;

	function input_chooser_N_sources_calculate_N_low(N : positive) return natural;

end input_chooser_N_sources_package;

package body input_chooser_N_sources_package is

	-- Calculate the ceil(log2(N)) where N is a positive natural number.
	-- - Done with a loop - it's expected that this will be used with
	--   constants.
	function ceil_log2(N : positive) return natural is
		variable count : natural := 0;
	begin
		while 2**count <= N loop
			count := count + 1;
		end loop;
		return count;
	end ceil_log2;

	-- This function calculates the size of the lower subtree in the recursive
	-- definition of input_chooser_N_sources. Low tree means the lower part
	-- of the range (N-1 downto 0). The size of the upper part is N_high = N - N_low.
	function input_chooser_N_sources_calculate_N_low(N : positive) return natural is
		-- N_low must be the larger group, if we want the highest indices to have
		-- the highest priority (which makes manually optimizing priority of inputs
		-- by ordering-of-connections an easier task)
		--
		-- The two subset sizes must be within a power of 2 of eachother to ensure
		-- that all leaf heights are within a range of height 1. This ensures
		-- that at worst, some inputs have double priority, but not quadruple
		-- priority, 8x priority, etc. If a leaf had 2 less depth than another,
		-- it would have 4x the priority.
		--
		-- More formally, for two subgroups 0 and 1, ceil(log2(N0)) and ceil(log2(N1))
		-- must be within 1 of eachother.
		--
		-- Generally there are two cases which may happen:
		--  - Either N_low or N_high equal 1/2 * 2**(ceil(log(N)))/2
		--     eg N=15 -> N_low=8 N_high=7
		--  - Either N1 or N2 equal 1/4 * 2**(ceil(log(N)))/4
		--     eg N=9  -> N0=4 N1=5
		-- Note that the two cases may both hold if one
		-- subgroup is a power of 2, and the other is the next heigher power of 2.
		variable p0 : natural; -- The power of 2 needed to hold N
		variable p1 : natural; -- p0 - 1, saturating at 0
		variable p2 : natural; -- p0 - 2, saturating at 0
		variable N_low : natural;
	begin
		p0 := ceil_log2(N);
		if p0 > 0 then
			p1 := p0 - 1;
			if p1 > 0 then
				p2 := p1  - 1;
			else
				p2 := 0;
			end if;
		else
			p1 := 0;
			p2 := 0;
		end if;

		-- Figure out which of the two subcases above we are in, and assign
		-- N1 and N2 such that their ceil_log2() values are within 1 of eachother.
		if N - 2**p1 >= 2**p2 then
			N_low := 2**p1;     -- and N_high = N - p2 <= N_low
		else
			N_low := N - 2**p2; -- and N_high = p2 <= N_low
		end if;

		--Debug use:
		--assert false report "N = " & integer'image(N) & "   N_low = " & integer'image(N_low) severity note;

		return N_low;

	end input_chooser_N_sources_calculate_N_low;



end input_chooser_N_sources_package;
