----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson, based on code by Hua Liu.
-- 
-- Create Date:    01/11/2014 
-- Design Name: 
-- Module Name:    Daisychain_module - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--     This file accepts input packet data from various sources into packet fifos,
--     and then routes data from these FIFOs to the correct output port based
--     upon the packet's source and destination fields.
--
--     This file replaces the version by Hua Liu, which operated very much the
--     same, but very much differently. This version is much more structural
--     and heirarchical in nature, and should be easier to decipher what it does.
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
use ieee.std_logic_unsigned.all; -- used for comparison of adress ranges

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

entity Daisychain_module is
	port (
		acquisition_data_receive_data_number : out std_logic_vector(15 downto 0);
		bug_out_put_from_Acquisition_to_Daisychain			: out std_logic;
		reset				: in std_logic;
		clk_50MHz				: in std_logic;
		boardid				: in std_logic_vector(2 downto 0);

		-- data receiving from GTP interface
		din_from_GTP			: in std_logic_vector(15 downto 0);
		din_from_GTP_wr			: in std_logic;
		-- to send the config data and acquisition data to GTP interface for transfer
		dout_to_GTP			: out std_logic_vector(15 downto 0);
		dout_to_GTP_wr			: out std_logic;
		is_GTP_ready			: in std_logic; -- todo fixme: use this!
		-- data to UDP interface
		dout_to_UDP			: out std_logic_vector(15 downto 0);
		dout_to_UDP_wr			: out std_logic;
		-- config_data_from_UDP_to_GTP
		config_data_from_UDP_to_GTP	: in std_logic_vector(15 downto 0);
		config_data_from_UDP_to_GTP_wr	: in std_logic;
		-- acquisition_data_from_local_to_GTP
		din_from_acquisition_wr            : in std_logic;
		din_from_acquisition               : in std_logic_vector(15 downto 0);
		-- current board configing data
		dout_to_serializing_wr		: out std_logic;
		dout_to_serializing		: out std_logic_vector(15 downto 0)
     );
end Daisychain_module;

architecture Behavioral of Daisychain_module is
	attribute keep : string;  
	attribute S: string;

	signal formal_word			: std_logic_vector(15 downto 0);
	signal acquisition_data_receive_data_number_i : std_logic_vector(63 downto 0);
	signal bug_bit				: std_logic_vector( 1 downto 0);
	-- global signals
	signal reset_fifo			: std_logic := '1';
	signal reset_fifo_vec			: std_logic_vector(3 downto 0) := "1111";
	-- config data related variables
	signal config_data_from_UDP_to_GTP_wr_i : std_logic := '0';
	signal config_data_from_UDP_to_GTP_i    : std_logic_vector(15 downto 0) := x"0000";
	signal config_data_fifo_dout_source_node      : std_logic_vector(2 downto 0) := "000";
	signal config_data_fifo_dout_destination_node : std_logic_vector(2 downto 0) := "000";
	signal config_data_fifo_dout_rd_en            : std_logic := '0';
	signal config_data_fifo_dout_packet_available : std_logic := '0';
	signal config_data_fifo_dout_empty_notready   : std_logic := '0';
	signal config_data_fifo_dout                  : std_logic_vector(15 downto 0) := x"0000";
	signal config_data_fifo_dout_end_of_packet    : std_logic := '0';

	-- GTP transmitter related variables
	signal din_from_GTP_wr_i : std_logic := '0';
	signal din_from_GTP_i    : std_logic_vector(15 downto 0) := x"0000";
	signal J40_data_fifo_dout_source_node      : std_logic_vector(2 downto 0) := "000";
	signal J40_data_fifo_dout_destination_node : std_logic_vector(2 downto 0) := "000";
	signal J40_data_fifo_dout_rd_en            : std_logic := '0';
	signal J40_data_fifo_dout_packet_available : std_logic := '0';
	signal J40_data_fifo_dout_empty_notready   : std_logic := '0';
	signal J40_data_fifo_dout                  : std_logic_vector(15 downto 0) := x"0000";
	signal J40_data_fifo_dout_end_of_packet    : std_logic := '0';

	signal gtpj40_packet_ready_immediately : std_logic := '0';

	-- local acquisition fifo
	signal din_from_acquisition_wr_i : std_logic := '0';
	signal din_from_acquisition_i    : std_logic_vector(15 downto 0) := x"0000";
	signal local_acquisition_data_fifo_dout_source_node      : std_logic_vector(2 downto 0) := "000";
	signal local_acquisition_data_fifo_dout_destination_node : std_logic_vector(2 downto 0) := "000";
	signal local_acquisition_data_fifo_dout_rd_en            : std_logic := '0';
	signal local_acquisition_data_fifo_dout_packet_available : std_logic := '0';
	signal local_acquisition_data_fifo_dout_empty_notready   : std_logic := '0';
	signal local_acquisition_data_fifo_dout                  : std_logic_vector(15 downto 0);
	signal local_acquisition_data_fifo_dout_end_of_packet    : std_logic := '0';

	signal acquisition_packet_ready_immediately : std_logic := '0';
	
	-- Assign one of these to input_switch_channel to select a channel (immediately).
	constant INPUT_CHANNEL_DONT_CHANGE : std_logic_vector(3 downto 1) := "000";
	constant INPUT_CHANNEL_UDP         : std_logic_vector(3 downto 1) := "001";
	constant INPUT_CHANNEL_GTPJ40      : std_logic_vector(3 downto 1) := "010";
	constant INPUT_CHANNEL_ACQUISITION  : std_logic_vector(3 downto 1) := "100";

	-- OR these masks to output_switch_channels_mask to add a channel to the enabled list.
	-- (Takes effect when the switch's set_channels signal is pulsed).
	constant OUTPUT_MASK_NOWHERE    : std_logic_vector(3 downto 1) := "000";
	constant OUTPUT_MASK_UDP        : std_logic_vector(3 downto 1) := "001";
	constant OUTPUT_MASK_GTPJ41     : std_logic_vector(3 downto 1) := "010";
	constant OUTPUT_MASK_SERIALIZER : std_logic_vector(3 downto 1) := "100";

	signal input_switch_rd_en   : std_logic := '0';
	signal input_switch_channel : std_logic_vector(3 downto 1) := INPUT_CHANNEL_DONT_CHANGE;
	signal input_switch_dout                : std_logic_vector(15 downto 0) := x"0000";
	signal input_switch_dout_empty_notready : std_logic := '0';
	signal input_switch_dout_end_of_packet  : std_logic := '0';
	
	signal output_switch_channels_mask : std_logic_vector(3 downto 1) := OUTPUT_MASK_NOWHERE;
	signal output_switch_set_channels  : std_logic := '0';
	signal output_switch_wr_en         : std_logic := '0';

	signal output_J41_is_echo          : std_logic := '0';
	signal output_J41_is_echo_next     : std_logic := '0';
	
	-- Signals going from the router to the echo_shaper, before heading out to
	-- the GTP port.
	signal dout_to_GTP_pre_echo_shaper         : std_logic_vector(15 downto 0) := x"0000";
	signal dout_to_GTP_wr_pre_echo_shaper      : std_logic := '0';
	signal dout_to_GTP_post_echo_shaper        : std_logic_vector(15 downto 0) := x"0000";
	signal dout_to_GTP_wr_post_echo_shaper     : std_logic := '0';

	type   router_state_machine_state_type is (idle, transferring);
	signal router_state_machine_state      : router_state_machine_state_type := idle;
	signal router_state_machine_state_next : router_state_machine_state_type := idle;

	-- The following signals are used to assign alternating priority between bottom tier sources.
	-- (the UDP input is always highest tier, it gets top priority always).
	type   bottom_tier_priority_source is (gtpj40, acquisition);
	signal router_bottom_tier_highest_priority_source      : bottom_tier_priority_source := gtpj40; 
	signal router_bottom_tier_highest_priority_source_next : bottom_tier_priority_source := gtpj40; 
	signal router_ok_receive_gtpj40      : std_logic := '0';
	signal router_ok_receive_acquisition : std_logic := '0';
	
	component smart_packets_fifo_1024_16
		port (
			reset       : in std_logic;
			clk         : in std_logic;
			din_wr_en   : in std_logic;
			din         : in std_logic_vector(15 downto 0);
			dout_source_node      : out std_logic_vector(2 downto 0); -- 0 to 4, valid from start up through word before end-word
			dout_destination_node : out std_logic_vector(2 downto 0); -- 0 to 4
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

	component output_fifo_switch
	port (
		reset         : in std_logic;
		clk           : in std_logic;
		-- control logic
		en_ch_1 : in std_logic; -- one-hot source selectors, act immediately
		en_ch_2 : in std_logic;
		en_ch_3 : in std_logic;
		set_channels : in std_logic;
		-- input signal
		in_wr_en      : in std_logic;
		-- output signal
		out_wr_en_1    : out std_logic;
		out_wr_en_2    : out std_logic;
		out_wr_en_3    : out std_logic
	);
	end component;

	component packet_source_destination_swapper is
	port (
		reset   : in  std_logic;
		clk     : in  std_logic;
		din     : in  std_logic_vector(15 downto 0);
		din_wr  : in  std_logic;
		swap_en : in  std_logic;
		dout    : out std_logic_vector(15 downto 0);
		dout_wr : out std_logic
	);	
	end component;	
	
begin
	config_data_from_UDP_to_GTP_wr_i <= config_data_from_UDP_to_GTP_wr;
	config_data_from_UDP_to_GTP_i <= config_data_from_UDP_to_GTP;


	acquisition_data_receive_data_number <= acquisition_data_receive_data_number_i(15 downto 0);
	---------------------------------------------------------------------
	-- Generate FIFO reset signal
	---------------------------------------------------------------------
	process ( clk_50MHz, reset)
	begin
		if ( reset = '1') then
			reset_fifo <= '1';
			reset_fifo_vec <= x"F";
		elsif (clk_50MHz 'event and clk_50MHz = '1') then
			reset_fifo_vec <= '0' & reset_fifo_vec(3 downto 1);
			reset_fifo <= reset_fifo_vec(0);
		end if;
	end process;

	--====================================================================
	--====================================================================
	-- Configure Data: Data from the PC, going out to the various nodes.
	--====================================================================
	--====================================================================

	fromUDP_packet_fifo : smart_packets_fifo_1024_16
	port map (
		reset       => reset_fifo,
		clk         => clk_50MHz,
		din_wr_en   => config_data_from_UDP_to_GTP_wr_i,
		din         => config_data_from_UDP_to_GTP_i,
		dout_source_node      => config_data_fifo_dout_source_node,
		dout_destination_node => config_data_fifo_dout_destination_node,
		dout_rd_en            => config_data_fifo_dout_rd_en,
		dout_packet_available => config_data_fifo_dout_packet_available,
		dout_empty_notready   => config_data_fifo_dout_empty_notready,
		dout                  => config_data_fifo_dout,
		dout_end_of_packet    => config_data_fifo_dout_end_of_packet,
		bytes_received  => open
	);


	--====================================================================
	--====================================================================
	-- Local Acquisition: Gathers packets from RENA Front End Boards attached
	--     directly to this node.
	--====================================================================
	--====================================================================

	din_from_acquisition_i <= din_from_acquisition;
	din_from_acquisition_wr_i <= din_from_acquisition_wr;

	fromAquisition_packet_fifo : smart_packets_fifo_1024_16
	port map (
		reset       => reset_fifo,
		clk         => clk_50MHz,
		din_wr_en   => din_from_acquisition_wr_i,
		din         => din_from_acquisition_i,
		dout_source_node      => local_acquisition_data_fifo_dout_source_node,
		dout_destination_node => local_acquisition_data_fifo_dout_destination_node,
		dout_rd_en            => local_acquisition_data_fifo_dout_rd_en,
		dout_packet_available => local_acquisition_data_fifo_dout_packet_available,
		dout_empty_notready   => local_acquisition_data_fifo_dout_empty_notready,
		dout                  => local_acquisition_data_fifo_dout,
		dout_end_of_packet    => local_acquisition_data_fifo_dout_end_of_packet,
		bytes_received  => acquisition_data_receive_data_number_i -- diagnostic??
	);


	--====================================================================
	--====================================================================
	-- GTP J40: Gathers packets from other nodes (Backend Boards) via
	--     the SATA cable connection.
	--====================================================================
	--====================================================================

	din_from_GTP_wr_i <= din_from_GTP_wr;
	din_from_GTP_i <= din_from_GTP;

	fromGTPJ40_packet_fifo : smart_packets_fifo_1024_16
	port map (
		reset       => reset_fifo,
		clk         => clk_50MHz,
		din_wr_en   => din_from_GTP_wr_i,	
		din         => din_from_GTP_i,
		dout_source_node      => J40_data_fifo_dout_source_node,
		dout_destination_node => J40_data_fifo_dout_destination_node,
		dout_rd_en            => J40_data_fifo_dout_rd_en,
		dout_packet_available => J40_data_fifo_dout_packet_available,
		dout_empty_notready   => J40_data_fifo_dout_empty_notready,
		dout                  => J40_data_fifo_dout,
		dout_end_of_packet    => J40_data_fifo_dout_end_of_packet,
		bytes_received  => open
	);


	--====================================================================
	--====================================================================
	-- Bug Find Process: looks for a certain bug condition.
	--   Todo: more description
	--====================================================================
	--====================================================================
	bug_find_process : process ( reset, clk_50MHz)
	begin
		if ( reset = '1') then
			bug_out_put_from_Acquisition_to_Daisychain <= '0';
			formal_word <= x"FF00";
			bug_bit <= "00";
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			case bug_bit is
				when "00" =>
					if ( din_from_acquisition_wr = '0') then
						formal_word <= formal_word;
						bug_bit <= "00";
						bug_out_put_from_Acquisition_to_Daisychain <= '0';
					elsif (din_from_acquisition_wr = '1') then
						if ((din_from_acquisition = x"0000")) then
							bug_bit <= "01";
						else
							bug_bit <= "00";
						end if;
						bug_out_put_from_Acquisition_to_Daisychain <= '0';
					end if;
				when "01" =>
					if ( din_from_acquisition_wr = '0') then
						bug_bit <= "01";
					elsif ( din_from_acquisition_wr = '1') then
						if ( din_from_acquisition = x"0000") then
							bug_bit <= "10";
						else
							bug_bit <= "00";
						end if;
					end if;
					bug_out_put_from_Acquisition_to_Daisychain <= '0';
				when "10" =>
					if ( din_from_acquisition_wr = '0') then
						bug_bit <= "10";
					elsif ( din_from_acquisition_wr = '1') then
						if ( din_from_acquisition = x"0000") then
							bug_bit <= "11";
						else
							bug_bit <= "00";
						end if;
					end if;
					bug_out_put_from_Acquisition_to_Daisychain <= '0';
				when "11" =>
					if ( din_from_acquisition_wr = '0') then
						bug_bit <= "11";
						bug_out_put_from_Acquisition_to_Daisychain <= '0';
					elsif ( din_from_acquisition_wr = '1') then
						if ( din_from_acquisition = x"0000") then
							bug_bit <= "00";
							bug_out_put_from_Acquisition_to_Daisychain <= '1';
						else
							bug_bit <= "00";
							bug_out_put_from_Acquisition_to_Daisychain <= '0';
						end if;
					end if;
				when others =>
					null;
			end case;
		end if;
	end process;


	--=============================================================================
	-- Echo Shaper
	-- - Packets travel through this on the way to the GTPJ41, and if the
	--   swap_en signal is set, the source and destination bytes are swapped.
	--   Thus, if the router process is producing a configuration data echo
	--   packet, it should enable the swap_en. Otherwise, it acts as a one
	--   cycle delay.
	--=============================================================================
	dout_to_GTP    <= dout_to_GTP_post_echo_shaper;
	dout_to_GTP_wr <= dout_to_GTP_wr_post_echo_shaper;

	echo_shaper : packet_source_destination_swapper port map(
		reset       => reset,
		clk         => clk_50MHz,
		din         => dout_to_GTP_pre_echo_shaper,
		din_wr      => dout_to_GTP_wr_pre_echo_shaper,
		swap_en     => output_J41_is_echo,
		dout        => dout_to_GTP_post_echo_shaper,
		dout_wr     => dout_to_GTP_wr_post_echo_shaper
	);

	--====================================================================
	--====================================================================
	-- Router:
	--     Data can flow from one and only one input port to one or
	--     more outputs (i.e. when echoing back configuration data).
	--     This router hardware has 3 main parts:
	--      1) Input Switch - Basically acts like a complicated MUX to
	--         present multiple input fifo sources as a single interface.
	--      2) Output Switch - Basically a demux, although it can forward
	--         the data to multiple outputs.
	--      3) Routing Process - Looks at the available sources, chooses
	--         one, and then switches the desired input to the desired
	--         outputs and clocks the bytes through.
	--====================================================================
	--====================================================================

	----------------------------------------------------------------------
	-- Input Switch
	--  - Easily control 3 input FIFOs from one simple interface.
	----------------------------------------------------------------------

	input_switch_instance : input_fifo_switch
	port map (
		reset         => reset,
		clk           => clk_50MHz,
		-- control logic
		in_rd_en       => input_switch_rd_en,
		in_use_input_1 => input_switch_channel(1), -- assign INPUT_CHANNEL_UDP
		in_use_input_2 => input_switch_channel(2), -- assign INPUT_CHANNEL_GTPJ40
		in_use_input_3 => input_switch_channel(3), -- assign INPUT_CHANNEL_AQUISITION
		-- fifo interfaces
		fifo_dout_1    =>            config_data_fifo_dout,
		fifo_dout_2    =>               J40_data_fifo_dout,
		fifo_dout_3    => local_acquisition_data_fifo_dout,
		fifo_rd_en_1   =>            config_data_fifo_dout_rd_en,
		fifo_rd_en_2   =>               J40_data_fifo_dout_rd_en,
		fifo_rd_en_3   => local_acquisition_data_fifo_dout_rd_en,
		fifo_dout_empty_notready_1 =>            config_data_fifo_dout_empty_notready,
		fifo_dout_empty_notready_2 =>               J40_data_fifo_dout_empty_notready,
		fifo_dout_empty_notready_3 => local_acquisition_data_fifo_dout_empty_notready,
		fifo_dout_end_of_packet_1  =>            config_data_fifo_dout_end_of_packet,
		fifo_dout_end_of_packet_2  =>               J40_data_fifo_dout_end_of_packet,
		fifo_dout_end_of_packet_3  => local_acquisition_data_fifo_dout_end_of_packet,
		-- output signals
		dout  => input_switch_dout,
		dout_empty_notready  => input_switch_dout_empty_notready,
		dout_end_of_packet   => input_switch_dout_end_of_packet

	);

	-------------------------------------------------------------------------------
	-- Output switching
	--  - Connects the wr_en signal for one or more output sources, like a demux.
	-------------------------------------------------------------------------------

	-- Connect the input switch data output to every output port.
	-- (Do the output routing using only the wr_en signals.)
	dout_to_UDP                  <= input_switch_dout;
	dout_to_GTP_pre_echo_shaper  <= input_switch_dout;
	dout_to_serializing          <= input_switch_dout;

	-- Output switch
	output_switch_instance : output_fifo_switch
	port map (
		reset   => reset,
		clk     => clk_50MHz,
		-- control logic
		en_ch_1 => output_switch_channels_mask(1), -- apply mask OUTPUT_MASK_UDP
		en_ch_2 => output_switch_channels_mask(2), -- apply mask OUTPUT_MASK_GTPJ41
		en_ch_3 => output_switch_channels_mask(3), -- apply mask OUTPUT_MASK_SERIALIZER
		set_channels => output_switch_set_channels,
		-- input signal
		in_wr_en     => output_switch_wr_en,
		-- output signal
		out_wr_en_1  => dout_to_UDP_wr,
		out_wr_en_2  => dout_to_GTP_wr_pre_echo_shaper,
		out_wr_en_3  => dout_to_serializing_wr
	);


	-------------------------------------------------------------------------------
	-- Low-Tier Source Prioritization
	--  - Combinational logic to determine which low-tier packet source (gtpj40 or aquisition) to use,
	--    based upon priority and availibility.
	-------------------------------------------------------------------------------
	
	-- Condense the conditions for a fifo to be ready to read immediately into simpler signals. Note
	-- that checking empty_notready = '0' is currently redundant, but good practice.
	gtpj40_packet_ready_immediately <=
		'1' when J40_data_fifo_dout_packet_available = '1' and J40_data_fifo_dout_empty_notready = '0' else '0';
	acquisition_packet_ready_immediately <=
		'1' when local_acquisition_data_fifo_dout_packet_available = '1' and local_acquisition_data_fifo_dout_empty_notready = '0' else '0';

	-- signal which, (of one or neither) recievers are ready based upon whether both
	--  a) there is data available AND
	--  b) it is this receiver's turn in alternating priority, or the other receiver is not ready, thus forfeits its turn.
	router_ok_receive_gtpj40 <=
		'1' when (gtpj40_packet_ready_immediately = '1')
		         and ((router_bottom_tier_highest_priority_source = gtpj40) or (acquisition_packet_ready_immediately = '0'))
		else '0';
	router_ok_receive_acquisition <=
		'1' when acquisition_packet_ready_immediately = '1'
		         and (router_bottom_tier_highest_priority_source = acquisition or gtpj40_packet_ready_immediately = '0')
		else '0';

	-------------------------------------------------------------------------------
	-- Router State Machine
	-- - Looks at the input FIFOs, figures out when to route data from which
	--   input fifo to which output.
	-------------------------------------------------------------------------------

	router_state_machine_flipflop_process: process(reset, clk_50MHz)
	begin
		if reset = '1' then
			router_state_machine_state <= idle;
			output_J41_is_echo <= '0';
			router_bottom_tier_highest_priority_source <= gtpj40;
		elsif clk_50MHz'event and clk_50MHz = '1' then
			router_state_machine_state <= router_state_machine_state_next;
			output_J41_is_echo <= output_J41_is_echo_next;
			router_bottom_tier_highest_priority_source <= router_bottom_tier_highest_priority_source_next;
		end if;
	end process;


	router_state_machine_async_logic_process: process(
		boardid,
		router_state_machine_state,
		config_data_fifo_dout_packet_available, config_data_fifo_dout_empty_notready,
		router_bottom_tier_highest_priority_source,
		router_ok_receive_gtpj40, router_ok_receive_acquisition,
		J40_data_fifo_dout_source_node, J40_data_fifo_dout_destination_node,
		local_acquisition_data_fifo_dout_source_node, local_acquisition_data_fifo_dout_destination_node,
		input_switch_dout_end_of_packet, input_switch_dout_empty_notready,
		output_J41_is_echo
	)
	begin
		-- By default, hold bottom-tier priority source constant for all states.
		-- Override this when actually sending from one of the bottom-tier sources.
		router_bottom_tier_highest_priority_source_next <= router_bottom_tier_highest_priority_source;

		case router_state_machine_state is
		when idle =>
			-- Always true in this state, as input_switch_dout is not ready because
			-- input_switch_rd_en has not pulled out the first byte yet.
			output_switch_wr_en <= '0';  

			-- UDP configuration data - highest priority to be transmitted
			if config_data_fifo_dout_packet_available = '1' and config_data_fifo_dout_empty_notready = '0' then

				-- Transmit down the GTP, even if node 1 is destination. This keeps code simpler (1 case).
				-- Don't need to setup an echo source/destination byte swapper to respond back to UDP if node 1 is destination.
				input_switch_channel <= INPUT_CHANNEL_UDP;
				input_switch_rd_en <= '1';
				output_switch_channels_mask <= OUTPUT_MASK_GTPJ41;
				output_switch_set_channels <= '1';
				output_J41_is_echo_next <= '0';
				router_state_machine_state_next <= transferring;

			-- Data from the former Virtex-5 board on J40 input - shares priority with data from
			-- the local acquistion module.
			elsif router_ok_receive_gtpj40 = '1' then
			
				-- Update bottom-tier priority to acquisition, since gtpj40 is getting handled this time.
				router_bottom_tier_highest_priority_source_next <= acquisition;

				-- GTPJ40 Input is available, so we will for sure read it (even if to just delete it).
				input_switch_channel <= INPUT_CHANNEL_GTPJ40;
				input_switch_rd_en <= '1';
				-- Specific output channels chosen below, but source will always be set (even if to NOWHERE).
				output_switch_set_channels <= '1';
				-- Transfer will happen.
				router_state_machine_state_next <= transferring;
				
				-- Default values (overriden if needed):
				output_J41_is_echo_next <= '0';

				-- If from PC
				if ( J40_data_fifo_dout_source_node = x"0") then
					-- Check node is valid, otherwise garbage.
					if ('0' & J40_data_fifo_dout_destination_node >= x"1" and '0' & J40_data_fifo_dout_destination_node <= x"04" ) then
						-- If this is the destination node, send to serializing port
						if ( J40_data_fifo_dout_destination_node = boardid ) then
							-- Send this data out to serializing
							-- Echo back the config data to the computer, via GTP (regardless of
							-- what node this is, for simplicity, the circular chain will handle it).
							output_switch_channels_mask <= OUTPUT_MASK_GTPJ41 or OUTPUT_MASK_SERIALIZER;
							output_J41_is_echo_next <= '1';
						-- If the destination is another node (not THIS node).
						else
							-- If data from the PC has tranversed all the nodes back to node 001, discard it. It is done.
							-- Note this occurs after the check to see if this packet is destined for this board. This is important
							-- because configuration data from the PC intended for boardid="001" actually traverses the whole loop,
							-- so that a special case doesn't have to be writen to route from the UDP output to the serializing.
							if ( boardid = "001") then 
								output_switch_channels_mask <= OUTPUT_MASK_NOWHERE;
							-- If this packet truly needs to go to another node, then pass to the next node.
							else
								output_switch_channels_mask <= OUTPUT_MASK_GTPJ41;
							end if;
						end if;
					-- Invalid destination (source is PC). Dump the packet, it's an error.
					else
						output_switch_channels_mask <= OUTPUT_MASK_NOWHERE; -- send it nowhere
					end if;

				-- Source is a node
				elsif '0' & J40_data_fifo_dout_source_node >= x"1" and '0' & J40_data_fifo_dout_source_node <= x"4" then
					-- Destination is the PC, as it should be.
					if '0' & J40_data_fifo_dout_destination_node = x"0" then
					-- acquisition data (or any data from a node to PC)
						-- Master node sends via UDP to PC
						if boardid = "001" then
							output_switch_channels_mask <= OUTPUT_MASK_UDP;
						-- Non-Master nodes pass to adjacent nodes.
						else
							output_switch_channels_mask <= OUTPUT_MASK_GTPJ41;
						end if;
					-- If source is node, and destination is not the PC, dump the packet. It is an error.
					else
						output_switch_channels_mask <= OUTPUT_MASK_NOWHERE;
					end if;
				-- Invalid source, dump packet.
				else
					output_switch_channels_mask <= OUTPUT_MASK_NOWHERE;
				end if;		

			-- Data from a local RENA frontend board, via the acquisition module - shares priority with data from
			-- the previous backplane node via GTP40.
			elsif router_ok_receive_acquisition = '1' then

				-- Update bottom-tier priority to gtpj40, since aquisition is getting handled this time.
				router_bottom_tier_highest_priority_source_next <= gtpj40;

				-- Available, so we will for sure read it (even if to just delete it).
				input_switch_channel <= INPUT_CHANNEL_ACQUISITION;
				input_switch_rd_en <= '1';
				-- Specific output channels chosen below, but source will always be set (even if to NOWHERE).
				output_switch_set_channels <= '1';
				-- This data is never echoed.
				output_J41_is_echo_next <= '0';
				-- Transfer will happen.
				router_state_machine_state_next <= transferring;

				-- The only valid source/destination for the local_acquisition is from this node to the PC.
				if local_acquisition_data_fifo_dout_source_node = boardid and '0' & local_acquisition_data_fifo_dout_destination_node = x"0" then
					-- If this is node 1, sent it via UDP
					if boardid = "001" then
						output_switch_channels_mask <= OUTPUT_MASK_UDP;
					else
						output_switch_channels_mask <= OUTPUT_MASK_GTPJ41;
					end if;
				else
					output_switch_channels_mask <= OUTPUT_MASK_NOWHERE;
				end if;

			-- No data to transmit.
			else
				input_switch_channel <= INPUT_CHANNEL_DONT_CHANGE;
				input_switch_rd_en <= '0';
				output_switch_channels_mask <= OUTPUT_MASK_NOWHERE;
				output_switch_set_channels <= '0';
				output_J41_is_echo_next <= '0';
				router_state_machine_state_next <= idle;
				router_bottom_tier_highest_priority_source_next <= gtpj40; -- Doesn't matter which.
			end if;

		-- In this state, keep sending packet bytes until the packet is done.
		when transferring =>
			
			input_switch_channel <= INPUT_CHANNEL_DONT_CHANGE;
			output_switch_channels_mask <= OUTPUT_MASK_NOWHERE; -- ignored
			output_switch_set_channels <= '0';
			output_J41_is_echo_next <= output_J41_is_echo;
			
			-- If the packet is done, finish up.
			if input_switch_dout_end_of_packet = '1' then
				input_switch_rd_en <= '0';
				output_switch_wr_en <= '1'; -- Send the output switch the final word.
				router_state_machine_state_next <= idle;
			-- If not at end of packet, clock more data if available.
			else
				-- If data isn't ready, hold state, don't ask for more, wait till later
				-- to write the output so we don't need to track that we have done that.
				if input_switch_dout_empty_notready = '1' then
					input_switch_rd_en <= '0';
					output_switch_wr_en <= '0';
				-- If data is ready, get it, send previous output.
				else
					input_switch_rd_en <= '1';
					output_switch_wr_en <= '1';
				end if;
				router_state_machine_state_next <= transferring;
			end if;
		end case;
	
	end process;
end Behavioral;
