----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson
--
-- Create Date:    01/06/2014 
-- Design Name:
-- Module Name:    packet_source_destination_swapper
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--     Passes through packets, but swaps the source/destination bytes if swap_en
--     is set. This is intended for use in the configuration echo-back. When
--     the packet coming through is an echo, the swap_en should be enabled,
--     otherwise it is deasserted.
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

entity packet_source_destination_swapper is
	port (
		reset   : in  std_logic;
		clk     : in  std_logic;
		din     : in  std_logic_vector(15 downto 0);
		din_wr  : in  std_logic;
		swap_en : in  std_logic;
		dout    : out std_logic_vector(15 downto 0);
		dout_wr : out std_logic
	);
end packet_source_destination_swapper;

architecture Behavioral of packet_source_destination_swapper is
	-- signals for 1 unit of bus delay
	signal din_delay1         : std_logic_vector(15 downto 0) := x"0000";
	signal din_delay1_next    : std_logic_vector(15 downto 0) := x"0000";
	signal din_wr_delay1      : std_logic := '0';
	signal din_wr_delay1_next : std_logic := '0';
	-- state machine
	signal waiting_on_second_word      : std_logic := '0';
	signal waiting_on_second_word_next : std_logic := '0';
begin

	----------------------------------------------------------------------------
	-- State Machine FlipFlip Process
	-- - Updates pending state values on the clock edge
	----------------------------------------------------------------------------
	state_flipflop_process: process( clk, reset)
	begin
		if ( reset = '1') then
			din_delay1    <= x"0000";
			din_wr_delay1 <= '0';
			waiting_on_second_word <= '0';
		elsif ( clk 'event and clk = '1' ) then
			din_delay1    <= din_delay1_next;
			din_wr_delay1 <= din_wr_delay1_next;
			waiting_on_second_word <= waiting_on_second_word_next;
		end if;
	end process;

	----------------------------------------------------------------------------
	-- State Machine Asynchronous Logic
	-- - React to state changes and external logic.
	-- - Basically need to have at least 1 level deep of pipelining
	--   1) If we didn't just get the first word, then march the pipeline
	--      without waiting for data. March the data and the associated wr
	--      signals through, and it will just be the bus with a delay of 1.
	--   2) If we DID get the first word, then the pipeline must halt until
	--      the second word comes in, so that we make sure we have both words
	--      so we can swap bytes before preceeding.
	----------------------------------------------------------------------------
	state_async_logic_process: process(
		din,        din_wr,
		din_delay1, din_wr_delay1,
		swap_en,
		waiting_on_second_word
	)
	begin
		-- Special case for when we have found the first word of a
		-- packet and are waiting for the second word.
		if waiting_on_second_word = '1' then
			-- If new data comes in, react to it
			if din_wr = '1' then
				-- output swapped first word
				dout <= din_delay1(15 downto 8) & din(15 downto 8);
				dout_wr <= '1';
				-- queue swapped second word
				din_delay1_next <= din_delay1(7 downto 0) & din (7 downto 0);
				din_wr_delay1_next <= '1';
				-- exit this mode and allow all to pass without waiting.
				waiting_on_second_word_next <= '0';
			-- If no new data comes in, hold on to the delayed value,
			-- don't write.
			else
				-- hold output disabled
				dout <= x"0000";
				dout_wr <= '0';
				-- hold the current delayed word until second word arrives
				din_delay1_next <= din_delay1;
				din_wr_delay1_next <= '1'; -- doesn't really matter
				-- continue waiting
				waiting_on_second_word_next <= '1';
			end if;

		-- If not waiting on second word, just act as a unit delay on
		-- the data and wr signals, but look for a new first-word-of-
		-- packet.
		else
			-- output delayed word, if present
			dout    <= din_delay1;
			dout_wr <= din_wr_delay1;
			-- queue incoming word for single delay, if present
			din_delay1_next <= din;
			din_wr_delay1_next <= din_wr;
			-- check for first word of packet, if found and the swap
			-- functionality is enabled it will wait in the delayed
			-- slot until the second word comes.
			if din(15 downto 8) = x"81" and swap_en = '1' then
				waiting_on_second_word_next <= '1';
			else
				waiting_on_second_word_next <= '0';
			end if;
		end if;
	end process;

end Behavioral;
