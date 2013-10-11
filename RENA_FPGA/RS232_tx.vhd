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

entity RS232_tx is
    Port ( mclk 			: 	in STD_LOGIC;
           data 			: 	in STD_LOGIC_VECTOR (7 downto 0);
           send_data 	: 	in STD_LOGIC;
           busy 			: 	out STD_LOGIC;
           tx 				: 	out STD_LOGIC);
end RS232_tx;

architecture Behavioral of RS232_tx is
constant system_speed : natural := 48000000; --HZ 
constant baudrate : natural := 12000000; -- baud
constant max_counter: natural := system_speed / baudrate ;

  type state_type is (
    IDLE,
    SEND_START_BIT,
    SEND_BITS,
    SEND_STOP_BIT);
	 
  signal state: state_type := IDLE;
  signal next_state : state_type := IDLE;
  signal next_tx : std_logic;
  signal next_busy : std_logic;

  signal baudrate_counter: natural range 0 to max_counter := 0;
  signal next_baudrate_counter : natural range 0 to max_counter := 0;
  
  signal bit_counter: natural range 0 to 7 := 0;
  signal next_bit_counter : natural range 0 to 7 := 0;
  
  signal shift_register: STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
  signal next_shift_register : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');

begin

	process(mclk)
	begin 
		if rising_edge(mclk) then
			state <= next_state;
			tx <= next_tx;
			busy <= next_busy;
			baudrate_counter <= next_baudrate_counter;
			shift_register <= next_shift_register;
			bit_counter <= next_bit_counter;
		end if;
	end process;


  process( state, send_data, baudrate_counter, shift_register, bit_counter, data )
  begin
	  case state is
		 when IDLE =>
			if send_data = '1' then
			  next_state <= SEND_START_BIT;
			  next_baudrate_counter <= max_counter - 1;
			  next_shift_register <= data;
			  next_bit_counter <= 7;
			  next_busy <= '1';
			  next_tx <= '0';
			else
			  next_state <= state;
			  next_baudrate_counter <= max_counter - 1;
			  next_shift_register <= shift_register;
			  next_bit_counter <= 7;
			  next_busy <= '0';
			  next_tx <= '1';
			end if;

		 when SEND_START_BIT =>
			next_shift_register <= shift_register;
			next_busy <= '1';
			next_bit_counter <= 7;
			
			if baudrate_counter = 0 then
			  next_state <= SEND_BITS;
			  next_baudrate_counter <= max_counter - 1;
			  next_tx <= shift_register(0);
			else
			  next_state <= state;
			  next_baudrate_counter <= baudrate_counter - 1;
			  next_tx <= '0';
			end if;

		 when SEND_BITS =>
			next_busy <= '1';
			
			if baudrate_counter = 0 then
			  next_baudrate_counter <= max_counter - 1;
			
			  if bit_counter = 0 then
				 next_state <= SEND_STOP_BIT;
				 next_shift_register <= shift_register;
				 next_bit_counter <= 7;
				 next_tx <= '1';
			  else
				 next_state <= state;
				 next_shift_register <= '0' & shift_register(7 downto 1);
				 next_bit_counter <= bit_counter - 1;
				 next_tx <= shift_register(0);
			  end if;
			  
			else
			  next_state <= state;
			  next_baudrate_counter <= baudrate_counter - 1;
			  next_shift_register <= shift_register;
			  next_bit_counter <= bit_counter;
			  next_tx <= shift_register(0);
			end if;

		 when SEND_STOP_BIT =>
			if baudrate_counter = 0 then
			  next_state <= IDLE;
			  next_baudrate_counter <= max_counter - 1;
			  next_shift_register <= shift_register;
			  next_bit_counter <= 7;
			  next_busy <= '1';
			  next_tx <= '1';
			else
			  next_state <= state;
			  next_baudrate_counter <= baudrate_counter - 1;
			  next_shift_register <= shift_register;
			  next_bit_counter <= 7;
			  next_busy <= '1';
			  next_tx <= '1';
			end if;
			
			when others => 
			  next_state <= IDLE;
			  next_baudrate_counter <= max_counter - 1;
			  next_shift_register <= shift_register;
			  next_bit_counter <= 7;
			  next_busy <= '1';
			  next_tx <= '1';
			
	  end case;
	end process;
end Behavioral;

