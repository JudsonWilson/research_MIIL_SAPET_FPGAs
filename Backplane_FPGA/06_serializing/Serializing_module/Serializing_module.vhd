----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    12:19:32 03/25/2013 
-- Design Name: 
-- Module Name:    Serializing_module - Behavioral 
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

entity Serializing_module is
	port (
		reset 				: in std_logic;
		clk_50MHz			: in std_logic;
		clk_12MHz			: in std_logic;
		-- configure data of the current board from Daisychain
		din_from_Daisychain_to_serialzing_wr : in std_logic;
	        din_from_Daisychain_to_serialzing   : in std_logic_vector(15 downto 0);
	        -- Serialing pin
		Tx				: out std_logic
	);
end Serializing_module;

architecture Behavioral of Serializing_module is
	signal reset_fifo			: std_logic := '1';
	signal reset_fifo_vec			: std_logic_vector(3 downto 0) := "1111";
	signal fifo_wr_en			: std_logic := '0';
	signal fifo_rd_en			: std_logic := '0';
	signal din_from_Daisychain		: std_logic_vector(15 downto 0);
	signal fifo_data_dout	        : std_logic_vector(15 downto 0);
	signal fifo_empty			: std_logic;
	signal receiving_configure_data_packet  : std_logic_vector(15 downto 0) := x"0000";
	signal fifo_write_or_read		: std_logic_vector(1 downto 0) := "00";
	type receiving_configure_data_type is ( idle, receive_data);
        signal receive_fifo_state : receiving_configure_data_type := idle;	

	signal byte_to_bit			: std_logic_vector(7 downto 0);
	type serializing_state_type is ( idle, start_word_judge, wait_for_stable_output, fifo_serializing);
	signal serializing_state : serializing_state_type := idle;
	type config_data_serializing_state_type is ( idle, serializing_normal_data_high_byte, serializing_normal_data_low_byte);
	signal fifo_config_data_serializing_state : config_data_serializing_state_type := idle;

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

begin
	-- Reset process
	process ( reset, clk_50MHz)
	begin
		if ( reset = '1') then
			reset_fifo <= '1';
			reset_fifo_vec <= x"F";
		elsif (clk_50MHz 'event and clk_50MHz = '1') then
			reset_fifo <= reset_fifo_vec(0);
			reset_fifo_vec <= '0' & reset_fifo_vec(3 downto 1);
		end if;
	end process;

	-----------------------------------------------------------------------
	-- This fifo is designed to buffer the configure data for serializing.
	-----------------------------------------------------------------------
	Configure_data_from_GTP_G40_to_Daisychain: fifo_block_1024_16
	port map (
			rst		=> reset_fifo,
			wr_clk		=> clk_50MHz,
			rd_clk		=> clk_50MHz,
			wr_en		=> fifo_wr_en,
			rd_en		=> fifo_rd_en,
			din		=> din_from_Daisychain,
			dout		=> fifo_data_dout,
			full		=> open,
			empty		=> fifo_empty
		);

	-----------------------------------------------------------------------------------------------------------
	-- To save the configure data
	-----------------------------------------------------------------------------------------------------------
	Inst_save_configure_data: process( reset, clk_50MHz)
	begin
			if ( reset = '1') then
				fifo_wr_en <= '0';
				receive_fifo_state <= idle;
				fifo_write_or_read(1) <= '0';
			elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			-- {
				din_from_Daisychain <= din_from_Daisychain_to_serialzing;
				case receive_fifo_state is
					when idle =>
					-- {
						fifo_write_or_read(1) <= '0';
						-- start signal and signal 81
						if ( din_from_Daisychain_to_serialzing(15 downto 8) = x"81") then
							fifo_wr_en <= din_from_Daisychain_to_serialzing_wr;
							receive_fifo_state <= receive_data;
						else
							fifo_wr_en <= '0';
						end if;
					-- }
					when receive_data =>
					-- {
						-- end signal 
						if ( din_from_Daisychain_to_serialzing(15 downto 8) = x"FF" or din_from_Daisychain_to_serialzing(7 downto 0) = x"FF") then
							fifo_write_or_read(1) <= '1';
							receive_fifo_state <= idle;
						else
							fifo_write_or_read(1) <= '0';
						end if;
						fifo_wr_en <= din_from_Daisychain_to_serialzing_wr;
					-- }
				end case;
			end if;
	                -- }
		end process;

	Inst_fifo_counter_number_for_configuration_data: process ( reset, clk_50MHz)
	begin
		if ( reset = '1') then
			receiving_configure_data_packet <= x"0000";
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			case fifo_write_or_read is
				when "00" =>
					receiving_configure_data_packet <= receiving_configure_data_packet;
				when "01" =>
					receiving_configure_data_packet <= receiving_configure_data_packet - x"0001";
				when "10" => 
					receiving_configure_data_packet <= receiving_configure_data_packet + x"0001";
				when "11" =>
					receiving_configure_data_packet <= receiving_configure_data_packet;
				when others =>
					receiving_configure_data_packet <= receiving_configure_data_packet;
			end case;
		end if;
	end process;

	Inst_serializing_the_configuring_data: process( clk_50MHz, reset)
	begin
	-- {
		if ( reset = '1') then
			fifo_rd_en <= '0';
			byte_to_bit <= x"00";
			Tx <= '1';
			-- '0': means read one packet
			fifo_write_or_read(0) <= '0';
			serializing_state <= idle;
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			case serializing_state is
				when idle =>
				-- {
					Tx <= '1';
					byte_to_bit <= x"00";
					fifo_write_or_read(0) <= '0';
					-- if ( fifo_empty = '0' and receiving_configure_data_packet > x"0") then
					if ( receiving_configure_data_packet > x"0") then
						fifo_rd_en <= '1';
						fifo_config_data_serializing_state <= idle;
						serializing_state <= wait_for_stable_output;
					else
						fifo_rd_en <= '0';
					end if;
				-- }
				when wait_for_stable_output =>
					Tx <= '1';
					fifo_rd_en <= '0';
					byte_to_bit <= x"00";
					serializing_state <= start_word_judge;
				when start_word_judge =>
					Tx <= '1';
					fifo_rd_en <= '0';
					byte_to_bit <= x"00";
					fifo_config_data_serializing_state <= idle;
					if ( fifo_data_dout(15 downto 8) = x"81") then
						fifo_write_or_read(0) <= '1';
						serializing_state <= fifo_serializing;
					else
						fifo_write_or_read(0) <= '0';
						serializing_state <= idle;
					end if;
				when fifo_serializing =>
				-- {
					fifo_write_or_read(0) <= '0';
					case fifo_config_data_serializing_state is
						when idle =>
							Tx <= '1';
							byte_to_bit <= x"00";
							fifo_rd_en <= '0';
							fifo_config_data_serializing_state <= serializing_normal_data_high_byte ;
						when serializing_normal_data_high_byte =>
						-- {
							case byte_to_bit is
							-- start signal
								when x"00" =>
									Tx <= '0';
									byte_to_bit <= byte_to_bit + x"01";
									fifo_rd_en <= '0';
								-- MSB 7
								when x"01" =>
									if (( fifo_data_dout(15 downto 8) and x"01") = x"01") then
										Tx <= '1';
									else
										Tx <= '0';
									end if;
									fifo_rd_en <= '0';
									byte_to_bit <= byte_to_bit + x"01";
								-- MSB 6
								when x"02" =>
									if (( fifo_data_dout(15 downto 8) and x"02") = x"02") then
										Tx <= '1';
									else
										Tx <= '0';
									end if;
									byte_to_bit <= byte_to_bit + x"01";
								-- MSB 5
								when x"03" =>
									if (( fifo_data_dout(15 downto 8) and x"04") = x"04") then
										Tx <= '1';
									else
										Tx <= '0';
									end if;
									byte_to_bit <= byte_to_bit + x"01";
								-- MSB 4
								when x"04" =>
									if(( fifo_data_dout(15 downto 8) and x"08") = x"08") then
										Tx <= '1';
									else
										Tx <= '0';
									end if;
									byte_to_bit <= byte_to_bit + x"01";
								-- MSB 3
								when x"05" =>
									if (( fifo_data_dout(15 downto 8) and x"10") = x"10") then
										Tx <= '1';
									else
										Tx <= '0';
									end if;
									byte_to_bit <= byte_to_bit + x"01";
								-- MSB 2
								when x"06" =>
									if (( fifo_data_dout(15 downto 8) and x"20") = x"20") then
										Tx <= '1';
									else
										Tx <= '0';
									end if;
									byte_to_bit <= byte_to_bit + x"01";
								-- MSB 1
								when x"07" =>
									if (( fifo_data_dout(15 downto 8) and x"40") = x"40") then
										Tx <= '1';
									else
										Tx <= '0';
									end if;
									byte_to_bit <= byte_to_bit + x"01";
								-- MSB 0
								when x"08" =>
									if (( fifo_data_dout(15 downto 8) and x"80") = x"80") then
										Tx <= '1';
									else
										Tx <= '0';
									end if;
									byte_to_bit <= byte_to_bit + x"01";
								-- end signal
								when  others =>
									Tx <= '1';
									byte_to_bit <= x"00";
									if ( fifo_data_dout( 15 downto 8) = x"FF") then
										fifo_config_data_serializing_state <= idle;
										serializing_state <= idle;
									else
										fifo_config_data_serializing_state <= serializing_normal_data_low_byte;
									end if;
							end case;
						-- }
						when serializing_normal_data_low_byte =>
						-- {
							case byte_to_bit is
								-- high byte
								-- start signal
								when x"00" =>
									Tx <= '0';
									byte_to_bit <= byte_to_bit + x"01";
								-- LSB 7
								when x"01" =>
									if (( fifo_data_dout (7 downto 0) and x"01") = x"01") then
										Tx <= '1';
									else
										Tx <= '0';
									end if;
									byte_to_bit <= byte_to_bit + x"01";
								-- LSB 6
								when x"02" =>
									if (( fifo_data_dout (7 downto 0) and x"02") = x"02") then
										Tx <= '1';
									else
										Tx <= '0';
									end if;
									byte_to_bit <= byte_to_bit + x"01";
								-- LSB 5
								when x"03" =>
									if (( fifo_data_dout (7 downto 0) and x"04") = x"04") then
										Tx <= '1';
									else
										Tx <= '0';
									end if;
									byte_to_bit <= byte_to_bit + x"01";
								-- LSB 4
								when x"04" =>
									if (( fifo_data_dout (7 downto 0) and x"08") = x"08") then
										Tx <= '1';
									else
										Tx <= '0';
									end if;
									byte_to_bit <= byte_to_bit + x"01";
								-- LSB 3
								when x"05" =>
									if (( fifo_data_dout (7 downto 0) and x"10") = x"10") then
										Tx <= '1';
									else
										Tx <= '0';
									end if;
									byte_to_bit <= byte_to_bit + x"01";
								-- LSB 2
								when x"06" =>
									if (( fifo_data_dout (7 downto 0) and x"20") = x"20") then
										Tx <= '1';
									else
										Tx <= '0';
									end if;
									byte_to_bit <= byte_to_bit + x"01";
								-- LSB 1
								when x"07" =>
									if (( fifo_data_dout (7 downto 0) and x"40") = x"40") then
										Tx <= '1';
									else
										Tx <= '0';
									end if;
									byte_to_bit <= byte_to_bit + x"01";
								-- LSB 0
								when x"08" =>
									if (( fifo_data_dout (7 downto 0) and x"80") = x"80") then
										Tx <= '1';
									else
										Tx <= '0';
									end if;
									-- fifo_rd_en <= '0';
									byte_to_bit <= byte_to_bit + x"01";
								-- end signal
								when x"09" =>
									Tx <= '1';
									byte_to_bit <= x"00";
									fifo_config_data_serializing_state <= idle;
									if ( fifo_data_dout( 7 downto 0) = x"FF") then
										fifo_rd_en <= '0';
										serializing_state <= idle;
									else
										fifo_rd_en <= '1';
										serializing_state <= fifo_serializing;
									end if;
								when others =>
							end case;
						-- }
					end case;
				-- }
			end case;
		end if;
	-- }
	end process;
end Behavioral;

