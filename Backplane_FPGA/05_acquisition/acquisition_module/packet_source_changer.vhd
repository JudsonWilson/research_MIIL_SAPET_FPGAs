----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson
--
-- Create Date:    04/08/2014
-- Design Name:
-- Module Name:    packet_source_changer
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--     Passes through packets, but changes the source node adress and the
-- frontend board address. This is meant as a tool for producing fake input
-- by tying a real source to multiple inputs in the data aquisition tree
-- and making them appear as real sources. Sometimes we call this the
-- "spoofer".
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

entity packet_source_changer is
	port (
		reset   : in  std_logic;
		clk     : in  std_logic;
		from_node_addr  : in std_logic_vector(7 downto 0);
		from_board_addr : in std_logic_vector(7 downto 0); -- Usually this is ('0' & board & rena), where board is 6 bits and rena is 1.
		din     : in  std_logic_vector(15 downto 0);
		din_wr  : in  std_logic;
		dout    : out std_logic_vector(15 downto 0);
		dout_wr : out std_logic
	);
end packet_source_changer;

architecture Behavioral of packet_source_changer is
	signal      toggle_board_address : std_logic := '0';
	signal next_toggle_board_address : std_logic := '0';
begin
	----------------------------------------------------------------------------
	-- State Machine FlipFlip Process
	-- - Updates pending state values on the clock edge
	----------------------------------------------------------------------------
	state_flipflop_process: process( clk, reset)
	begin
		if ( reset = '1') then
			toggle_board_address <= '0';
		elsif ( clk 'event and clk = '1' ) then
			toggle_board_address <= next_toggle_board_address;
		end if;
	end process;

	----------------------------------------------------------------------------
	-- State Machine Asynchronous Logic
	-- - React to state changes and external logic.
	-- - Only state machine action right now is to keep track of whether we
	--   need to swap the board address in the next word.
	----------------------------------------------------------------------------
	state_async_logic_process: process(
		from_node_addr, from_board_addr,
		toggle_board_address,
		din,        din_wr
	)
	begin
		-- Hunt for first word, change node address. On the next word, change the
		-- frontend board adress. Pass through the wr signal.
		if din_wr = '1' then
			-- queue incoming word for single delay, if present
			-- swap node, if this is the kind of packet we want to do that to
			if din(15 downto 8) = packet_start_token_throughput_test then
				dout <= din(15 downto 8) & from_node_addr;
				next_toggle_board_address <= '1';
			-- This state gets set on the first word of packet, becomes active on second word of packet, where the 
			elsif toggle_board_address = '1' then
				dout <= din(15 downto 8) & from_board_addr; --Format is always 00bbbbbb, and usually the lowest b is a rena number. 
				next_toggle_board_address <= '0';
			else
				dout <= din;
				next_toggle_board_address <= '0';
			end if;
		else
			-- Do not change the status of this:
			next_toggle_board_address <= toggle_board_address;
			dout <= din;
		end if;
		
		dout_wr <= din_wr;
	end process;

end Behavioral;
