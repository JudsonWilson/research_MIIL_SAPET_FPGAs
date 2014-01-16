----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson
--
-- Create Date:    01/04/2013 
-- Design Name:
-- Module Name:    serialize_preprocessor
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--     Passes through packets, but strips out the following bytes:
--      - 2nd Byte - Source Node Address
--      - 3rd Byte - Destination Node Address
--     Note this component is mostly asynchronous. In general the data will pass
--     through this without clock delays, except for the 1st header word, which
--     is quarantined and then melded with the 2nd header word to erase the
--     source/destination bytes.
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

use work.sapet_packets.all;

entity serializer_preprocessor is
	port (
		reset   : in  std_logic;
		clk     : in  std_logic;
		din     : in  std_logic_vector(15 downto 0);
		din_wr  : in  std_logic;
		dout    : out std_logic_vector(15 downto 0);
		dout_wr : out std_logic
	);
end serializer_preprocessor;

architecture Behavioral of serializer_preprocessor is
	-- Stored copy of the first byte of the header, to merge into the second
	-- word once it comes in.
	signal first_header_byte      : std_logic_vector(7 downto 0);
	signal first_header_byte_next : std_logic_vector(7 downto 0);
	-- Signals that we have stored first_header_byte (and implies the next
	-- word received is the second header word).
	signal first_header_byte_is_waiting      : std_logic;
	signal first_header_byte_is_waiting_next : std_logic;
begin

	----------------------------------------------------------------------------
	-- State Machine FlipFlip Process
	-- - Updates pending state values on the clock edge
	----------------------------------------------------------------------------
	state_flipflop_process: process( clk, reset)
	begin
		if ( reset = '1') then
			first_header_byte <= x"00";
			first_header_byte_is_waiting <= '0';
		elsif ( clk 'event and clk = '1' ) then
			first_header_byte <= first_header_byte_next;
			first_header_byte_is_waiting <= first_header_byte_is_waiting_next;
		end if;
	end process;
	
	----------------------------------------------------------------------------
	-- State Machine Asynchronous Logic
	-- - React to state changes and external logic.
	-- - Note that this state machine is mostly asynchronous. In general the
	--   data will pass through this without delay, except for the 1st header
	--   word, which is quarantined and then melded with the 2nd header word to
	--   erase the source/destination. The 2nd header word passes through
	--   without delay, as a mix of the input 1st/2nd header word bytes.
	----------------------------------------------------------------------------
	state_async_logic_process: process(
		din,          din_wr,
		first_header_byte,
		first_header_byte_is_waiting
	)
	begin
		-- If new data came in, handle it.
		if din_wr = '1' then

			-- Look for first word of packet, save part of it
			if is_packet_start_token(din(15 downto 8)) then
				-- save the first byte, dump the second byte
				first_header_byte_next <= din(15 downto 8);
				first_header_byte_is_waiting_next <= '1';
				-- dump this word
				dout_wr <= '0';
				dout    <= x"0000"; -- makes for easier testing
			-- Look for second word of packet, and send out header with
			-- source/destination removed.
			elsif first_header_byte_is_waiting = '1' then
				first_header_byte_next <= x"00";
				first_header_byte_is_waiting_next <= '0';
				-- Write out a new first word of packet that does not include
				-- the source and destination.
				dout_wr <= '1';
				dout    <= first_header_byte & din(7 downto 0);
			-- If not in header, just forward the word.
			else
				first_header_byte_next <= x"00";
				first_header_byte_is_waiting_next <= '0';
				dout_wr <= '1';
				dout    <= din;
			end if;

		-- No data came in, hold state
		else
			first_header_byte_next <= first_header_byte;
			first_header_byte_is_waiting_next <= first_header_byte_is_waiting;
			dout_wr <= '0';
			dout    <= din;
		end if;

	end process;

end Behavioral;
