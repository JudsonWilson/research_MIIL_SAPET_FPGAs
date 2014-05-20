----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    14:49:10 04/03/2012 
-- Design Name: 
-- Module Name:    LED - Behavioral 
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
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
-- use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity LED is
    Port ( mclk   : in  STD_LOGIC;
			  rst    : in  STD_LOGIC;
           ledOut : out STD_LOGIC);
end LED;

--================================================================================
architecture Behavioral of LED is

-- Signals
signal nextLedOut : std_logic;
signal counter : std_logic_vector(23 downto 0) := "000000000000000000000000";
signal nextCounter : std_logic_vector(23 downto 0) := "000000000000000000000000";

--================================================================================
begin

process(mclk)
begin
	if rst = '1' then
		counter <= "000000000000000000000000";
		ledOut  <= '0';
	elsif rising_edge(mclk) then
		counter <= nextCounter;
		ledOut <= nextLedOut;
	end if;
end process;

process(rst, counter)
begin
	-- This makes LEDs blink at 2.861 Hz
	nextLedOut  <= counter(23);
	nextCounter <= counter + 1;
end process;

end Behavioral;
