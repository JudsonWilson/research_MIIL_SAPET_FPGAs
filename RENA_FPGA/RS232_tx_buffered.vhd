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
	tx_busy 		: 	out STD_LOGIC;
	tx 			: 	out STD_LOGIC
	);
end RS232_tx_buffered;

architecture Behavioral of RS232_tx_buffered is

constant system_speed : natural := 48000000; --HZ 
constant baudrate : natural := 48000000; -- baud
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

type state_type is (
	IDLE,
	RETRIEVE_DATA,
	SEND_START_BIT,
	SEND_BITS,
	SEND_STOP_BIT,
	SEND_STOP_BIT2,
	CHECK_IF_MORE_DATA);
 
signal state: state_type := IDLE;
signal next_state : state_type := IDLE;
signal state_out : std_logic_vector (2 downto 0);
signal next_state_out : std_logic_vector (2 downto 0);

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

signal fifo_data_out1 : std_logic_vector(7 downto 0);
signal get_next_fifo_data1 : std_logic;

signal fifo_data_out2 : std_logic_vector(7 downto 0);
signal get_next_fifo_data2 : std_logic;

signal current_fifo : std_logic;
signal next_current_fifo : std_logic;

signal still_sending_packet : std_logic;
signal next_still_sending_packet : std_logic;

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

debugOut <= state_out;

process(mclk)
begin 
	if rising_edge(mclk) then
		state <= next_state;
		state_out <= next_state_out;
		tx <= next_tx;
		tx_busy <= next_busy;
		baudrate_counter <= next_baudrate_counter;
		shift_register <= next_shift_register;
		bit_counter <= next_bit_counter;
		current_fifo <= next_current_fifo;
		still_sending_packet <= next_still_sending_packet;
	end if;
end process;

process( state, baudrate_counter, shift_register, bit_counter,
			fifo_data_out1, fifo_empty1, fifo_empty2, fifo_data_out2,
			still_sending_packet,
			current_fifo)
begin

	case state is
		-- 000
		when IDLE =>
			if fifo_empty1 = '0' then
				next_current_fifo <= '0';
				next_state <= RETRIEVE_DATA;
				next_state_out <= "001";
				next_baudrate_counter <= max_counter - 1;
				next_shift_register <= fifo_data_out1;
				next_bit_counter <= 7;
				next_busy <= '1';
				next_tx <= '1';
				get_next_fifo_data1 <= '1';  -- this should be clocked probably
				get_next_fifo_data2 <= '0';
				next_still_sending_packet <= '0';
			elsif fifo_empty2 = '0' then
				next_current_fifo <= '1';
				next_state <= RETRIEVE_DATA;
				next_state_out <= "001";
				next_baudrate_counter <= max_counter - 1;
				next_shift_register <= fifo_data_out2;
				next_bit_counter <= 7;
				next_busy <= '1';
				next_tx <= '1';
				get_next_fifo_data1 <= '0';
				get_next_fifo_data2 <= '1';
				next_still_sending_packet <= '0';
			else
				next_current_fifo <= current_fifo;
				next_state <= state;
				next_state_out <= "000";
				next_baudrate_counter <= max_counter - 1;
				next_shift_register <= shift_register;
				next_bit_counter <= 7;
				next_busy <= '0';
				next_tx <= '1';
				get_next_fifo_data1 <= '0';
				get_next_fifo_data2 <= '0';
				next_still_sending_packet <= '0';
			end if;

		-- 001
		when RETRIEVE_DATA =>
			next_state <= SEND_START_BIT;
			next_state_out <= "010";
			next_baudrate_counter <= max_counter - 1;
			if current_fifo = '0' then
				next_shift_register <= fifo_data_out1;
				case fifo_data_out1 is
					when x"81" =>
						next_still_sending_packet <= '1';
					when x"FF" =>
						next_still_sending_packet <= '0';
					when others =>
						next_still_sending_packet <= still_sending_packet;
				end case;
			else
				next_shift_register <= fifo_data_out2;
				case fifo_data_out2 is
					when x"81" =>
						next_still_sending_packet <= '1';
					when x"FF" =>
						next_still_sending_packet <= '0';
					when others =>
						next_still_sending_packet <= still_sending_packet;
				end case;
			end if;
			next_bit_counter <= 7;
			next_busy <= '1';
			next_tx <= '1';
			get_next_fifo_data1 <= '0';
			get_next_fifo_data2 <= '0';
			next_current_fifo <= current_fifo;

		-- 010
		when SEND_START_BIT =>
			next_shift_register <= shift_register;
			next_busy <= '1';
			next_bit_counter <= 7;
			get_next_fifo_data1 <= '0';
			get_next_fifo_data2 <= '0';
			next_tx <= '0';

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
			next_still_sending_packet <= still_sending_packet;

		-- 011
		when SEND_BITS =>
			next_busy <= '1';
			get_next_fifo_data1 <= '0';
			get_next_fifo_data2 <= '0';
			next_current_fifo <= current_fifo;
			next_still_sending_packet <= still_sending_packet;

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
			get_next_fifo_data1 <= '0';
			get_next_fifo_data2 <= '0';
			next_current_fifo <= current_fifo;
			next_still_sending_packet <= still_sending_packet;

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
			get_next_fifo_data1 <= '0';
			get_next_fifo_data2 <= '0';
			next_current_fifo <= current_fifo;
			next_still_sending_packet <= still_sending_packet;

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
			-- We are currently sending data from fifo 0?
			if current_fifo = '0' then
				-- Read new data from fifo 0 if it is not empty
				if fifo_empty1 = '0' then
					next_current_fifo <= '0';
					next_still_sending_packet <= still_sending_packet;
					next_state <= RETRIEVE_DATA;
					next_state_out <= "001";
					next_baudrate_counter <= max_counter - 1;
					next_shift_register <= fifo_data_out1;
					next_bit_counter <= 7;
					next_busy <= '1';
					next_tx <= '1';
					get_next_fifo_data1 <= '1';
					get_next_fifo_data2 <= '0';
				-- If fifo 0 is empty
				else
					-- If we are in the middle of a packet, the remainder of
					-- the packet must be being written to fifo 0 still. So 
					-- wait and finish sending the packet first, i.e. see the 
					-- termination character 0xFF, before switching to fifo 1.
					if (still_sending_packet = '1') then
						next_current_fifo <= '0';
						next_still_sending_packet <= still_sending_packet;
						next_state <= CHECK_IF_MORE_DATA;
						next_state_out <= "110";
						next_baudrate_counter <= max_counter - 1;
						next_shift_register <= shift_register;
						next_bit_counter <= 7;
						next_busy <= '1';
						next_tx <= '1';
						get_next_fifo_data1 <= '0';
						get_next_fifo_data2 <= '0';
					else
						-- If we have finished sending a full packet from fifo 
						-- 0, switch to sending data from fifo 1 if it is not 
						-- empty.
						if fifo_empty2 = '0' then
							next_current_fifo <= '1';
							next_still_sending_packet <= still_sending_packet;
							next_state <= RETRIEVE_DATA;
							next_state_out <= "001";
							next_baudrate_counter <= max_counter - 1;
							next_shift_register <= fifo_data_out2;
							next_bit_counter <= 7;
							next_busy <= '1';
							next_tx <= '1';
							get_next_fifo_data1 <= '0';
							get_next_fifo_data2 <= '1';
						else
							next_current_fifo <= current_fifo;
							next_still_sending_packet <= still_sending_packet;
							next_state <= IDLE;
							next_state_out <= "000";
							next_baudrate_counter <= max_counter - 1;
							next_shift_register <= shift_register;
							next_bit_counter <= 7;
							next_busy <= '0';
							next_tx <= '1';
							get_next_fifo_data1 <= '0';
							get_next_fifo_data2 <= '0';
						end if;
					end if;
				end if;
			-- We are currently sending data from fifo 1
			else
				-- Read new data from fifo 1 if it is not empty
				if fifo_empty2 = '0' then
					next_current_fifo <= '1';
					next_still_sending_packet <= still_sending_packet;
					next_state <= RETRIEVE_DATA;
					next_state_out <= "001";
					next_baudrate_counter <= max_counter - 1;
					next_shift_register <= fifo_data_out2;
					next_bit_counter <= 7;
					next_busy <= '1';
					next_tx <= '1';
					get_next_fifo_data1 <= '0';
					get_next_fifo_data2 <= '1';
				-- If fifo 0 is empty
				else
					-- If we are in the middle of a packet, the remainder of
					-- the packet must be being written to fifo 1 still. So 
					-- wait and finish sending the packet first, i.e. see the 
					-- termination character 0xFF, before switching to fifo 0.
					if (still_sending_packet = '1') then
						next_current_fifo <= '1';
						next_still_sending_packet <= still_sending_packet;
						next_state <= CHECK_IF_MORE_DATA;
						next_state_out <= "110";
						next_baudrate_counter <= max_counter - 1;
						next_shift_register <= shift_register;
						next_bit_counter <= 7;
						next_busy <= '1';
						next_tx <= '1';
						get_next_fifo_data1 <= '0';
						get_next_fifo_data2 <= '0';
					else
						-- If we have finished sending a full packet from fifo 
						-- 1, switch to sending data from fifo 0 if it is not 
						-- empty.
						if fifo_empty1 = '0' then
							next_current_fifo <= '0';
							next_still_sending_packet <= still_sending_packet;
							next_state <= RETRIEVE_DATA;
							next_state_out <= "001";
							next_baudrate_counter <= max_counter - 1;
							next_shift_register <= fifo_data_out1;
							next_bit_counter <= 7;
							next_busy <= '1';
							next_tx <= '1';
							get_next_fifo_data1 <= '1';
							get_next_fifo_data2 <= '0';
						else
							next_current_fifo <= current_fifo;
							next_still_sending_packet <= still_sending_packet;
							next_state <= IDLE;
							next_state_out <= "000";
							next_baudrate_counter <= max_counter - 1;
							next_shift_register <= shift_register;
							next_bit_counter <= 7;
							next_busy <= '0';
							next_tx <= '1';
							get_next_fifo_data1 <= '0';
							get_next_fifo_data2 <= '0';
						end if;
					end if;
				end if;
			end if;

		when others =>
			next_still_sending_packet <= still_sending_packet;
			next_state <= IDLE;
			next_state_out <= "000";
			next_baudrate_counter <= max_counter - 1;
			next_shift_register <= shift_register;
			next_bit_counter <= 7;
			next_busy <= '1';
			next_tx <= '1';
			get_next_fifo_data1 <= '0';
			get_next_fifo_data2 <= '0';
			next_current_fifo <= current_fifo;
	end case;
end process;
end Behavioral;

