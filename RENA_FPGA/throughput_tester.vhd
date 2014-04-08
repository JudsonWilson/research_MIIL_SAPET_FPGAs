----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson
--
-- Create Date:    03/27/2014
-- Design Name:
-- Module Name:    throughput_tester - Behavioral
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--     Using a programmable counter, sends packets at specified time intervals.
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
package THROUGHPUT_TESTER_PACKAGE is
	-- Can count up to 268,435,455, between packets, i.e. roughly 1 packet every 5 seconds at 50MHz, at the longest.
	constant throughput_packet_period_bits : INTEGER := 28;
end package;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use WORK.THROUGHPUT_TESTER_PACKAGE.all;
use WORK.SAPET_PACKETS.ALL;

entity throughput_tester is
	Port (
		clk    : in STD_LOGIC;
		reset  : in STD_LOGIC;

		fpga_addr      : in std_logic_vector(5 downto 0);

		-- Configuration (Dynamic)
		num_packet_bytes_filler  : in STD_LOGIC_VECTOR (7 downto 0); -- Number of extra bytes to put in the end of the packet, to adjust the length
		throughput_packet_period : in STD_LOGIC_VECTOR (throughput_packet_period_bits-1 downto 0);

		enable : in STD_LOGIC; -- Enable/Disable the counter and packet sending trigger. Existing trigger events will run through completion.

		-- Packet Output
		take_tx_port     : out STD_LOGIC;   -- Set this high when we might be sending data (i.e. when enable='1', and possibly for a short time thereafter while finishing).
		packet_data      : out STD_LOGIC_VECTOR (7 downto 0); -- Output packet data to the TX
		packet_data_wr   : out STD_LOGIC;                     -- Tells the TX that data is valid. Pulse once per byte.
		packet_fifo_busy : in STD_LOGIC                       -- Notification that the receiving FIFO has not finished sending previous packet.
	);
end throughput_tester;


architecture Behavioral of throughput_tester is
	-- Used to detect startup of the throughput_tester, so we can setup the countdown period as desired.
	signal previous_enable : STD_LOGIC;
	
	-- Used to fire off packets at regular intervals. Set this to throughput_packet_period, and then count down to zero, repeatedly.
	signal countdown_counter : unsigned (throughput_packet_period_bits-1 downto 0);
	signal countdown_counter_next : unsigned (throughput_packet_period_bits-1 downto 0);
	
	-- Oneshot signal to send a packet, triggered when the countdown reaches zero.
	signal send : STD_LOGIC;

	signal packet_data_next    : STD_LOGIC_VECTOR (7 downto 0);
	signal packet_data_wr_next : STD_LOGIC;

	-- Sending State Machine
	type sendstate_type is (
		SENDSTATE_IDLE,
		SENDSTATE_FRONTEND_ADDR,
		SENDSTATE_FLAGS,
		SENDSTATE_PACKETNUM,
		SENDSTATE_FILLER,
		SENDSTATE_LASTBYTE
		);
	signal send_state       : sendstate_type := SENDSTATE_IDLE;
	signal send_state_next  : sendstate_type := SENDSTATE_IDLE;

	-- Used to count down the number of bytes in a section of the packet.
	constant num_packet_byte_counter_bits : INTEGER := 8; -- 256ish bytes of filler, max
	signal packet_byte_counter      : unsigned (num_packet_byte_counter_bits-1 downto 0);
	signal packet_byte_counter_next : unsigned (num_packet_byte_counter_bits-1 downto 0);

	-- Keeps track of which packet this is. Increments every time a packet is triggered.
	constant num_packetnum_bits : INTEGER := 16; -- Can count up to 65,535 packets before rolling over. Should be WAY overkill.
	signal packetnum_counter : unsigned (num_packetnum_bits-1 downto 0);
	signal packetnum_counter_next : unsigned (num_packetnum_bits-1 downto 0);
	-- Copy used for packet shift-register. Note that its a std_logic_vector instead of unsigned.
	signal packetnum_copy_for_packet      : STD_LOGIC_VECTOR (num_packetnum_bits-1 downto 0);
	signal packetnum_copy_for_packet_next : STD_LOGIC_VECTOR (num_packetnum_bits-1 downto 0);

	-- Number of packet bytes for the packetnum field in the packet.
	-- (Note each packet byte contains only 6 bits of data.)
	constant num_packet_bytes_packetnum : INTEGER := (num_packetnum_bits + 5) / 6; -- Adding 5 ensures a round-up operation on the division

	signal error_flag_couldnt_send_throughput_packet      : STD_LOGIC;
	signal error_flag_couldnt_send_throughput_packet_next : STD_LOGIC;
begin

	--=====================================================================
	-- Countdown State Machine
	-- - Periodically triggers a one-shot pulse on send
	--=====================================================================
	-----------------------------------------------------------------------
	-- Countdown State Machine DFF
	-----------------------------------------------------------------------
	-- State transition on clock, or reset
	countdown_state_transition_process: process(clk, reset)
	begin
		if reset = '1' then
			previous_enable <= '0';
			countdown_counter <= (others => '0');
		elsif rising_edge(clk) then
			previous_enable <= enable;
			countdown_counter <= countdown_counter_next;
		end if;
	end process;

	-----------------------------------------------------------------------
	-- Countdown State Machine Updator
	-----------------------------------------------------------------------
	countdown_next_state_process: process( enable, previous_enable, countdown_counter, throughput_packet_period )
	begin
		if enable = '1' then
			-- If we just started, force 0.5-second delay before data starts pouring through, to help ensure configuration
			-- packets get through the sytem.
			if previous_enable = '0' then
				countdown_counter_next <= to_unsigned(2500000, countdown_counter_next'length);
				send <= '0';
			-- Trigger packet and reset count if we counted down to zero.
			elsif countdown_counter = (countdown_counter'range => '0') then
				countdown_counter_next <= unsigned(throughput_packet_period)-1;
				send <= '1';
			-- Else, count down, don't trigger packet.
			else
				countdown_counter_next <= countdown_counter - 1;
				send <= '0';
			end if;
		else
				countdown_counter_next <= (countdown_counter'range => '0'); -- Will send packet immediately after enable.
				send <= '0';
		end if;
	end process;


	--=====================================================================
	-- take_tx_port
	-- - This signal is 1 when we want to takeover the TX port that is
	--   usually used for rena data output packets.
	--=====================================================================
	take_tx_port <= '1' when (enable = '1' or send_state /= SENDSTATE_IDLE) else '0';

	--=====================================================================
	-- Packet Writer State Machine
	--=====================================================================
	-----------------------------------------------------------------------
	-- Packet Writer State Machine DFF
	-----------------------------------------------------------------------
	-- State transition on clock, or reset
	state_transition_process: process(clk, reset)
	begin
		if reset = '1' then
			packet_data <= (others => '0');
			packet_data_wr <= '0';
			packet_byte_counter <= to_unsigned(0, num_packet_byte_counter_bits);
			packetnum_counter <= to_unsigned(0, packetnum_counter'length);
			packetnum_copy_for_packet <= (others => '0');
			error_flag_couldnt_send_throughput_packet <= '0';
			send_state <= SENDSTATE_IDLE;
		elsif rising_edge(clk) then
			packet_data <= packet_data_next;
			packet_data_wr <= packet_data_wr_next;
			packet_byte_counter <= packet_byte_counter_next;
			packetnum_counter <= packetnum_counter_next;
			packetnum_copy_for_packet <= packetnum_copy_for_packet_next;
			error_flag_couldnt_send_throughput_packet <= error_flag_couldnt_send_throughput_packet_next;
			send_state <= send_state_next;
		end if;
	end process;

	-----------------------------------------------------------------------
	-- Packet Writer State Machine Decision Logic
	-----------------------------------------------------------------------
	compute_next_state_process: process( send,
	                                     send_state,
	                                     packet_fifo_busy,
	                                     packet_byte_counter,
	                                     packetnum_counter, packetnum_copy_for_packet,
	                                     error_flag_couldnt_send_throughput_packet,
	                                     fpga_addr,
	                                     num_packet_bytes_filler
	                                   )
	begin
		-- Default: Don't send data.
		packet_data_next    <= (others => '0');
		packet_data_wr_next <= '0';
		-- Default: Don't update the packet byte field counter
		packet_byte_counter_next <= packet_byte_counter;
		-- Default: Don't update the packetnum counter or the copy for the packet
		packetnum_counter_next <= packetnum_counter;
		packetnum_copy_for_packet_next <= packetnum_copy_for_packet;
		-- Default: Don't change the error flags.
		error_flag_couldnt_send_throughput_packet_next <= error_flag_couldnt_send_throughput_packet;


		case send_state is
		when SENDSTATE_IDLE =>
			-- If the counter is triggering a new packet at this moment.
			if send = '1' then
				-- If the tx has not finished sending the previous packet.
				if packet_fifo_busy = '1' then
					-- Set error, wait for next send request
					error_flag_couldnt_send_throughput_packet_next <= '1';
					send_state_next <= SENDSTATE_IDLE;
				-- If tx is ready for a new packet
				else
					-- Start a transmission, buffer any data that will be sent (except flags), update packetnum counter
					packetnum_copy_for_packet_next <= STD_LOGIC_VECTOR(packetnum_counter);
					packetnum_counter_next <= packetnum_counter + 1;
					-- Send byte of packet
					packet_data_next    <= packet_start_token_throughput_test;  -- Send the first byte.
					packet_data_wr_next <= '1';                                 --   "   "    "    "
					-- Send the FPGA_ADDR on next byte
					send_state_next <= SENDSTATE_FRONTEND_ADDR;
				end if;
			else
				send_state_next <= send_state;
			end if;

		when SENDSTATE_FRONTEND_ADDR =>
			-- Check for failed send error
			if send = '1' then
				error_flag_couldnt_send_throughput_packet_next <= '1';
			end if;
			-- Send the second header byte, identifying this RENA board ID.
			packet_data_next <= "0" & fpga_addr & "0"; -- Lower bit, chip_id=0, to match layout of the other data packets.
			packet_data_wr_next <= '1';
			-- Setup for the flags section of the packet.
			send_state_next <= SENDSTATE_FLAGS;

		when SENDSTATE_FLAGS =>
			-- Check for failed send error, clear now if not since this is the state where we transmit the flag.
			if send = '1' then
				error_flag_couldnt_send_throughput_packet_next <= '1';
			else
				error_flag_couldnt_send_throughput_packet_next <= '0';
			end if;
			-- Fill the packet with various flags (probably some kind of over-run flag when we triggered a new packet but the fifo was full)
			packet_data_next <= "00" & "00000" -- 5 empty flags
											 & error_flag_couldnt_send_throughput_packet;
			packet_data_wr_next <= '1';
			-- Setup for the packetnum section of the packet.
			packet_byte_counter_next <= to_unsigned(0, packet_byte_counter'length); --num_packet_byte_counter_bits);
			send_state_next <= SENDSTATE_PACKETNUM;

		when SENDSTATE_PACKETNUM =>
			-- Fill the packet with the top 6 bits of packet_num_copy_for_packet
			packet_data_next <= "00" & packetnum_copy_for_packet(num_packetnum_bits-1 downto num_packetnum_bits-1-5);
			packet_data_wr_next <= '1';
			-- Shift packet_num_copy_for_packet up by 6 bits (using it as a shift register).
			packetnum_copy_for_packet_next <= packetnum_copy_for_packet(num_packetnum_bits-1-6 downto 0) & "000000";
			-- Do this state for the correct number of bytes.
			if packet_byte_counter >= num_packet_bytes_packetnum - 1 then
				-- Now send bug notifications
				send_state_next <= SENDSTATE_FILLER;
				packet_byte_counter_next <= to_unsigned(0, packet_byte_counter'length);
			else
				-- Continue sending rena2 settings.
				send_state_next <= send_state;
				packet_byte_counter_next <= packet_byte_counter + 1;
			end if;

		when SENDSTATE_FILLER =>
			-- Fill the packet with useless data to get the desired packet size.
			packet_data_next <= "00" & "111111";
			packet_data_wr_next <= '1';
			-- Do this state for the correct number of bytes.
			if packet_byte_counter >= unsigned(num_packet_bytes_filler) - 1 then
				-- Now send end of packet
				send_state_next <= SENDSTATE_LASTBYTE;
				packet_byte_counter_next <= to_unsigned(0, packet_byte_counter'length);
			else
				-- Continue sending filler.
				send_state_next <= send_state;
				packet_byte_counter_next <= packet_byte_counter + 1;
			end if;

		when SENDSTATE_LASTBYTE =>
			packet_data_next <= packet_end_token;
			packet_data_wr_next <= '1';
			send_state_next <= SENDSTATE_IDLE;

		when others =>
			send_state_next <= SENDSTATE_IDLE;
		end case;
	end process;

end Behavioral;

