----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    08:18:24 08/26/2008 
-- Design Name: 
-- Module Name:    RS232_tx - Behavioral 
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
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity RS232_tx_buffered is
Port ( 
	debugOut    : out STD_LOGIC_VECTOR (2 downto 0);
	mclk 			: 	in STD_LOGIC;
	data1 		: 	in STD_LOGIC_VECTOR (7 downto 0);
	new_data1	:  in STD_LOGIC;
	data2 		: 	in STD_LOGIC_VECTOR (7 downto 0);
	new_data2	:  in STD_LOGIC;
	data3 		: 	in STD_LOGIC_VECTOR (7 downto 0);
	new_data3	:  in STD_LOGIC;
	tx_busy 		: 	out STD_LOGIC;
	tx 			: 	out STD_LOGIC
	);
end RS232_tx_buffered;

architecture Behavioral of RS232_tx_buffered is

constant system_speed : natural := 48000000; --HZ 
constant baudrate : natural := 48000000; -- baud setting for UDP
--constant baudrate : natural := 12000000; -- baud setting for USB
constant max_counter: natural := system_speed / baudrate;

component TX_Fifo
port (
	clk			: IN std_logic;
	din			: IN std_logic_VECTOR(7 downto 0);
	rd_en			: IN std_logic;
	srst			: IN std_logic;
	wr_en			: IN std_logic;
	dout			: OUT std_logic_VECTOR(7 downto 0);
	empty			: OUT std_logic;
	full			: OUT std_logic
	);
end component;

component crc8byte
	port (
		new_byte : in  std_logic_vector(7 downto 0);
		prev_crc : in  std_logic_vector(7 downto 0);
		next_crc : out std_logic_vector(7 downto 0)
	);
end component;

type state_type is (
	IDLE,
	FINISH_RETRIEVE_DATA_FROM_FIFO,
	SEND_START_BIT,
	SEND_BITS,
	SEND_STOP_BIT,
	SEND_STOP_BIT2,
	CHECK_IF_MORE_DATA);
 
signal state: state_type := IDLE;
signal next_state : state_type := IDLE;
signal state_out : std_logic_vector (2 downto 0);
signal next_state_out : std_logic_vector (2 downto 0);

-- The data source state is used to hold states that signify whether
-- grabbing data from a FIFO for the beginning of a packet, or
-- inserting crc bytes at the end of a packet.
constant DATA_SOURCE_FIFOS : std_logic_vector (1 downto 0) := "00";
constant DATA_SOURCE_CRC2  : std_logic_vector (1 downto 0) := "01"; -- CRC last 4 bits,  just before end of packet. (First 4 bits triggered by FIFO 0xFF).
constant DATA_SOURCE_FF    : std_logic_vector (1 downto 0) := "10"; -- x"FF" code at end of packet
constant DATA_SOURCE_DONE  : std_logic_vector (1 downto 0) := "11"; -- Packet is done loading data. Once sent, find new packet to send.
signal data_source : std_logic_vector (1 downto 0); -- Sort of a state machine hack used to insert the CRC before the last 0xFF byte.
signal next_data_source : std_logic_vector (1 downto 0); -- Sort of a state machine hack used to insert the CRC before the last 0xFF byte.

signal next_tx : std_logic;
signal next_busy : std_logic;

signal baudrate_counter: natural range 0 to max_counter := 0;
signal next_baudrate_counter : natural range 0 to max_counter := 0;

signal bit_counter: natural range 0 to 7 := 0;
signal next_bit_counter : natural range 0 to 7 := 0;

signal shift_register: STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
signal next_shift_register : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');

signal fifo_empty1 : std_logic;
signal fifo_empty2 : std_logic;
signal fifo_empty3 : std_logic;

signal fifo_data_out1 : std_logic_vector(7 downto 0);
signal get_next_fifo_data1 : std_logic;

signal fifo_data_out2 : std_logic_vector(7 downto 0);
signal get_next_fifo_data2 : std_logic;

signal fifo_data_out3 : std_logic_vector(7 downto 0);
signal get_next_fifo_data3 : std_logic;

signal current_fifo : std_logic_vector(1 downto 0);
signal next_current_fifo : std_logic_vector(1 downto 0);

signal current_fifo_empty : std_logic;
signal current_fifo_data_out : std_logic_vector(7 downto 0);
signal get_next_current_fifo_data : std_logic;

signal crc_new_byte      : std_logic_vector(7 downto 0);
signal next_crc_new_byte : std_logic_vector(7 downto 0);
signal crc_prev_crc      : std_logic_vector(7 downto 0);
signal next_crc_prev_crc : std_logic_vector(7 downto 0);
signal crc_new_crc       : std_logic_vector(7 downto 0);

begin

TX_FIFO1 : TX_Fifo port map(
	clk	=>   	mclk,
	din	=> 	data1,
	rd_en	=>		get_next_fifo_data1,
	srst	=> 	'0',
	wr_en	=> 	new_data1,
	dout	=>		fifo_data_out1,
	empty	=> 	fifo_empty1,
	full	=>		open
);

TX_FIFO2 : TX_Fifo port map(
	clk	=>   	mclk,
	din	=> 	data2,
	rd_en	=>		get_next_fifo_data2,
	srst	=> 	'0',
	wr_en	=> 	new_data2,
	dout	=>		fifo_data_out2,
	empty	=> 	fifo_empty2,
	full	=>		open
);

TX_FIFO3 : TX_Fifo port map(
	clk	=>   	mclk,
	din	=> 	data3,
	rd_en	=>		get_next_fifo_data3,
	srst	=> 	'0',
	wr_en	=> 	new_data3,
	dout	=>		fifo_data_out3,
	empty	=> 	fifo_empty3,
	full	=>		open
);

CRC8_CALCULATOR: crc8byte
	port map(
		new_byte => crc_new_byte,
		prev_crc => crc_prev_crc,
		next_crc => crc_new_crc
	);

debugOut <= state_out;

process(mclk)
begin 
	if rising_edge(mclk) then
		state <= next_state;
		state_out <= next_state_out;
		data_source <= next_data_source;
		tx <= next_tx;
		tx_busy <= next_busy;
		baudrate_counter <= next_baudrate_counter;
		shift_register <= next_shift_register;
		bit_counter <= next_bit_counter;
		current_fifo <= next_current_fifo;
		crc_new_byte <= next_crc_new_byte;
		crc_prev_crc <= next_crc_prev_crc;
	end if;
end process;

--This process basically is a mux connecting various signals into a unified single
--"current_fifo" interface to reduce code elsewhere. Follows the model that only
--one fifo is used at a time (on the output side).
fifo_mux_proc: process( next_current_fifo, current_fifo,
                        fifo_data_out1, fifo_empty1,
                        fifo_data_out2, fifo_empty2,
                        fifo_data_out3, fifo_empty3,
                        get_next_current_fifo_data
                      )
begin
	case current_fifo is
	when "01" =>
		current_fifo_empty <= fifo_empty1;
		current_fifo_data_out <= fifo_data_out1;
	when "10" =>
		current_fifo_empty <= fifo_empty2;
		current_fifo_data_out <= fifo_data_out2;
	when others =>
		current_fifo_empty <= fifo_empty3;
		current_fifo_data_out <= fifo_data_out3;
	end case;

	--Update "get_next_fifo_data#" instantaneously after a transition of
	--"next_current_fifo" so that the fifo's read bit is set active
	--before the next clock edge.
	--Do this because we only switch fifos when data is available on
	--another fifo, and we want the first byte of data on the next tick.
	case next_current_fifo is
	when "01" =>
		get_next_fifo_data1 <= get_next_current_fifo_data;
		get_next_fifo_data2 <= '0';
		get_next_fifo_data3 <= '0';
	when "10" =>
		get_next_fifo_data1 <= '0';
		get_next_fifo_data2 <= get_next_current_fifo_data;
		get_next_fifo_data3 <= '0';
	when others =>
		get_next_fifo_data1 <= '0';
		get_next_fifo_data2 <= '0';
		get_next_fifo_data3 <= get_next_current_fifo_data;
	end case;
end process fifo_mux_proc;


process( state, data_source, baudrate_counter, shift_register, bit_counter,
         fifo_empty1, fifo_empty2, fifo_empty3,
         current_fifo, current_fifo_data_out, current_fifo_empty,
         crc_new_byte, crc_prev_crc, crc_new_crc
       )
begin

	case state is
		-- 000
		when IDLE =>
			-- If data to send
			if fifo_empty1 = '0' or fifo_empty2 = '0' or fifo_empty3 = '0' then
				--choose a fifo
				if fifo_empty1 = '0' then
					next_current_fifo <= "01";
				elsif fifo_empty2 = '0' then
					next_current_fifo <= "10";
				else
					next_current_fifo <= "11";
				end if;
				--Setup retrieval of data
				next_state <= FINISH_RETRIEVE_DATA_FROM_FIFO;
				next_state_out <= "001";
				next_busy <= '1';
				get_next_current_fifo_data <= '1';
			else
				next_current_fifo <= current_fifo;
				next_state <= state;
				next_state_out <= "000";
				next_busy <= '0';
				get_next_current_fifo_data <= '0';
			end if;
			next_baudrate_counter <= max_counter - 1;
			next_shift_register <= shift_register;
			next_bit_counter <= 7;
			next_tx <= '1';
			next_data_source <= DATA_SOURCE_DONE; --Leave as done, used for diagnostic purposes on the first byte of next packet.
			next_crc_prev_crc <= crc_prev_crc; -- do not update crc, hold inputs constant
			next_crc_new_byte <= crc_new_byte;

		-- 001
		when FINISH_RETRIEVE_DATA_FROM_FIFO =>
			next_state <= SEND_START_BIT;
			next_state_out <= "010";
			next_baudrate_counter <= max_counter - 1;
			--TODO: check the top bit on everyth byte, and only allow "1" if valid starting token and data_source=DATA_SOURCE_NONE
			case current_fifo_data_out is
			--Valid Start-of-Packet Token.
			when x"81" =>
				next_shift_register <= current_fifo_data_out;
				next_data_source <= DATA_SOURCE_FIFOS;
				next_crc_prev_crc <= x"00"; -- start a new crc on the packet
				next_crc_new_byte <= current_fifo_data_out;
			when x"82" =>
				next_shift_register <= current_fifo_data_out;
				next_data_source <= DATA_SOURCE_FIFOS;
				next_crc_prev_crc <= x"00"; -- start a new crc on the packet
				next_crc_new_byte <= current_fifo_data_out;
			when x"84" =>
				next_shift_register <= current_fifo_data_out;
				next_data_source <= DATA_SOURCE_FIFOS;
				next_crc_prev_crc <= x"00"; -- start a new crc on the packet
				next_crc_new_byte <= current_fifo_data_out;
			--End-of-Packet Token
			when x"FF" =>
				--We have just read the last byte in the packet. Insert the crc bytes now.
				next_shift_register <= "0000" & crc_new_crc(7 downto 4);
				next_data_source <= DATA_SOURCE_CRC2;
				next_crc_prev_crc <= crc_prev_crc; -- do not update crc, it is done for packet, hold inputs constant
				next_crc_new_byte <= crc_new_byte;
			--Body, or Erroneous Token
			when others =>
				--body of packet, unless DATA_SOURCE_DONE, then error
				if data_source = DATA_SOURCE_DONE then
					-- TODO FIXME: This is a bug condition. Throw diagnostic.
					-- This should be the start of a packet but is the wrong
					-- byte code.
				end if;
				next_shift_register <= current_fifo_data_out;
				next_data_source <= data_source; --If in DATA_SOURCE_DONE error condition, stay done, will give priority to other FIFOs, etc. Untested, may be the wrong thing to do.
				next_crc_prev_crc <= crc_new_crc; -- update the crc. Feed last value in as new input, with next byte in packet.
				next_crc_new_byte <= current_fifo_data_out;
			end case;
			next_bit_counter <= 7;
			next_busy <= '1';
			next_tx <= '1';
			get_next_current_fifo_data <= '0';
			next_current_fifo <= current_fifo;

		-- 010
		when SEND_START_BIT =>
			next_shift_register <= shift_register;
			next_busy <= '1';
			next_bit_counter <= 7;
			next_tx <= '0';
			get_next_current_fifo_data <= '0';
			next_data_source <= data_source;
			next_crc_prev_crc <= crc_prev_crc; -- do not update crc, hold inputs constant
			next_crc_new_byte <= crc_new_byte;

			if baudrate_counter = 0 then
				next_state <= SEND_BITS;
				next_state_out <= "011";
				next_baudrate_counter <= max_counter - 1;
			else
				next_state <= state;
				next_state_out <= "010";
				next_baudrate_counter <= baudrate_counter - 1;
			end if;

			next_current_fifo <= current_fifo;

		-- 011
		when SEND_BITS =>
			next_busy <= '1';
			get_next_current_fifo_data <= '0';
			next_data_source <= data_source;
			next_crc_prev_crc <= crc_prev_crc; -- do not update crc, hold inputs constant
			next_crc_new_byte <= crc_new_byte;
			next_current_fifo <= current_fifo;

			if baudrate_counter = 0 then
				next_baudrate_counter <= max_counter - 1;

				if bit_counter = 0 then
					next_state <= SEND_STOP_BIT;
					next_state_out <= "100";
					next_shift_register <= shift_register;
					next_bit_counter <= 7;
					next_tx <= shift_register(0);
				else
					next_state <= state;
					next_state_out <= "011";
					next_shift_register <= '0' & shift_register(7 downto 1);
					next_bit_counter <= bit_counter - 1;
					next_tx <= shift_register(0);
				end if;

			else
				next_state <= state;
				next_state_out <= "011";
				next_baudrate_counter <= baudrate_counter - 1;
				next_shift_register <= shift_register;
				next_bit_counter <= bit_counter;
				next_tx <= shift_register(0);
			end if;

		-- 100
		when SEND_STOP_BIT =>
			get_next_current_fifo_data <= '0';
			next_data_source <= data_source;
			next_crc_prev_crc <= crc_prev_crc; -- do not update crc, hold inputs constant
			next_crc_new_byte <= crc_new_byte;
			next_current_fifo <= current_fifo;

			if baudrate_counter = 0 then
				next_state <= SEND_STOP_BIT2;
				next_state_out <= "101";
				next_baudrate_counter <= max_counter - 1;
				next_shift_register <= shift_register;
				next_bit_counter <= 7;
				next_busy <= '1';
				next_tx <= '1';
			else
				next_state <= state;
				next_state_out <= "100";
				next_baudrate_counter <= baudrate_counter - 1;
				next_shift_register <= shift_register;
				next_bit_counter <= 7;
				next_busy <= '1';
				next_tx <= '1';
			end if;

		-- 101
		when SEND_STOP_BIT2 =>
			get_next_current_fifo_data <= '0';
			next_data_source <= data_source;
			next_crc_prev_crc <= crc_prev_crc; -- do not update crc, hold inputs constant
			next_crc_new_byte <= crc_new_byte;
			next_current_fifo <= current_fifo;

			if baudrate_counter = 0 then
				next_state <= CHECK_IF_MORE_DATA;
				next_state_out <= "110";
				next_baudrate_counter <= max_counter - 1;
				next_shift_register <= shift_register;
				next_bit_counter <= 7;
				next_busy <= '1';
				next_tx <= '1';
			else
				next_state <= state;
				next_state_out <= "101";
				next_baudrate_counter <= baudrate_counter - 1;
				next_shift_register <= shift_register;
				next_bit_counter <= 7;
				next_busy <= '1';
				next_tx <= '1';
			end if;

		-- 110
		when CHECK_IF_MORE_DATA =>
			case data_source is
			-- Middle of packet. Wait here for more FIFO data. Must complete the packet.
			when DATA_SOURCE_FIFOS =>
				-- Can we read more data from the current fifo immediately?
				if current_fifo_empty = '0' then
					next_shift_register <= shift_register;
					get_next_current_fifo_data <= '1';
					next_crc_prev_crc <= crc_prev_crc; -- do not update crc, hold inputs constant
					next_data_source <= data_source;
					next_crc_new_byte <= crc_new_byte;
					next_current_fifo <= current_fifo;
					next_state <= FINISH_RETRIEVE_DATA_FROM_FIFO;
					next_state_out <= "001";
					next_baudrate_counter <= max_counter - 1;
					next_bit_counter <= 7;
					next_busy <= '1';
					next_tx <= '1';
				-- If we are in the middle of a packet, the remainder of
				-- the packet must be being written to its fifo still. So 
				-- wait and finish sending the packet.
				else
					next_current_fifo <= current_fifo;
					next_state <= CHECK_IF_MORE_DATA;
					next_state_out <= "110";
					next_baudrate_counter <= max_counter - 1;
					next_shift_register <= shift_register;
					next_bit_counter <= 7;
					next_busy <= '1';
					next_tx <= '1';
					get_next_current_fifo_data <= '0';
					next_data_source <= data_source;
					next_crc_prev_crc <= crc_prev_crc; -- do not update crc, hold inputs constant
					next_crc_new_byte <= crc_new_byte;
				end if;

			-- Load up the second half of the CRC in a packet and set state directly to transmit.
			-- Set data source to x"FF" for next byte in packet.
			when DATA_SOURCE_CRC2 =>
				next_shift_register <= "0000" & crc_new_crc(3 downto 0);
				next_data_source <= DATA_SOURCE_FF;
				get_next_current_fifo_data <= '0';
				next_crc_prev_crc <= crc_prev_crc; -- do not update crc, hold inputs constant
				next_crc_new_byte <= crc_new_byte;
				next_current_fifo <= current_fifo;
				next_state <= SEND_START_BIT;
				next_state_out <= "010";
				next_baudrate_counter <= max_counter - 1;
				next_bit_counter <= 7;
				next_busy <= '1';
				next_tx <= '1';

			-- Load up the x"FF" in the shift register and set state directly to transmit.
			-- After the end-of-packet FF, kick data source back to FIFO in case there is
			-- another packet to send, or the 
			when DATA_SOURCE_FF =>
				next_shift_register <= x"FF";
				next_data_source <= DATA_SOURCE_DONE;
				get_next_current_fifo_data <= '0';
				next_crc_prev_crc <= crc_prev_crc; -- do not update crc, hold inputs constant
				next_crc_new_byte <= crc_new_byte;
				next_current_fifo <= current_fifo;
				next_state <= SEND_START_BIT;
				next_state_out <= "010";
				next_baudrate_counter <= max_counter - 1;
				next_bit_counter <= 7;
				next_busy <= '1';
				next_tx <= '1';

			when others => --DATA_SOURCE_DONE
				-- If we have finished sending a full packet from current 
				-- fifo, switch to sending data from highest priority fifo
				-- that has data, if any. This step is important to make
				-- sure we empty all FIFOs before we clear the busy flag,
				-- but order of priority probably does not matter because
				-- no FIFOs should fill when busy.
				-- Data fifos (1 and 2) have higher priority than
				-- diagnostic fifo (3)
				next_baudrate_counter <= max_counter - 1;
				next_shift_register <= shift_register;
				next_bit_counter <= 7;
				next_tx <= '1';
				next_data_source <= DATA_SOURCE_DONE; --Leave as done, used for diagnostic purposes on the first byte of next packet.
				next_crc_prev_crc <= crc_prev_crc; -- do not update crc, hold inputs constant
				next_crc_new_byte <= crc_new_byte;
				--switch fifo if above condition true
				if fifo_empty1 = '0' or fifo_empty2 = '0' or fifo_empty3 = '0' then
					if fifo_empty1 = '0' then
						next_current_fifo <= "01";
					elsif fifo_empty2 = '0' then
						next_current_fifo <= "10";
					else
						next_current_fifo <= "11";
					end if;
					next_state <= FINISH_RETRIEVE_DATA_FROM_FIFO;
					next_state_out <= "001";
					next_busy <= '1';
					get_next_current_fifo_data <= '1';
				else
					next_current_fifo <= current_fifo;
					next_state <= IDLE;
					next_state_out <= "000";
					next_busy <= '0';
					get_next_current_fifo_data <= '0';
				end if;
			end case;
		when others =>
			next_data_source <= DATA_SOURCE_DONE; --Set as done, used for diagnostic purposes on the first byte of next packet.
			next_state <= IDLE;
			next_state_out <= "000";
			next_baudrate_counter <= max_counter - 1;
			next_shift_register <= shift_register;
			next_bit_counter <= 7;
			next_busy <= '1';
			next_tx <= '1';
			get_next_current_fifo_data <= '0';
			next_crc_prev_crc <= crc_prev_crc; -- do not update crc, hold inputs constant
			next_crc_new_byte <= crc_new_byte;
			next_current_fifo <= current_fifo;
	end case;
end process;
end Behavioral;

