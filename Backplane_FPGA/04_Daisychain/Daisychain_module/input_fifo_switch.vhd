----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson
--
-- Create Date:    01/09/2014 
-- Design Name:
-- Module Name:    input_fifo_switch
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--     Choose an input FIFO using the in_use_input_# one-hot signals.
--     1) Immediately, the in_rd_en signal is connected to the appropriate
--        output rd_# signal. It will continue to be connected until a new
--        input channel connection is selected.
--     2) On the FOLLOWING cycle, the appropriate din_# signal is connected
--        is connected to dout. It will continue to be connected until a new
--        input channel connection is selected.
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

entity input_fifo_switch is
	port (
		reset         : in std_logic;
		clk           : in std_logic;
		-- control logic
		in_rd_en      : in std_logic;
		in_use_input_1 : in std_logic; -- one-hot source selectors, act immediately
		in_use_input_2 : in std_logic;
		in_use_input_3 : in std_logic;
		-- fifo interfaces
		fifo_dout_1    : in std_logic_vector(15 downto 0);
		fifo_dout_2    : in std_logic_vector(15 downto 0);
		fifo_dout_3    : in std_logic_vector(15 downto 0);
		fifo_rd_en_1   : out std_logic;
		fifo_rd_en_2   : out std_logic;
		fifo_rd_en_3   : out std_logic;
		fifo_dout_empty_notready_1 : in std_logic;
		fifo_dout_empty_notready_2 : in std_logic;
		fifo_dout_empty_notready_3 : in std_logic;
		fifo_dout_end_of_packet_1  : in std_logic;
		fifo_dout_end_of_packet_2  : in std_logic;
		fifo_dout_end_of_packet_3  : in std_logic;
		-- output signals
		dout  : out std_logic_vector(15 downto 0);
		dout_empty_notready   : out std_logic; -- Indicates the user should not try and read (rd_en). May happen mid-packet! Always check this!
		dout_end_of_packet    : out std_logic
	);
end input_fifo_switch;

architecture Behavioral of input_fifo_switch is
	attribute keep : string;  
	attribute S: string;

	type   uint16_array is array(integer range <>) of std_logic_vector(15 downto 0);

	-- single inputs to array signal
	signal use_input        : std_logic_vector(3 downto 1);
	signal fifo_dout        : uint16_array(3 downto 1);
	signal fifo_dout_empty_notready   : std_logic_vector(3 downto 1);
	signal fifo_dout_end_of_packet    : std_logic_vector(3 downto 1);
	
	-- array signals to single outputs
	signal fifo_rd_en : std_logic_vector(3 downto 1);
	
	-- state signals, which store the most recently selected channel, so
	-- that we can hold this channel on until switching to the next.
	signal previous_input_selection      : std_logic_vector(3 downto 1);
	signal previous_input_selection_next : std_logic_vector(3 downto 1);

	signal debug_signal : std_logic;
begin
	-- convert individual inputs into array
	use_input                 <= (            in_use_input_3,             in_use_input_2,             in_use_input_1);
	fifo_dout                 <= (               fifo_dout_3,                fifo_dout_2,                fifo_dout_1);
	fifo_dout_empty_notready  <= (fifo_dout_empty_notready_3, fifo_dout_empty_notready_2, fifo_dout_empty_notready_1);
	fifo_dout_end_of_packet   <= ( fifo_dout_end_of_packet_3,  fifo_dout_end_of_packet_2,  fifo_dout_end_of_packet_1);

	-- convert array signal to individual outputs
	fifo_rd_en_1 <= fifo_rd_en(1);
	fifo_rd_en_2 <= fifo_rd_en(2);
	fifo_rd_en_3 <= fifo_rd_en(3);

	-------------------------------------------------------------------------------
	-- State Machine
	-------------------------------------------------------------------------------
	state_flipflop_process: process(reset, clk)
	begin
		if reset = '1' then
			previous_input_selection <= "000";
		elsif clk 'event and clk = '1' then
			previous_input_selection <= previous_input_selection_next;
		end if;
	end process;

	state_async_logic_process: process(
		use_input,
		in_rd_en,
		fifo_dout, fifo_dout_empty_notready, fifo_dout_end_of_packet,
		previous_input_selection
	)
	begin
		-- If the user is selecting a new input, immediately set things relating to
		-- reading the next byte:
		--  - fifo_rd_en
		--  - dout_empty_notready
		previous_input_selection_next <= "000"; -- default value
		fifo_rd_en <= "000"; -- default value
		if use_input /= "000" then
			debug_signal <= '1';
			if    use_input(1) = '1' then  previous_input_selection_next(1) <= '1';  fifo_rd_en(1) <= in_rd_en;  dout_empty_notready <= fifo_dout_empty_notready(1);
			elsif use_input(2) = '1' then  previous_input_selection_next(2) <= '1';  fifo_rd_en(2) <= in_rd_en;  dout_empty_notready <= fifo_dout_empty_notready(2);
			else                           previous_input_selection_next(3) <= '1';  fifo_rd_en(3) <= in_rd_en;  dout_empty_notready <= fifo_dout_empty_notready(3);
			end if;
		-- If the user is NOT selecting a new input source, connect in_rd_en
		-- to the same source as last clock cycle.
		else
			debug_signal <= '0';
			-- Maintain same input source.
			previous_input_selection_next <= previous_input_selection;
			if    previous_input_selection(1) = '1' then  fifo_rd_en(1) <= in_rd_en;  dout_empty_notready <= fifo_dout_empty_notready(1);
			elsif previous_input_selection(2) = '1' then  fifo_rd_en(2) <= in_rd_en;  dout_empty_notready <= fifo_dout_empty_notready(2);
			else                                          fifo_rd_en(3) <= in_rd_en;  dout_empty_notready <= fifo_dout_empty_notready(3);
			end if;
		end if;
		
		-- Connect the approprate dout, and dout_end_of_packet
		if    previous_input_selection(1) = '1' then  dout <= fifo_dout(1);  dout_end_of_packet <= fifo_dout_end_of_packet(1);
		elsif previous_input_selection(2) = '1' then  dout <= fifo_dout(2);  dout_end_of_packet <= fifo_dout_end_of_packet(2);
		else                                          dout <= fifo_dout(3);  dout_end_of_packet <= fifo_dout_end_of_packet(3);
		end if;

	end process;

end Behavioral;
