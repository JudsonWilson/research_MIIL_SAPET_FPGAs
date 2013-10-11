----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:23:55 02/07/2009 
-- Design Name: 
-- Module Name:    Serial_rx - Behavioral 
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

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Serial_rx is
    Port ( mclkx2   : in   STD_LOGIC;
           rx       : in   STD_LOGIC;
           data     : out  STD_LOGIC_VECTOR (7 downto 0);
           new_data : out  STD_LOGIC);
end Serial_rx;

architecture Behavioral of Serial_rx is

-- Constant definitions
constant system_speed       : natural := 48000000; -- HZ
constant system_speed_x2    : natural := system_speed*2; -- Hz
constant baudrate           : natural := 48000000; -- baud
constant max_counter_rx  : natural := system_speed_x2 / baudrate;
constant max_counter_sys : natural := system_speed_x2 / system_speed;

-- FSM state definitions
type state_type is (
	IDLE,
	RECEIVE_START_BIT,
	RECEIVE_BITS,
	RECEIVE_STOP_BIT);

type new_data_bit_state_type is (
	LO,
	HI);

-- Signal declarations
signal state      : state_type := IDLE;
signal next_state : state_type := IDLE;

signal new_data_bit_state      : new_data_bit_state_type := LO;
signal next_new_data_bit_state : new_data_bit_state_type := LO;

signal baudrate_counter      : natural range 0 to max_counter_rx := 0;
signal next_baudrate_counter : natural range 0 to max_counter_rx := 0;

signal sysspeed_counter      : natural range 0 to max_counter_sys := 0;
signal next_sysspeed_counter : natural range 0 to max_counter_sys := 0;

signal bit_counter: natural range 0 to 7 := 0;
signal next_bit_counter: natural range 0 to 7 := 0;

signal shift_register: STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
signal next_shift_register: STD_LOGIC_VECTOR(7 downto 0) := (others => '0');

signal next_new_data1 : std_logic;
signal next_new_data2 : std_logic;

signal data_temp : std_logic_vector(7 downto 0);
signal next_data_temp : std_logic_vector(7 downto 0);
  
begin

data <= data_temp;

-- DFFs
process(mclkx2)
 begin
	if rising_edge(mclkx2) then
		state <= next_state;
		new_data_bit_state <= next_new_data_bit_state;
		bit_counter <= next_bit_counter;
		baudrate_counter <= next_baudrate_counter;
		sysspeed_counter <= next_sysspeed_counter;
		shift_register <= next_shift_register;
		-- Due to jitter between the mclk and mclkx2 clock domains,
		-- delay by one mlkX2 cycle for good measure.
		new_data <= next_new_data1;
		next_new_data1 <= next_new_data2;
		data_temp <= next_data_temp;
	end if;
end process;

-- RX FSM
-- The FMS assumes 1 start bit, 8 data bits (LB first), 1 stop bit, and
-- active low signals.
process(shift_register, state, rx, baudrate_counter, bit_counter, data_temp)
	begin
		case state is
		-- Wait until the rx line asserts valid data
		when IDLE =>
			next_shift_register <= shift_register;
			next_data_temp <= data_temp;
			next_bit_counter <= 7;

			-- We use (max_counter_rx/2)-1 to ensure that we read the start
			-- bit in the middle of the bit, maximally away from clock edges.
			-- Subsqeuently, we continue to read (or sample) bits in the
			-- middle of the bits every max_counter_rx clock cycles.
			next_baudrate_counter <= (max_counter_rx/2)-1;

			if rx = '0' then
				next_state <= RECEIVE_START_BIT;
			else
				next_state <= state;
			end if;

		when RECEIVE_START_BIT =>
			next_shift_register <= shift_register;
			next_data_temp <= data_temp;
			next_bit_counter <= 7;

			if baudrate_counter = 0 then
				next_state <= RECEIVE_BITS;
				next_baudrate_counter <= max_counter_rx - 1;
			else
				next_state <= state;
				next_baudrate_counter <= baudrate_counter - 1;
			end if;

		when RECEIVE_BITS =>
			next_data_temp <= data_temp;

			if baudrate_counter = 0 then
				next_baudrate_counter <= max_counter_rx - 1;
				next_shift_register <= rx & shift_register(7 downto 1);

				if bit_counter = 0 then
					next_state <= RECEIVE_STOP_BIT;
					next_bit_counter <= 7;
				else
					next_state <= state;
					next_bit_counter <= bit_counter - 1;
				end if;
			else
				next_state <= state;
				next_baudrate_counter <= baudrate_counter - 1;
				next_shift_register <= shift_register;
				next_bit_counter <= bit_counter;
			end if;

		when RECEIVE_STOP_BIT =>
			if baudrate_counter = 0 then
				next_data_temp <= shift_register;
				next_baudrate_counter <= (max_counter_rx/2)-1;
				next_shift_register <= shift_register;
				next_bit_counter <= 7;
				next_state <= IDLE;		
			else
				next_data_temp <= data_temp;
				next_state <= state;
				next_baudrate_counter <= baudrate_counter - 1;
				next_shift_register <= shift_register;
				next_bit_counter <= 7;
			end if;
		
		when others =>
			next_baudrate_counter <= (max_counter_rx/2)-1;
			next_data_temp <= data_temp;
			next_shift_register <= shift_register;
			next_bit_counter <= 7;
			next_state <= IDLE;
		end case;
end process;

-- New data bit FSM
-- The FSM ensures the new_data bit is high for 1 system clock cycle
process(new_data_bit_state, sysspeed_counter, state, baudrate_counter)
	begin
		case new_data_bit_state is
		when LO =>
			next_sysspeed_counter <= max_counter_sys - 1;
			if ((state = RECEIVE_STOP_BIT) and (baudrate_counter = 0)) then
				next_new_data_bit_state <= HI;
				next_new_data2 <= '1';
			else
				next_new_data_bit_state <= LO;
				next_new_data2 <= '0';
			end if;
			
		when HI =>
			if ((state = RECEIVE_STOP_BIT) and (baudrate_counter = 0)) then
				next_sysspeed_counter <= max_counter_sys - 1;
				next_new_data_bit_state <= HI;
				next_new_data2 <= '1';
			else
				if (sysspeed_counter = 0) then
					next_sysspeed_counter <= max_counter_sys - 1;
					next_new_data_bit_state <= LO;
					next_new_data2 <= '0';
				else
					next_sysspeed_counter <= sysspeed_counter - 1;
					next_new_data_bit_state <= HI;
					next_new_data2 <= '1';
				end if;
			end if;
			
		when others =>
			next_sysspeed_counter <= max_counter_sys - 1;
			next_new_data_bit_state <= LO;
			next_new_data2 <= '0';
		end case;
end process;

end Behavioral;
