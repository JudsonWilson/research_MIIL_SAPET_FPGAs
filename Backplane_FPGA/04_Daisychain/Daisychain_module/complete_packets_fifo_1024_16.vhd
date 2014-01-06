----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson, based on code by Hua Liu.
--
-- Create Date:    01/04/2013 
-- Design Name:
-- Module Name:    complete_packets_fifo_1024_16
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--     Wraps a fifo with logic that allows only full packets to enter/exit
-- gaplessly. This is done using the following methods:
--     a) Packets are only placed in the fifo if, at the first byte, there
--        is enough room for a complete packet. Otherwise the packet is
--        effectively erased. This prevents a partial packet from getting
--        in and the buffer overflowing.
--     b) The output is only signaled as ready if there is at least one
--        full packet inside.
-- This code originates from code that occurred multiple times in the
-- Daisychain Module.
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

entity complete_packets_fifo_1024_16 is
	port (
		reset       : in std_logic;
		clk_50MHz   : in std_logic;
		din_wr_en   : in std_logic;
		din         : in std_logic_vector(15 downto 0);
		dout_rd_en  : in std_logic;
		dout_decrement_packet_count  : in  std_logic;
		dout_packet_available        : out std_logic;
		dout        : out std_logic_vector(15 downto 0);
		dout_end_of_packet : out std_logic;
		bytes_received     : out std_logic_vector(63 downto 0) -- includes those that are thrown away to preempt buffer overflow
	);
end complete_packets_fifo_1024_16;

architecture Behavioral of complete_packets_fifo_1024_16 is
	attribute keep : string;  
	attribute S: string;

	signal reset_i			: std_logic := '1';

	signal bytes_received_i : std_logic_vector(63 downto 0);

	-- local acquisition fifo
	signal word_fifo_wr_en       : std_logic;
	signal word_fifo_rd_en       : std_logic;
		attribute keep of word_fifo_rd_en: signal is "true";  
		attribute S    of word_fifo_rd_en: signal is "true";  	
	signal word_fifo_bytes_used  : std_logic_vector( 9 downto 0) := "00" & x"00";
	signal word_fifo_din 	     : std_logic_vector(15 downto 0);
	signal word_fifo_dout        : std_logic_vector(15 downto 0);
		attribute keep of word_fifo_dout: signal is "true";
		attribute S    of word_fifo_dout: signal is "true";
	signal word_fifo_empty       : std_logic;
	-- Set bits in here to increment/decrement the packet depth counter, upon writing a packet to or reading a packet from the
	-- the word fifo. Do once per packet. Bit 1 indicates read, bit 0 indicates write.
	signal packet_depth_counter_write_and_read_trigger : std_logic_vector(1 downto 0) := "00";
	signal packet_depth_counter  : std_logic_vector(15 downto 0);
		attribute keep of packet_depth_counter: signal is "true";  
		attribute S    of packet_depth_counter: signal is "true";  	

	-- State machine states.
	type input_manager_state_type is ( start_word_judge, receive_data, wait_for_fifo_ready);
	signal input_manager_state    : input_manager_state_type := start_word_judge;

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
	reset_i <= reset;
	dout <= word_fifo_dout;
	word_fifo_rd_en <= dout_rd_en;
	packet_depth_counter_write_and_read_trigger(1) <= dout_decrement_packet_count;
	bytes_received <= bytes_received_i;

	--------------------------------------------------------------------
	-- The underlying FIFO, which stores 1024 words. 
	--------------------------------------------------------------------
	word_fifo: fifo_1024_16_counter 
		port map (
			rst     => reset_i,
			wr_clk  => clk_50MHz,
			rd_clk  => clk_50MHz,
			din     => word_fifo_din, 
			wr_en   => word_fifo_wr_en,
			rd_en   => word_fifo_rd_en,
			dout    => word_fifo_dout,
			full    => open,
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
	received_bytes_counter: process(reset, clk_50MHz)
	begin
		if ( reset = '1') then
			bytes_received_i <= std_logic_vector(to_unsigned(0,64));
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			if ( din_wr_en = '1') then
				if ( word_fifo_din(15 downto 8) = x"FF") then -- Bottom byte is filler.
					bytes_received_i <= std_logic_vector(unsigned(bytes_received_i) + 1);
				else
					bytes_received_i <= std_logic_vector(unsigned(bytes_received_i) + 2);
				end if;
			end if;
		end if;
	end process;


	-------------------------------------------------------------------------------
	-- Manage the FIFO input.
	-- - Note that the word_fifo_din and word_fifo_wr_en signals reach the fifo 1
	--   cycle after they reach this process. The process synchronizes the delay of
	--   these signals.
	-------------------------------------------------------------------------------
	fifo_input_manager: process( clk_50MHz, reset)
	begin
		if ( reset = '1') then
			word_fifo_wr_en <= '0';
			word_fifo_din <= x"0000";
			packet_depth_counter_write_and_read_trigger(0) <= '0';
			input_manager_state <= start_word_judge;
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
		-- {
			word_fifo_din <= din; -- delays the fifo input data by 1 clock cycle to match the delayed wr_en signal below.
			case input_manager_state is
				when start_word_judge =>
				-- {
					if (din_wr_en = '1') then
						if ((din > x"8100") and (din < x"8105")) then -- Packet must have a valid first byte and source node.
							if (word_fifo_bytes_used <= x"3A6") then -- If room for a whole packet
								word_fifo_wr_en <= din_wr_en;
								input_manager_state <= receive_data;
							else
								word_fifo_wr_en <= '0';
								input_manager_state <= wait_for_fifo_ready;
							end if;
						else
							word_fifo_wr_en <= '0';
							input_manager_state <= start_word_judge;
						end if;

					else
						word_fifo_wr_en <= '0';
						input_manager_state <= start_word_judge;
					end if;
					packet_depth_counter_write_and_read_trigger(0) <= '0';
				-- }
				when receive_data =>
				-- {
					-- end signal
					if ( din(15 downto 8) = x"FF" or din(7 downto 0) = x"FF") then
						packet_depth_counter_write_and_read_trigger(0) <= '1'; --signal that we just finished writing a packet, for counting purposes
						input_manager_state <= start_word_judge;
					else
						packet_depth_counter_write_and_read_trigger(0) <= '0';
						input_manager_state <= receive_data;
					end if;
					word_fifo_wr_en <= din_wr_en;
				-- }
				when wait_for_fifo_ready =>
				-- {
					if ( word_fifo_bytes_used > x"3A6") then -- If room for a whole packet
						input_manager_state <= wait_for_fifo_ready;
					else
						input_manager_state <= start_word_judge;
					end if;
					word_fifo_wr_en <= '0';
					packet_depth_counter_write_and_read_trigger(0) <= '0';
				-- }
			end case;
		end if;
		-- }
	end process;


	-------------------------------------------------------------------------------
	-- Packet Depth Counter Process
	-- - Count the number of complete packets in the FIFO. This is used to ensure
	--   that we don't start transferring a packet out until we have a complete
	--   packet to send. (We don't want to sit and wait around mid transfer for the
	--   rest of a packet.)
	-------------------------------------------------------------------------------
	packet_depth_counter_process: process(reset, clk_50MHz)
	begin
		if ( reset = '1') then
			packet_depth_counter <= x"0000";
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			-- Check wether finished writing, or reading a packet, and update count accordingly.
			case packet_depth_counter_write_and_read_trigger is
				when "00" =>
					packet_depth_counter <= packet_depth_counter;
				when "01" =>
					packet_depth_counter <= std_logic_vector(unsigned(packet_depth_counter) + 1);
				when "10" =>
					packet_depth_counter <= std_logic_vector(unsigned(packet_depth_counter) - 1);
				when "11" =>
					packet_depth_counter <= packet_depth_counter;
				when others =>
			end case;
		end if;
	end process;


	-------------------------------------------------------------------------------
	-- FIFO Output Manager
	-- - Various logic for handling output.
	-------------------------------------------------------------------------------
	fifo_output_manager: process( word_fifo_dout, packet_depth_counter, word_fifo_empty )
	begin
		if (word_fifo_dout(15 downto 8) = x"FF" or word_fifo_dout(7 downto 0) = x"FF")
		   and word_fifo_empty = '0' then -- empty criterion ideally isn't necessary, but should prevent non-stop spews if something weird happens.
			dout_end_of_packet <= '1';
		else
			dout_end_of_packet <= '0';
		end if;
		
		if unsigned(packet_depth_counter) > 0 then
			dout_packet_available <= '1';
		else
			dout_packet_available <= '0';
		end if;
	end process;

end Behavioral;