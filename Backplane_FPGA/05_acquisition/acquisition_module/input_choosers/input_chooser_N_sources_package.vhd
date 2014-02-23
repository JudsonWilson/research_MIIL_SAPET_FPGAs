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

end input_chooser_N_sources_package;

package body input_chooser_N_sources_package is

end input_chooser_N_sources_package;
