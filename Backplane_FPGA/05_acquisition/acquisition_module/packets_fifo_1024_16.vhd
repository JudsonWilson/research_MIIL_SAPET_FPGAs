----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson, based on code by Hua Liu.
--
-- Create Date:    01/20/2014 
-- Design Name:
-- Module Name:    packets_fifo_1024_16
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--     Wraps the fifo_1024_16_counter component with control logic that
-- ensures packets enter and leave as a complete packet.
--
--     Wraps a fifo with logic that allows only full packets to enter/exit
-- (almost) gaplessly. This is done using the following methods:
--     a) Packets are only placed in the fifo if, at the first byte, there
--        is enough room for a complete packet. Otherwise the packet is
--        effectively erased. This prevents a partial packet from getting
--        in and the buffer overflowing.
--     b) The output is only signaled as ready if there is at least one
--        full packet inside. Note that there could be SMALL necessary
--        gaps in reading the output if the input was fed with gaps
--        and the data has yet to fully propogate the FIFO.
-- This code is a stripped down version of smart_packets_fifo_1024_16.
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
use ieee.numeric_std.ALL;

use work.sapet_packets.all;

entity packets_fifo_1024_16 is
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
end packets_fifo_1024_16;

architecture Behavioral of packets_fifo_1024_16 is
	attribute keep : string;  
	attribute S: string;

	signal reset_i			: std_logic := '1';
	signal clk_i         : std_logic;
	signal din_wr_en_i   : std_logic;
	signal din_i         : std_logic_vector(15 downto 0);
	signal bytes_received_i     : std_logic_vector(63 downto 0); -- includes those that are thrown away to preempt buffer overflow

	-- word-fifo signals
	signal word_fifo_wr_en       : std_logic;
	signal word_fifo_rd_en       : std_logic;
	signal word_fifo_bytes_used  : std_logic_vector( 9 downto 0) := "00" & x"00";
	signal word_fifo_din 	     : std_logic_vector(15 downto 0);
	signal word_fifo_dout        : std_logic_vector(15 downto 0);
	signal word_fifo_empty       : std_logic;

	-- packet depth counter signals
	signal packet_depth_counter_decrement : std_logic := '0';
	signal packet_depth_counter_increment : std_logic := '0';
	signal packet_depth_counter  : unsigned(15 downto 0);

	-- input-manager state machine states.
	type   input_manager_state_type is ( start_word_judge, receive_data, wait_for_fifo_ready);
	signal input_manager_state      : input_manager_state_type := start_word_judge;
	signal input_manager_state_next : input_manager_state_type := start_word_judge;

	-- output-manager state machine states.
	type   output_manager_state_type is (startup, reading);
	signal output_manager_state      : output_manager_state_type := startup;
	signal output_manager_state_next : output_manager_state_type := startup;

	constant default_output : std_logic_vector(15 downto 0) := x"00" & packet_end_token; -- Use this at startup, etc, on the outputs.

	-- Actual depth is 1023 (not 1024!). Decrease by 5 for increased robustness handling off-by-1 errors, etc.
	constant fifo_word_depth : integer := 1018;
	-- The write depth must be less than this number to ensure a full packet can be added to the FIFO.
	constant fifo_maximum_used_bytes_for_new_packet : integer := fifo_word_depth - (max_packet_size_bytes)/2;

	component fifo_1024_16_counter
		port (
			rst     : in std_logic;
			wr_clk  : in std_logic;
			rd_clk  : in std_logic;
			din     : in std_logic_vector(15 downto 0);
			wr_en   : in std_logic;
			rd_en   : in std_logic;
			dout    : out std_logic_vector(15 downto 0);
			full    : out std_logic;
			empty   : out std_logic;
			rd_data_count  : out std_logic_vector( 9 downto 0);
			wr_data_count  : out std_logic_vector( 9 downto 0)
		);
	end component;

begin
	-- pass through intermediate signals
	reset_i <= reset;
	clk_i <= clk;
	din_wr_en_i <= din_wr_en;
	din_i <= din;
	bytes_received <= bytes_received_i;

	--------------------------------------------------------------------
	-- The underlying FIFO, which stores 1024 words. 
	--------------------------------------------------------------------
	word_fifo: fifo_1024_16_counter 
		port map (
			rst     => reset_i,
			wr_clk  => clk,
			rd_clk  => clk,
			din     => word_fifo_din, 
			wr_en   => word_fifo_wr_en,
			rd_en   => word_fifo_rd_en,
			dout    => word_fifo_dout,
			full    => open, -- todo: might be a good thing to use for diagnostics?
			empty   => word_fifo_empty,
			-- Depth Counters --
			--  - rd_data_count never over-reports usage (may under-report,
			--    so not useful to us).
			rd_data_count  => open, 
			--  - wr_data_count outputs how many 16bit words currently used.
			--    Never under-reports usage. We need this guarantee to
			--    prevent overfilling.
			wr_data_count  => word_fifo_bytes_used 
		);


	-------------------------------------------------------------------------------
	-- Received Bytes Counter
	-- - Process to count incoming bytes (whether they are stored or ignored) for
	--   diagnostic purposes.
	-------------------------------------------------------------------------------
	received_bytes_counter: process(reset, clk)
	begin
		if reset = '1' then
			bytes_received_i <= std_logic_vector(to_unsigned(0,64));
		elsif clk'event and clk = '1' then
			if din_wr_en = '1' then
				if word_fifo_din(15 downto 8) = packet_end_token then -- Bottom byte is filler.
					bytes_received_i <= std_logic_vector(unsigned(bytes_received_i) + 1);
				else
					bytes_received_i <= std_logic_vector(unsigned(bytes_received_i) + 2);
				end if;
			end if;
		end if;
	end process;


	--=============================================================================
	-- FIFO Input Manager
	--=============================================================================

	----------------------------------------------------------------------------
	-- State Machine FlipFlip Process
	-- - Updates pending state values on the clock edge
	----------------------------------------------------------------------------
	input_manager_FSM_flipflop_process: process(clk, reset)
	begin
		if reset = '1' then
			input_manager_state <= start_word_judge;
		elsif clk'event and clk = '1' then
			input_manager_state <= input_manager_state_next;
		end if;
	end process;

	----------------------------------------------------------------------------
	-- State Machine Asynchronous Logic
	-- - React to state changes and external logic.
	-- - Generally looks for a packet, and either clocks it into the FIFO
	--   if the FIFO has enough room for the maximum-sized packet, or it
	--   otherwise clocks it into nowhere (throws it away).
	----------------------------------------------------------------------------
	input_manager_FSM_async_logic_process: process(
		din, din_wr_en, word_fifo_bytes_used
	)
	begin
		word_fifo_din <= din; -- delays the fifo input data by 1 clock cycle to match the delayed wr_en signal below.
		case input_manager_state is
		when start_word_judge =>
		-- {
			if (din_wr_en = '1') then
				if check_first_packet_word_good(din, x"00", x"04") then
					if (unsigned(word_fifo_bytes_used) <= fifo_maximum_used_bytes_for_new_packet) then -- If room for a whole packet
						word_fifo_wr_en <= din_wr_en;
						input_manager_state_next <= receive_data;
					else
						word_fifo_wr_en <= '0';
						input_manager_state_next <= wait_for_fifo_ready;
					end if;
				else
					-- erroneous data condition, todo: log this somehow
					word_fifo_wr_en <= '0';
					input_manager_state_next <= start_word_judge;
				end if;
			else
				word_fifo_wr_en <= '0';
				input_manager_state_next <= start_word_judge;
			end if;
			packet_depth_counter_increment <= '0';
		-- }
		when receive_data =>
		-- {
			-- keep receiving until end signal
			if din_wr_en = '1' and word_contains_packet_end_token(din) then
				packet_depth_counter_increment <= '1'; --signal that we just finished writing a packet, for counting purposes
				input_manager_state_next <= start_word_judge;
			else
				packet_depth_counter_increment <= '0';
				input_manager_state_next <= receive_data;
			end if;
			word_fifo_wr_en <= din_wr_en;
		-- }
		when wait_for_fifo_ready =>
		-- {
			if ( unsigned(word_fifo_bytes_used) > fifo_maximum_used_bytes_for_new_packet) then -- If not room for a whole packet
				input_manager_state_next <= wait_for_fifo_ready;
			else
				-- If mid packet, the start_word_judge state will ignore everything until
				-- the next packet start.
				input_manager_state_next <= start_word_judge;
			end if;
			word_fifo_wr_en <= '0';
			packet_depth_counter_increment <= '0';
		-- }
		end case;
	end process;


	--=============================================================================
	-- Packet Depth Counter Process
	-- - Count the number of complete packets in the FIFO. This is used to ensure
	--   that we don't start transferring a packet out until we have a complete
	--   packet to send. (We don't want to sit and wait around mid transfer for the
	--   rest of a packet.)
	--=============================================================================
	packet_depth_counter_process: process(reset, clk)
	begin
		if reset = '1' then
			packet_depth_counter <= x"0000";
		elsif clk'event and clk = '1' then
			-- Increment/Decrement count.
			if packet_depth_counter_decrement = '1' and packet_depth_counter_increment = '0' then
				packet_depth_counter <= packet_depth_counter - 1;
			elsif packet_depth_counter_decrement = '0' and packet_depth_counter_increment = '1' then
				packet_depth_counter <= packet_depth_counter + 1;
			else
				packet_depth_counter <= packet_depth_counter;
			end if;
		end if;
	end process;


	--=============================================================================
	-- FIFO Output Manager
	--=============================================================================

	----------------------------------------------------------------------------
	-- State Machine FlipFlip Process
	-- - Updates pending state values on the clock edge
	----------------------------------------------------------------------------
	output_manager_FSM_flipflop_process: process( clk_i, reset_i)
	begin
		if ( reset_i = '1') then
			output_manager_state <= startup;
		elsif ( clk_i'event and clk_i = '1' ) then
			output_manager_state <= output_manager_state_next;
		end if;
	end process;

	----------------------------------------------------------------------------
	-- State Machine Asynchronous Logic
	-- - React to state changes and external logic.
	-- - Two states. The first state is used at startup when the FIFO output
	--   is not valid. The second state uses the FIFO output to track state
	--   information (end of packet is the special case that requires different
	--   control logic).
	----------------------------------------------------------------------------
	output_manager_FSM_async_logic_process: process(
		dout_rd_en,
		word_fifo_dout, word_fifo_empty,
		output_manager_state
	)
	begin
		-- default behaviors
		output_manager_state_next <= output_manager_state; -- keep state constant
		dout_end_of_packet <= '0';
		dout_packet_available <= '0';
		packet_depth_counter_decrement <= '0';

		case output_manager_state is
		-- This state only exists to handle the initial state where the FIFO output
		-- is not guaranteed. After this state, the FIFO output will be held between
		-- packets, and should have the packet_end_token in it.
		when startup =>
			if packet_depth_counter > 0 and word_fifo_empty = '0' then
				-- Data is ready to read.
				if dout_rd_en = '1' then
					-- If user is trying to read the data, decrement the packet counter
					-- and start reading it.
					word_fifo_rd_en <= '1';
					packet_depth_counter_decrement <= '1';
					output_manager_state_next <= reading;
				else
					-- Otherwise do nothing.
					word_fifo_rd_en <= '0';
				end if;
				dout_empty_notready <= '0';
				dout_packet_available <= '1';
			else
				-- keep waiting
				word_fifo_rd_en <= '0';
				dout_empty_notready <= '1';
				dout_packet_available <= '0';
			end if;
			dout_end_of_packet <= '1';
			dout <= default_output;
		-- This state only exists to handle the initial state where the FIFO output
		-- is not guaranteed. After this state, the FIFO output will be held between
		-- packets, and should have the packet_end_token in it.
		when reading =>
			-- If the output is an end-of-packet, do special logic 
			if word_contains_packet_end_token(word_fifo_dout) then
				if packet_depth_counter > 0 and word_fifo_empty = '0' then
					-- Data is ready to read.
					if dout_rd_en = '1' then
						-- If user is trying to read the data, decrement the packet counter
						-- and start reading it.
						word_fifo_rd_en <= '1';
						packet_depth_counter_decrement <= '1';
					else
						-- Otherwise do nothing.
						word_fifo_rd_en <= '0';
					end if;
					dout_empty_notready <= '0';
					dout_packet_available <= '1';
				else
					-- keep waiting
					word_fifo_rd_en <= '0';
					dout_empty_notready <= '1';
					dout_packet_available <= '0';
				end if;
				dout_end_of_packet <= '1';
			-- If not end of packet, allow user to keep reading along,
			-- don't signal any new packets avaiable.
			else
				-- keep reading
				dout_end_of_packet <= '0';
				dout_empty_notready <= word_fifo_empty;
				word_fifo_rd_en <= dout_rd_en; -- trusting the user to obey dout_empty_notready!
				dout_packet_available <= '0';
			end if;
			dout <= word_fifo_dout;

		when others =>
			-- Neutralize everything
			-- - state machine
			output_manager_state_next <= startup;
			-- - word fifo
			word_fifo_rd_en <= '0';
			-- - output
			dout <= default_output;
			dout_packet_available <= '0';
			dout_end_of_packet <= '1'; -- Attempt to get any readers to stop reading.
			dout_empty_notready <= '1';
		end case;
	end process;

end Behavioral;