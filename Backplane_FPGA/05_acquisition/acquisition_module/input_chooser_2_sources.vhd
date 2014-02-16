----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson, based on code by Hua Liu.
--
-- Create Date:    02/15/2014
-- Design Name:
-- Module Name:    input_chooser_2_sources
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


use work.sapet_packets.all;

entity input_chooser_2_sources is
	port (
		reset       : in std_logic;
		clk         : in std_logic;
		-- Input, Source Port 0
		din_0_rd_en  : out std_logic;
		din_0_packet_available : in std_logic; -- Goes to '1' before first word of packet is read, goes to '0' immediately afterwards.
		din_0_empty_notready   : in std_logic; -- Indicates the user should not try and read (rd_en). May happen mid-packet! Always check this!
		din_0        : in std_logic_vector(15 downto 0);
		din_0_end_of_packet : in std_logic;
		-- Input, Source Port 1
		din_1_rd_en  : out std_logic;
		din_1_packet_available : in std_logic; -- Goes to '1' before first word of packet is read, goes to '0' immediately afterwards.
		din_1_empty_notready   : in std_logic; -- Indicates the user should not try and read (rd_en). May happen mid-packet! Always check this!
		din_1        : in std_logic_vector(15 downto 0);
		din_1_end_of_packet : in std_logic;
		-- Output Port
		dout_rd_en  : in std_logic;
		dout_packet_available : out std_logic; -- Goes to '1' before first word of packet is read, goes to '0' immediately afterwards.
		dout_empty_notready   : out std_logic; -- Indicates the user should not try and read (rd_en). May happen mid-packet! Always check this!
		dout        : out std_logic_vector(15 downto 0);
		dout_end_of_packet : out std_logic
	);
end input_chooser_2_sources;

architecture Behavioral of input_chooser_2_sources is
	attribute keep : string;  
	attribute S: string;

	signal reset_i			: std_logic := '1';
	signal clk_i         : std_logic;

	-- Assign one of these to input_switch_channel to select a channel (immediately).
	constant INPUT_CHANNEL_DONT_CHANGE : std_logic_vector(3 downto 1) := "000";
	constant INPUT_CHANNEL_0           : std_logic_vector(3 downto 1) := "001";
	constant INPUT_CHANNEL_1           : std_logic_vector(3 downto 1) := "010";

	signal input_switch_rd_en   : std_logic := '0';
	signal input_switch_channel : std_logic_vector(3 downto 1) := INPUT_CHANNEL_DONT_CHANGE;
	signal input_switch_dout                : std_logic_vector(15 downto 0) := x"0000";
	signal input_switch_dout_empty_notready : std_logic := '0';
	signal input_switch_dout_end_of_packet  : std_logic := '0';

	signal channel_0_ready_immediately : std_logic := '0';
	signal channel_1_ready_immediately : std_logic := '0';

	signal router_ok_receive_channel_0 : std_logic := '0';
	signal router_ok_receive_channel_1 : std_logic := '0';

	signal input_chooser_highest_priority_source      : std_logic;
	signal input_chooser_highest_priority_source_next : std_logic;

	-- input-manager state machine states.
	type   input_chooser_state_type is ( wait_for_first_read, transferring);
	signal input_chooser_state      : input_chooser_state_type := wait_for_first_read;
	signal input_chooser_state_next : input_chooser_state_type := wait_for_first_read;

	signal output_end_word       : std_logic_vector(15 downto 0);
	signal output_end_word_next  : std_logic_vector(15 downto 0);

	component input_fifo_switch
	port (
		reset         : in std_logic;
		clk           : in std_logic;
		-- control logic
		in_rd_en      : in std_logic;
		in_use_input_1 : in std_logic; -- one-hot source selectors, act immediately
		in_use_input_2 : in std_logic;
		in_use_input_3 : in std_logic;
		-- fifo interfaces
		fifo_dout_1    : in std_logic_vector(15 downto 0);
		fifo_dout_2    : in std_logic_vector(15 downto 0);
		fifo_dout_3    : in std_logic_vector(15 downto 0);
		fifo_rd_en_1   : out std_logic;
		fifo_rd_en_2   : out std_logic;
		fifo_rd_en_3   : out std_logic;
		fifo_dout_empty_notready_1 : in std_logic;
		fifo_dout_empty_notready_2 : in std_logic;
		fifo_dout_empty_notready_3 : in std_logic;
		fifo_dout_end_of_packet_1  : in std_logic;
		fifo_dout_end_of_packet_2  : in std_logic;
		fifo_dout_end_of_packet_3  : in std_logic;
		-- output data
		dout  : out std_logic_vector(15 downto 0);
		dout_empty_notready   : out std_logic; -- Indicates the user should not try and read (rd_en). May happen mid-packet! Always check this!
		dout_end_of_packet    : out std_logic
	);
	end component;

begin
	-- pass through intermediate signals
	reset_i <= reset;
	clk_i <= clk;


	-- Input Switch:
	-- Hybrid synchronous/combinational mux system to provide a single
	-- interface to two different inputs. (It is a dumb interface,
	-- the input_chooser state machine picks which one to use.)
	input_switch_instance : input_fifo_switch
	port map (
		reset         => reset,
		clk           => clk,
		-- control logic
		in_rd_en       => input_switch_rd_en,
		in_use_input_1 => input_switch_channel(1), -- channel 0
		in_use_input_2 => input_switch_channel(2), -- channel 1
		in_use_input_3 => '0',
		-- fifo interfaces
		fifo_dout_1    => din_0,
		fifo_dout_2    => din_1,
		fifo_dout_3    => x"0000",
		fifo_rd_en_1   => din_0_rd_en,
		fifo_rd_en_2   => din_1_rd_en,
		fifo_rd_en_3   => open,
		fifo_dout_empty_notready_1 => din_0_empty_notready,
		fifo_dout_empty_notready_2 => din_1_empty_notready,
		fifo_dout_empty_notready_3 => '0',
		fifo_dout_end_of_packet_1  => din_0_end_of_packet,
		fifo_dout_end_of_packet_2  => din_1_end_of_packet,
		fifo_dout_end_of_packet_3  => '0',
		-- output signals
		dout  => input_switch_dout,
		dout_empty_notready  => input_switch_dout_empty_notready,
		dout_end_of_packet   => input_switch_dout_end_of_packet
	);


	-------------------------------------------------------------------------------
	-- Source Prioritization
	--  - Combinational logic to determine which sources (fifo_0 or fifo_1) to use
	--    for next packet routing, based upon priority and availibility.
	-------------------------------------------------------------------------------
	
	-- Condense the conditions for a fifo to be ready to read immediately into simpler signals. Note
	-- that checking empty_notready = '0' is currently redundant, but good practice.
	channel_0_ready_immediately <=
		'1' when din_0_packet_available = '1' and din_0_empty_notready = '0' else '0';
	channel_1_ready_immediately <=
		'1' when din_1_packet_available = '1' and din_1_empty_notready = '0' else '0';

	-- signal which, (of one or neither) recievers are ready based upon whether both
	--  a) there is data available AND
	--  b) it is this channels's turn in alternating priority, or the other channel is not ready, thus forfeits its turn.
	router_ok_receive_channel_0 <=
		'1' when (channel_0_ready_immediately = '1')
		         and ((input_chooser_highest_priority_source = '0') or (channel_1_ready_immediately = '0'))
		else '0';
	router_ok_receive_channel_1 <=
		'1' when channel_1_ready_immediately = '1'
		         and ((input_chooser_highest_priority_source = '1') or (channel_0_ready_immediately = '0'))
		else '0';


	--=============================================================================
	-- input chooser state machine
	--=============================================================================

	----------------------------------------------------------------------------
	-- State Machine FlipFlip Process
	-- - Updates pending state values on the clock edge
	----------------------------------------------------------------------------
	input_chooser_FSM_flipflop_process: process( clk_i, reset_i)
	begin
		if ( reset_i = '1') then
			input_chooser_state <= wait_for_first_read;
			input_chooser_highest_priority_source <= '0';
			output_end_word <= x"0000";
		elsif ( clk_i'event and clk_i = '1' ) then
			input_chooser_state <= input_chooser_state_next;
			input_chooser_highest_priority_source <= input_chooser_highest_priority_source_next;
			output_end_word <= output_end_word_next;
		end if;
	end process;

	----------------------------------------------------------------------------
	-- State Machine Asynchronous Logic
	-- - React to state changes and external logic.
	-- - Generally attempts to grab first word from underlying packet fifo,
	--   store it, and then present the source + destination as outputs and
	--   then act like a packet fifo until the whole packet is removed.
	----------------------------------------------------------------------------
	input_chooser_FSM_async_logic_process: process(
		dout_rd_en,
		input_chooser_state,
		output_end_word,
		router_ok_receive_channel_0, router_ok_receive_channel_1,
		input_switch_dout, input_switch_dout_empty_notready
	)
	begin
		-- default behaviors
		input_chooser_highest_priority_source_next <= input_chooser_highest_priority_source;
		output_end_word_next <= output_end_word;
		dout_end_of_packet <= '0';
		dout_packet_available <= '0';

		case input_chooser_state is
		-- First state notifies when there is a packet available.
		-- When a read signal is received it sets the input switch channel and
		-- enables that input's read signal, and then swaps the prioritization
		-- register to prioritize the other source next time.
		when wait_for_first_read =>
			dout <= output_end_word;
			dout_end_of_packet <= '1';
			-- check if there is data ready
			-- output signaling
			if router_ok_receive_channel_0 = '1' or router_ok_receive_channel_1 = '1' then
				dout_empty_notready <= '0';
				dout_packet_available <= '1';
			else 
				dout_empty_notready <= '1';
				dout_packet_available <= '0';
			end if;
			-- handle incoming read signal
			if dout_rd_en = '1' then
				input_switch_rd_en <= '1';
			
				if router_ok_receive_channel_0 = '1' then
					-- Update priority to channel_1 for next time after this.
					input_chooser_highest_priority_source_next <= '1';
					-- Start transfer
					input_switch_channel <= INPUT_CHANNEL_0;
					input_switch_rd_en <= '1';
					input_chooser_state_next <= transferring;
				-- It is time to transfer from channel 1
				elsif router_ok_receive_channel_1 = '1' then
					-- Update priority to channel_1 for next time after this.
					input_chooser_highest_priority_source_next <= '0';
					-- Start transfer
					input_switch_channel <= INPUT_CHANNEL_1;
					input_switch_rd_en <= '1';
					input_chooser_state_next <= transferring;
				-- No data to transmit.
				else
					input_switch_channel <= INPUT_CHANNEL_DONT_CHANGE;
					input_switch_rd_en <= '0';
					input_chooser_state_next <= wait_for_first_read;
				end if;
			-- handle lack of read signal
			else
				input_switch_rd_en <= '0';
				input_chooser_state_next <= wait_for_first_read;
			end if;

		-- Handle transfer until the packet is done.
		when transferring =>
			dout <= input_switch_dout;
			if word_contains_packet_end_token(input_switch_dout) then
				-- If end of packet, hold the last packet outputs and immediately
				-- attempt to find the next packet to output.
				-- Note that this causes a 1 cycle gap in transmissions between packets,
				-- this could probably be coded out, was originally put in to allow
				-- state machines with a delay to over-run the output by 1 cycle.
				dout_end_of_packet <= '1';
				dout_empty_notready <= '1';
				output_end_word_next <= input_switch_dout; -- we will hold this word while a new word comes in
				input_switch_rd_en <= '0';
				input_chooser_state_next <= wait_for_first_read;
			else
				-- keep reading
				dout_end_of_packet <= '0';
				dout_empty_notready <= input_switch_dout_empty_notready;
				input_switch_rd_en <= dout_rd_en; -- trusting the user to obey dout_empty_notready!
				input_chooser_state_next <= transferring;
			end if;

		when others =>
			-- Neutralize everything
			-- - state machine
			input_chooser_state_next <= wait_for_first_read;
			output_end_word_next <= x"0000";
			-- - sources
			input_switch_channel <= INPUT_CHANNEL_0; -- anything valid
			input_switch_rd_en <= '0';
			-- - output
			dout <= x"0000";
			dout_packet_available <= '0';
			dout_end_of_packet <= '1'; -- Attempt to get any readers to stop reading.
			dout_empty_notready <= '1';
		end case;
	end process;

end Behavioral;					
