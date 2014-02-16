----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson, based on code by Hua Liu.
--
-- Create Date:    02/15/2014
-- Design Name:
-- Module Name:    packet_bus_output_synchronizer
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--     The output port works just like the output port of a packet fifo, but
-- under-the-hood it uses a fair priority scheme to choose between two inputs
-- that also have a packet fifo output interface.
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


entity packet_bus_output_synchronizer is
	port (
		reset       : in std_logic;
		clk         : in std_logic;
		-- Input, Source Port
		din_rd_en  : out std_logic;
		din_packet_available : in std_logic; -- Goes to '1' before first word of packet is read, goes to '0' immediately afterwards.
		din_empty_notready   : in std_logic; -- Indicates the user should not try and read (rd_en). May happen mid-packet! Always check this!
		din        : in std_logic_vector(15 downto 0);
		din_end_of_packet : in std_logic;
		-- Output Port
		dout_rd_en  : in std_logic;
		dout_packet_available : out std_logic; -- Goes to '1' before first word of packet is read, goes to '0' immediately afterwards.
		dout_empty_notready   : out std_logic; -- Indicates the user should not try and read (rd_en). May happen mid-packet! Always check this!
		dout        : out std_logic_vector(15 downto 0);
		dout_end_of_packet : out std_logic
	);
end packet_bus_output_synchronizer;

architecture Behavioral of packet_bus_output_synchronizer is
	attribute keep : string;  
	attribute S: string;

	signal reset_i  : std_logic := '1';
	signal clk_i    : std_logic;

	signal dout_packet_available_i  : std_logic := '0';
	signal dout_empty_notready_i    : std_logic := '1';
	signal dout_i                   : std_logic_vector(15 downto 0) := x"0000";
	signal dout_end_of_packet_i     : std_logic := '1';
		
	signal dout_packet_available_next  : std_logic := '0';
	signal dout_empty_notready_next    : std_logic := '1';
	signal dout_next                   : std_logic_vector(15 downto 0) := x"0000";
	signal dout_end_of_packet_next     : std_logic := '1';

	-- input-manager state machine states.
	type   output_synchronizer_state_type is ( unread_input, stale_input );
	signal output_synchronizer_state      : output_synchronizer_state_type := unread_input;
	signal output_synchronizer_state_next : output_synchronizer_state_type := unread_input;

begin
	-- pass through intermediate signals
	reset_i <= reset;
	clk_i <= clk;
	dout_packet_available <= dout_packet_available_i;
	dout_empty_notready <= dout_empty_notready_i;
	dout <= dout_i;
	dout_end_of_packet <= dout_end_of_packet_i;

	--=============================================================================
	-- Output Synchronizer State Machine
	--=============================================================================

	----------------------------------------------------------------------------
	-- State Machine FlipFlip Process
	-- - Updates pending state values on the clock edge
	----------------------------------------------------------------------------
	output_synchronizer_FSM_flipflop_process: process( clk_i, reset_i)
	begin
		if ( reset_i = '1') then
			dout_i <= x"0000";
			dout_empty_notready_i <= '1';
			dout_packet_available_i <= '0';
			dout_end_of_packet_i <= '1';
			output_synchronizer_state <= stale_input;
		elsif ( clk_i'event and clk_i = '1' ) then
			dout_i <= dout_next;
			dout_empty_notready_i <= dout_empty_notready_next;
			dout_packet_available_i <= dout_packet_available_next;
			dout_end_of_packet_i <= dout_end_of_packet_next;
			output_synchronizer_state <= output_synchronizer_state_next;
		end if;
	end process;

	----------------------------------------------------------------------------
	-- State Machine Combinational Logic
	-- - React to state changes and external logic.
	-- - Basically acts like 1 state worth of "buffering" between an input
	--   packet_bus (like from the output of a packet fifo) and an identical
	--   output bus, except this is guaranteed to have synchronous outputs.
	--   This is good if cascading several 
	----------------------------------------------------------------------------
	output_synchronizer_FSM_combi_logic_process: process(
		din,  din_packet_available, din_empty_notready, din_end_of_packet,
		dout_rd_en,
		dout_i, dout_empty_notready_i, dout_packet_available_i, dout_end_of_packet_i,
		output_synchronizer_state
	)
	begin
		case output_synchronizer_state is
		-- In this state there is fresh data to output if the dout_rd_en is strobed,
		-- so handle that even if it occurs, or wait.
		when unread_input =>
			if dout_rd_en = '1' then
				dout_next <= din;
				dout_end_of_packet_next <= din_end_of_packet;
				-- See if we can get fresh data for next state
				-- or, if not, next output will be stale.
				if din_empty_notready = '0' then
					din_rd_en <= '1';
					dout_empty_notready_next <= '0';
					-- If the word that arrives next cycle (and will be available for requestin
					-- next cycle) is a first-word-of-packet, then next cycle we should also
					-- announce it is a first word of packet.
					dout_packet_available_next <= din_packet_available;
					output_synchronizer_state_next <= unread_input;
				else
					din_rd_en <= '0';
					dout_empty_notready_next <= '1';
					-- In general packet_available = '1' implies empty = '0',
					-- so stay consistent.
					dout_packet_available_next <= '0'; 
					output_synchronizer_state_next <= stale_input;
				end if;
			else -- dout_rd_en = '0'
				din_rd_en <= '0';
				-- Hold state constant
				dout_next <= dout_i;
				dout_empty_notready_next <= dout_empty_notready_i;
				-- Basically if the word that could be requested this cycle is
				-- a first-word-of-packet, and it isn't read, then it will still
				-- be a first-word-of-packet next cycle.
				dout_packet_available_next <= dout_packet_available_i; 
				dout_end_of_packet_next <= dout_end_of_packet_i;
				output_synchronizer_state_next <= output_synchronizer_state;
			end if;
		-- If the available input is stale (i.e. we have nothing new
		-- that can be output), wait until we get some new data.
		when stale_input =>
			dout_next <= dout_i;
			dout_end_of_packet_next <= dout_end_of_packet_i;
			-- Can we get fresh data?
			if din_empty_notready = '0' then
				din_rd_en <= '1';
				dout_empty_notready_next <= '0';
				-- If the word that arrives next cycle (and will be available for requestin
				-- next cycle) is a first-word-of-packet, then next cycle we should also
				-- announce it is a first-word-of-packet.
				dout_packet_available_next <= din_packet_available;
				output_synchronizer_state_next <= unread_input;
			-- Can't get fresh data? Keep waiting.
			else
				din_rd_en <= '0';
				dout_empty_notready_next <= '1';
				-- In general, packet_available = '1' implies empty = '0',
				-- so stay consistent.
				dout_packet_available_next <= '0';
				output_synchronizer_state_next <= stale_input;
			end if;
		end case;
	end process;

end Behavioral;					
