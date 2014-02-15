----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson, based on code by Hua Liu.
--
-- Create Date:    02/12/2014 
-- Design Name:
-- Module Name:    acquisition_module
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--     Takes two serial UART port inputs and produces a parallel output. The
-- output signals are meant to directly interface to a FIFO. There is no flow
-- control.
--     Code originates from the Acquisition module by Hua Liu, but has been
-- mostly revamped and had many pieces removed.
--     Presently this interfaces with two frontend boards (via two serial
-- ports), but will scale up to more in the future.
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


entity acquisition_module is
	port(
		reset       : in std_logic;
		boardid     : in std_logic_vector(2 downto 0);
		clk_50MHz   : in std_logic;
		-- Interface with Daisychain
		dout_wr_en  : out std_logic;
		dout        : out std_logic_vector(15 downto 0);
		-- Input from IOBs
		Rx0         : in std_logic;
		Rx1         : in std_logic
	);
end acquisition_module;

architecture Behavioral of acquisition_module is
	-- global
	signal reset_fifo      : std_logic;
	signal reset_fifo_vec  : std_logic_vector(3 downto 0);
	
	signal fifo_0_din_wr  : std_logic;
	signal fifo_0_din     : std_logic_vector(15 downto 0);
	signal fifo_0_rd_en   : std_logic;
	signal fifo_0_packet_available  : std_logic;
	signal fifo_0_empty_notready    : std_logic;
	signal fifo_0_dout    : std_logic_vector(15 downto 0);
	signal fifo_0_end_of_packet     : std_logic;

	signal fifo_1_din_wr  : std_logic;
	signal fifo_1_din     : std_logic_vector(15 downto 0);
	signal fifo_1_rd_en   : std_logic;
	signal fifo_1_packet_available  : std_logic;
	signal fifo_1_empty_notready    : std_logic;
	signal fifo_1_dout    : std_logic_vector(15 downto 0);
	signal fifo_1_end_of_packet     : std_logic;

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

	-- For the following signals, 0 indicates channel 0, 1 indictions channel 1
	signal router_highest_priority_source      : std_logic := '0'; 
	signal router_highest_priority_source_next : std_logic := '0'; 

	type   router_state_machine_state_type is (idle, transferring);
	signal router_state_machine_state      : router_state_machine_state_type := idle;
	signal router_state_machine_state_next : router_state_machine_state_type := idle;

	component deserializer is
		port(
			reset         : in std_logic;
			clk_50MHz     : in std_logic;
			boardid       : in std_logic_vector(2 downto 0);
			-- Interface, serial input, parallel output
			s_in          : in std_logic;
			p_out_wr      : out std_logic;
			p_out_data    : out std_logic_vector(15 downto 0)
		);
	end component;

	component packets_fifo_1024_16 is
		port (
			reset       : in std_logic;
			clk         : in std_logic;
			din_wr_en   : in std_logic;
			din         : in std_logic_vector(15 downto 0);
			dout_rd_en  : in std_logic;
			dout_packet_available : out std_logic; -- Goes to '1' before first word of packet is read, goes to '0' immediately afterwards.
			dout_empty_notready   : out std_logic; -- Indicates the user should not try and read (rd_en). May happen mid-packet! Always check this!
			dout        : out std_logic_vector(15 downto 0);
			dout_end_of_packet : out std_logic;
			bytes_received     : out std_logic_vector(63 downto 0) -- includes those that are thrown away to preempt buffer overflow
		);
	end component;

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

	-------------------------------------------------------------------------------
	-- FIFO Reset
	-- - Not sure why we do this, but gives a longer reset signal to the FIFOs. 
	--   I believe if a partial packet is recieved when coming out of reset, will
	--   be ignored. Only after the first valid start byte is recieved will any
	--   data pass.
	-------------------------------------------------------------------------------
	process ( reset, clk_50MHz)
	begin
		if ( reset = '1') then
			reset_fifo <= '1';
			reset_fifo_vec <= x"F";
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			reset_fifo_vec <= '0' & reset_fifo_vec(3 downto 1);
			reset_fifo <= reset_fifo_vec(0);
		end if;
	end process;


	--====================================================================
	--====================================================================
	-- Frontend Serial Reciever 0
	-- - Connect a deserializer to a packet FIFO. Router processes will
	--   milk this FIFO when it gets a chance.
	--====================================================================
	--====================================================================
	deserializer_0: deserializer
	port map (
		reset         => reset,
		clk_50MHz     => clk_50Mhz,
		boardid       => boardid,
		-- Interface, serial input, parallel output
		s_in          => Rx0,
		p_out_wr      => fifo_0_din_wr,
		p_out_data    => fifo_0_din
	);

	deserializer_0_fifo: packets_fifo_1024_16
	port map (
		reset       => reset_fifo,
		clk         => clk_50MHz,
		din_wr_en   => fifo_0_din_wr,
		din         => fifo_0_din,
		dout_rd_en  => fifo_0_rd_en,
		dout_packet_available => fifo_0_packet_available,
		dout_empty_notready   => fifo_0_empty_notready,
		dout        => fifo_0_dout,
		dout_end_of_packet => fifo_0_end_of_packet,
		bytes_received     => open
	);

	--====================================================================
	--====================================================================
	-- Frontend Serial Reciever 1
	-- - Connect a deserializer to a packet FIFO. Router processes will
	--   milk this FIFO when it gets a chance.
	--====================================================================
	--====================================================================
	deserializer_1: deserializer
	port map (
		reset         => reset,
		clk_50MHz     => clk_50Mhz,
		boardid       => boardid,
		-- Interface, serial input, parallel output
		s_in          => Rx0,
		p_out_wr      => fifo_1_din_wr,
		p_out_data    => fifo_1_din
	);

	deserializer_1_fifo: packets_fifo_1024_16
	port map (
		reset       => reset_fifo,
		clk         => clk_50MHz,
		din_wr_en   => fifo_1_din_wr,
		din         => fifo_1_din,
		dout_rd_en  => fifo_1_rd_en,
		dout_packet_available => fifo_1_packet_available,
		dout_empty_notready   => fifo_1_empty_notready,
		dout        => fifo_1_dout,
		dout_end_of_packet => fifo_1_end_of_packet,
		bytes_received     => open
	);


	--====================================================================
	--====================================================================
	-- Router:
	--     Data can flow from one and only one input channel to the
	--     output. This router hardware has 2 main parts:
	--      1) Input Switch - Basically acts like a complicated MUX to
	--         present multiple input fifo sources as a single interface.
	--      3) Routing Process - Looks at the available sources, chooses
	--         one, and then switches the desired input to the output
	--         and clocks the bytes through.
	--     This is a simplified version of the router that is (at the time
	--     of this writing) being used in the Daisychain_module.
	--====================================================================
	--====================================================================

	-- Input Switch:
	-- Hybrid synchronous/combinational mux system to provide a single
	-- interface to two different fifos
	input_switch_instance : input_fifo_switch
	port map (
		reset         => reset,
		clk           => clk_50MHz,
		-- control logic
		in_rd_en       => input_switch_rd_en,
		in_use_input_1 => input_switch_channel(1), -- channel 0
		in_use_input_2 => input_switch_channel(2), -- channel 1
		in_use_input_3 => '0',
		-- fifo interfaces
		fifo_dout_1    => fifo_0_dout,
		fifo_dout_2    => fifo_1_dout,
		fifo_dout_3    => x"0000",
		fifo_rd_en_1   => fifo_0_rd_en,
		fifo_rd_en_2   => fifo_1_rd_en,
		fifo_rd_en_3   => open,
		fifo_dout_empty_notready_1 => fifo_0_empty_notready,
		fifo_dout_empty_notready_2 => fifo_1_empty_notready,
		fifo_dout_empty_notready_3 => '0',
		fifo_dout_end_of_packet_1  => fifo_0_end_of_packet,
		fifo_dout_end_of_packet_2  => fifo_1_end_of_packet,
		fifo_dout_end_of_packet_3  => '0',
		-- output signals
		dout  => dout,
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
		'1' when fifo_0_packet_available = '1' and fifo_0_empty_notready = '0' else '0';
	channel_1_ready_immediately <=
		'1' when fifo_1_packet_available = '1' and fifo_1_empty_notready = '0' else '0';

	-- signal which, (of one or neither) recievers are ready based upon whether both
	--  a) there is data available AND
	--  b) it is this channels's turn in alternating priority, or the other channel is not ready, thus forfeits its turn.
	router_ok_receive_channel_0 <=
		'1' when (channel_0_ready_immediately = '1')
		         and ((router_highest_priority_source = '0') or (channel_1_ready_immediately = '0'))
		else '0';
	router_ok_receive_channel_1 <=
		'1' when channel_1_ready_immediately = '1'
		         and ((router_highest_priority_source = '1') or (channel_0_ready_immediately = '0'))
		else '0';

	-------------------------------------------------------------------------------
	-- Router State Machine
	-- - Looks for a channel thats ready, flips the input mux switch, then pulls
	--   data out of the channel and pushes it to the output port
	-------------------------------------------------------------------------------
	
	router_state_machine_flipflop_process: process(reset, clk_50MHz)
	begin
		if reset = '1' then
			router_state_machine_state <= idle;
			router_highest_priority_source <= '0';
		elsif clk_50MHz'event and clk_50MHz = '1' then
			router_state_machine_state <= router_state_machine_state_next;
			router_highest_priority_source <= router_highest_priority_source_next;
		end if;
	end process;


	router_state_machine_async_logic_process: process(
		router_state_machine_state,
		router_highest_priority_source,
		router_ok_receive_channel_0, router_ok_receive_channel_1,
		input_switch_dout_end_of_packet, input_switch_dout_empty_notready
	)
	begin
		-- By default, hold priority source constant for all states.
		-- Override this when actually sending from one of the sources.
		router_highest_priority_source_next <= router_highest_priority_source;

		case router_state_machine_state is
		when idle =>
			-- Always true in this state, as dout is not ready because
			-- input_switch_rd_en has not pulled out the first byte yet.
			dout_wr_en <= '0';

			-- It is time to transfer from channel 0
			if router_ok_receive_channel_0 = '1' then
				-- Update priority to channel_1 for next time after this.
				router_highest_priority_source_next <= '1';
				-- Start transfer
				input_switch_channel <= INPUT_CHANNEL_0;
				input_switch_rd_en <= '1';
				router_state_machine_state_next <= transferring;
			-- It is time to transfer from channel 1
			elsif router_ok_receive_channel_1 = '1' then
				-- Update priority to channel_1 for next time after this.
				router_highest_priority_source_next <= '0';
				-- Start transfer
				input_switch_channel <= INPUT_CHANNEL_1;
				input_switch_rd_en <= '1';
				router_state_machine_state_next <= transferring;
			-- No data to transmit.
			else
				input_switch_channel <= INPUT_CHANNEL_DONT_CHANGE;
				input_switch_rd_en <= '0';
				router_state_machine_state_next <= idle;
				router_highest_priority_source_next <= router_highest_priority_source;
			end if;

		-- In this state, keep sending packet bytes until the packet is done.
		when transferring =>
			input_switch_channel <= INPUT_CHANNEL_DONT_CHANGE;
			
			-- If the packet is done, finish up.
			if input_switch_dout_end_of_packet = '1' then
				input_switch_rd_en <= '0';
				dout_wr_en <= '1'; -- Send the output switch the final word.
				router_state_machine_state_next <= idle;
			-- If not at end of packet, clock more data if available.
			else
				-- If data isn't ready, hold state, don't ask for more, wait till later
				-- to write the output so we don't need to track that we have done that.
				if input_switch_dout_empty_notready = '1' then
					input_switch_rd_en <= '0';
					dout_wr_en <= '0';
				-- If data is ready, get it, send previous output.
				else
					input_switch_rd_en <= '1';
					dout_wr_en <= '1';
				end if;
				router_state_machine_state_next <= transferring;
			end if;
		end case;
	end process;

end Behavioral;

