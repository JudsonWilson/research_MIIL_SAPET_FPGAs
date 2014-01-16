----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:27:52 11/14/2012 
-- Design Name: 
-- Module Name:    acquisition_module - Behavioral 
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

use work.sapet_packets.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity acquisition_module is
	port(
	bug_in_acqusition_process			: out std_logic;
	bug_in_acqusition_write_fifo 			: out std_logic;
	bug_in_write_number_over_flow			: out std_logic;
	bug_in_xx_8102_xx_in_acquisition          : out std_logic;
		acquisition_data_number			: out std_logic_vector(15 downto 0);
		reset 					: in std_logic;
		boardid					: in std_logic_vector(2 downto 0);
		clk_50MHz				: in std_logic;
		-- Interface with Daisychain
		local_acquisition_data_dout_to_Daisychain_wr : out std_logic;
		local_acquisition_data_dout_to_Daisychain : out std_logic_vector(15 downto 0);
		Rx0					: in std_logic;
		Rx1 					: in std_logic
--		Rx					: in std_logic_vector(1 downto 0)
);
end acquisition_module;

architecture Behavioral of acquisition_module is
	signal local_acquisition_data_dout_to_Daisychain_wr_i : std_logic;
	signal local_acquisition_data_dout_to_Daisychain_i : std_logic_vector(15 downto 0);
	signal bug_bit					: std_logic_vector(2 downto 0);
	signal bug_bit1					: std_logic_vector(2 downto 0);
	signal formal_word1				: std_logic_vector(15 downto 0);
	signal formal_word2				: std_logic_vector(15 downto 0);
	signal bug_bit2					: std_logic_vector(1 downto 0);
	signal bug_bit3 				: std_logic_vector(2 downto 0);
	signal formal_word3				: std_logic_vector(15 downto 0);


	-- global
	signal reset_fifo				: std_logic;
	signal reset_fifo_vec				: std_logic_vector(3 downto 0);
	signal acquisition_data_number_0		: std_logic_vector(15 downto 0);
	-- local_acquisition_data_fifo: 0-47
	signal bit_to_bytes				: std_logic_vector(7 downto 0);

	type receive_state_type is ( idle, data_receiving);
	signal receive_state 				: receive_state_type := idle;

	type local_acquisition_data_interface is array (0 to 1) of std_logic_vector(15 downto 0);
	type serializing_to_parallel is array (0 to 47) of std_logic_vector(7 downto 0);
	signal bit_to_byte : serializing_to_parallel;
	signal local_acquisition_data_din : local_acquisition_data_interface;
	signal local_acquisition_data_dout : local_acquisition_data_interface;
	signal first_word			: std_logic_vector(15 downto 0);
	signal second_word			: std_logic_vector(15 downto 0);


	type acquisition_fifo_control_variable_type is array (0 to 1) of std_logic;
	signal local_acquisition_data_wr   : acquisition_fifo_control_variable_type := ('0', '0');
	signal local_acquisition_data_rd	: acquisition_fifo_control_variable_type := (others => '0');
	signal local_acquisition_data_empty : acquisition_fifo_control_variable_type := (others => '0');
	type counter_for_fifo_type is array ( 0 to 1) of std_logic_vector(9 downto 0);
	signal rd_data_counter : counter_for_fifo_type := (others => "00" & x"00");
	signal wr_data_counter : counter_for_fifo_type := (others => "00" & x"00");
	type write_or_read_one_packet_variable_type is array (0 to 47) of std_logic_vector(1 downto 0);
	signal write_or_read_one_packet : write_or_read_one_packet_variable_type;
	signal local_acquisition_data_write_number : local_acquisition_data_interface;

	type local_acquisition_data_receving_state_value is ( idle, start_signal_receiving, add_from_and_to_address, normal_receiving_data, clear_wr_data_counter);
	type local_acquisition_data_receving_array is array(1 downto 0) of local_acquisition_data_receving_state_value;
	signal local_acquisition_data_receving : local_acquisition_data_receving_array;
	
	type send_local_aquisition_data_status_type is (idle, local_acquisition_data_transfer_fifo_0, local_acquisition_data_transfer_fifo_1);
	signal send_local_aquisition_data_status : send_local_aquisition_data_status_type := idle;
	type transfering_local_acquisition_data_type is (first_word_judge, first_word_output, second_word_out, align_one_clock, valid_data_judge, save_second_word, acquisition_data_judge_and_transfer, error_data_process, end_process); 
	signal transfering_local_acquisition_data : transfering_local_acquisition_data_type := first_word_judge;



	signal transfer_local_data_token 	: std_logic_vector(7 downto 0);
	type send_to_Daisychain_status_type is array (0 to 1) of std_logic;
	signal send_to_Daisychain_status  	: send_to_Daisychain_status_type := ('0', '0');

	-- Actual depth is 1023 (not 1024!). Decrease by 5 for increased robustness handling off-by-1 errors, etc.
	constant fifo_word_depth : integer := 1018;
	-- The write depth must be less than this number to ensure a full packet can be added to the FIFO.
	constant fifo_maximum_used_bytes_for_new_packet : integer := fifo_word_depth - (max_packet_size_bytes)/2;

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
	component fifo_1024_16_counter IS
		port (
			     rst: IN std_logic;
			     wr_clk: IN std_logic;
			     rd_clk: IN std_logic;
			     din: IN std_logic_VECTOR(15 downto 0);
			     wr_en: IN std_logic;
			     rd_en: IN std_logic;
			     dout: OUT std_logic_VECTOR(15 downto 0);
			     full: OUT std_logic;
			     empty: OUT std_logic;
			     rd_data_count: OUT std_logic_VECTOR(9 downto 0);
			     wr_data_count: OUT std_logic_VECTOR(9 downto 0)
		     );
	end component;

begin
	acquisition_data_number <= acquisition_data_number_0;
	local_acquisition_data_dout_to_Daisychain_wr <= local_acquisition_data_dout_to_Daisychain_wr_i;
	local_acquisition_data_dout_to_Daisychain <= local_acquisition_data_dout_to_Daisychain_i;

	-------------------------------------------------------------------------------------------------------------
	-- Global logics
	-------------------------------------------------------------------------------------------------------------
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


	----------------------------------------------------------------------------------------------------------
	-- Rx0: To get the local acquisition data
	-- Fifo: 512 - 2 bytes
	----------------------------------------------------------------------------------------------------------
	Local_acquisition_data_from_Rx0_to_Daisychain: fifo_1024_16_counter
	port map (
			rst		=> reset_fifo,
			wr_clk		=> clk_50MHz,
			rd_clk		=> clk_50MHz,
			wr_en		=> local_acquisition_data_wr(0),
			rd_en		=> local_acquisition_data_rd(0),
			din		=> local_acquisition_data_din(0),
			dout		=> local_acquisition_data_dout(0),
			full		=> open,
			empty		=> local_acquisition_data_empty(0),
			rd_data_count   => rd_data_counter(0),
			wr_data_count   => wr_data_counter(0)
		);

	Inst_acquisition_data_number: process( reset, clk_50MHz)
	begin
		if ( reset = '1') then
			acquisition_data_number_0 <= x"0000";
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			if ( local_acquisition_data_wr(0) = '1') then
				if(local_acquisition_data_din(0)(15 downto 8) = x"FF") then
					acquisition_data_number_0 <= acquisition_data_number_0 + x"01";
				else
					acquisition_data_number_0 <= acquisition_data_number_0 + x"02";
				end if;
			end if;
		end if;
	end process;


	Rx0_Inst_get_local_acquisition_data_Rx0: process( clk_50MHz, reset)
	begin
	-- {
		if ( reset = '1' ) then
			local_acquisition_data_wr(0) <= '0';
			local_acquisition_data_din(0) <= x"0000";
			bit_to_byte(0) <= x"00";
			local_acquisition_data_receving(0) <= idle;
			write_or_read_one_packet(0)(0) <= '0';
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			case local_acquisition_data_receving(0) is
				when idle =>
					write_or_read_one_packet(0)(0) <= '0';
					local_acquisition_data_wr(0) <= '0';
					local_acquisition_data_din(0) <= x"0000";
					bit_to_byte(0) <= x"00";
					if ( Rx0 = '0') then
						local_acquisition_data_receving(0) <= start_signal_receiving;
					else
						local_acquisition_data_receving(0) <= idle;
					end if;
				when start_signal_receiving =>
				-- {
					write_or_read_one_packet(0)(0) <= '0';
					case bit_to_byte(0) is
						when x"00" =>
							if (Rx0 = '1') then
								local_acquisition_data_din(0)(15 downto 8) <= x"01";
							else
								local_acquisition_data_din(0)(15 downto 8) <= x"00";
							end if;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= start_signal_receiving;
						when x"01" =>
							if ( Rx0 = '1') then
								local_acquisition_data_din(0)(15 downto 8) <= local_acquisition_data_din(0)(15 downto 8) or x"02";
							else
								local_acquisition_data_din(0)(15 downto 8) <= local_acquisition_data_din(0)(15 downto 8);

							end if;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= start_signal_receiving;
						when x"02" =>
							if ( Rx0 = '1') then
								local_acquisition_data_din(0)(15 downto 8) <= local_acquisition_data_din(0)(15 downto 8) or x"04";
							else
								local_acquisition_data_din(0)(15 downto 8) <= local_acquisition_data_din(0)(15 downto 8);
							end if;
							local_acquisition_data_wr(0) <= '0';
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
							local_acquisition_data_receving(0) <= start_signal_receiving;
						when x"03" =>
							if (Rx0 = '1') then
								local_acquisition_data_din(0)(15 downto 8) <= local_acquisition_data_din(0)(15 downto 8) or x"08";
							else
								local_acquisition_data_din(0)(15 downto 8) <= local_acquisition_data_din(0)(15 downto 8);
							end if;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= start_signal_receiving;
						when x"04" =>
							if ( Rx0 = '1') then
								local_acquisition_data_din(0)(15 downto 8) <= local_acquisition_data_din(0)(15 downto 8) or x"10";
							else
								local_acquisition_data_din(0)(15 downto 8) <= local_acquisition_data_din(0)(15 downto 8);
							end if;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= start_signal_receiving;
						when x"05" =>
							if ( Rx0 = '1') then
								local_acquisition_data_din(0)(15 downto 8) <= local_acquisition_data_din(0)(15 downto 8) or x"20";
							else
								local_acquisition_data_din(0)(15 downto 8) <= local_acquisition_data_din(0)(15 downto 8);
							end if;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= start_signal_receiving;
						when x"06" =>
							if ( Rx0 = '1') then
								local_acquisition_data_din(0)(15 downto 8) <= local_acquisition_data_din(0)(15 downto 8) or x"40";
							else
								local_acquisition_data_din(0)(15 downto 8) <= local_acquisition_data_din(0)(15 downto 8);
							end if;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= start_signal_receiving;
						when x"07" =>
							if ( Rx0 = '1') then
								local_acquisition_data_din(0)(15 downto 8) <= local_acquisition_data_din(0)(15 downto 8) or x"80";
							else
								local_acquisition_data_din(0)(15 downto 8) <= local_acquisition_data_din(0)(15 downto 8);
							end if;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= start_signal_receiving;
						when x"08" =>
							if is_packet_start_token(local_acquisition_data_din(0)(15 downto 8)) then
								-- From address: to add the current Virtex-5 board id
								-- add the ID of the Virtex-5 board
								local_acquisition_data_din(0)(7 downto 0) <= "00000" & boardid;
								if (wr_data_counter(0) <= fifo_maximum_used_bytes_for_new_packet) then
									local_acquisition_data_wr(0) <= '1';
									bit_to_byte(0) <= bit_to_byte(0) + x"01";
									local_acquisition_data_receving(0) <= start_signal_receiving;
								else
									local_acquisition_data_wr(0) <= '0';
									bit_to_byte(0) <= x"00";
									local_acquisition_data_receving(0) <= clear_wr_data_counter;
								end if;
							else
								-- It is not an valid data packet. Discard and wait for another data packet.
								local_acquisition_data_wr(0) <= '0';
								local_acquisition_data_din(0) <= x"0000";
								bit_to_byte(0) <= x"00";
								local_acquisition_data_receving(0) <= idle;
							end if;
						when x"09" =>
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_din(0) <= x"0000";
							-- wait for the Rx0 = '0' to start receiving.
							if ( Rx0 = '0') then
								bit_to_byte(0) <= x"00";
								local_acquisition_data_receving(0) <= add_from_and_to_address; 
							else
								bit_to_byte(0) <= bit_to_byte(0);
								local_acquisition_data_receving(0) <= start_signal_receiving;
							end if;
						when others =>
							null;
					end case;
				-- }
				when add_from_and_to_address =>
				-- {
					write_or_read_one_packet(0)(0) <= '0';
					case bit_to_byte(0) is
						when x"00" =>
							if (Rx0 = '1') then
								local_acquisition_data_din(0)(7 downto 0) <= x"01";
							else
								local_acquisition_data_din(0)(7 downto 0) <= x"00";
							end if;
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= add_from_and_to_address;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
						when x"01" =>
							if ( Rx0 = '1') then
								local_acquisition_data_din(0)(7 downto 0) <= local_acquisition_data_din(0)(7 downto 0) or x"02";
							else
								local_acquisition_data_din(0)(7 downto 0) <= local_acquisition_data_din(0)(7 downto 0);
							end if;
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= add_from_and_to_address;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
						when x"02" =>
							if ( Rx0 = '1') then
								local_acquisition_data_din(0)(7 downto 0) <= local_acquisition_data_din(0)(7 downto 0) or x"04";
							else
								local_acquisition_data_din(0)(7 downto 0) <= local_acquisition_data_din(0)(7 downto 0);
							end if;
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= add_from_and_to_address;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
						when x"03" =>
							if (Rx0 = '1') then
								local_acquisition_data_din(0)(7 downto 0) <= local_acquisition_data_din(0)(7 downto 0) or x"08";
							else
								local_acquisition_data_din(0)(7 downto 0) <= local_acquisition_data_din(0)(7 downto 0);
							end if;
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= add_from_and_to_address;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
						when x"04" =>
							if ( Rx0 = '1') then
								local_acquisition_data_din(0)(7 downto 0) <= local_acquisition_data_din(0)(7 downto 0) or x"10";
							else
								local_acquisition_data_din(0)(7 downto 0) <= local_acquisition_data_din(0)(7 downto 0);
							end if;
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= add_from_and_to_address;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
						when x"05" =>
							if ( Rx0 = '1') then
								local_acquisition_data_din(0)(7 downto 0) <= local_acquisition_data_din(0)(7 downto 0) or x"20";
							else
								local_acquisition_data_din(0)(7 downto 0) <= local_acquisition_data_din(0)(7 downto 0);
							end if;
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= add_from_and_to_address;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
						when x"06" =>
							if ( Rx0 = '1') then
								local_acquisition_data_din(0)(7 downto 0) <= local_acquisition_data_din(0)(7 downto 0) or x"40";
							else
								local_acquisition_data_din(0)(7 downto 0) <= local_acquisition_data_din(0)(7 downto 0);
							end if;
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= add_from_and_to_address;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
						when x"07" =>
							if ( Rx0 = '1') then
								local_acquisition_data_din(0)(7 downto 0) <= local_acquisition_data_din(0)(7 downto 0) or x"80";
							else
								local_acquisition_data_din(0)(7 downto 0) <= local_acquisition_data_din(0)(7 downto 0);
							end if;
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= add_from_and_to_address;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
						when x"08" =>
							-- Add the destination ID.
							local_acquisition_data_wr(0) <= '1';
							local_acquisition_data_din(0)(15 downto 8) <= x"00";
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
							local_acquisition_data_receving(0) <= add_from_and_to_address;
						when x"09" =>
							if (Rx0 = '0') then
								bit_to_byte(0) <= x"00";
								local_acquisition_data_receving(0) <= normal_receiving_data;
							else
								bit_to_byte(0) <= bit_to_byte(0);
								local_acquisition_data_receving(0) <= add_from_and_to_address;
							end if;
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_din(0) <= x"0000";
						when others =>
							null;
					end case;
				-- }
				when normal_receiving_data =>
				-- { 
					case bit_to_byte(0) is
						when x"00" =>
							write_or_read_one_packet(0)(0) <= '0';
							if (Rx0 = '1') then
								local_acquisition_data_din(0)(15 downto 8)<= x"01";
							else
								local_acquisition_data_din(0)(15 downto 8)<= x"00";
							end if;
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= normal_receiving_data;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
						when x"01" =>
							write_or_read_one_packet(0)(0) <= '0';
							if ( Rx0 = '1') then
								local_acquisition_data_din(0)(15 downto 8)<= local_acquisition_data_din(0)(15 downto 8) or x"02";
							else
								local_acquisition_data_din(0)(15 downto 8)<= local_acquisition_data_din(0)(15 downto 8);
							end if;
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= normal_receiving_data;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
						when x"02" =>
							write_or_read_one_packet(0)(0) <= '0';
							if ( Rx0 = '1') then
								local_acquisition_data_din(0)(15 downto 8)<= local_acquisition_data_din(0)(15 downto 8) or x"04";
							else
								local_acquisition_data_din(0)(15 downto 8)<= local_acquisition_data_din(0)(15 downto 8);
							end if;
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= normal_receiving_data;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
						when x"03" =>
							write_or_read_one_packet(0)(0) <= '0';
							if (Rx0 = '1') then
								local_acquisition_data_din(0)(15 downto 8)<= local_acquisition_data_din(0)(15 downto 8) or x"08";
							else
								local_acquisition_data_din(0)(15 downto 8)<= local_acquisition_data_din(0)(15 downto 8);
							end if;
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= normal_receiving_data;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
						when x"04" =>
							write_or_read_one_packet(0)(0) <= '0';
							if ( Rx0 = '1') then
								local_acquisition_data_din(0)(15 downto 8)<= local_acquisition_data_din(0)(15 downto 8) or x"10";
							else
								local_acquisition_data_din(0)(15 downto 8)<= local_acquisition_data_din(0)(15 downto 8);
							end if;
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= normal_receiving_data;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
						when x"05" =>
							write_or_read_one_packet(0)(0) <= '0';
							if ( Rx0 = '1') then
								local_acquisition_data_din(0)(15 downto 8)<= local_acquisition_data_din(0)(15 downto 8) or x"20";
							else
								local_acquisition_data_din(0)(15 downto 8)<= local_acquisition_data_din(0)(15 downto 8);
							end if;
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= normal_receiving_data;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
						when x"06" =>
							write_or_read_one_packet(0)(0) <= '0';
							if ( Rx0 = '1') then
								local_acquisition_data_din(0)(15 downto 8)<= local_acquisition_data_din(0)(15 downto 8) or x"40";
							else
								local_acquisition_data_din(0)(15 downto 8)<= local_acquisition_data_din(0)(15 downto 8);
							end if;
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= normal_receiving_data;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
						when x"07" =>
							write_or_read_one_packet(0)(0) <= '0';
							if ( Rx0 = '1') then
								local_acquisition_data_din(0)(15 downto 8)<= local_acquisition_data_din(0)(15 downto 8) or x"80";
							else
								local_acquisition_data_din(0)(15 downto 8)<= local_acquisition_data_din(0)(15 downto 8);
							end if;
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= normal_receiving_data;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
						when x"08" =>
							-- The end signal for the whole packet is 0xFF.
						        -- As soon as the 0xFF is coming, another data packet will be save to another fifo.
							if ( local_acquisition_data_din(0)(15 downto 8)= x"FF") then
								-- Leave this process to wait for another data packet.
								local_acquisition_data_din(0)(15 downto 0) <= x"FF00";
								local_acquisition_data_wr(0) <= '1';
								bit_to_byte(0) <= x"00";
								write_or_read_one_packet(0)(0) <= '1';
								local_acquisition_data_receving(0) <= idle;
							else
								local_acquisition_data_wr(0) <= '0';
								local_acquisition_data_din(0) <= local_acquisition_data_din(0);
								write_or_read_one_packet(0)(0) <= '0';
								bit_to_byte(0) <= bit_to_byte(0) + x"01";
								local_acquisition_data_receving(0) <= normal_receiving_data;
							end if;
						when x"09" =>
							-- !!!!
							-- If there is no data input, the process will stay here untill the new data incoming.
							write_or_read_one_packet(0)(0) <= '0';
							local_acquisition_data_din(0) <= local_acquisition_data_din(0);
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= normal_receiving_data;
							if (Rx0 = '0') then
								bit_to_byte(0) <= bit_to_byte(0) + x"01";
							else
								bit_to_byte(0) <= bit_to_byte(0);
							end if;
						when x"0a" => 
							write_or_read_one_packet(0)(0) <= '0';
							if (Rx0 = '1') then
								local_acquisition_data_din(0)(7 downto 0) <= x"01";
							else
								local_acquisition_data_din(0)(7 downto 0) <= x"00";
							end if;
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= normal_receiving_data;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
						when x"0b" =>
							write_or_read_one_packet(0)(0) <= '0';
							if ( Rx0 = '1') then
								local_acquisition_data_din(0)(7 downto 0) <= local_acquisition_data_din(0)(7 downto 0) or x"02";
							else
								local_acquisition_data_din(0) <= local_acquisition_data_din(0) ;
							end if;
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= normal_receiving_data;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
						when x"0c" =>
							write_or_read_one_packet(0)(0) <= '0';
							if ( Rx0 = '1') then
								local_acquisition_data_din(0)(7 downto 0) <= local_acquisition_data_din(0)(7 downto 0) or x"04";
							else
								local_acquisition_data_din(0) <= local_acquisition_data_din(0) ;
							end if;
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= normal_receiving_data;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
						when x"0d" =>
							write_or_read_one_packet(0)(0) <= '0';
							if (Rx0 = '1') then
								local_acquisition_data_din(0)(7 downto 0) <= local_acquisition_data_din(0)(7 downto 0) or x"08";
							else
								local_acquisition_data_din(0) <= local_acquisition_data_din(0) ;
							end if;
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= normal_receiving_data;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
						when x"0e" =>
							write_or_read_one_packet(0)(0) <= '0';
							if ( Rx0 = '1') then
								local_acquisition_data_din(0)(7 downto 0) <= local_acquisition_data_din(0)(7 downto 0) or x"10";
							else
								local_acquisition_data_din(0) <= local_acquisition_data_din(0) ;
							end if;
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= normal_receiving_data;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
						when x"0f" =>
							write_or_read_one_packet(0)(0) <= '0';
							if ( Rx0 = '1') then
								local_acquisition_data_din(0)(7 downto 0) <= local_acquisition_data_din(0)(7 downto 0) or x"20";
							else
								local_acquisition_data_din(0) <= local_acquisition_data_din(0) ;
							end if;
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= normal_receiving_data;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
						when x"10" =>
							write_or_read_one_packet(0)(0) <= '0';
							if ( Rx0 = '1') then
								local_acquisition_data_din(0)(7 downto 0) <= local_acquisition_data_din(0)(7 downto 0) or x"40";
							else
								local_acquisition_data_din(0) <= local_acquisition_data_din(0) ;
							end if;
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= normal_receiving_data;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
						when x"11" =>
							write_or_read_one_packet(0)(0) <= '0';
							if ( Rx0 = '1') then
								local_acquisition_data_din(0)(7 downto 0) <= local_acquisition_data_din(0)(7 downto 0) or x"80";
							else
								local_acquisition_data_din(0) <= local_acquisition_data_din(0) ;
							end if;
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_receving(0) <= normal_receiving_data;
							bit_to_byte(0) <= bit_to_byte(0) + x"01";
						when x"12" =>
							-- The end signal for the whole packet is 0xFF.
						        -- As soon as the 0xFF is coming, another data packet will be save to another fifo.
							if ( local_acquisition_data_din(0)(7 downto 0) = x"FF") then
								-- Leave the process to wait for another data packet.
								bit_to_byte(0) <= x"00";
								write_or_read_one_packet(0)(0) <= '1';
								local_acquisition_data_receving(0) <= idle;
							else
								write_or_read_one_packet(0)(0) <= '0';
								bit_to_byte(0) <= bit_to_byte(0) + x"01";
								local_acquisition_data_receving(0) <= normal_receiving_data;
							end if;
							local_acquisition_data_wr(0) <= '1';
							local_acquisition_data_din(0) <= local_acquisition_data_din(0) ;
						when others =>
							write_or_read_one_packet(0)(0) <= '0';
							if (Rx0 = '0') then
								bit_to_byte(0) <= x"00";
							else
								bit_to_byte(0) <= bit_to_byte(0);
							end if;
							local_acquisition_data_wr(0) <= '0';
							local_acquisition_data_din(0) <= x"0000" ;
							local_acquisition_data_receving(0) <= normal_receiving_data;
					end case;
				-- }
				when clear_wr_data_counter =>
					write_or_read_one_packet(0)(0) <= '0';
					bit_to_byte(0) <= x"00";
					local_acquisition_data_wr(0) <= '0';
					local_acquisition_data_din(0) <= x"0000";
					if ( wr_data_counter(0) > fifo_maximum_used_bytes_for_new_packet) then
						local_acquisition_data_receving(0) <= clear_wr_data_counter;
					else
						local_acquisition_data_receving(0) <= idle;
					end if;
			end case;
		end if;
	-- }
	end process;

	bug_in_writing_fifo_maximal_number: process ( reset, clk_50MHz)
	begin
		if ( reset = '1') then
			bug_in_write_number_over_flow <= '0';
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			if ( wr_data_counter(0) > x"3FE") then
				bug_in_write_number_over_flow <= '1';
			else
				bug_in_write_number_over_flow <= '0';
			end if;
		end if;
	end process;

	bug_in_xx_8102_xx_in_acquisition_process: process ( reset, clk_50MHz)
	begin
		if ( reset = '1') then
			bug_in_xx_8102_xx_in_acquisition <= '0';
			formal_word3 <= x"0000";
			bug_bit2 <= "00";
		elsif( clk_50MHz 'event and clk_50MHz = '1') then
			case bug_bit2 is
				when "00" =>
					if ( local_acquisition_data_dout_to_Daisychain_wr_i = '0') then
						bug_bit2 <= "00";
						formal_word3 <= formal_word3;
					else
						bug_bit2 <= "01";
						formal_word3 <= local_acquisition_data_dout_to_Daisychain_i;
					end if;
					bug_in_xx_8102_xx_in_acquisition <= '0';
				when "01" =>
					if ( local_acquisition_data_dout_to_Daisychain_wr_i = '0') then
						bug_bit2 <= "01";
						formal_word3 <= formal_word3;
						bug_in_xx_8102_xx_in_acquisition <= '0';
					elsif ( (local_acquisition_data_dout_to_Daisychain_wr_i = '1') and (local_acquisition_data_dout_to_Daisychain_i /= x"8102")) then
						bug_bit2 <= "01";
						formal_word3 <= local_acquisition_data_dout_to_Daisychain_i;
						bug_in_xx_8102_xx_in_acquisition <= '0';
					elsif ( (local_acquisition_data_dout_to_Daisychain_wr_i = '1') and (local_acquisition_data_dout_to_Daisychain_i = x"8102") and ((local_acquisition_data_dout_to_Daisychain_i(15 downto 8) = x"FF") or ( local_acquisition_data_dout_to_Daisychain_i(7 downto 0) = x"FF"))) then
						bug_bit2 <= "01";
						formal_word3 <= local_acquisition_data_dout_to_Daisychain_i;
						bug_in_xx_8102_xx_in_acquisition <= '0';
					elsif ( (local_acquisition_data_dout_to_Daisychain_wr_i = '1') and (local_acquisition_data_dout_to_Daisychain_i = x"8102") and ((local_acquisition_data_dout_to_Daisychain_i(15 downto 8) /= x"FF") or ( local_acquisition_data_dout_to_Daisychain_i(7 downto 0) /= x"FF"))) then
						bug_bit2 <= "00";
						formal_word3 <= formal_word3;
						bug_in_xx_8102_xx_in_acquisition <= '1';
					end if;
				when others =>
					null;
			end case;
		end if;
	end process;


	bug_capture_write_fifo_process: process ( reset, clk_50MHz)
	begin
		if ( reset = '1') then
			bug_in_acqusition_write_fifo <= '0';
			formal_word1 <= x"0000";
			bug_bit1 <= "000";
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			case bug_bit1 is
				when "000" =>
					if (local_acquisition_data_wr(0) = '0') then
						bug_bit1 <= "000";
					else
						bug_bit1 <= "001";
						formal_word1 <= local_acquisition_data_din(0);
					end if;
					bug_in_acqusition_write_fifo <= '0';
				when "001" =>
					if (local_acquisition_data_wr(0) = '0') then
						bug_bit1 <= "001";
					elsif ( (local_acquisition_data_wr(0) = '1') and ( local_acquisition_data_din(0) = formal_word1)) then
						bug_bit1 <= "010";
					else
						formal_word1 <= local_acquisition_data_din(0);
						bug_bit1 <= "001";
					end if;
					bug_in_acqusition_write_fifo <= '0';
				when "010" =>
					if (local_acquisition_data_wr(0) = '0')  then
						bug_bit1 <= "010";
					elsif ( (local_acquisition_data_wr(0) = '1') and ( local_acquisition_data_din(0) = formal_word1)) then
						bug_bit1 <= "011";
					else
						formal_word1 <= local_acquisition_data_din(0);
						bug_bit1 <= "001";
					end if;
					bug_in_acqusition_write_fifo <= '0';
				when "011" =>
					if (local_acquisition_data_wr(0) = '0')  then
						bug_bit1 <= "011";
					elsif ( (local_acquisition_data_wr(0) = '1') and ( local_acquisition_data_din(0) = formal_word1)) then
						bug_bit1 <= "100";
					else
						formal_word1 <= local_acquisition_data_din(0);
						bug_bit1 <= "001";
					end if;
					bug_in_acqusition_write_fifo <= '0';
				when "100" =>
					if (local_acquisition_data_wr(0) = '0')  then
						bug_bit1 <= "100";
					elsif ( (local_acquisition_data_wr(0) = '1') and ( local_acquisition_data_din(0) = formal_word1)) then
						bug_bit1 <= "101";
					else
						formal_word1 <= local_acquisition_data_din(0);
						bug_bit1 <= "001";
					end if;
					bug_in_acqusition_write_fifo <= '0';
				when "101" =>
					if (local_acquisition_data_wr(0) = '0')  then
						bug_bit1 <= "101";
					elsif ( (local_acquisition_data_wr(0) = '1') and ( local_acquisition_data_din(0) = formal_word1)) then
						bug_bit1 <= "110";
					else
						formal_word1 <= local_acquisition_data_din(0);
						bug_bit1 <= "001";
					end if;
					bug_in_acqusition_write_fifo <= '0';
				when "110" =>
					if (local_acquisition_data_wr(0) = '0')  then
						bug_in_acqusition_write_fifo <= '0';
					elsif ( (local_acquisition_data_wr(0) = '1') and ( local_acquisition_data_din(0) = formal_word1)) then
						bug_in_acqusition_write_fifo <= '1';
					else
						formal_word1 <= local_acquisition_data_din(0);
					end if;
					bug_bit1 <= "001";
				when others =>
					null;
			end case;
		end if;
	end process;

	bug_capture_read_fifo_process: process ( reset, clk_50MHz)
	begin
		if ( reset = '1') then
			bug_in_acqusition_process <= '0';
			formal_word2 <= x"0000";
			bug_bit3 <= "000";
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			case bug_bit3 is
				when "000" =>
					if ( local_acquisition_data_dout_to_Daisychain_wr_i = '0') then
						bug_bit3 <= "000";
					else
						bug_bit3 <= "001";
						formal_word2 <= local_acquisition_data_dout_to_Daisychain_i;
					end if;
					bug_in_acqusition_process <= '0';
				when "001" =>
					if ( local_acquisition_data_dout_to_Daisychain_wr_i = '0') then
						bug_bit3 <= "001";
					elsif ( (local_acquisition_data_dout_to_Daisychain_wr_i = '1') and ( local_acquisition_data_dout_to_Daisychain_i = formal_word2)) then
						bug_bit3 <= "010";
					else
						formal_word2 <= local_acquisition_data_dout_to_Daisychain_i;
						bug_bit3 <= "001";
					end if;
					bug_in_acqusition_process <= '0';
				when "010" =>
					if (local_acquisition_data_dout_to_Daisychain_wr_i = '0')  then
						bug_bit3 <= "010";
					elsif ( (local_acquisition_data_dout_to_Daisychain_wr_i = '1') and ( local_acquisition_data_dout_to_Daisychain_i = formal_word2)) then
						bug_bit3 <= "011";
					else
						formal_word2 <= local_acquisition_data_dout_to_Daisychain_i;
						bug_bit3 <= "001";
					end if;
					bug_in_acqusition_process <= '0';
				when "011" =>
					if (local_acquisition_data_dout_to_Daisychain_wr_i = '0')  then
						bug_bit3 <= "011";
					elsif ( (local_acquisition_data_dout_to_Daisychain_wr_i = '1') and ( local_acquisition_data_dout_to_Daisychain_i = formal_word2)) then
						bug_bit3 <= "100";
					else
						formal_word2 <= local_acquisition_data_dout_to_Daisychain_i;
						bug_bit3 <= "001";
					end if;
					bug_in_acqusition_process <= '0';
				when "100" =>
					if (local_acquisition_data_dout_to_Daisychain_wr_i = '0')  then
						bug_bit3 <= "100";
					elsif ( (local_acquisition_data_dout_to_Daisychain_wr_i = '1') and ( local_acquisition_data_dout_to_Daisychain_i = formal_word2)) then
						bug_bit3 <= "101";
					else
						formal_word2 <= local_acquisition_data_dout_to_Daisychain_i;
						bug_bit3 <= "001";
					end if;
					bug_in_acqusition_process <= '0';
				when "101" =>
					if (local_acquisition_data_dout_to_Daisychain_wr_i = '0')  then
						bug_bit3 <= "101";
					elsif ( (local_acquisition_data_dout_to_Daisychain_wr_i = '1') and ( local_acquisition_data_dout_to_Daisychain_i = formal_word2)) then
						bug_bit3 <= "110";
					else
						formal_word2 <= local_acquisition_data_dout_to_Daisychain_i;
						bug_bit3 <= "001";
					end if;
					bug_in_acqusition_process <= '0';
				when "110" =>
					if (local_acquisition_data_dout_to_Daisychain_wr_i = '0')  then
						bug_in_acqusition_process <= '0';
					elsif ( (local_acquisition_data_dout_to_Daisychain_wr_i = '1') and ( local_acquisition_data_dout_to_Daisychain_i = formal_word2)) then
						bug_in_acqusition_process <= '1';
					else
						formal_word2 <= local_acquisition_data_dout_to_Daisychain_i;
					end if;
					bug_bit3 <= "001";
				when others =>
					null;
			end case;
		end if;
	end process;
	


	------- This process is to treat the write and read fifo
	Inst_write_and_read_process : process ( reset, clk_50MHz)
	begin
		if ( reset = '1') then
			local_acquisition_data_write_number(0) <= x"0000";
		elsif ( clk_50Mhz 'event and clk_50MHz = '1') then
			case write_or_read_one_packet(0) is
				when "00" =>
					local_acquisition_data_write_number(0) <= local_acquisition_data_write_number(0);
				when "01" =>
					local_acquisition_data_write_number(0) <= local_acquisition_data_write_number(0) + x"01";
				when "10" =>
					local_acquisition_data_write_number(0) <= local_acquisition_data_write_number(0) - x"01";
				when "11" =>
					local_acquisition_data_write_number(0) <= local_acquisition_data_write_number(0);
				when others =>
					null;
			end case;
		end if;
	end process;

	----------------------------------------------------------------------------------------------------------
	-- Rx1: To get the local acquisition data
	-- Fifo: 512 - 2 bytes
	----------------------------------------------------------------------------------------------------------
	Local_acquisition_data_from_Rx1_to_Daisychain: fifo_1024_16_counter
	port map (
			rst		=> reset_fifo,
			wr_clk		=> clk_50MHz,
			rd_clk		=> clk_50MHz,
			wr_en		=> local_acquisition_data_wr(1),
			rd_en		=> local_acquisition_data_rd(1),
			din		=> local_acquisition_data_din(1),
			dout		=> local_acquisition_data_dout(1),
			full		=> open,
			empty		=> local_acquisition_data_empty(1),
			rd_data_count   => rd_data_counter(1),
			wr_data_count   => wr_data_counter(1)

		);

	Rx1_Inst_get_local_acquisition_data_Rx1: process( clk_50MHz, reset)
	begin
	-- {
		if ( reset = '1' ) then
			local_acquisition_data_wr(1) <= '0';
			local_acquisition_data_din(1) <= x"0000";
			bit_to_byte(1) <= x"00";
			local_acquisition_data_receving(1) <= idle;
			write_or_read_one_packet(1)(0) <= '0';
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			case local_acquisition_data_receving(1) is
				when idle =>
					write_or_read_one_packet(1)(0) <= '0';
					local_acquisition_data_wr(1) <= '0';
					local_acquisition_data_din(1) <= x"0000";
					bit_to_byte(1) <= x"00";
					if ( Rx1 = '0') then
						local_acquisition_data_receving(1) <= start_signal_receiving;
					else
						local_acquisition_data_receving(1) <= idle;
					end if;
				when start_signal_receiving =>
				-- {
					write_or_read_one_packet(1)(0) <= '0';
					case bit_to_byte(1) is
						when x"00" =>
							if (Rx1 = '1') then
								local_acquisition_data_din(1)(15 downto 8) <= x"01";
							else
								local_acquisition_data_din(1)(15 downto 8) <= x"00";
							end if;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= start_signal_receiving;
						when x"01" =>
							if ( Rx1 = '1') then
								local_acquisition_data_din(1)(15 downto 8) <= local_acquisition_data_din(1)(15 downto 8) or x"02";
							else
								local_acquisition_data_din(1)(15 downto 8) <= local_acquisition_data_din(1)(15 downto 8);

							end if;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= start_signal_receiving;
						when x"02" =>
							if ( Rx1 = '1') then
								local_acquisition_data_din(1)(15 downto 8) <= local_acquisition_data_din(1)(15 downto 8) or x"04";
							else
								local_acquisition_data_din(1)(15 downto 8) <= local_acquisition_data_din(1)(15 downto 8);
							end if;
							local_acquisition_data_wr(1) <= '0';
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
							local_acquisition_data_receving(1) <= start_signal_receiving;
						when x"03" =>
							if (Rx1 = '1') then
								local_acquisition_data_din(1)(15 downto 8) <= local_acquisition_data_din(1)(15 downto 8) or x"08";
							else
								local_acquisition_data_din(1)(15 downto 8) <= local_acquisition_data_din(1)(15 downto 8);
							end if;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= start_signal_receiving;
						when x"04" =>
							if ( Rx1 = '1') then
								local_acquisition_data_din(1)(15 downto 8) <= local_acquisition_data_din(1)(15 downto 8) or x"10";
							else
								local_acquisition_data_din(1)(15 downto 8) <= local_acquisition_data_din(1)(15 downto 8);
							end if;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= start_signal_receiving;
						when x"05" =>
							if ( Rx1 = '1') then
								local_acquisition_data_din(1)(15 downto 8) <= local_acquisition_data_din(1)(15 downto 8) or x"20";
							else
								local_acquisition_data_din(1)(15 downto 8) <= local_acquisition_data_din(1)(15 downto 8);
							end if;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= start_signal_receiving;
						when x"06" =>
							if ( Rx1 = '1') then
								local_acquisition_data_din(1)(15 downto 8) <= local_acquisition_data_din(1)(15 downto 8) or x"40";
							else
								local_acquisition_data_din(1)(15 downto 8) <= local_acquisition_data_din(1)(15 downto 8);
							end if;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= start_signal_receiving;
						when x"07" =>
							if ( Rx1 = '1') then
								local_acquisition_data_din(1)(15 downto 8) <= local_acquisition_data_din(1)(15 downto 8) or x"80";
							else
								local_acquisition_data_din(1)(15 downto 8) <= local_acquisition_data_din(1)(15 downto 8);
							end if;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= start_signal_receiving;
						when x"08" =>
							if is_packet_start_token(local_acquisition_data_din(1)(15 downto 8)) then
								-- From address: to add the current Virtex-5 board id
								-- add the ID of the Virtex-5 board
								local_acquisition_data_din(1)(7 downto 0) <= "00000" & boardid;
								if (wr_data_counter(1) <= fifo_maximum_used_bytes_for_new_packet) then
									local_acquisition_data_wr(1) <= '1';
									bit_to_byte(1) <= bit_to_byte(1) + x"01";
									local_acquisition_data_receving(1) <= start_signal_receiving;
								else
									local_acquisition_data_wr(1) <= '0';
									bit_to_byte(1) <= x"00";
									local_acquisition_data_receving(1) <= clear_wr_data_counter;
								end if;
							else
								-- It is not an valid data packet. Discard and wait for another data packet.
								local_acquisition_data_wr(1) <= '0';
								local_acquisition_data_din(1) <= x"0000";
								bit_to_byte(1) <= x"00";
								local_acquisition_data_receving(1) <= idle;
							end if;
						when x"09" =>
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_din(1) <= x"0000";
							-- wait for the Rx1 = '0' to start receiving.
							if ( Rx1 = '0') then
								bit_to_byte(1) <= x"00";
								local_acquisition_data_receving(1) <= add_from_and_to_address; 
							else
								bit_to_byte(1) <= bit_to_byte(1);
								local_acquisition_data_receving(1) <= start_signal_receiving;
							end if;
						when others =>
							null;
					end case;
				-- }
				when add_from_and_to_address =>
				-- {
					write_or_read_one_packet(1)(0) <= '0';
					case bit_to_byte(1) is
						when x"00" =>
							if (Rx1 = '1') then
								local_acquisition_data_din(1)(7 downto 0) <= x"01";
							else
								local_acquisition_data_din(1)(7 downto 0) <= x"00";
							end if;
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= add_from_and_to_address;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
						when x"01" =>
							if ( Rx1 = '1') then
								local_acquisition_data_din(1)(7 downto 0) <= local_acquisition_data_din(1)(7 downto 0) or x"02";
							else
								local_acquisition_data_din(1)(7 downto 0) <= local_acquisition_data_din(1)(7 downto 0);
							end if;
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= add_from_and_to_address;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
						when x"02" =>
							if ( Rx1 = '1') then
								local_acquisition_data_din(1)(7 downto 0) <= local_acquisition_data_din(1)(7 downto 0) or x"04";
							else
								local_acquisition_data_din(1)(7 downto 0) <= local_acquisition_data_din(1)(7 downto 0);
							end if;
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= add_from_and_to_address;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
						when x"03" =>
							if (Rx1 = '1') then
								local_acquisition_data_din(1)(7 downto 0) <= local_acquisition_data_din(1)(7 downto 0) or x"08";
							else
								local_acquisition_data_din(1)(7 downto 0) <= local_acquisition_data_din(1)(7 downto 0);
							end if;
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= add_from_and_to_address;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
						when x"04" =>
							if ( Rx1 = '1') then
								local_acquisition_data_din(1)(7 downto 0) <= local_acquisition_data_din(1)(7 downto 0) or x"10";
							else
								local_acquisition_data_din(1)(7 downto 0) <= local_acquisition_data_din(1)(7 downto 0);
							end if;
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= add_from_and_to_address;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
						when x"05" =>
							if ( Rx1 = '1') then
								local_acquisition_data_din(1)(7 downto 0) <= local_acquisition_data_din(1)(7 downto 0) or x"20";
							else
								local_acquisition_data_din(1)(7 downto 0) <= local_acquisition_data_din(1)(7 downto 0);
							end if;
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= add_from_and_to_address;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
						when x"06" =>
							if ( Rx1 = '1') then
								local_acquisition_data_din(1)(7 downto 0) <= local_acquisition_data_din(1)(7 downto 0) or x"40";
							else
								local_acquisition_data_din(1)(7 downto 0) <= local_acquisition_data_din(1)(7 downto 0);
							end if;
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= add_from_and_to_address;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
						when x"07" =>
							if ( Rx1 = '1') then
								local_acquisition_data_din(1)(7 downto 0) <= local_acquisition_data_din(1)(7 downto 0) or x"80";
							else
								local_acquisition_data_din(1)(7 downto 0) <= local_acquisition_data_din(1)(7 downto 0);
							end if;
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= add_from_and_to_address;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
						when x"08" =>
							-- Add the destination ID.
							local_acquisition_data_wr(1) <= '1';
							local_acquisition_data_din(1)(15 downto 8) <= x"00";
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
							local_acquisition_data_receving(1) <= add_from_and_to_address;
						when x"09" =>
							if (Rx1 = '0') then
								bit_to_byte(1) <= x"00";
								local_acquisition_data_receving(1) <= normal_receiving_data;
							else
								bit_to_byte(1) <= bit_to_byte(1);
								local_acquisition_data_receving(1) <= add_from_and_to_address;
							end if;
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_din(1) <= x"0000";
						when others =>
							null;
					end case;
				-- }
				when normal_receiving_data =>
				-- { 
					case bit_to_byte(1) is
						when x"00" =>
							write_or_read_one_packet(1)(0) <= '0';
							if (Rx1 = '1') then
								local_acquisition_data_din(1)(15 downto 8)<= x"01";
							else
								local_acquisition_data_din(1)(15 downto 8)<= x"00";
							end if;
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= normal_receiving_data;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
						when x"01" =>
							write_or_read_one_packet(1)(0) <= '0';
							if ( Rx1 = '1') then
								local_acquisition_data_din(1)(15 downto 8)<= local_acquisition_data_din(1)(15 downto 8) or x"02";
							else
								local_acquisition_data_din(1)(15 downto 8)<= local_acquisition_data_din(1)(15 downto 8);
							end if;
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= normal_receiving_data;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
						when x"02" =>
							write_or_read_one_packet(1)(0) <= '0';
							if ( Rx1 = '1') then
								local_acquisition_data_din(1)(15 downto 8)<= local_acquisition_data_din(1)(15 downto 8) or x"04";
							else
								local_acquisition_data_din(1)(15 downto 8)<= local_acquisition_data_din(1)(15 downto 8);
							end if;
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= normal_receiving_data;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
						when x"03" =>
							write_or_read_one_packet(1)(0) <= '0';
							if (Rx1 = '1') then
								local_acquisition_data_din(1)(15 downto 8)<= local_acquisition_data_din(1)(15 downto 8) or x"08";
							else
								local_acquisition_data_din(1)(15 downto 8)<= local_acquisition_data_din(1)(15 downto 8);
							end if;
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= normal_receiving_data;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
						when x"04" =>
							write_or_read_one_packet(1)(0) <= '0';
							if ( Rx1 = '1') then
								local_acquisition_data_din(1)(15 downto 8)<= local_acquisition_data_din(1)(15 downto 8) or x"10";
							else
								local_acquisition_data_din(1)(15 downto 8)<= local_acquisition_data_din(1)(15 downto 8);
							end if;
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= normal_receiving_data;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
						when x"05" =>
							write_or_read_one_packet(1)(0) <= '0';
							if ( Rx1 = '1') then
								local_acquisition_data_din(1)(15 downto 8)<= local_acquisition_data_din(1)(15 downto 8) or x"20";
							else
								local_acquisition_data_din(1)(15 downto 8)<= local_acquisition_data_din(1)(15 downto 8);
							end if;
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= normal_receiving_data;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
						when x"06" =>
							write_or_read_one_packet(1)(0) <= '0';
							if ( Rx1 = '1') then
								local_acquisition_data_din(1)(15 downto 8)<= local_acquisition_data_din(1)(15 downto 8) or x"40";
							else
								local_acquisition_data_din(1)(15 downto 8)<= local_acquisition_data_din(1)(15 downto 8);
							end if;
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= normal_receiving_data;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
						when x"07" =>
							write_or_read_one_packet(1)(0) <= '0';
							if ( Rx1 = '1') then
								local_acquisition_data_din(1)(15 downto 8)<= local_acquisition_data_din(1)(15 downto 8) or x"80";
							else
								local_acquisition_data_din(1)(15 downto 8)<= local_acquisition_data_din(1)(15 downto 8);
							end if;
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= normal_receiving_data;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
						when x"08" =>
							-- The end signal for the whole packet is 0xFF.
						        -- As soon as the 0xFF is coming, another data packet will be save to another fifo.
							if ( local_acquisition_data_din(1)(15 downto 8)= x"FF") then
								-- Leave this process to wait for another data packet.
								local_acquisition_data_din(1)(15 downto 0) <= x"FF00";
								local_acquisition_data_wr(1) <= '1';
								bit_to_byte(1) <= x"00";
								write_or_read_one_packet(1)(0) <= '1';
								local_acquisition_data_receving(1) <= idle;
							else
								local_acquisition_data_wr(1) <= '0';
								local_acquisition_data_din(1) <= local_acquisition_data_din(1);
								write_or_read_one_packet(1)(0) <= '0';
								bit_to_byte(1) <= bit_to_byte(1) + x"01";
								local_acquisition_data_receving(1) <= normal_receiving_data;
							end if;
						when x"09" =>
							-- !!!!
							-- If there is no data input, the process will stay here untill the new data incoming.
							write_or_read_one_packet(1)(0) <= '0';
							local_acquisition_data_din(1) <= local_acquisition_data_din(1);
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= normal_receiving_data;
							if (Rx1 = '0') then
								bit_to_byte(1) <= bit_to_byte(1) + x"01";
							else
								bit_to_byte(1) <= bit_to_byte(1);
							end if;
						when x"0a" => 
							write_or_read_one_packet(1)(0) <= '0';
							if (Rx1 = '1') then
								local_acquisition_data_din(1)(7 downto 0) <= x"01";
							else
								local_acquisition_data_din(1)(7 downto 0) <= x"00";
							end if;
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= normal_receiving_data;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
						when x"0b" =>
							write_or_read_one_packet(1)(0) <= '0';
							if ( Rx1 = '1') then
								local_acquisition_data_din(1)(7 downto 0) <= local_acquisition_data_din(1)(7 downto 0) or x"02";
							else
								local_acquisition_data_din(1) <= local_acquisition_data_din(1) ;
							end if;
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= normal_receiving_data;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
						when x"0c" =>
							write_or_read_one_packet(1)(0) <= '0';
							if ( Rx1 = '1') then
								local_acquisition_data_din(1)(7 downto 0) <= local_acquisition_data_din(1)(7 downto 0) or x"04";
							else
								local_acquisition_data_din(1) <= local_acquisition_data_din(1) ;
							end if;
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= normal_receiving_data;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
						when x"0d" =>
							write_or_read_one_packet(1)(0) <= '0';
							if (Rx1 = '1') then
								local_acquisition_data_din(1)(7 downto 0) <= local_acquisition_data_din(1)(7 downto 0) or x"08";
							else
								local_acquisition_data_din(1) <= local_acquisition_data_din(1) ;
							end if;
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= normal_receiving_data;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
						when x"0e" =>
							write_or_read_one_packet(1)(0) <= '0';
							if ( Rx1 = '1') then
								local_acquisition_data_din(1)(7 downto 0) <= local_acquisition_data_din(1)(7 downto 0) or x"10";
							else
								local_acquisition_data_din(1) <= local_acquisition_data_din(1) ;
							end if;
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= normal_receiving_data;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
						when x"0f" =>
							write_or_read_one_packet(1)(0) <= '0';
							if ( Rx1 = '1') then
								local_acquisition_data_din(1)(7 downto 0) <= local_acquisition_data_din(1)(7 downto 0) or x"20";
							else
								local_acquisition_data_din(1) <= local_acquisition_data_din(1) ;
							end if;
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= normal_receiving_data;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
						when x"10" =>
							write_or_read_one_packet(1)(0) <= '0';
							if ( Rx1 = '1') then
								local_acquisition_data_din(1)(7 downto 0) <= local_acquisition_data_din(1)(7 downto 0) or x"40";
							else
								local_acquisition_data_din(1) <= local_acquisition_data_din(1) ;
							end if;
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= normal_receiving_data;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
						when x"11" =>
							write_or_read_one_packet(1)(0) <= '0';
							if ( Rx1 = '1') then
								local_acquisition_data_din(1)(7 downto 0) <= local_acquisition_data_din(1)(7 downto 0) or x"80";
							else
								local_acquisition_data_din(1) <= local_acquisition_data_din(1) ;
							end if;
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_receving(1) <= normal_receiving_data;
							bit_to_byte(1) <= bit_to_byte(1) + x"01";
						when x"12" =>
							-- The end signal for the whole packet is 0xFF.
						        -- As soon as the 0xFF is coming, another data packet will be save to another fifo.
							if ( local_acquisition_data_din(1)(7 downto 0) = x"FF") then
								-- Leave the process to wait for another data packet.
								bit_to_byte(1) <= x"00";
								write_or_read_one_packet(1)(0) <= '1';
								local_acquisition_data_receving(1) <= idle;
							else
								write_or_read_one_packet(1)(0) <= '0';
								bit_to_byte(1) <= bit_to_byte(1) + x"01";
								local_acquisition_data_receving(1) <= normal_receiving_data;
							end if;
							local_acquisition_data_wr(1) <= '1';
							local_acquisition_data_din(1) <= local_acquisition_data_din(1) ;
						when others =>
							write_or_read_one_packet(1)(0) <= '0';
							if (Rx1 = '0') then
								bit_to_byte(1) <= x"00";
							else
								bit_to_byte(1) <= bit_to_byte(1);
							end if;
							local_acquisition_data_wr(1) <= '0';
							local_acquisition_data_din(1) <= x"0000" ;
							local_acquisition_data_receving(1) <= normal_receiving_data;
					end case;
				-- }
				when clear_wr_data_counter =>
					write_or_read_one_packet(1)(0) <= '0';
					bit_to_byte(1) <= x"00";
					local_acquisition_data_wr(1) <= '0';
					local_acquisition_data_din(1) <= x"0000";
					if ( wr_data_counter(1) > fifo_maximum_used_bytes_for_new_packet) then
						local_acquisition_data_receving(1) <= clear_wr_data_counter;
					else
						local_acquisition_data_receving(1) <= idle;
					end if;
			end case;
		end if;
	-- }
	end process;

	------- This process is to treat the write and read fifo
	Rx1_Inst_write_and_read_process : process ( reset, clk_50MHz)
	begin
	-- {
		if ( reset = '1') then
			local_acquisition_data_write_number(1) <= x"0000";
		elsif ( clk_50Mhz 'event and clk_50MHz = '1') then
			case write_or_read_one_packet(1) is
				when "00" =>
					local_acquisition_data_write_number(1) <= local_acquisition_data_write_number(1);
				when "01" =>
					local_acquisition_data_write_number(1) <= local_acquisition_data_write_number(1) + x"01";
				when "10" =>
					local_acquisition_data_write_number(1) <= local_acquisition_data_write_number(1) - x"01";
				when "11" =>
					local_acquisition_data_write_number(1) <= local_acquisition_data_write_number(1);
				when others =>
					null;
			end case;
		end if;
	-- }
	end process;


	------- important process to transfer data from this module to the daisychain
	Inst_transfer_local_acquisition_data_to_daisychain: process(reset, clk_50Mhz)
	begin
		if ( reset = '1') then
			first_word <= x"0000";
			second_word <= x"0000";
			local_acquisition_data_dout_to_Daisychain_wr_i <= '0';
			local_acquisition_data_dout_to_Daisychain_i <= x"0000";
			local_acquisition_data_rd(0) <= '0';
			local_acquisition_data_rd(1) <= '0';
			transfer_local_data_token <= x"00";
			write_or_read_one_packet(0)(1) <= '0';
			write_or_read_one_packet(1)(1) <= '0';
			transfering_local_acquisition_data <= first_word_judge;
			send_local_aquisition_data_status <= idle;
		elsif ( clk_50mhz 'event and clk_50mhz = '1') then
			case send_local_aquisition_data_status is 
				when idle =>
				-- {
					first_word <= x"0000";
					second_word <= x"0000";
					local_acquisition_data_dout_to_Daisychain_wr_i <= '0';
					local_acquisition_data_dout_to_Daisychain_i <= x"0000";
					transfering_local_acquisition_data <= first_word_judge;
					case transfer_local_data_token is
						when x"00" =>
							local_acquisition_data_rd(0) <= '0';
							if ( local_acquisition_data_empty(0) = '0' and local_acquisition_data_write_number(0) > x"0000" ) then
								write_or_read_one_packet(0)(1) <= '1';
								send_local_aquisition_data_status <= local_acquisition_data_transfer_fifo_0;
							else
								write_or_read_one_packet(0)(1) <= '0';
								send_local_aquisition_data_status <= idle;
							end if;
							transfer_local_data_token <= transfer_local_data_token + x"01";
						when x"01" => 
							local_acquisition_data_rd(1) <= '0';
							if ( local_acquisition_data_empty(1) = '0' and local_acquisition_data_write_number(1) > x"0000") then 
								write_or_read_one_packet(1)(1) <= '1';
								send_local_aquisition_data_status <= local_acquisition_data_transfer_fifo_1;
							else
								write_or_read_one_packet(1)(1) <= '0';
								send_local_aquisition_data_status <= idle;
							end if;
					-- transfer_local_data_token <= transfer_local_data_token + x"01";
							transfer_local_data_token <= x"00";
						when others =>
							null;
					end case;
				-- }
				when local_acquisition_data_transfer_fifo_0 =>
				-- {
					local_acquisition_data_rd(1) <= '0';
					transfer_local_data_token <= transfer_local_data_token;
					write_or_read_one_packet(0)(1) <= '0';
					write_or_read_one_packet(1)(1) <= '0';
					case transfering_local_acquisition_data is
						when first_word_judge =>
						-- {
							local_acquisition_data_rd(0) <= '1';
							if check_first_packet_word_good(local_acquisition_data_dout(0), x"01", x"04") then
								transfering_local_acquisition_data <= second_word_out;	
							else
								transfering_local_acquisition_data <= first_word_output;	
							end if;
							first_word <= local_acquisition_data_dout(0);
							second_word <= x"0000";
							local_acquisition_data_dout_to_Daisychain_wr_i <= '0';
							local_acquisition_data_dout_to_Daisychain_i <= x"0000";
							send_local_aquisition_data_status <= local_acquisition_data_transfer_fifo_0;
						-- }
						when first_word_output =>
						-- {
							local_acquisition_data_rd(0) <= '1';
							if check_first_packet_word_good(local_acquisition_data_dout(0), x"01", x"04") then
								transfering_local_acquisition_data <= valid_data_judge;	
							else
								transfering_local_acquisition_data <= first_word_output;	
							end if;
							first_word <= local_acquisition_data_dout(0);
							second_word <= x"0000";
							local_acquisition_data_dout_to_Daisychain_wr_i <= '0';
							local_acquisition_data_dout_to_Daisychain_i <= x"0000";
							send_local_aquisition_data_status <= local_acquisition_data_transfer_fifo_0;
						-- }
						when second_word_out =>
						-- {
							local_acquisition_data_rd(0) <= '0';
							first_word <= first_word;
							second_word <= local_acquisition_data_dout(0);
							local_acquisition_data_dout_to_Daisychain_wr_i <= '0';
							local_acquisition_data_dout_to_Daisychain_i <= x"0000";
							transfering_local_acquisition_data <= align_one_clock;	
							send_local_aquisition_data_status <= local_acquisition_data_transfer_fifo_0;
						-- }
						when align_one_clock =>
						-- {
							local_acquisition_data_rd(0) <= '1';
							first_word <= first_word;
							second_word <= second_word;
							local_acquisition_data_dout_to_Daisychain_wr_i <= '0';
							local_acquisition_data_dout_to_Daisychain_i <= x"0000";
							transfering_local_acquisition_data <= valid_data_judge;	
							send_local_aquisition_data_status <= local_acquisition_data_transfer_fifo_0;
						-- }
						when valid_data_judge =>
						-- {
							first_word <= first_word;
							second_word <= local_acquisition_data_dout(0);
							if is_packet_start_token( first_word(15 downto 8) )
							   and first_word(7 downto 0) = "00000" & boardid
							   and local_acquisition_data_dout(0)(15 downto 8) = x"00"
							then
								local_acquisition_data_rd(0) <= '0';
								local_acquisition_data_dout_to_Daisychain_wr_i <= '1';
								local_acquisition_data_dout_to_Daisychain_i <= first_word;
								transfering_local_acquisition_data <= save_second_word;
							else
								local_acquisition_data_rd(0) <= '1';
								local_acquisition_data_dout_to_Daisychain_wr_i <= '0';
								local_acquisition_data_dout_to_Daisychain_i <= x"0000";
								transfering_local_acquisition_data <= error_data_process;	
							end if;
							send_local_aquisition_data_status <= local_acquisition_data_transfer_fifo_0;
						-- }
						when save_second_word =>
						-- {
							local_acquisition_data_rd(0) <= '1';
							first_word <= x"0000";
							second_word <= second_word;
							local_acquisition_data_dout_to_Daisychain_wr_i <= '1';
							local_acquisition_data_dout_to_Daisychain_i <= second_word;
							transfering_local_acquisition_data <= acquisition_data_judge_and_transfer;
							send_local_aquisition_data_status <= local_acquisition_data_transfer_fifo_0;
						-- }
						when acquisition_data_judge_and_transfer =>
						-- {
							first_word <= x"0000";
							second_word <= x"0000";
							local_acquisition_data_dout_to_Daisychain_wr_i <= '1'; 
							local_acquisition_data_dout_to_Daisychain_i <= local_acquisition_data_dout(0);
							send_local_aquisition_data_status <= local_acquisition_data_transfer_fifo_0;
							if ( local_acquisition_data_dout(0)(15 downto 8) = x"FF" or local_acquisition_data_dout(0)(7 downto 0) = x"FF"  ) then
								local_acquisition_data_rd(0) <= '0';
								transfering_local_acquisition_data <= end_process;
							else
								local_acquisition_data_rd(0) <= '1';
								transfering_local_acquisition_data <= acquisition_data_judge_and_transfer;
							end if;
						-- }
						when error_data_process =>
						-- {
							first_word <= x"5555";
							second_word <= x"6666";
							local_acquisition_data_dout_to_Daisychain_wr_i <= '0'; 
							local_acquisition_data_dout_to_Daisychain_i <= local_acquisition_data_dout(0);
							if ( local_acquisition_data_dout(0)(15 downto 8) = x"FF" or local_acquisition_data_dout(0)(7 downto 0) = x"FF"  ) then
								local_acquisition_data_rd(0) <= '0';
								transfering_local_acquisition_data <= end_process;
							else
								local_acquisition_data_rd(0) <= '1';
								transfering_local_acquisition_data <= error_data_process;
							end if;
							send_local_aquisition_data_status <= local_acquisition_data_transfer_fifo_0;
						-- }
						when end_process =>
						-- {
							local_acquisition_data_rd(0) <= '0';
							first_word <= x"0000";
							second_word <= x"0000";
							local_acquisition_data_dout_to_Daisychain_wr_i <= '0';
							local_acquisition_data_dout_to_Daisychain_i <= x"0000";
							transfering_local_acquisition_data <= first_word_judge;
							send_local_aquisition_data_status <= idle;
						-- }
					end case;
				-- }
				when local_acquisition_data_transfer_fifo_1 =>
				-- {
					local_acquisition_data_rd(0) <= '0';
					transfer_local_data_token <= transfer_local_data_token;
					write_or_read_one_packet(0)(1) <= '0';
					write_or_read_one_packet(1)(1) <= '0';
					case transfering_local_acquisition_data is
						when first_word_judge =>
						-- {
							local_acquisition_data_rd(1) <= '1';
							if check_first_packet_word_good(local_acquisition_data_dout(1), x"01", x"04") then
								transfering_local_acquisition_data <= second_word_out;	
							else
								transfering_local_acquisition_data <= first_word_output;	
							end if;
							first_word <= local_acquisition_data_dout(1);
							second_word <= x"0000";
							local_acquisition_data_dout_to_Daisychain_wr_i <= '0';
							local_acquisition_data_dout_to_Daisychain_i <= x"0000";
							send_local_aquisition_data_status <= local_acquisition_data_transfer_fifo_1;
						-- }
						when first_word_output =>
						-- {
							local_acquisition_data_rd(1) <= '1';
							if check_first_packet_word_good(local_acquisition_data_dout(1), x"01", x"04") then
								transfering_local_acquisition_data <= valid_data_judge;	
							else
								transfering_local_acquisition_data <= first_word_output;	
							end if;
							first_word <= local_acquisition_data_dout(1);
							second_word <= x"0000";
							local_acquisition_data_dout_to_Daisychain_wr_i <= '0';
							local_acquisition_data_dout_to_Daisychain_i <= x"0000";
							send_local_aquisition_data_status <= local_acquisition_data_transfer_fifo_1;
						-- }
						when second_word_out =>
						-- {
							local_acquisition_data_rd(1) <= '0';
							first_word <= first_word;
							second_word <= local_acquisition_data_dout(1);
							local_acquisition_data_dout_to_Daisychain_wr_i <= '0';
							local_acquisition_data_dout_to_Daisychain_i <= x"0000";
							transfering_local_acquisition_data <= align_one_clock;	
							send_local_aquisition_data_status <= local_acquisition_data_transfer_fifo_1;
						-- }
						when align_one_clock =>
						-- {
							local_acquisition_data_rd(1) <= '1';
							first_word <= first_word;
							second_word <= second_word;
							local_acquisition_data_dout_to_Daisychain_wr_i <= '0';
							local_acquisition_data_dout_to_Daisychain_i <= x"0000";
							transfering_local_acquisition_data <= valid_data_judge;	
							send_local_aquisition_data_status <= local_acquisition_data_transfer_fifo_1;
						-- }
						when valid_data_judge =>
						-- {
							first_word <= first_word;
							second_word <= local_acquisition_data_dout(1);
							if is_packet_start_token(first_word(15 downto 8))
							   and first_word(7 downto 0) = "00000" & boardid
							   and local_acquisition_data_dout(1)(15 downto 8) = x"00"
							then
								local_acquisition_data_rd(1) <= '0';
								local_acquisition_data_dout_to_Daisychain_wr_i <= '1';
								local_acquisition_data_dout_to_Daisychain_i <= first_word;
								transfering_local_acquisition_data <= save_second_word;
							else
								local_acquisition_data_rd(1) <= '1';
								local_acquisition_data_dout_to_Daisychain_wr_i <= '0';
								local_acquisition_data_dout_to_Daisychain_i <= x"0000";
								transfering_local_acquisition_data <= error_data_process;	
							end if;
							send_local_aquisition_data_status <= local_acquisition_data_transfer_fifo_1;
						-- }
						when save_second_word =>
						-- {
							local_acquisition_data_rd(1) <= '1';
							first_word <= x"0000";
							second_word <= second_word;
							local_acquisition_data_dout_to_Daisychain_wr_i <= '1';
							local_acquisition_data_dout_to_Daisychain_i <= second_word;
							transfering_local_acquisition_data <= acquisition_data_judge_and_transfer;
							send_local_aquisition_data_status <= local_acquisition_data_transfer_fifo_1;
						-- }
						when acquisition_data_judge_and_transfer =>
						-- {
							first_word <= x"0000";
							second_word <= x"0000";
							local_acquisition_data_dout_to_Daisychain_wr_i <= '1'; 
							local_acquisition_data_dout_to_Daisychain_i <= local_acquisition_data_dout(1);
							send_local_aquisition_data_status <= local_acquisition_data_transfer_fifo_1;
							if ( local_acquisition_data_dout(1)(15 downto 8) = x"FF" or local_acquisition_data_dout(1)(7 downto 0) = x"FF"  ) then
								local_acquisition_data_rd(1) <= '0';
								transfering_local_acquisition_data <= end_process;
							else
								local_acquisition_data_rd(1) <= '1';
								transfering_local_acquisition_data <= acquisition_data_judge_and_transfer;
							end if;
						-- }
						when error_data_process =>
						-- {
							first_word <= x"5555";
							second_word <= x"6666";
							local_acquisition_data_dout_to_Daisychain_wr_i <= '0'; 
							local_acquisition_data_dout_to_Daisychain_i <= local_acquisition_data_dout(1);
							if ( local_acquisition_data_dout(1)(15 downto 8) = x"FF" or local_acquisition_data_dout(1)(7 downto 0) = x"FF"  ) then
								local_acquisition_data_rd(1) <= '0';
								transfering_local_acquisition_data <= end_process;
							else
								local_acquisition_data_rd(1) <= '1';
								transfering_local_acquisition_data <= error_data_process;
							end if;
							send_local_aquisition_data_status <= local_acquisition_data_transfer_fifo_1;
						-- }
						when end_process =>
						-- {
							local_acquisition_data_rd(1) <= '0';
							first_word <= x"0000";
							second_word <= x"0000";
							local_acquisition_data_dout_to_Daisychain_wr_i <= '0';
							local_acquisition_data_dout_to_Daisychain_i <= x"0000";
							transfering_local_acquisition_data <= first_word_judge;
							send_local_aquisition_data_status <= idle;
						-- }
					end case;
				-- }
			end case;
		end if;
	end process;
end Behavioral;

