----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:19:06 04/06/2012 
-- Design Name: 
-- Module Name:    testRx - Behavioral 
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity testRx is
    Port ( mclk : in  STD_LOGIC;
           testRx : in  STD_LOGIC;
           dataRx : out  STD_LOGIC_VECTOR (7 downto 0);
           rxFlag : out  STD_LOGIC;
			  debugOut : out STD_LOGIC_VECTOR (1 downto 0)
			  );
end testRx;

architecture Behavioral of testRx is
  type state_type is (
    IDLE,
    RECEIVE_START_BIT,
    RECEIVE_BIT0,
	 RECEIVE_BIT1,
	 RECEIVE_BIT2,
	 RECEIVE_BIT3,
	 RECEIVE_BIT4,
	 RECEIVE_BIT5,
	 RECEIVE_BIT6,
	 RECEIVE_BIT7,
    RECEIVE_STOP_BIT);

	constant sysClk   : natural := 48000000; --HZ 
	constant baudrate : natural := 9600; -- baud
	constant divider  : natural := sysClk / baudrate ;

	signal state           : state_type := IDLE;
	signal nextState       : state_type := IDLE;
	signal counter         : natural range 0 to divider := 0;
	signal nextCounter     : natural range 0 to divider := 0;
	signal myData          : std_logic_vector(7 downto 0) := "00000000";
   signal nextDataRx      : std_logic_vector(7 downto 0) := "00000000";
	signal tempDataRx      : std_logic_vector(7 downto 0) := "00000000";
	signal nextTempDataRx  : std_logic_vector(7 downto 0) := "00000000";
	signal nextRxFlag      : std_logic;
	signal nextDebug       : std_logic_vector(1 downto 0) := "11";
begin

-- Sequential
process(mclk)
begin
    if rising_edge(mclk) then
		counter    <= nextCounter;
		state      <= nextState;
		myData     <= nextDataRx;
		tempDataRx <= nextTempDataRx;
		rxFlag     <= nextRxFlag;
		debugOut   <= nextDebug;
	 end if;
end process;

-- Combinational
process(myData)
begin
	dataRx <= myData;
end process;

process(counter, state, testRx)
begin
	case state is
		-- Wait for data
		when IDLE =>
			nextDebug <= "11";
			nextDataRx <= myData;
			nextTempDataRx <= (others => '0');
			nextRxFlag <= '0';
			
			if (testRx = '1') then
				nextState <= IDLE;
				nextCounter <= 0;
			else
				nextState <= RECEIVE_START_BIT;
				nextCounter <= counter + 1;
			end if;
		-- Wait out Start bit
		when RECEIVE_START_BIT =>
			nextDebug <= "11";
			nextDataRx <= myData;
			nextTempDataRx <= tempDataRx;
			nextRxFlag <= '0';
			if (counter < divider) then
				nextState <= state;
				nextCounter <= counter + 1;
			else
				nextState <= RECEIVE_BIT0;
				nextCounter <= 0;
			end if;
		-- Receive bit 0
		when RECEIVE_BIT0 =>
			nextDebug <= "11";
			nextRxFlag <= '0';
			nextDataRx <= myData;
			if (counter < divider) then
				if (counter = 1) then
					nextTempDataRx <= tempDataRx(7 downto 1) & testRx;
				else
					nextTempDataRx <= tempDataRx;
				end if;
				nextState <= state;
				nextCounter <= counter + 1;
			else
				nextTempDataRx <= tempDataRx;
				nextState <= RECEIVE_BIT1;
				nextCounter <= 0;
			end if;
		-- Receive bit 1
		when RECEIVE_BIT1 =>
			nextDebug <= "11";
			nextRxFlag <= '0';
			nextDataRx <= myData;
			if (counter < divider) then
				if (counter = 1) then
					nextTempDataRx <= tempDataRx(7 downto 2) & testRx & tempDataRx(0);
				else
					nextTempDataRx <= tempDataRx;
				end if;
				nextState <= state;
				nextCounter <= counter + 1;
			else
				nextTempDataRx <= tempDataRx;
				nextState <= RECEIVE_BIT2;
				nextCounter <= 0;
			end if;
		-- Receive bit 2
		when RECEIVE_BIT2 =>
			nextDebug <= "11";
			nextRxFlag <= '0';
			nextDataRx <= myData;
			if (counter < divider) then
				if (counter = 1) then
					nextTempDataRx <= tempDataRx(7 downto 3) & testRx & tempDataRx(1 downto 0);
				else
					nextTempDataRx <= tempDataRx;
				end if;
				nextState <= state;
				nextCounter <= counter + 1;
			else
				nextTempDataRx <= tempDataRx;
				nextState <= RECEIVE_BIT3;
				nextCounter <= 0;
			end if;
		-- Receive bit 3
		when RECEIVE_BIT3 =>
			nextDebug <= "10";
			nextRxFlag <= '0';
			nextDataRx <= myData;
			if (counter < divider) then
				if (counter = 1) then
					nextTempDataRx <= tempDataRx(7 downto 4) & testRx & tempDataRx(2 downto 0);
				else
					nextTempDataRx <= tempDataRx;
				end if;
				nextState <= state;
				nextCounter <= counter + 1;
			else
				nextTempDataRx <= tempDataRx;
				nextState <= RECEIVE_BIT4;
				nextCounter <= 0;
			end if;
		-- Receive bit 4
		when RECEIVE_BIT4 =>
			nextDebug <= "10";
			nextRxFlag <= '0';
			nextDataRx <= myData;
			if (counter < divider) then
				if (counter = 1) then
					nextTempDataRx <= tempDataRx(7 downto 5) & testRx & tempDataRx(3 downto 0);
				else
					nextTempDataRx <= tempDataRx;
				end if;
				nextState <= state;
				nextCounter <= counter + 1;
			else
				nextTempDataRx <= tempDataRx;
				nextState <= RECEIVE_BIT5;
				nextCounter <= 0;
			end if;
		-- Receive bit 5
		when RECEIVE_BIT5 =>
			nextDebug <= "10";
			nextRxFlag <= '0';
			nextDataRx <= myData;
			if (counter < divider) then
				if (counter = 1) then
					nextTempDataRx <= tempDataRx(7 downto 6) & testRx & tempDataRx(4 downto 0);
				else
					nextTempDataRx <= tempDataRx;
				end if;
				nextState <= state;
				nextCounter <= counter + 1;
			else
				nextTempDataRx <= tempDataRx;
				nextState <= RECEIVE_BIT6;
				nextCounter <= 0;
			end if;
		-- Receive bit 6
		when RECEIVE_BIT6 =>
			nextDebug <= "10";
			nextRxFlag <= '0';
			nextDataRx <= myData;
			if (counter < divider) then
				if (counter = 1) then
					nextTempDataRx <= tempDataRx(7) & testRx & tempDataRx(5 downto 0);
				else
					nextTempDataRx <= tempDataRx;
				end if;
				nextState <= state;
				nextCounter <= counter + 1;
			else
				nextTempDataRx <= tempDataRx;
				nextState <= RECEIVE_BIT7;
				nextCounter <= 0;
			end if;
		-- Receive bit 7
		when RECEIVE_BIT7 =>
			nextDebug <= "10";
			nextRxFlag <= '0';
			nextDataRx <= myData;
			if (counter < divider) then
				if (counter = 1) then
					nextTempDataRx <= testRx & tempDataRx(6 downto 0);
				else
					nextTempDataRx <= tempDataRx;
				end if;
				nextState <= state;
				nextCounter <= counter + 1;
			else
				nextTempDataRx <= tempDataRx;
				nextState <= RECEIVE_STOP_BIT;
				nextCounter <= 0;
			end if;
		when RECEIVE_STOP_BIT =>
			nextDebug <= "10";
			nextRxFlag <= '1';
			nextDataRx <= tempDataRx;
			nextTempDataRx <= tempDataRx;
			nextState <= IDLE;
			nextCounter <= 0;
	end case;
end process;

end Behavioral;
