----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    12:55:27 04/06/2012 
-- Design Name: 
-- Module Name:    testTx - Behavioral 
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity testTx is
    Port ( mclk   : in  std_logic;
           txFlag : in  std_logic;
           dataTx : in  std_logic_vector(7 downto 0);
           testTx : out std_logic);
			  
end testTx;

architecture Behavioral of testTx is
  type state_type is (
    IDLE,
    SEND_START_BIT,
    SEND_BIT0,
	 SEND_BIT1,
	 SEND_BIT2,
	 SEND_BIT3,
	 SEND_BIT4,
	 SEND_BIT5,
	 SEND_BIT6,
	 SEND_BIT7,
    SEND_STOP_BIT);
	 
	constant sysClk   : natural := 48000000; --HZ 
	constant baudrate : natural := 9600; -- baud
	constant divider  : natural := sysClk / baudrate ;

	signal state           : state_type := IDLE;
	signal nextState       : state_type := IDLE;	
	signal counter         : natural range 0 to divider := 0;
	signal nextCounter     : natural range 0 to divider := 0;
	signal nextTestTx      : std_logic;
	
begin

-- Sequential
process(mclk)
begin
    if rising_edge(mclk) then
		counter  <= nextCounter;
		state    <= nextState;
		testTx   <= nextTestTx;
	 end if;
end process;

-- Combinational
process(state, dataTx, txFlag)
begin
	case state is
		when IDLE =>
			nextTestTx <= '1';
			nextCounter <= 0;
			if (txFlag = '0') then
				nextState <= IDLE;
			else
				nextState <= SEND_START_BIT;
			end if;
		-- Start bit
		when SEND_START_BIT =>
			nextTestTx <= '0';
			if (counter < divider) then
				nextCounter <= counter + 1;
				nextState <= state;
			else
				nextCounter <= 0;
				nextState <= SEND_BIT0;
			end if;
		-- Bit 0
	   when SEND_BIT0 =>
			nextTestTx <= dataTx(0);
			if (counter < divider) then
				nextCounter <= counter + 1;
				nextState <= state;
			else
				nextCounter <= 0;
				nextState <= SEND_BIT1;
			end if;
		-- Bit 1
	   when SEND_BIT1 =>
			nextTestTx <= dataTx(1);
			if (counter < divider) then
				nextCounter <= counter + 1;
				nextState <= state;
			else
				nextCounter <= 0;
				nextState <= SEND_BIT2;
			end if;
		-- Bit 2
	   when SEND_BIT2 =>
			nextTestTx <= dataTx(2);
			if (counter < divider) then
				nextCounter <= counter + 1;
				nextState <= state;
			else
				nextCounter <= 0;
				nextState <= SEND_BIT3;
			end if;
		-- Bit 3
	   when SEND_BIT3 =>
			nextTestTx <= dataTx(3);
			if (counter < divider) then
				nextCounter <= counter + 1;
				nextState <= state;
			else
				nextCounter <= 0;
				nextState <= SEND_BIT4;
			end if;
		-- Bit 4
	   when SEND_BIT4 =>
			nextTestTx <= dataTx(4);
			if (counter < divider) then
				nextCounter <= counter + 1;
				nextState <= state;
			else
				nextCounter <= 0;
				nextState <= SEND_BIT5;
			end if;
		-- Bit 5
	   when SEND_BIT5 =>
			nextTestTx <= dataTx(5);
			if (counter < divider) then
				nextCounter <= counter + 1;
				nextState <= state;
			else
				nextCounter <= 0;
				nextState <= SEND_BIT6;
			end if;
		-- Bit 6
	   when SEND_BIT6 =>
			nextTestTx <= dataTx(6);
			if (counter < divider) then
				nextCounter <= counter + 1;
				nextState <= state;
			else
				nextCounter <= 0;
				nextState <= SEND_BIT7;
			end if;
		-- Bit 7
	   when SEND_BIT7 =>
			nextTestTx <= dataTx(7);
			if (counter < divider) then
				nextCounter <= counter + 1;
				nextState <= state;
			else
				nextCounter <= 0;
				nextState <= SEND_STOP_BIT;
			end if;
		-- Stop bit
	   when SEND_STOP_BIT =>
			nextTestTx <= '1';
			if (counter < divider) then
				nextCounter <= counter + 1;
				nextState <= state;
			else
				nextCounter <= 0;
				nextState <= IDLE;
			end if;
		when others =>
			nextTestTx <= '1';
			nextCounter <= 0;
			nextState <= IDLE;
	end case;
end process;
end Behavioral;
