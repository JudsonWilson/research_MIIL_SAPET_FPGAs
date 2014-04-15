----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson, based on code by Hua Liu.
-- 
-- Create Date:    04/14/2014 
-- Design Name: 
-- Module Name:    LED_extender - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
-- 	When pulsed '1', guarantees a pulse at least 4FFFFF long, which is
-- approximately 5e6, or 1/10th of a second at 50MHz, which is visible.
-- Also pulses high for FFFFFF cycles at reset, or approximately 16e6, or
-- 1/3 of a second at 50Mhz
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
use IEEE.NUMERIC_STD.ALL;

entity LED_extender is
	port ( 
		reset : in  std_logic;
		clk   : in  std_logic;
		din   : in  std_logic;
		dout  : out std_logic
	);
end LED_extender;

architecture Behavioral of LED_extender is

	signal next_counter : unsigned(23 downto 0);
	signal counter      : unsigned(23 downto 0);

begin

	FSM_FF: process(clk, reset)
	begin
		if reset = '1' then
			counter <= x"FFFFFF"; --to_unsigned(16777215, LED_counter_gtp_tx'length); -- Start with the LEDs active.
		elsif clk'event and clk = '1' then
			counter <= next_counter;
		end if;
	end process;
	
	FSM_LOGIC: process(din, counter)
	begin
		if din = '1' then
			next_counter <= x"4FFFFF"; -- Inactive state for uart.
			dout <= '1';
		elsif counter = x"000000" then
			next_counter <= x"000000";
			dout <= '0';
		else
			next_counter <= counter - 1;
			dout <= '1';
		end if;
	end process;
	
end Behavioral;

