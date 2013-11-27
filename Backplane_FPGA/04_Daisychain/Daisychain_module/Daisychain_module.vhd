----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    16:50:25 10/22/2012 
-- Design Name: 
-- Module Name:    Daisychain_module - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library unisim;
use unisim.vcomponents.all;


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Daisychain_module is
	port (
		     acquisition_data_receive_data_number : out std_logic_vector(15 downto 0);
		     bug_out_put_from_Acquisition_to_Daisychain			: out std_logic;
		     reset				: in std_logic;
		     clk_50MHz				: in std_logic;
		     boardid				: in std_logic_vector(2 downto 0);
		     -- to get the config data and acquisition data from GTP interface for serializing
		-- data receiving from GTP interface
		     din_from_GTP			: in std_logic_vector(15 downto 0);
		     din_from_GTP_wr			: in std_logic;
		-- to send the config data and acquisition data to GTP interface for transfer
		     dout_to_GTP			: out std_logic_vector(15 downto 0);
		     dout_to_GTP_wr			: out std_logic;
		     is_GTP_ready			: in std_logic;
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
	signal formal_word			: std_logic_vector(15 downto 0);
	signal acquisition_data_receive_data_number_i : std_logic_vector(15 downto 0);
	signal bug_bit				: std_logic_vector( 1 downto 0);
	-- global signals
	signal reset_fifo			: std_logic := '1';
	signal reset_fifo_vec			: std_logic_vector(3 downto 0) := "1111";
	-- config data related variables
	signal config_data_fifo_wr_en 		: std_logic := '0';
	signal config_data_fifo_rd_en		: std_logic := '0';
	signal config_data_fifo_din		: std_logic_vector(15 downto 0) := x"0000";
	signal config_data_fifo_dout		: std_logic_vector(15 downto 0) := x"0000";
	signal config_data_fifo_empty		: std_logic := '0';
	signal one_packet_write_or_read_config_data_fifo	: std_logic_vector(1 downto 0) := "00";
	signal packets_write_config_data_fifo	: std_logic_vector(15 downto 0) := x"0000";
	signal wr_data_counter_local		: std_logic_vector( 9 downto 0) := "00" & x"00";
	signal wr_data_counter_J40		: std_logic_vector( 9 downto 0) := "00" & x"00";
	signal wr_data_counter_configure	: std_logic_vector( 9 downto 0) := "00" & x"00";

	-- GTP transmitter related variables
	signal J40_data_fifo_wr_en		: std_logic;
	signal J40_data_fifo_rd_en 		: std_logic := '0';
	signal J40_data_fifo_din 		: std_logic_vector(15 downto 0);
	signal J40_data_fifo_dout		: std_logic_vector(15 downto 0);
	signal J40_data_fifo_empty		: std_logic;
	signal one_packet_write_or_read_J40_data_fifo : std_logic_vector(1 downto 0) := "00";
	signal packets_write_J40_data_fifo  : std_logic_vector(15 downto 0);

	-- local acquisition fifo
	signal local_acquisition_data_fifo_wr_en : std_logic;
	signal local_acquisition_data_fifo_rd_en : std_logic;
	signal local_acquisition_data 	        : std_logic_vector(15 downto 0);
	signal local_acquisition_data_fifo_dout : std_logic_vector(15 downto 0);
	signal local_acquisition_data_fifo_empty : std_logic;
	signal one_packet_write_or_read_local_acquisition_fifo : std_logic_vector(1 downto 0) := "00";
	signal packets_write_local_acquisition_fifo  : std_logic_vector(15 downto 0);


	signal increase_one_clock_for_config_data : std_logic_vector(1 downto 0) := "00";
	signal increase_one_clock_for_acquisition_data : std_logic_vector(1 downto 0) := "00";
	signal first_header_word		: std_logic_vector(15 downto 0);
	signal second_header_word 		: std_logic_vector(15 downto 0);

	type fifo_status_type is ( start_word_judge, receive_data, wait_for_fifo_ready);
	-- for receiving data from J40
	signal J40_fifo_status 			: fifo_status_type := start_word_judge;
	-- for receiving data from local_acquisition_module
	signal local_acquisition_fifo_status    : fifo_status_type := start_word_judge;
	-- for receiving data from UDP
	signal config_data_fifo_status		: fifo_status_type := start_word_judge;

	type J41_Tx_send_state_type is (idle, data_from_former_Virtex_5_data_transmit_fifo, UDP_config_data_transmit, local_acquisition_data_transfer_fifo);
	-- for transmitting data to J41
	signal J41_Tx_send_state : J41_Tx_send_state_type := idle;

	type transfering_local_acquisition_data_type is (first_word_judge, first_word_output, align_one_clock, valid_data_judge, save_second_word, local_acquisition_data_transfer, error_data_process, end_process);
	signal fifo_local_acquisition_data_transmit_state : transfering_local_acquisition_data_type := first_word_judge;

	type former_Virtex_5_data_transmit_state_type is (first_header_word_judge, first_header_word_output, align_read_out_clock, valid_header_word_judge, serializing_config_data_for_current_board_transfer, not_the_current_board_config_data_transmit_former_board_data, acquisition_data_transmit_former_board, error_data_process);
	signal fifo_former_Virtex_5_data_transmit_state : former_Virtex_5_data_transmit_state_type := first_header_word_judge;

	type   config_data_transfer_state_type is (first_word_judge, first_word_output, align_one_clock, valid_data_judge, save_second_word, body_transfer, error_data_process, end_process);
	signal config_data_transfer_state : config_data_transfer_state_type := first_word_judge;
	
	signal echo_back_config_data		: std_logic_vector(15 downto 0);

	signal transfer_data_token		: std_logic := '0'; 
		     

	component fifo_block_1024_16 
		port (
			     rst		: in std_logic;
			     wr_clk		: in std_logic;
			     rd_clk		: in std_logic;
			     din 		: in std_logic_vector(15 downto 0);
			     wr_en		: in std_logic;
			     rd_en		: in std_logic;
			     dout		: out std_logic_vector(15 downto 0);
			     full		: out std_logic;
			     empty		: out std_logic
		     );
	end component;

	component fifo_1024_16_counter
		port (
			     rst		: in std_logic;
			     wr_clk		: in std_logic;
			     rd_clk		: in std_logic;
			     din 		: in std_logic_vector(15 downto 0);
			     wr_en		: in std_logic;
			     rd_en		: in std_logic;
			     dout		: out std_logic_vector(15 downto 0);
			     full		: out std_logic;
			     empty		: out std_logic;
			     rd_data_count	: out std_logic_vector( 9 downto 0);
			     wr_data_count	: out std_logic_vector( 9 downto 0)
		     );
	end component;



begin
	acquisition_data_receive_data_number <= acquisition_data_receive_data_number_i;
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


	--------------------------------------------------------------------
	-- To get the configure data from PC computer
	-- Only judge the start signal 8100 and the end signal FFxx or xxFF
	--------------------------------------------------------------------
	Inst_get_configure_data_from_PC_computer : fifo_1024_16_counter 
	port map (
			rst 		=> reset_fifo,
			wr_clk		=> clk_50MHz,
			rd_clk		=> clk_50MHz,
			din		=> config_data_fifo_din,
			wr_en		=> config_data_fifo_wr_en,
			rd_en		=> config_data_fifo_rd_en,
			dout		=> config_data_fifo_dout,
			full		=> open,
			empty		=> config_data_fifo_empty,
			rd_data_count  	=> open,
			wr_data_count  	=> wr_data_counter_configure -- Outputs how many 16bit words currently used.
		);
	--------------------------------------------------------------------
	-- configure data to fifo
	-- 04-05-2013
	--------------------------------------------------------------------
	Configure_dta_to_fifo: process ( clk_50MHz, reset)
	begin
		if ( reset = '1') then
			config_data_fifo_wr_en <= '0';
			config_data_fifo_din <= x"0000";
			one_packet_write_or_read_config_data_fifo(0) <= '0';
			config_data_fifo_status <= start_word_judge;
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
		-- {
			config_data_fifo_din <= config_data_from_UDP_to_GTP;
			case config_data_fifo_status is
				when start_word_judge =>
				-- {
					-- start signal 8100
					if ( config_data_from_UDP_to_GTP_wr = '1') then
						if ( config_data_from_UDP_to_GTP = x"8100") then -- Start of configure packet, source = PC
							if ( wr_data_counter_configure <= x"3A6") then -- If room for a whole packet
								config_data_fifo_wr_en <= config_data_from_UDP_to_GTP_wr;
								config_data_fifo_status <= receive_data;
							else
								config_data_fifo_wr_en <= '0';
								config_data_fifo_status <= wait_for_fifo_ready;
							end if;
						else
							config_data_fifo_wr_en <= '0';
							config_data_fifo_status <= start_word_judge;
						end if;
					else
						config_data_fifo_wr_en <= '0';
						config_data_fifo_status <= start_word_judge;
					end if;
					one_packet_write_or_read_config_data_fifo(0) <= '0';
				--}
				when receive_data =>
				-- {
					-- end signal xxFF or FFxx
					if ( config_data_from_UDP_to_GTP(15 downto 8) = x"FF" or config_data_from_UDP_to_GTP(7 downto 0) = x"FF") then
						one_packet_write_or_read_config_data_fifo(0) <= '1'; --signal that we just finished writing a packet, for counting purposes
						config_data_fifo_status <= start_word_judge;
					else
						one_packet_write_or_read_config_data_fifo(0) <= '0';
						config_data_fifo_status <= receive_data;
					end if;
					config_data_fifo_wr_en <= config_data_from_UDP_to_GTP_wr;
				--}
				when wait_for_fifo_ready =>
				-- {
					if ( wr_data_counter_configure > x"3A6") then -- If room for a whole packet
						config_data_fifo_status <= wait_for_fifo_ready;
					else
						config_data_fifo_status <= start_word_judge;
					end if;
					config_data_fifo_wr_en <= '0';
					one_packet_write_or_read_config_data_fifo(0) <= '0';
				-- }
			end case;
		end if;
		-- }
	end process;

	-- Count the number of complete packets in the FIFO. This is used to ensure that we don't start transferring
	-- a packet out until we have a complete packet to send. (We don't want to sit and wait around mid transfer for
	-- the rest of a packet.)
	Inst_receive_config_data_packet_number_fifo: process( reset, clk_50MHz)
	begin
		if ( reset = '1') then
			packets_write_config_data_fifo <= x"0000";
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			-- Check wether finished writing, or reading a packet, and update count accordingly.
			case one_packet_write_or_read_config_data_fifo is 
				when "00" =>
					packets_write_config_data_fifo <= packets_write_config_data_fifo;
				when "01" =>
					packets_write_config_data_fifo <= packets_write_config_data_fifo + x"01";
				when "10" =>
					packets_write_config_data_fifo <= packets_write_config_data_fifo - x"01";
				when "11" =>
					packets_write_config_data_fifo <= packets_write_config_data_fifo;
				when others =>
			end case;
		end if;
	end process;


	--====================================================================
	--====================================================================
	-- Local Acquisition: Gathers packets from RENA Front End Boards attached
	--     directly to this node.
	--====================================================================
	--====================================================================

	--------------------------------------------------------------------
	-- To get the data from local acquisition module and save into fifo_block_16
	-- Only judge the start signal 8101-8104 and the end signal FFxx or xxFF 
	--------------------------------------------------------------------
	Inst_get_data_from_local_acquisition_module_to_Daisychain: fifo_1024_16_counter 
	port map (
			rst		=> reset_fifo,
			wr_clk		=> clk_50MHz,
			rd_clk		=> clk_50MHz,
			din		=> local_acquisition_data, 
			wr_en		=> local_acquisition_data_fifo_wr_en,
			rd_en		=> local_acquisition_data_fifo_rd_en,
			dout		=> local_acquisition_data_fifo_dout,
			full		=> open,
			empty		=> local_acquisition_data_fifo_empty,
			rd_data_count  	=> open,
			wr_data_count  	=> wr_data_counter_local -- Outputs how many 16bit words currently used.
		);

	-- Count the actual number of bytes received, regardless of wether we drop it due to lack of room in
	-- the FIFO. This is used externally for diagnostics.
	Inst_count_received_acquisition_data: process(reset, clk_50MHz)
	begin
		if ( reset = '1') then
			acquisition_data_receive_data_number_i <= x"0000";
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			if ( din_from_acquisition_wr = '1') then
				if ( local_acquisition_data(15 downto 8) = x"FF") then -- Bottom byte is filler.
					acquisition_data_receive_data_number_i <= acquisition_data_receive_data_number_i + x"1";
				else
					acquisition_data_receive_data_number_i <= acquisition_data_receive_data_number_i + x"2";
				end if;
			end if;
		end if;
	end process;


	----------------------------------------------------------------------------------------------------------
	-- Manage the FIFO.
	----------------------------------------------------------------------------------------------------------
	Local_acquisition_data_to_Daisychain: process( clk_50MHz, reset)
	begin
		if ( reset = '1') then
			local_acquisition_data_fifo_wr_en <= '0';
			local_acquisition_data <= x"0000";
			one_packet_write_or_read_local_acquisition_fifo(0) <= '0';
			local_acquisition_fifo_status <= start_word_judge;
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
		-- {
			local_acquisition_data <= din_from_acquisition;
			case local_acquisition_fifo_status is
				when start_word_judge =>
				-- {
					if (din_from_acquisition_wr = '1') then
						if ((din_from_acquisition > x"8100") and (din_from_acquisition < x"8105")) then -- Packet must have a valid first byte and source node.
							if (wr_data_counter_local <= x"3A6") then -- If room for a whole packet
								local_acquisition_data_fifo_wr_en <= din_from_acquisition_wr;
								local_acquisition_fifo_status <= receive_data;
							else
								local_acquisition_data_fifo_wr_en <= '0';
								local_acquisition_fifo_status <= wait_for_fifo_ready;
							end if;
						else
							local_acquisition_data_fifo_wr_en <= '0';
							local_acquisition_fifo_status <= start_word_judge;
						end if;

					else
						local_acquisition_data_fifo_wr_en <= '0';
						local_acquisition_fifo_status <= start_word_judge;
					end if;
					one_packet_write_or_read_local_acquisition_fifo(0) <= '0';
				-- }
				when receive_data =>
				-- {
					-- end signal
					if ( din_from_acquisition(15 downto 8) = x"FF" or din_from_acquisition(7 downto 0) = x"FF") then
						one_packet_write_or_read_local_acquisition_fifo(0) <= '1'; --signal that we just finished writing a packet, for counting purposes
						local_acquisition_fifo_status <= start_word_judge;
					else
						one_packet_write_or_read_local_acquisition_fifo(0) <= '0';
						local_acquisition_fifo_status <= receive_data;
					end if;
					local_acquisition_data_fifo_wr_en <= din_from_acquisition_wr;
				-- }
				when wait_for_fifo_ready =>
				-- {
					if ( wr_data_counter_local > x"3A6") then -- If room for a whole packet
						local_acquisition_fifo_status <= wait_for_fifo_ready;
					else
						local_acquisition_fifo_status <= start_word_judge;
					end if;
					local_acquisition_data_fifo_wr_en <= '0';
					one_packet_write_or_read_local_acquisition_fifo(0) <= '0';
				-- }
			end case;
		end if;
		-- }
	end process;

	-- Count the number of complete packets in the FIFO. This is used to ensure that we don't start transferring
	-- a packet out until we have a complete packet to send. (We don't want to sit and wait around mid transfer for
	-- the rest of a packet.)
	Inst_receive_local_acquisition_packet_number_fifo: process(reset, clk_50MHz)
	begin
		if ( reset = '1') then
			packets_write_local_acquisition_fifo <= x"0000";
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			-- Check wether finished writing, or reading a packet, and update count accordingly.
			case one_packet_write_or_read_local_acquisition_fifo is
				when "00" =>
					packets_write_local_acquisition_fifo <= packets_write_local_acquisition_fifo;
				when "01" =>
					packets_write_local_acquisition_fifo <= packets_write_local_acquisition_fifo + x"01";
				when "10" =>
					packets_write_local_acquisition_fifo <= packets_write_local_acquisition_fifo - x"01";
				when "11" =>
					packets_write_local_acquisition_fifo <= packets_write_local_acquisition_fifo;
				when others =>
			end case;
		end if;
	end process;

	--====================================================================
	--====================================================================
	-- GTP J40: Gathers packets from other nodes (Backend Boards) via
	--     the SATA cable connection.
	--====================================================================
	--====================================================================

	--------------------------------------------------------------------
	-- To get the data from GTP J40 interface and save into fifo_block_16
	-- Only to get the data, not judge the data
	--------------------------------------------------------------------
	Inst_get_data_from_GTP_J40_to_Daisychain: fifo_1024_16_counter 
	port map (
			rst		=> reset_fifo,
			wr_clk		=> clk_50MHz,
			rd_clk		=> clk_50MHz,
			din		=> J40_data_fifo_din,
			wr_en		=> J40_data_fifo_wr_en,
			rd_en		=> J40_data_fifo_rd_en,
			dout		=> J40_data_fifo_dout,
			full		=> open,
			empty		=> J40_data_fifo_empty,
			rd_data_count  	=> open,
			wr_data_count  	=> wr_data_counter_J40 -- Outputs how many 16bit words currently used.
		);
	----------------------------------------------------------------------------------------------------------
	-- save config data from GTP J40 interface to a specify config fifo
	----------------------------------------------------------------------------------------------------------
	-- 12/12/2012
	-- Maybe there is some problem, such as the syncronizing of the writing data and the reading data
	----------------------------------------------------------------------------------------------------------
	J40_data_from_former_board_to_Daisychain: process ( clk_50MHz, reset)
	begin
		if ( reset = '1') then
			J40_data_fifo_wr_en <= '0';
			J40_fifo_status <= start_word_judge;
			J40_data_fifo_din <= x"0000";
			one_packet_write_or_read_J40_data_fifo(0) <= '0';
		elsif (clk_50MHz 'event and clk_50MHz = '1') then
		-- {
			J40_data_fifo_din <= din_from_GTP;
			case J40_fifo_status is
				when start_word_judge =>
				-- {
					if ( din_from_GTP_wr = '1') then
						if ( din_from_GTP(15 downto 8) = x"81") then -- Packet must have a valid first byte.
							if ( wr_data_counter_J40 <= x"3A6") then -- If room for a whole packet
								J40_data_fifo_wr_en <= din_from_GTP_wr;
								J40_fifo_status <= receive_data;
							else
								J40_data_fifo_wr_en <= '0';
								J40_fifo_status <= wait_for_fifo_ready;
							end if;
						else
							J40_data_fifo_wr_en <= '0';
							J40_fifo_status <= start_word_judge;
						end if;
					else
						J40_data_fifo_wr_en <= '0';
						J40_fifo_status <= start_word_judge;
					end if;
					one_packet_write_or_read_J40_data_fifo(0) <= '0';
				-- }
				when receive_data =>
				-- {
					-- end signal
					if (din_from_GTP(15 downto 8) = x"FF" or din_from_GTP(7 downto 0) = x"FF") then
						one_packet_write_or_read_J40_data_fifo(0) <= '1'; --signal that we just finished writing a packet, for counting purposes
						J40_fifo_status <= start_word_judge; 
					else
						one_packet_write_or_read_J40_data_fifo(0) <= '0';
						J40_fifo_status <= receive_data; 
					end if;
					J40_data_fifo_wr_en <= din_from_GTP_wr;
				-- }
				when wait_for_fifo_ready =>
				-- {
					if ( wr_data_counter_J40 > x"3A6") then -- If room for a whole packet
						J40_fifo_status <= wait_for_fifo_ready; 
					else
						J40_fifo_status <= start_word_judge; 
					end if;
					J40_data_fifo_wr_en <= '0';
					one_packet_write_or_read_J40_data_fifo(0) <= '0';
				-- }
			end case;
		end if;
		-- }
	end process;

	-- Count the number of complete packets in the FIFO. This is used to ensure that we don't start transferring
	-- a packet out until we have a complete packet to send. (We don't want to sit and wait around mid transfer for
	-- the rest of a packet.)
	Inst_receive_J40_packet_number_fifo: process(reset, clk_50MHz)
	begin
		if ( reset = '1') then
			packets_write_J40_data_fifo <= x"0000";
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			-- Check wether finished writing, or reading a packet, and update count accordingly.
			case one_packet_write_or_read_J40_data_fifo is
				when "00" =>
					packets_write_J40_data_fifo <= packets_write_J40_data_fifo;
				when "01" =>
					packets_write_J40_data_fifo <= packets_write_J40_data_fifo + x"01";
				when "10" =>
					packets_write_J40_data_fifo <= packets_write_J40_data_fifo - x"01";
				when "11" =>
					packets_write_J40_data_fifo <= packets_write_J40_data_fifo;
				when others =>
			end case;
		end if;
	end process;


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



	--====================================================================
	--====================================================================
	-- Routing Process:
	--     Data can flow from one and only one input port to either the
	--	    J41 GTP output port, or the UDP port. This process prioritizes
	--     the input port, and writes to the correct output depending on
	--     which board Node ID this is, etc.
	--====================================================================
	--====================================================================
	--     FIFO note:
	--     Because of the design of this process and the way
	--     the sensitivity works (sensitive only to clock), a FIFO output
	--     as seen in the process becomes valid on the 2nd following clock
	--     tick. To understand this, note that the enable signal is read
	--     by the fifo on the next clock edge, and the data becomes valid
	--     on the output AFTER the clock edge. This will not change the
	--     signal in the eyes of the state machine until the next clock
	--     edge after that (becaue the process samples on clock edge). So
	--     this means output on second clock after read strobe.
	--
	--     This causes all the FIFO reading states to be funny. To be more
	--     straight-forward, you would do a signal-read, pause, react
	--     sequence, but this would cut throughput in half. So instead,
	--     we try and be smart (rather than rewrite the state machine as
	--     two processes, where one updates flip-flops on clock edges, and
	--     the other has asynchronous logic that is sensitive to all
	--     signals of interest <- which would work a lot better).
	--
	--     Instead, we read the whole body without gaps. Thus, by the time
	--     we notice that we got the last word of the packet, we read too
	--     far already.
	--
	--     The first reading state then needs to check for two possibilities:
	--     1) At startup, or after reading one packet with nothing after it,
	--     the FIFO should not be outputting a x"810#" word. So start reading.
	--     2) The FIFO output is the first word from the next packet, because
	--     there was a second one in the FIFO when we over-ran the ending.
	--
	--     If you understand that, you can understand the rest of the states.
	----------------------------------------------------------------------

	----------------------------------------------------------------------------------------------------------
	-- Old comment:
	----------------------------------------------------------------------------------------------------------
	-- GTP J41 transfer: (dout_to_GTP_wr, dout_to_GTP)
	-- The following data will be sent:
	-- 1. configuration data from UDP_interface to GTP
	-- 2. the former Virtex-5 board data from J40(configuration data and former local acquisition data)
	-- 3. local acquisition data
	-- For the configuration data fromo J41, serializing and transmitting at the same time
	----------------------------------------------------------------------------------------------------------
	GTP_J41_state_machine: process( clk_50MHz, reset)
	begin
		if ( reset = '1') then
			config_data_fifo_rd_en <= '0';
			J40_data_fifo_rd_en <= '0';
			local_acquisition_data_fifo_rd_en <= '0';

			-- To control the serializing fifo
			dout_to_serializing_wr <= '0';
			dout_to_serializing <= x"0000";
			dout_to_UDP_wr <= '0';
			dout_to_UDP <= x"0000";
			dout_to_GTP_wr <= '0';
			dout_to_GTP <= x"0000";
			-- control the data packet in fifo
			one_packet_write_or_read_J40_data_fifo(1) <= '0';
			one_packet_write_or_read_local_acquisition_fifo(1) <= '0';
			one_packet_write_or_read_config_data_fifo(1) <= '0';

			transfer_data_token <= '0';
			increase_one_clock_for_acquisition_data <= "00";
			increase_one_clock_for_config_data <= "00";
			fifo_former_Virtex_5_data_transmit_state <= first_header_word_judge;
			fifo_local_acquisition_data_transmit_state <= first_word_judge;
			config_data_transfer_state <= first_word_judge;
			J41_Tx_send_state <= idle;
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then 
			case J41_Tx_send_state is
				when idle =>
				-- {
					dout_to_UDP_wr <= '0';
					dout_to_GTP_wr <= '0';
					dout_to_serializing_wr <= '0';
					dout_to_UDP <= x"0000";
					dout_to_GTP <= x"0000";
					dout_to_serializing <= x"0000";
					-- UDP configuration data - highest priority to be transmitted
					if ( config_data_fifo_empty = '0' and packets_write_config_data_fifo > x"00") then
						config_data_fifo_rd_en <= '0';
						one_packet_write_or_read_J40_data_fifo(1) <= '0';
						one_packet_write_or_read_local_acquisition_fifo(1) <= '0';
						one_packet_write_or_read_config_data_fifo(1) <= '1'; -- Signal that we just started reading a config packet, so there is 1 less full packet now.
						config_data_transfer_state <= first_word_judge;
						J41_Tx_send_state <= UDP_config_data_transmit;
					else
					-- Data from the former Virtex-5 board on J40 input, to J41 output - the second priority
					-- Including the former acquisition data and the configuration data
						one_packet_write_or_read_config_data_fifo(1) <= '0';
						-- transfer_data_token flips back and forth, so as to attempt to not give constant priority
						case transfer_data_token is 
							when '0' =>
								if ( J40_data_fifo_empty = '0' and packets_write_J40_data_fifo > x"0") then
									J40_data_fifo_rd_en <= '0';
									one_packet_write_or_read_J40_data_fifo(1) <= '1'; -- Trigger decrease packet counter by 1
									fifo_former_Virtex_5_data_transmit_state <= first_header_word_judge;
									J41_Tx_send_state <= data_from_former_Virtex_5_data_transmit_fifo;
								else
									J40_data_fifo_rd_en <= '0';
									one_packet_write_or_read_J40_data_fifo(1) <= '0';
									fifo_former_Virtex_5_data_transmit_state <= first_header_word_judge;
									J41_Tx_send_state <= idle;
								end if;
								transfer_data_token <= '1';
							when '1' =>
								if ( local_acquisition_data_fifo_empty = '0' and packets_write_local_acquisition_fifo > x"0")  then
									local_acquisition_data_fifo_rd_en <= '0';
									one_packet_write_or_read_local_acquisition_fifo(1) <= '1'; -- Trigger decrease packet counter by 1
									fifo_local_acquisition_data_transmit_state <= first_word_judge;
									J41_Tx_send_state <= local_acquisition_data_transfer_fifo;
								else
									local_acquisition_data_fifo_rd_en <= '0';
									one_packet_write_or_read_local_acquisition_fifo(1) <= '0';
									fifo_local_acquisition_data_transmit_state <= first_word_judge;
									J41_Tx_send_state <= idle;
								end if;
								transfer_data_token <= '0';
							when others =>
								null;
						end case;
					end if;
				-- }

				--
				-- Data from a local RENA is ready to send. This will send it either out the UDP (if we are
				-- master node boardid="001") or the GTP.
				--
				when local_acquisition_data_transfer_fifo => 
				-- {
					dout_to_serializing_wr <= '0';
					dout_to_serializing <= x"0000";
					one_packet_write_or_read_config_data_fifo(1) <= '0';
					one_packet_write_or_read_J40_data_fifo(1) <= '0';
					one_packet_write_or_read_local_acquisition_fifo(1) <= '0';
					case fifo_local_acquisition_data_transmit_state is
					-- Determine if the first byte is already on output of FIFO or not.
						when first_word_judge =>
						-- {
							-- See the "FIFO note" under the header block comment for this process for full
							-- description of what is going on in this state.
							local_acquisition_data_fifo_rd_en <= '1';
							if ( (local_acquisition_data_fifo_dout > x"8100") and (local_acquisition_data_fifo_dout < x"8105")) then
								fifo_local_acquisition_data_transmit_state <= align_one_clock;
							else
								fifo_local_acquisition_data_transmit_state <= first_word_output;
							end if;
							dout_to_GTP_wr <= '0';
							dout_to_UDP_wr <= '0';
							dout_to_GTP <= x"0000";
							dout_to_UDP <= x"0000";
							first_header_word <= local_acquisition_data_fifo_dout;
							second_header_word <= x"0000";
							J41_Tx_send_state <= local_acquisition_data_transfer_fifo;
						-- }
						-- Wait for header byte. Note that the FIFO output is delayed by 2, so the state after
						-- this will already have the second word.
						when first_word_output =>
						-- {
							if ( (local_acquisition_data_fifo_dout > x"8100") and (local_acquisition_data_fifo_dout < x"8105")) then
								local_acquisition_data_fifo_rd_en <= '0'; -- Stop fifo output to give a chance to send second word.
								fifo_local_acquisition_data_transmit_state <= valid_data_judge;
							else
								local_acquisition_data_fifo_rd_en <= '1';
								fifo_local_acquisition_data_transmit_state <= first_word_output;
							end if;
							dout_to_GTP_wr <= '0';
							dout_to_UDP_wr <= '0';
							dout_to_GTP <= x"0000";
							dout_to_UDP <= x"0000";
							first_header_word <= local_acquisition_data_fifo_dout;
							second_header_word <= x"0000";
							J41_Tx_send_state <= local_acquisition_data_transfer_fifo;
						-- }
						-- Momentarily wait before FIFO output is valid with second word.
						when align_one_clock =>
						-- {
							local_acquisition_data_fifo_rd_en <= '0'; -- Stop fifo output to give a chance to send second word.
							dout_to_GTP_wr <= '0';
							dout_to_UDP_wr <= '0';
							dout_to_GTP <= x"0000";
							dout_to_UDP <= x"0000";
							first_header_word <= first_header_word; 
							second_header_word <= x"0000";
							fifo_local_acquisition_data_transmit_state <= valid_data_judge;
							J41_Tx_send_state <= local_acquisition_data_transfer_fifo;
						-- }
						-- Sends out the first word, and saves the second word from the FIFO.
						--  - Assumes that 2 states ago the fifo rd was enabled, but previous state it was NOT.
						--    Therefore, have data to read this state, but not the next state.
						--  - Enables rd so that after the second word is sent next packet, we can read the
						--    fifo output and send it directly out.
						when valid_data_judge =>
						-- {
							local_acquisition_data_fifo_rd_en <= '1';
							first_header_word <= first_header_word;
							second_header_word <= local_acquisition_data_fifo_dout;
							if ((first_header_word > x"8100") and (first_header_word < x"8105") and ( local_acquisition_data_fifo_dout(15 downto 8) = x"00")) then
								if ( boardid = "001") then
									dout_to_GTP_wr <= '0';
									dout_to_GTP <= x"0000";
									dout_to_UDP_wr <= '1';
									dout_to_UDP <= first_header_word;
								else
									dout_to_GTP_wr <= '1';
									dout_to_GTP <= first_header_word;
									dout_to_UDP_wr <= '0';
									dout_to_UDP <= x"0000";
								end if;
								fifo_local_acquisition_data_transmit_state <= save_second_word;
							else
								dout_to_UDP_wr <= '0';
								dout_to_GTP_wr <= '0';
								fifo_local_acquisition_data_transmit_state <= error_data_process;
							end if;
							J41_Tx_send_state <= local_acquisition_data_transfer_fifo;
						-- }
						-- Sends the second word out. No new data to send yet.
						--  - Assumes that 2 states ago the fifo rd was NOT enabled.
						--    Therefore, no new data to read.
						--  - Previous state the rd WAS enabled, which will be the beginning of the body streaming
						--    from the fifo
						when save_second_word =>
						-- {
							first_header_word <= first_header_word;
							second_header_word <= second_header_word;
							local_acquisition_data_fifo_rd_en <= '1';
							if ( boardid = "001") then
								dout_to_GTP_wr <= '0';
								dout_to_GTP <= x"0000";
								dout_to_UDP_wr <= '1';
								dout_to_UDP <= second_header_word;
							else
								dout_to_GTP_wr <= '1';
								dout_to_GTP <= second_header_word;
								dout_to_UDP_wr <= '0';
								dout_to_UDP <= x"0000";
							end if;
							fifo_local_acquisition_data_transmit_state <= local_acquisition_data_transfer;
							J41_Tx_send_state <= local_acquisition_data_transfer_fifo;
						-- }
						-- Send the rest of the body of the packet, stop on x"FF" in upper or lower byte.
						when local_acquisition_data_transfer =>
						-- {
							first_header_word <= x"0000";
							second_header_word <= x"0000";
							if ( boardid = "001") then
								dout_to_GTP_wr <= '0';
								dout_to_GTP <= x"0000";
								dout_to_UDP_wr <= '1';
								dout_to_UDP <= local_acquisition_data_fifo_dout;
								if ( local_acquisition_data_fifo_dout(15 downto 8) = x"FF" or local_acquisition_data_fifo_dout(7 downto 0) = x"FF") then
									local_acquisition_data_fifo_rd_en <= '0';
									fifo_local_acquisition_data_transmit_state <= end_process;
								else
									local_acquisition_data_fifo_rd_en <= '1';
									fifo_local_acquisition_data_transmit_state <= local_acquisition_data_transfer;
								end if;
							else
								dout_to_UDP_wr <= '0';
								dout_to_UDP <= x"0000";
								dout_to_GTP_wr <= '1';
								dout_to_GTP <= local_acquisition_data_fifo_dout;
								if ( local_acquisition_data_fifo_dout(15 downto 8) = x"FF" or local_acquisition_data_fifo_dout(7 downto 0) = x"FF") then
									local_acquisition_data_fifo_rd_en <= '0';
									fifo_local_acquisition_data_transmit_state <= end_process;
								else
									local_acquisition_data_fifo_rd_en <= '1';
									fifo_local_acquisition_data_transmit_state <= local_acquisition_data_transfer;
								end if;
							end if;
							J41_Tx_send_state <= local_acquisition_data_transfer_fifo;
						-- }
						-- Clear out a bad packet from the FIFO
						when error_data_process =>
						-- {
							first_header_word <= x"0000";
							second_header_word <= x"0000";
							dout_to_GTP_wr <= '0';
							dout_to_GTP <= x"0000";
							dout_to_UDP_wr <= '0';
							dout_to_UDP <= x"0000";
							if ( local_acquisition_data_fifo_dout(15 downto 8) = x"FF" or local_acquisition_data_fifo_dout(7 downto 0) = x"FF") then
								local_acquisition_data_fifo_rd_en <= '0';
								fifo_local_acquisition_data_transmit_state <= end_process;
							else
								local_acquisition_data_fifo_rd_en <= '1';
								fifo_local_acquisition_data_transmit_state <= error_data_process;
							end if;
							J41_Tx_send_state <= local_acquisition_data_transfer_fifo;
						-- }
						-- Let the FIFO finish outputting data.
						when end_process =>
						-- {
							local_acquisition_data_fifo_rd_en <= '0';
							first_header_word <= x"0000";
							second_header_word <= x"0000";
							dout_to_GTP_wr <= '0';
							dout_to_GTP <= x"0000";
							dout_to_UDP_wr <= '0';
							dout_to_UDP <= x"0000";
							fifo_local_acquisition_data_transmit_state <= first_word_judge;
							J41_Tx_send_state <= idle;
						-- }
					end case;
				-- }

				--
				-- Data from GTP J41 (connected to the previous Virtex 5 node) is ready to send. This will
				-- send it to either this nodes serializing port (serializing), or the next node in the
				-- chain (GTP J40) or the PC (UDP), depending on the destinaion and this board's boardid.
			 	when data_from_former_Virtex_5_data_transmit_fifo =>
				-- {
					local_acquisition_data_fifo_rd_en <= '0';
					transfer_data_token <= transfer_data_token;
					one_packet_write_or_read_config_data_fifo(1) <= '0';
					one_packet_write_or_read_local_acquisition_fifo(1) <= '0';
					one_packet_write_or_read_J40_data_fifo(1) <= '0';
					case  fifo_former_Virtex_5_data_transmit_state is
						-- Determine if the first byte is already on output of FIFO or not.
						when first_header_word_judge =>
						-- {
							-- See the "FIFO note" under the header block comment for this process for full
							-- description of what is going on in this state.
							J40_data_fifo_rd_en <= '1';
							if ( J40_data_fifo_dout(15 downto 8) = x"81") then
								fifo_former_Virtex_5_data_transmit_state <= align_read_out_clock;
							else
								fifo_former_Virtex_5_data_transmit_state <= first_header_word_output;
							end if;
							first_header_word <= J40_data_fifo_dout;
							second_header_word <= x"0000";
							dout_to_GTP_wr <= '0';
							dout_to_UDP_wr <= '0';
							dout_to_serializing_wr <= '0';
							dout_to_GTP <= x"0000";
							dout_to_UDP <= x"0000";
							dout_to_serializing <= x"0000";
							increase_one_clock_for_config_data <= "00";
							increase_one_clock_for_acquisition_data <= "00";
							J41_Tx_send_state <= data_from_former_Virtex_5_data_transmit_fifo;
						--}
						-- Wait for header byte. Note that the FIFO output is delayed by 2, so the state after
						-- this will already have the second word.
						when first_header_word_output =>
						-- {
							J40_data_fifo_rd_en <= '1';
							if ( J40_data_fifo_dout(15 downto 8) = x"81") then
								fifo_former_Virtex_5_data_transmit_state <= valid_header_word_judge;
							else
								fifo_former_Virtex_5_data_transmit_state <= first_header_word_output;
							end if;
							first_header_word <= J40_data_fifo_dout;
							second_header_word <= x"0000";
							dout_to_GTP_wr <= '0';
							dout_to_UDP_wr <= '0';
							dout_to_serializing_wr <= '0';
							dout_to_GTP <= x"0000";
							dout_to_UDP <= x"0000";
							dout_to_serializing <= x"0000";
							increase_one_clock_for_config_data <= "00";
							increase_one_clock_for_acquisition_data <= "00";
							J41_Tx_send_state <= data_from_former_Virtex_5_data_transmit_fifo;
						--}
						when align_read_out_clock =>
						-- {
							J40_data_fifo_rd_en <= '1';
							first_header_word <= first_header_word;
							second_header_word <= x"0000";
							fifo_former_Virtex_5_data_transmit_state <= valid_header_word_judge;
							dout_to_GTP_wr <= '0';
							dout_to_UDP_wr <= '0';
							dout_to_serializing_wr <= '0';
							dout_to_GTP <= x"0000";
							dout_to_UDP <= x"0000";
							dout_to_serializing <= x"0000";
							increase_one_clock_for_config_data <= "00";
							increase_one_clock_for_acquisition_data <= "00";
							J41_Tx_send_state <= data_from_former_Virtex_5_data_transmit_fifo;
						--}
						-- Send out the first word to the proper destination, and save the second word from the FIFO.
						-- Sets remaining states to direct the data to the correct output.
						-- Next state will have valid packet body data.
						when valid_header_word_judge =>
						-- {
							first_header_word <= first_header_word;
							second_header_word <= J40_data_fifo_dout;
							J41_Tx_send_state <= data_from_former_Virtex_5_data_transmit_fifo;
							-- If from PC
							if ( first_header_word = x"8100") then
							-- {
								-- Check node is valid, otherwise garbage.
								if (J40_data_fifo_dout(15 downto 8) > x"00" and J40_data_fifo_dout(15 downto 8) < x"05" ) then
									-- If this is the destination node, send to serializing port
									if ( J40_data_fifo_dout (10 downto 8) = boardid ) then
										-- Pause FIFO output to send second header word.
										J40_data_fifo_rd_en <= '0';
										increase_one_clock_for_config_data <= "01";
										-- Send this data out to serializing
										--   - strip out the source and destination addresses.
										dout_to_serializing_wr <= '1';
										dout_to_serializing <= first_header_word(15 downto 8) & J40_data_fifo_dout(7 downto 0); --strip source/destination
										-- Echo back the config data to the computer, changing source and destination.
										dout_to_GTP_wr <= '1';
										dout_to_GTP <= first_header_word(15 downto 8) & "00000" & boardid; -- I am the source
										echo_back_config_data <= x"00" & J40_data_fifo_dout(7 downto 0); -- PC is the destination
										dout_to_UDP_wr <= '0';
										dout_to_UDP <= x"0000";

										fifo_former_Virtex_5_data_transmit_state <= serializing_config_data_for_current_board_transfer;
									-- If the destination is another node (not THIS node).
									else
										-- If data from the PC has tranversed all the nodes back to node 001, discard it. It is done.
										-- Note this occurs after the check to see if this packet is destined for this board. This is important
										-- because configuration data from the PC intended for boardid="001" actually traverses the whole loop,
										-- so that a special case doesn't have to be writen to route from the UDP output to the serializing.
										if ( boardid = "001") then 
											J40_data_fifo_rd_en <= '1';
											dout_to_GTP_wr <= '0';
											dout_to_GTP <= x"0000";
											dout_to_UDP_wr <= '0';
											dout_to_serializing_wr <= '0';
											dout_to_UDP <= x"0000";
											dout_to_serializing <= x"0000";
											increase_one_clock_for_config_data <= "00";
											fifo_former_Virtex_5_data_transmit_state <= error_data_process; -- Dump this packet, even though not an error.
										-- If this packet truly needs to go to another node, then pass to the next node.
										else
											-- Pause FIFO output to send second header word.
											J40_data_fifo_rd_en <= '0';
											increase_one_clock_for_config_data <= "01";
											dout_to_GTP_wr <= '1';
											dout_to_GTP <= first_header_word;
											dout_to_UDP_wr <= '0';
											dout_to_serializing_wr <= '0';
											dout_to_UDP <= x"0000";
											dout_to_serializing <= x"0000";
											fifo_former_Virtex_5_data_transmit_state <= not_the_current_board_config_data_transmit_former_board_data;
										end if;
									end if;
								-- Invalid destination (source is PC). Dump the packet, it's an error.
								else
									J40_data_fifo_rd_en <= '1';
									dout_to_GTP_wr <= '0';
									dout_to_UDP_wr <= '0';
									dout_to_serializing_wr <= '0';
									dout_to_GTP <= x"0000";
									dout_to_UDP <= x"0000";
									dout_to_serializing <= x"0000";
									increase_one_clock_for_config_data <= "00";
									fifo_former_Virtex_5_data_transmit_state <= error_data_process;
								end if;
							-- }
							-- Source is a node
							elsif (first_header_word > x"8100" and first_header_word < x"8105") then
							-- {
								dout_to_serializing_wr <= '0';
								dout_to_serializing <= x"0000";
								-- Destination is the PC, as it should be.
								if ( J40_data_fifo_dout(15 downto 8) = x"00") then
								-- acquisition data (or any data from a node to PC)
									-- Master node sends via UDP to PC
									if ( boardid = "001") then
										dout_to_UDP_wr <= '1';
										dout_to_UDP <= first_header_word;
										dout_to_GTP_wr <= '0';
										dout_to_GTP <= x"0000";
									-- Non-Master nodes pass to adjacent nodes.
									else
										dout_to_GTP_wr <= '1';
										dout_to_GTP <= first_header_word;
										dout_to_UDP_wr <= '0';
										dout_to_UDP <= x"0000";
									end if;
									-- Pause FIFO output to send second header word.
									J40_data_fifo_rd_en <= '0';
									fifo_former_Virtex_5_data_transmit_state <= acquisition_data_transmit_former_board;
									increase_one_clock_for_acquisition_data <= "01";
								-- If source is node, and destination is not the PC, dump the packet. It is an error.
								else
									J40_data_fifo_rd_en <= '1';
									dout_to_GTP_wr <= '0';
									dout_to_UDP_wr <= '0';
									dout_to_GTP <= x"0000";
									dout_to_UDP <= x"0000";
									dout_to_serializing <= x"0000";
									fifo_former_Virtex_5_data_transmit_state <= error_data_process;
								end if;
							-- }
							-- Invalid source, dump packet.
							else
								J40_data_fifo_rd_en <= '1';
								dout_to_GTP_wr <= '0';
								dout_to_UDP_wr <= '0';
								dout_to_serializing_wr <= '0';
								dout_to_GTP <= x"0000";
								dout_to_UDP <= x"0000";
								dout_to_serializing <= x"0000";
								fifo_former_Virtex_5_data_transmit_state <= error_data_process;
							end if;
						-- }
						-- Serializing data from GTP J40, and also echoing it back to the PC over GTP J41
						-- Handles second word, and body data.
						when serializing_config_data_for_current_board_transfer =>
						-- {
							dout_to_UDP_wr <= '0';
							dout_to_UDP <= x"0000";
							case increase_one_clock_for_config_data is
								-- Delay FIFO output while writing second header word out to echo response.
								when "01" =>
									J40_data_fifo_rd_en <= '1';
									dout_to_serializing_wr <= '0';
									dout_to_serializing <= x"0000";
									dout_to_GTP_wr <= '1';
									dout_to_GTP <= echo_back_config_data; -- Second word of response
									fifo_former_Virtex_5_data_transmit_state <= serializing_config_data_for_current_board_transfer;
									J41_Tx_send_state <= data_from_former_Virtex_5_data_transmit_fifo;
									increase_one_clock_for_config_data <= "11";
								-- Normal state, sending body.
								when "11" =>
									dout_to_serializing_wr <= '1';
									dout_to_serializing <= J40_data_fifo_dout;
									-- echo back to the computer
									dout_to_GTP_wr <= '1';
									dout_to_GTP <= J40_data_fifo_dout;
									if (J40_data_fifo_dout(15 downto 8) = x"FF" or J40_data_fifo_dout(7 downto 0) = x"FF") then
										J40_data_fifo_rd_en <= '0';
										fifo_former_Virtex_5_data_transmit_state <= first_header_word_judge;
										J41_Tx_send_state <= idle;
										increase_one_clock_for_config_data <= "00";
									else
										J40_data_fifo_rd_en <= '1';
										fifo_former_Virtex_5_data_transmit_state <= serializing_config_data_for_current_board_transfer;
										J41_Tx_send_state <= data_from_former_Virtex_5_data_transmit_fifo;
										increase_one_clock_for_config_data <= "11";
									end if;
								when others =>
									null;
							end case;
						-- }
						-- Passing configuraiton data (data from PC) from this node to the next node.
						-- Handles second word, and body data.
						when not_the_current_board_config_data_transmit_former_board_data =>
						-- {
							-- Transfer the configuration data to the GTP interface
							dout_to_UDP_wr <= '0';
							dout_to_UDP <= x"0000";
							dout_to_serializing_wr <= '0';
							dout_to_serializing <= x"0000";
							case increase_one_clock_for_config_data is
								-- Delay FIFO output while writing second header word.
								when "01" =>
									J40_data_fifo_rd_en <= '1';
									dout_to_GTP_wr <= '1';
									dout_to_GTP <= second_header_word;
									fifo_former_Virtex_5_data_transmit_state <= not_the_current_board_config_data_transmit_former_board_data;
									J41_Tx_send_state <= data_from_former_Virtex_5_data_transmit_fifo;
									increase_one_clock_for_config_data <= "11";
								-- Normal state, sending body.
								when "11" =>
									first_header_word <= x"0000";
									second_header_word <= x"0000";
									dout_to_GTP_wr <= '1';
									dout_to_GTP <= J40_data_fifo_dout;
									-- must transfer the end signal
									if ( J40_data_fifo_dout (15 downto 8) = x"FF" or J40_data_fifo_dout( 7 downto 0) = x"FF") then
										J40_data_fifo_rd_en <= '0';
										fifo_former_Virtex_5_data_transmit_state <= first_header_word_judge;
										J41_Tx_send_state <= idle;
										increase_one_clock_for_config_data <= "00";
									else
										J40_data_fifo_rd_en <= '1';
										fifo_former_Virtex_5_data_transmit_state <= not_the_current_board_config_data_transmit_former_board_data;
										J41_Tx_send_state <= data_from_former_Virtex_5_data_transmit_fifo;
										increase_one_clock_for_config_data <= "11";
									end if;
								when others =>
									null;
							end case;
						-- }
						-- Passing acquisition (or other) data (data from a node to PC) to either the next
						-- node via GTP J40 to the PC via UDP if this node is master (boardid="001").
						-- Handles second word, and body data.
						when acquisition_data_transmit_former_board =>
						-- {
							dout_to_serializing_wr <= '0';
							dout_to_serializing <= x"0000";
							case increase_one_clock_for_acquisition_data  is
								-- Delayed FIFO output while writing second header word.
								when "01" =>
								-- {
									J40_data_fifo_rd_en <= '1';
									if ( boardid = "001") then
										dout_to_UDP_wr <= '1';
										dout_to_UDP <= second_header_word;
										dout_to_GTP_wr <= '0';
										dout_to_GTP <= x"0000";
									else
										dout_to_GTP_wr <= '1';
										dout_to_GTP <= second_header_word;
										dout_to_UDP_wr <= '0';
										dout_to_UDP <= x"0000";
									end if;
									increase_one_clock_for_acquisition_data <= "11";
									fifo_former_Virtex_5_data_transmit_state <= acquisition_data_transmit_former_board;
									J41_Tx_send_state <= data_from_former_Virtex_5_data_transmit_fifo;
								-- }
								-- Normal state, sending body.
								when "11" =>
									first_header_word <= x"0000";
									second_header_word <= x"0000";
									-- Route to PC or next node
									if ( boardid = "001") then
										dout_to_UDP_wr <= '1';
										dout_to_UDP <= J40_data_fifo_dout;
										dout_to_GTP_wr <= '0';
										dout_to_GTP <= x"0000";
									else
										dout_to_GTP_wr <= '1';
										dout_to_GTP <= J40_data_fifo_dout;
										dout_to_UDP_wr <= '0';
										dout_to_UDP <= x"0000";
									end if;
									-- Detect End of Packet
									if ((J40_data_fifo_dout(15 downto 8) = x"FF") or (J40_data_fifo_dout(7 downto 0) = x"FF")) then
										J40_data_fifo_rd_en <= '0';
										fifo_former_Virtex_5_data_transmit_state <= first_header_word_judge;
										J41_Tx_send_state <= idle;
										increase_one_clock_for_acquisition_data <= "00";
									 else
										J40_data_fifo_rd_en <= '1';
										fifo_former_Virtex_5_data_transmit_state <= acquisition_data_transmit_former_board;
										J41_Tx_send_state <= data_from_former_Virtex_5_data_transmit_fifo;
										 increase_one_clock_for_acquisition_data <= "11";	
									end if;
								when others =>
									null;
							end case;
						-- }
						-- Clear out bad packet (or end-of-chain packet) from FIFO
						when error_data_process =>
						-- {
							first_header_word <= x"0000";
							second_header_word <= x"0000";
							dout_to_GTP_wr <= '0';
							dout_to_UDP_wr <= '0';
							dout_to_serializing_wr <= '0';
							dout_to_GTP <= x"0000";
							dout_to_UDP <= x"0000";
							dout_to_serializing <= x"0000";
							if ( J40_data_fifo_dout(15 downto 8) = x"FF" or J40_data_fifo_dout(7 downto 0) = x"FF") then
								J40_data_fifo_rd_en <= '0';
								fifo_former_Virtex_5_data_transmit_state <= first_header_word_judge;
								J41_Tx_send_state <= idle;
							else
								J40_data_fifo_rd_en <= '1';
								fifo_former_Virtex_5_data_transmit_state <= error_data_process;
								J41_Tx_send_state <= data_from_former_Virtex_5_data_transmit_fifo;
							end if;
						-- }
					end case;
				-- }

				--
				-- Data from the PC is ready to send (config data). This will send it to the GTP J40 to
				-- the next node. If the data is destined for the serializer on this board, it will
				-- first make a loop through the nodes via the GTP interfaces. This was done to keep
				-- the system simple. It is expected this will add minimal traffic.
				when UDP_config_data_transmit =>
				-- {
					dout_to_serializing_wr <= '0';
					dout_to_serializing <= x"0000";
					dout_to_UDP_wr <= '0';
					dout_to_UDP <= x"0000";
					one_packet_write_or_read_config_data_fifo(1) <= '0';
					one_packet_write_or_read_J40_data_fifo(1) <= '0';
					one_packet_write_or_read_local_acquisition_fifo(1) <= '0';
					case config_data_transfer_state is
						-- Determine if the first byte is already on output of FIFO or not.
						when first_word_judge =>
						-- {
							-- See the "FIFO note" under the header block comment for this process for full
							-- description of what is going on in this state.
							config_data_fifo_rd_en <= '1';
							if (config_data_fifo_dout = x"8100") then
								config_data_transfer_state <= align_one_clock;
							else
								config_data_transfer_state <= first_word_output;
							end if;
							dout_to_GTP_wr <= '0';
							dout_to_GTP <= x"0000";
							first_header_word <= config_data_fifo_dout;
							second_header_word <= x"0000";
							J41_Tx_send_state <= UDP_config_data_transmit;
						-- }
						-- Wait for header byte. Note that the FIFO output is delayed by 2, so the state after
						-- this will already have the second word.
						when first_word_output =>
						-- {
							if (config_data_fifo_dout = x"8100") then
								config_data_fifo_rd_en <= '0'; -- Stop fifo output to give a chance to send second word.
								config_data_transfer_state <= valid_data_judge;
							else
								config_data_fifo_rd_en <= '1';
								config_data_transfer_state <= first_word_output;
							end if;
							dout_to_GTP_wr <= '0';
							dout_to_GTP <= x"0000";
							first_header_word <= config_data_fifo_dout;
							second_header_word <= x"0000";
							J41_Tx_send_state <= UDP_config_data_transmit;
						-- }
						-- Momentarily wait before FIFO output is valid with second word.
						when align_one_clock =>
						-- {
							config_data_fifo_rd_en <= '0'; -- Stop fifo output to give a chance to send second word.
							dout_to_GTP_wr <= '0';
							dout_to_GTP <= x"0000";
							first_header_word <= first_header_word;
							second_header_word <= second_header_word;
							config_data_transfer_state <= valid_data_judge;
							J41_Tx_send_state <= UDP_config_data_transmit;
						-- }
						-- Sends out the first word, and saves the second word from the FIFO.
						--  - Assumes that 2 states ago the fifo rd was enabled, but previous state it was NOT.
						--    Therefore, have data to read this state, but not the next state.
						--  - Enables rd so that after the second word is sent next packet, we can read the
						--    fifo output and send it directly out.
						when valid_data_judge =>
						-- {
							config_data_fifo_rd_en <= '1';
							first_header_word <= first_header_word;
							second_header_word <= config_data_fifo_dout;
							if (first_header_word = x"8100")
							   and (config_data_fifo_dout(15 downto 8) > x"00") and config_data_fifo_dout(15 downto 8) < x"05" then
								dout_to_GTP_wr <= '1';
								dout_to_GTP <= first_header_word;
								config_data_transfer_state <= save_second_word;
							else
								dout_to_GTP_wr <= '0';
								dout_to_GTP <= x"0000";
								config_data_transfer_state <= error_data_process;
							end if;
							J41_Tx_send_state <= UDP_config_data_transmit;
						-- }
						-- Sends the second word out. No new data to send yet.
						--  - Assumes that 2 states ago the fifo rd was NOT enabled.
						--    Therefore, no new data to read.
						--  - Previous state the rd WAS enabled, which will be the beginning of the body streaming
						--    from the fifo
						when save_second_word =>
						-- {
							first_header_word <= first_header_word;
							second_header_word <= second_header_word;
							config_data_fifo_rd_en <= '1';
							dout_to_GTP_wr <= '1';
							dout_to_GTP <= second_header_word;
							config_data_transfer_state <= body_transfer;
							J41_Tx_send_state <= UDP_config_data_transmit;
						-- }
						-- Send the rest of the body of the packet, stop on x"FF" in upper or lower byte.
						when body_transfer =>
						-- {
							first_header_word <= x"0000";
							second_header_word <= x"0000";
							dout_to_GTP_wr <= '1';
							dout_to_GTP <= config_data_fifo_dout;
							if ( config_data_fifo_dout(15 downto 8) = x"FF" or config_data_fifo_dout(7 downto 0) = x"FF") then
								config_data_fifo_rd_en <= '0';
								config_data_transfer_state <= end_process;
							else
								config_data_fifo_rd_en <= '1';
								config_data_transfer_state <= body_transfer;
							end if;
							J41_Tx_send_state <= UDP_config_data_transmit;
						-- }
						-- Clear out a bad packet from the FIFO
						when error_data_process =>
						-- {
							first_header_word <= x"0000";
							second_header_word <= x"0000";
							dout_to_GTP_wr <= '0';
							dout_to_GTP <= x"0000";
							if ( config_data_fifo_dout(15 downto 8) = x"FF" or config_data_fifo_dout(7 downto 0) = x"FF") then
								config_data_fifo_rd_en <= '0';
								config_data_transfer_state <= end_process;
							else
								config_data_fifo_rd_en <= '1';
								config_data_transfer_state <= error_data_process;
							end if;
							J41_Tx_send_state <= UDP_config_data_transmit;
						-- }
						-- Let the FIFO finish outputting data.
						when end_process =>
						-- {
							config_data_fifo_rd_en <= '0';
							first_header_word <= x"0000";
							second_header_word <= x"0000";
							dout_to_GTP_wr <= '0';
							dout_to_GTP <= x"0000";
							config_data_transfer_state <= first_word_judge;
							J41_Tx_send_state <= idle;
						-- }
				-- }
				end case;
			end case;
		end if;
	end process;
end Behavioral;
