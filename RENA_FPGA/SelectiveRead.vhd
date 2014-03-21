----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    01:51:24 03/15/2014 
-- Design Name: 
-- Module Name:    SelectiveRead - Behavioral 
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity SelectiveRead is
Port (
	mclk 	     : in std_logic;
	reset      : in std_logic;
	selective_read : in std_logic;
	
	an_trig1   : in std_logic;
	ca_trig1   : in std_logic;
	readingHR1 : in std_logic_vector(1 downto 0);
	
	an_trig2   : in std_logic;
	ca_trig2   : in std_logic;
	readingHR2 : in std_logic_vector(1 downto 0);
	
	selective_decision1 : out std_logic_vector(1 downto 0);
	selective_decision2 : out std_logic_vector(1 downto 0)
	);
end SelectiveRead;

architecture Behavioral of SelectiveRead is

type sd_state_type is (
	 IDLE,
    WAITING,
	 ONE_RENA_DONE_READING_HR,
    DECISION
);
	 
--========================================================================
-- Signal declarations
--========================================================================
-- State machine signals
-- RENA data readout FSM
signal state                    : sd_state_type := IDLE;
signal next_state               : sd_state_type := IDLE;
signal next_selective_decision1 : std_logic_vector(1 downto 0);
signal next_selective_decision2 : std_logic_vector(1 downto 0);
signal rena_id                  : std_logic;
signal next_rena_id             : std_logic;

begin

--========================================================================
-- Main D flip flop for sequential logic
--========================================================================
process(mclk, next_selective_decision1, next_selective_decision2)
begin
	if rising_edge(mclk) then
		if (reset = '1') then
			selective_decision1 <= "00";
			selective_decision2 <= "00";
			state <= IDLE;
			rena_id <= '0';
		else
			-- selective_decision values:
			-- 00: Wait
			-- 01: Proceed with read out
			-- 10: Send RENA readout back to IDLE state
			selective_decision1 <= next_selective_decision1;
			selective_decision2 <= next_selective_decision2;
			state <= next_state;
			rena_id <= next_rena_id;
		end if;
	end if;
end process;

--========================================================================
-- State machine
--========================================================================
process(state, an_trig1, ca_trig1, readingHR1, an_trig2, ca_trig2, readingHR2, rena_id)
begin
	if ((reset = '1') or (selective_read = '0')) then
		next_selective_decision1 <= "00";
		next_selective_decision2 <= "00";
		next_state <= IDLE;
		next_rena_id <= '0';
	else
		case state is
			-- Check if any of the RENAs are reading
			when IDLE =>
				next_state <= IDLE;
				next_rena_id <= '0';
				next_selective_decision1 <= "00";
				next_selective_decision2 <= "00";
				
				-- RENA 1
				if ((readingHR1 = "01") or (readingHR1 = "10")) then
					case readingHR1 is
						when "01" =>
							next_state <= WAITING;
							next_rena_id <= '0';
						when "10" =>
							next_selective_decision1 <= "10";
							next_selective_decision2 <= "00";
						when others =>
					end case;		
				else
					-- RENA 2
					if ((readingHR2 = "01") or (readingHR2 = "10"))then
						case readingHR2 is
							when "01" =>
								next_state <= WAITING;
								next_rena_id <= '1';
							when "10" =>
								next_selective_decision1 <= "00";
								next_selective_decision2 <= "10";
							when others =>
						end case;
					end if;
				end if;
				
--				-- RENA 1
--				if (readingHR1 = "01") then
--					next_state <= WAITING;
--					next_rena_id <= '0';
--				else
--					-- RENA 2
--					if (readingHR2 = "01") then
--						next_state <= WAITING;
--						next_rena_id <= '1';
--					else
--						next_state <= IDLE;
--						next_rena_id <= '0';
--					end if;
--				end if;
--				next_selective_decision1 <= "00";
--				next_selective_decision2 <= "00";
				
			-- Wait for RENA to finish reading its HR registers
			when WAITING =>
				if (rena_id = '0') then
					case readingHR1 is
						-- Trigger not valid, e.g. only eith fast or slow channel
						-- triggered in AND mode.
						when "00" =>
							next_state <= IDLE;
							
						-- Still reading HR
						when "01" =>
							next_state <= WAITING;
							
						-- Done reading HR
						when "10" =>
							next_state <= ONE_RENA_DONE_READING_HR;
							
						-- Should not ever happen
						when others =>
							next_state <= IDLE;
					end case;
				else
					case readingHR2 is
						-- Trigger not valid, e.g. only eith fast or slow channel
						-- triggered in AND mode
						when "00" =>
							next_state <= IDLE;
							
						-- Still reading HR
						when "01" =>
							next_state <= WAITING;
							
						-- Done reading HR
						when "10" =>
							next_state <= ONE_RENA_DONE_READING_HR;
							
						-- Should not ever happen
						when others =>
							next_state <= IDLE;
					end case;
				end if;
				next_rena_id <= rena_id;
				next_selective_decision1 <= "00";
				next_selective_decision2 <= "00";
				
			-- One of the RENAs have finished reading HR
			when ONE_RENA_DONE_READING_HR =>
				if (rena_id = '0') then
					case readingHR2 is
						-- Nothing is happening on RENA 2
						when "00" =>
							next_state <= DECISION;
							if ((an_trig1 = '1') and (ca_trig1 = '1')) then
								next_selective_decision1 <= "01";
								next_selective_decision2 <= "00";
							else
								next_selective_decision1 <= "10";
								next_selective_decision2 <= "00";
							end if;
							
						-- RENA 2 is still reading HR
						when "01" =>
							next_state <= ONE_RENA_DONE_READING_HR;
							next_selective_decision1 <= "00";
							next_selective_decision2 <= "00";
							
						-- RENA 2 is done reading HR
						when "10" =>
							next_state <= DECISION;
							if (((an_trig1 = '1') or (an_trig2 = '1')) and ((ca_trig1 = '1') or (ca_trig2 = '1'))) then
								next_selective_decision1 <= "01";
								next_selective_decision2 <= "01";
							else
								next_selective_decision1 <= "10";
								next_selective_decision2 <= "10";
							end if;
						
						-- Should not ever happen
						when others =>
							next_state <= IDLE;
							next_selective_decision1 <= "00";
							next_selective_decision2 <= "00";
					end case;
					
				-- rena_id = '1'
				else
					case readingHR1 is
						-- Nothing is happening on RENA 1
						when "00" =>
							next_state <= DECISION;
							if ((an_trig2 = '1') and (ca_trig2 = '1')) then
								next_selective_decision1 <= "00";
								next_selective_decision2 <= "01";
							else
								next_selective_decision1 <= "00";
								next_selective_decision2 <= "10";
							end if;
							
						-- RENA 1 is still reading HR
						when "01" =>
							next_state <= ONE_RENA_DONE_READING_HR;
							next_selective_decision1 <= "00";
							next_selective_decision2 <= "00";
							
						-- RENA 1 is done reading HR
						when "10" =>
							next_state <= DECISION;
							if (((an_trig1 = '1') or (an_trig2 = '1')) and ((ca_trig1 = '1') or (ca_trig2 = '1'))) then
								next_selective_decision1 <= "01";
								next_selective_decision2 <= "01";
							else
								next_selective_decision1 <= "10";
								next_selective_decision2 <= "10";
							end if;
						
						-- Should not ever happen
						when others =>
							next_state <= IDLE;
							next_selective_decision1 <= "00";
							next_selective_decision2 <= "00";
					end case;
				end if;
				next_rena_id <= rena_id;
							
			-- Send state machien back to IDLE
			when DECISION =>
				next_state <= IDLE;
				next_selective_decision1 <= "00";
				next_selective_decision2 <= "00";
				
			when others =>
				next_state <= IDLE;
				next_selective_decision1 <= "00";
				next_selective_decision2 <= "00";
		end case;
	end if;
end process;

end Behavioral;
