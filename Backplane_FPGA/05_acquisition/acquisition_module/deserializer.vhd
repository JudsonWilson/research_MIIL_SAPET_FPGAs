----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson, based on code by Hua Liu.
--
-- Create Date:    02/12/2014 
-- Design Name:
-- Module Name:    deserializer
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--     Takes a searial UART port input and produces a parallel output. The output
-- signals are meant to directly interface to a FIFO. There is no flow control.
--     Code originates from the Acquisition module by Hua Liu.
--
--     I would like to remove all of the redundant code, use a shift register,
-- etc, but did not have time to refactor that much. - Judson
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
use ieee.std_logic_unsigned.all;

use work.sapet_packets.all;


entity deserializer is
	port(
		reset         : in std_logic;
		clk_50MHz     : in std_logic;
		boardid       : in std_logic_vector(2 downto 0);
		-- Interface, serial input, parallel output
		s_in          : in std_logic;
		p_out_wr      : out std_logic;
		p_out_data    : out std_logic_vector(15 downto 0)
);
end deserializer;

architecture Behavioral of deserializer is
	signal p_out_data_i : std_logic_vector(15 downto 0);

	type deserializer_state_type is ( idle, deserializer_state_first_byte, deserializer_state_second_byte, deserializer_state_other_bytes);
	signal deserializer_state : deserializer_state_type := idle;

	-- State variable for bits 1-8, and a few additional states like start-bit, etc.
	signal bit_in_byte_substate : std_logic_vector(7 downto 0);

begin

	p_out_data <= p_out_data_i;

	deserializer_proc: process( clk_50MHz, reset)
	begin
	-- {
		if ( reset = '1' ) then
			p_out_wr <= '0';
			p_out_data_i <= x"0000";
			deserializer_state <= idle;
			bit_in_byte_substate <= x"00";
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			case deserializer_state is
			when idle =>
				p_out_wr <= '0';
				p_out_data_i <= x"0000";
				bit_in_byte_substate <= x"00";
				if ( s_in = '0') then
					deserializer_state <= deserializer_state_first_byte;
				else
					deserializer_state <= idle;
				end if;
			
			-- Special state receives the first byte so that we can append
			-- the source node address after it.
			when deserializer_state_first_byte =>
			-- {
				case bit_in_byte_substate is
					when x"00" =>
						if (s_in = '1') then
							p_out_data_i(15 downto 8) <= x"01";
						else
							p_out_data_i(15 downto 8) <= x"00";
						end if;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_first_byte;
					when x"01" =>
						if ( s_in = '1') then
							p_out_data_i(15 downto 8) <= p_out_data_i(15 downto 8) or x"02";
						else
							p_out_data_i(15 downto 8) <= p_out_data_i(15 downto 8);

						end if;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_first_byte;
					when x"02" =>
						if ( s_in = '1') then
							p_out_data_i(15 downto 8) <= p_out_data_i(15 downto 8) or x"04";
						else
							p_out_data_i(15 downto 8) <= p_out_data_i(15 downto 8);
						end if;
						p_out_wr <= '0';
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
						deserializer_state <= deserializer_state_first_byte;
					when x"03" =>
						if (s_in = '1') then
							p_out_data_i(15 downto 8) <= p_out_data_i(15 downto 8) or x"08";
						else
							p_out_data_i(15 downto 8) <= p_out_data_i(15 downto 8);
						end if;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_first_byte;
					when x"04" =>
						if ( s_in = '1') then
							p_out_data_i(15 downto 8) <= p_out_data_i(15 downto 8) or x"10";
						else
							p_out_data_i(15 downto 8) <= p_out_data_i(15 downto 8);
						end if;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_first_byte;
					when x"05" =>
						if ( s_in = '1') then
							p_out_data_i(15 downto 8) <= p_out_data_i(15 downto 8) or x"20";
						else
							p_out_data_i(15 downto 8) <= p_out_data_i(15 downto 8);
						end if;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_first_byte;
					when x"06" =>
						if ( s_in = '1') then
							p_out_data_i(15 downto 8) <= p_out_data_i(15 downto 8) or x"40";
						else
							p_out_data_i(15 downto 8) <= p_out_data_i(15 downto 8);
						end if;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_first_byte;
					when x"07" =>
						if ( s_in = '1') then
							p_out_data_i(15 downto 8) <= p_out_data_i(15 downto 8) or x"80";
						else
							p_out_data_i(15 downto 8) <= p_out_data_i(15 downto 8);
						end if;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_first_byte;
					-- The next state assumes a gap of 1 high bit after the byte, and uses
					-- the time to output the new parallel 1st byte while appending the source
					-- node address.
					when x"08" =>
						if is_packet_start_token(p_out_data_i(15 downto 8)) then
							-- From address: to add the current Virtex-5 board id
							-- add the ID of the Virtex-5 board
							p_out_data_i(7 downto 0) <= "00000" & boardid;
							p_out_wr <= '1';
							bit_in_byte_substate <= bit_in_byte_substate + x"01";
							deserializer_state <= deserializer_state_first_byte;
						else
							-- It is not an valid data packet. Discard and wait for another data packet.
							p_out_wr <= '0';
							p_out_data_i <= x"0000";
							bit_in_byte_substate <= x"00";
							deserializer_state <= idle;
						end if;
					-- Wait for next start bit and stop writing the parallel data.
					when x"09" =>
						p_out_wr <= '0';
						p_out_data_i <= x"0000";
						-- wait for the s_in = '0' to start receiving.
						if ( s_in = '0') then
							bit_in_byte_substate <= x"00";
							deserializer_state <= deserializer_state_second_byte; 
						else
							bit_in_byte_substate <= bit_in_byte_substate; -- keep waiting for start bit.
							deserializer_state <= deserializer_state_first_byte;
						end if;
					when others =>
						p_out_wr <= '0';
						p_out_data_i <= x"0000" ;
						deserializer_state <= idle;
						bit_in_byte_substate <= x"00";
				end case;
			-- }

			-- Special state receives the second byte so we can insert the
			-- destination node address after it.
			when deserializer_state_second_byte =>
			-- {
				case bit_in_byte_substate is
					when x"00" =>
						if (s_in = '1') then
							p_out_data_i(7 downto 0) <= x"01";
						else
							p_out_data_i(7 downto 0) <= x"00";
						end if;
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_second_byte;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
					when x"01" =>
						if ( s_in = '1') then
							p_out_data_i(7 downto 0) <= p_out_data_i(7 downto 0) or x"02";
						else
							p_out_data_i(7 downto 0) <= p_out_data_i(7 downto 0);
						end if;
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_second_byte;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
					when x"02" =>
						if ( s_in = '1') then
							p_out_data_i(7 downto 0) <= p_out_data_i(7 downto 0) or x"04";
						else
							p_out_data_i(7 downto 0) <= p_out_data_i(7 downto 0);
						end if;
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_second_byte;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
					when x"03" =>
						if (s_in = '1') then
							p_out_data_i(7 downto 0) <= p_out_data_i(7 downto 0) or x"08";
						else
							p_out_data_i(7 downto 0) <= p_out_data_i(7 downto 0);
						end if;
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_second_byte;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
					when x"04" =>
						if ( s_in = '1') then
							p_out_data_i(7 downto 0) <= p_out_data_i(7 downto 0) or x"10";
						else
							p_out_data_i(7 downto 0) <= p_out_data_i(7 downto 0);
						end if;
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_second_byte;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
					when x"05" =>
						if ( s_in = '1') then
							p_out_data_i(7 downto 0) <= p_out_data_i(7 downto 0) or x"20";
						else
							p_out_data_i(7 downto 0) <= p_out_data_i(7 downto 0);
						end if;
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_second_byte;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
					when x"06" =>
						if ( s_in = '1') then
							p_out_data_i(7 downto 0) <= p_out_data_i(7 downto 0) or x"40";
						else
							p_out_data_i(7 downto 0) <= p_out_data_i(7 downto 0);
						end if;
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_second_byte;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
					when x"07" =>
						if ( s_in = '1') then
							p_out_data_i(7 downto 0) <= p_out_data_i(7 downto 0) or x"80";
						else
							p_out_data_i(7 downto 0) <= p_out_data_i(7 downto 0);
						end if;
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_second_byte;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
					-- The next state assumes a gap of 1 high bit after the byte, and uses
					-- the time to output the new parallel 2nd byte while appending the destination
					-- node address before it.
					when x"08" =>
						-- Add the destination ID, which is always the PC (node 0).
						p_out_wr <= '1';
						p_out_data_i(15 downto 8) <= x"00";
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
						deserializer_state <= deserializer_state_second_byte;
					-- Wait for next start bit and stop writing the parallel data.
					when x"09" =>
						if (s_in = '0') then
							bit_in_byte_substate <= x"00";
							deserializer_state <= deserializer_state_other_bytes;
						else
							bit_in_byte_substate <= bit_in_byte_substate; -- keep waiting for start bit.
							deserializer_state <= deserializer_state_second_byte;
						end if;
						p_out_wr <= '0';
						p_out_data_i <= x"0000";
					when others =>
						p_out_wr <= '0';
						p_out_data_i <= x"0000" ;
						deserializer_state <= idle;
						bit_in_byte_substate <= x"00";
				end case;
			-- }

			-- State for receiving everything AFTER 1st/2nd bytes.
			-- One substate for each bit of 2 bytes, since parallel output data is 16 bit.
			when deserializer_state_other_bytes =>
			-- { 
				case bit_in_byte_substate is
					when x"00" =>
						if (s_in = '1') then
							p_out_data_i(15 downto 8)<= x"01";
						else
							p_out_data_i(15 downto 8)<= x"00";
						end if;
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_other_bytes;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
					when x"01" =>
						if ( s_in = '1') then
							p_out_data_i(15 downto 8)<= p_out_data_i(15 downto 8) or x"02";
						else
							p_out_data_i(15 downto 8)<= p_out_data_i(15 downto 8);
						end if;
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_other_bytes;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
					when x"02" =>
						if ( s_in = '1') then
							p_out_data_i(15 downto 8)<= p_out_data_i(15 downto 8) or x"04";
						else
							p_out_data_i(15 downto 8)<= p_out_data_i(15 downto 8);
						end if;
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_other_bytes;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
					when x"03" =>
						if (s_in = '1') then
							p_out_data_i(15 downto 8)<= p_out_data_i(15 downto 8) or x"08";
						else
							p_out_data_i(15 downto 8)<= p_out_data_i(15 downto 8);
						end if;
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_other_bytes;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
					when x"04" =>
						if ( s_in = '1') then
							p_out_data_i(15 downto 8)<= p_out_data_i(15 downto 8) or x"10";
						else
							p_out_data_i(15 downto 8)<= p_out_data_i(15 downto 8);
						end if;
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_other_bytes;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
					when x"05" =>
						if ( s_in = '1') then
							p_out_data_i(15 downto 8)<= p_out_data_i(15 downto 8) or x"20";
						else
							p_out_data_i(15 downto 8)<= p_out_data_i(15 downto 8);
						end if;
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_other_bytes;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
					when x"06" =>
						if ( s_in = '1') then
							p_out_data_i(15 downto 8)<= p_out_data_i(15 downto 8) or x"40";
						else
							p_out_data_i(15 downto 8)<= p_out_data_i(15 downto 8);
						end if;
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_other_bytes;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
					when x"07" =>
						if ( s_in = '1') then
							p_out_data_i(15 downto 8)<= p_out_data_i(15 downto 8) or x"80";
						else
							p_out_data_i(15 downto 8)<= p_out_data_i(15 downto 8);
						end if;
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_other_bytes;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
					-- Wait between bytes, check and see if this was the end of packet.
					-- If end of packet, send the end of packet token & x"00" out and 
					-- terminate state early.
					when x"08" =>
						-- The end signal for the whole packet is 0xFF.
							  -- As soon as the 0xFF is coming, another data packet will be save to another fifo.
						if ( p_out_data_i(15 downto 8)= x"FF") then
							-- Leave this process to wait for another data packet.
							p_out_data_i(15 downto 0) <= x"FF00";
							p_out_wr <= '1';
							bit_in_byte_substate <= x"00";
							deserializer_state <= idle;
						else
							p_out_wr <= '0';
							p_out_data_i <= p_out_data_i;
							bit_in_byte_substate <= bit_in_byte_substate + x"01";
							deserializer_state <= deserializer_state_other_bytes;
						end if;
					-- Wait for start bit.
					when x"09" =>
						-- !!!!
						-- If there is no data input, the process will stay here untill the new data incoming.
					--	write_or_read_one_packet(0)(0) <= '0';
						p_out_data_i <= p_out_data_i;
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_other_bytes;
						if (s_in = '0') then
							bit_in_byte_substate <= x"10";
						else
							bit_in_byte_substate <= bit_in_byte_substate; -- keep waiting for start bit
						end if;
					when x"10" => 
						if (s_in = '1') then
							p_out_data_i(7 downto 0) <= x"01";
						else
							p_out_data_i(7 downto 0) <= x"00";
						end if;
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_other_bytes;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
					when x"11" =>
						if ( s_in = '1') then
							p_out_data_i(7 downto 0) <= p_out_data_i(7 downto 0) or x"02";
						else
							p_out_data_i <= p_out_data_i ;
						end if;
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_other_bytes;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
					when x"12" =>
						if ( s_in = '1') then
							p_out_data_i(7 downto 0) <= p_out_data_i(7 downto 0) or x"04";
						else
							p_out_data_i <= p_out_data_i ;
						end if;
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_other_bytes;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
					when x"13" =>
						if (s_in = '1') then
							p_out_data_i(7 downto 0) <= p_out_data_i(7 downto 0) or x"08";
						else
							p_out_data_i <= p_out_data_i ;
						end if;
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_other_bytes;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
					when x"14" =>
						if ( s_in = '1') then
							p_out_data_i(7 downto 0) <= p_out_data_i(7 downto 0) or x"10";
						else
							p_out_data_i <= p_out_data_i ;
						end if;
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_other_bytes;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
					when x"15" =>
						if ( s_in = '1') then
							p_out_data_i(7 downto 0) <= p_out_data_i(7 downto 0) or x"20";
						else
							p_out_data_i <= p_out_data_i ;
						end if;
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_other_bytes;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
					when x"16" =>
						if ( s_in = '1') then
							p_out_data_i(7 downto 0) <= p_out_data_i(7 downto 0) or x"40";
						else
							p_out_data_i <= p_out_data_i ;
						end if;
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_other_bytes;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
					when x"17" =>
						if ( s_in = '1') then
							p_out_data_i(7 downto 0) <= p_out_data_i(7 downto 0) or x"80";
						else
							p_out_data_i <= p_out_data_i ;
						end if;
						p_out_wr <= '0';
						deserializer_state <= deserializer_state_other_bytes;
						bit_in_byte_substate <= bit_in_byte_substate + x"01";
					-- The next state assumes a gap of 1 high bit after the byte, and uses
					-- the time to output the new parallel 2nd byte and deciding wether the
					-- packet is done or not.
					when x"18" =>
						-- The end signal for the whole packet is 0xFF.
							  -- As soon as the 0xFF is coming, another data packet will be save to another fifo.
						if ( p_out_data_i(7 downto 0) = x"FF") then
							-- Leave the state to wait for another data packet.
							bit_in_byte_substate <= x"00";
							deserializer_state <= idle;
						else
							bit_in_byte_substate <= bit_in_byte_substate + x"01";
							deserializer_state <= deserializer_state_other_bytes;
						end if;
						p_out_wr <= '1';
						p_out_data_i <= p_out_data_i ;
					-- Wait for start-bit. 
					when x"19" =>
						if (s_in = '0') then
							bit_in_byte_substate <= x"00";
						else
							bit_in_byte_substate <= bit_in_byte_substate;
						end if;
						p_out_wr <= '0';
						p_out_data_i <= x"0000" ;
						deserializer_state <= deserializer_state_other_bytes;
					when others =>
						p_out_wr <= '0';
						p_out_data_i <= x"0000" ;
						deserializer_state <= idle;
						bit_in_byte_substate <= x"00";
				end case;
			-- }

			when others =>
				p_out_wr <= '0';
				p_out_data_i <= x"0000" ;
				deserializer_state <= idle;
				bit_in_byte_substate <= x"00";
			end case;
		end if;
	end process;
end Behavioral;

