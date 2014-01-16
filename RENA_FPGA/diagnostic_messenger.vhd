----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson
--
-- Create Date:    14:51:52 10/29/2013
-- Design Name:
-- Module Name:    diagnostic - Behavioral
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--     Stores various data from other diagnostic detection code in the design, and
-- when triggered, produces a packet that is sent out of the FPGA.
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

-- TODO: put this in a package so that other components can use these constants.
package P is
	constant diagnostic_num_rena_settings_bits    : INTEGER := 36+36     -- anode mask = 36; cathode mask = 36;
	                                                           +42       -- last channel { Which = 1; Settings = 41; } = 42
	                                                           +1+1+1    -- OR Mode Triggers = 1; Force Trigger Mode = 1; Selective Reade = 1;
	                                                           +1+1      -- Enable Readout = 1; Coincidence Read = 1;
	                                                           +1+1+6+2; -- Follower{ Mode 1&2 = 1+1; Chan = 6; tclk = 2};
	                                                            -- Total = 129
	constant diagnostic_num_rena_settings_packets : INTEGER := (129 + 5) / 6; -- Adding 5 ensures a round-up operation on the division
end package;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.P.all;

use WORK.SAPET_PACKETS.ALL;

entity diagnostic_messenger is
	Generic (
		num_bug_bits : INTEGER
	);
	Port (
		clk   : in STD_LOGIC;
		reset : in STD_LOGIC;

		fpga_addr      : in std_logic_vector(5 downto 0);

		send  : in STD_LOGIC; -- Pulse to send the current state out to the TX, and reset the state

		packet_data    : out STD_LOGIC_VECTOR (7 downto 0); -- Output packet data to the TX
		packet_data_wr : out STD_LOGIC;                     -- Tells the TX that data is valid. Pulse once per byte.

		rena1_settings    : in STD_LOGIC_VECTOR (diagnostic_num_rena_settings_bits-1 downto 0); --Last value that was programmed to rena1
		rena2_settings    : in STD_LOGIC_VECTOR (diagnostic_num_rena_settings_bits-1 downto 0); --Last value that was programmed to rena2
		bug_notifications : in STD_LOGIC_VECTOR (num_bug_bits-1 downto 0) --Pulse a bit to notify that an occurence of that bug happened.
	);
end diagnostic_messenger;


architecture Behavioral of diagnostic_messenger is
	constant num_bug_packets : INTEGER := (num_bug_bits + 5) / 6; -- Adding 5 ensures a round-up operation on the division

	signal packet_data_next    : STD_LOGIC_VECTOR (7 downto 0);
	signal packet_data_wr_next : STD_LOGIC;

	signal bugs_notified       : STD_LOGIC_VECTOR (num_bug_bits-1 downto 0); -- These bits remain high once a corresponding bug_notification bit pulse occurs.
	signal bugs_notified_next  : STD_LOGIC_VECTOR (num_bug_bits-1 downto 0);

	-- Stored copies for sending, such that nothing changes mid-transition.
	signal send_copy_rena1_settings      : STD_LOGIC_VECTOR (diagnostic_num_rena_settings_bits-1 downto 0);
	signal send_copy_rena1_settings_next : STD_LOGIC_VECTOR (diagnostic_num_rena_settings_bits-1 downto 0);
	signal send_copy_rena2_settings      : STD_LOGIC_VECTOR (diagnostic_num_rena_settings_bits-1 downto 0);
	signal send_copy_rena2_settings_next : STD_LOGIC_VECTOR (diagnostic_num_rena_settings_bits-1 downto 0);
	signal send_copy_bugs_notified       : STD_LOGIC_VECTOR (num_bug_bits-1 downto 0);
	signal send_copy_bugs_notified_next  : STD_LOGIC_VECTOR (num_bug_bits-1 downto 0);

	-- Sending State Machine
	constant num_sendstate_bits  : INTEGER := 3;
	constant SENDSTATE_IDLE      : STD_LOGIC_VECTOR (num_sendstate_bits-1 downto 0) := "000";
	constant SENDSTATE_RENA_ADDR : STD_LOGIC_VECTOR (num_sendstate_bits-1 downto 0) := "001";
	constant SENDSTATE_HEADER_3  : STD_LOGIC_VECTOR (num_sendstate_bits-1 downto 0) := "010";
	constant SENDSTATE_RENA1     : STD_LOGIC_VECTOR (num_sendstate_bits-1 downto 0) := "011";
	constant SENDSTATE_RENA2     : STD_LOGIC_VECTOR (num_sendstate_bits-1 downto 0) := "100";
	constant SENDSTATE_BUGS      : STD_LOGIC_VECTOR (num_sendstate_bits-1 downto 0) := "101";
	constant SENDSTATE_LASTBYTE  : STD_LOGIC_VECTOR (num_sendstate_bits-1 downto 0) := "110";

	signal send_state            : STD_LOGIC_VECTOR (num_sendstate_bits-1 downto 0);
	signal send_state_next       : STD_LOGIC_VECTOR (num_sendstate_bits-1 downto 0);

	constant num_send_counter_bits : INTEGER := diagnostic_num_rena_settings_packets;
	signal send_counter      : unsigned (num_send_counter_bits-1 downto 0);
	signal send_counter_next : unsigned (num_send_counter_bits-1 downto 0);
begin
	-- State transition on clock, or reset
	state_transition_process: process(clk, reset)
	begin
		if reset = '1' then
			packet_data <= (others => '0');
			packet_data_wr <= '0';
			bugs_notified <= (others => '0');
			send_copy_rena1_settings <= (others => '0');
			send_copy_rena2_settings <= (others => '0');
			send_copy_bugs_notified <= (others => '0');
			send_state <= SENDSTATE_IDLE;
			send_counter <= to_unsigned(0, num_send_counter_bits);
		elsif rising_edge(clk) then
			packet_data <= packet_data_next;
			packet_data_wr <= packet_data_wr_next;
			bugs_notified <= bugs_notified_next;
			send_copy_rena1_settings <= send_copy_rena1_settings_next;
			send_copy_rena2_settings <= send_copy_rena2_settings_next;
			send_copy_bugs_notified <= send_copy_bugs_notified_next;
			send_state <= send_state_next;
			send_counter <= send_counter_next;
		end if;
	end process;

	-- State machine updator, etc
	compute_next_state_process: process( bugs_notified, bug_notifications,
	                                     rena1_settings, rena2_settings,
	                                     send,
	                                     send_copy_rena1_settings, send_copy_rena2_settings, send_copy_bugs_notified,
	                                     send_state, send_counter)
	begin
		--By default, don't send data
		packet_data_next    <= (others => '0');
		packet_data_wr_next <= '0';
		-- Default: Do update bug notifications.
		bugs_notified_next <= bugs_notified or bug_notifications;
		-- Default: Don't change the send copies.
		send_copy_rena1_settings_next <= send_copy_rena1_settings;
		send_copy_rena2_settings_next <= send_copy_rena2_settings;
		send_copy_bugs_notified_next <= send_copy_bugs_notified;
		-- Default: Don't update counter
		send_counter_next <= send_counter;

		case send_state is
			when SENDSTATE_IDLE =>
				if send = '1' then
					-- Start a transmission --
					-- Snapshot of the rena settings
					send_copy_rena1_settings_next <= rena1_settings;
					send_copy_rena2_settings_next <= rena2_settings;
					-- Update-store-and-clear bug notifications - never miss a bug, not even when storing and clearing for a send
					send_copy_bugs_notified_next <= bugs_notified or bug_notifications;
					bugs_notified_next <= (others => '0');
					-- Send byte of packet
					packet_data_next    <= packet_start_token_frontend_diagnostic;  -- Send the first byte.
					packet_data_wr_next <= '1';    --   "   "    "    "
					-- Send the FPGA_ADDR on next byte
					send_state_next <= SENDSTATE_RENA_ADDR;
				else
					send_state_next <= send_state;
				end if;

			when SENDSTATE_RENA_ADDR =>
				-- Send the second header byte, identifying this RENA board ID.
				packet_data_next <= "0" & fpga_addr & "0"; -- Lower bit, chip_id=0, to match layout of the other data packets.
				packet_data_wr_next <= '1';
				-- Send the diagnostic packet identifier on next byte
				send_state_next <= SENDSTATE_HEADER_3;

			when SENDSTATE_HEADER_3 =>
				-- Send the third header byte, x"84", signifying a diagnostic packet.
				packet_data_next <= x"84";
				packet_data_wr_next <= '1';
				-- Start sending RENA data on next state
				send_state_next <= SENDSTATE_RENA1;
				send_counter_next <= to_unsigned(0, num_send_counter_bits);

			when SENDSTATE_RENA1 =>
				-- Fill the packet with the top 6 bits of send_copy_rena1_settings
				packet_data_next <= "00" & send_copy_rena1_settings(diagnostic_num_rena_settings_bits-1 downto diagnostic_num_rena_settings_bits-1-5);
				packet_data_wr_next <= '1';
				-- Shift send_copy_rena1_settings up by 6 for the next packet
				send_copy_rena1_settings_next
				    <= send_copy_rena1_settings(diagnostic_num_rena_settings_bits-1-6 downto 0) & "000000";
				if send_counter >= diagnostic_num_rena_settings_packets - 1 then
					-- Now send rena2 settings.
					send_state_next <= SENDSTATE_RENA2;
					send_counter_next <= to_unsigned(0, num_send_counter_bits);
				else
					-- Continue sending rena1 settings.
					send_state_next <= send_state;
					send_counter_next <= send_counter + 1;
				end if;

			when SENDSTATE_RENA2 =>
				-- Fill the packet with the top 6 bits of send_copy_rena2_settings
				packet_data_next <= "00" & send_copy_rena2_settings(diagnostic_num_rena_settings_bits-1 downto diagnostic_num_rena_settings_bits-1-5);
				packet_data_wr_next <= '1';
				-- Shift send_copy_rena2_settings up by 6 for the next packet
				send_copy_rena2_settings_next
				    <= send_copy_rena2_settings(diagnostic_num_rena_settings_bits-1-6 downto 0) & "000000";
				if send_counter >= diagnostic_num_rena_settings_packets - 1 then
					-- Now send bug notifications
					send_state_next <= SENDSTATE_BUGS;
					send_counter_next <= to_unsigned(0, num_send_counter_bits);
				else
					-- Continue sending rena2 settings.
					send_state_next <= send_state;
					send_counter_next <= send_counter + 1;
				end if;

			when SENDSTATE_BUGS =>
				-- Fill the packet with the top 6 bits of send_copy_rena1_settings
				packet_data_next <= "00" & send_copy_bugs_notified(num_bug_bits-1 downto num_bug_bits-1-5);
				packet_data_wr_next <= '1';
				-- Shift send_copy_bugs_notified up by 6 for the next packet
				send_copy_bugs_notified_next
				    <= send_copy_bugs_notified(num_bug_bits-1-6 downto 0) & "000000";
				if send_counter >= num_bug_packets - 1 then
					-- Now send end of packet
					send_state_next <= SENDSTATE_LASTBYTE;
					send_counter_next <= to_unsigned(0, num_send_counter_bits);
				else
					-- Continue sending rena2 settings.
					send_state_next <= send_state;
					send_counter_next <= send_counter + 1;
				end if;

			when SENDSTATE_LASTBYTE =>
				-- Fill the packet with the top 6 bits of send_copy_rena1_settings
				packet_data_next <= x"FF";
				packet_data_wr_next <= '1';
				send_state_next <= SENDSTATE_IDLE;

			when others =>
				send_state_next <= SENDSTATE_IDLE;
		end case;
	end process;
end Behavioral;

