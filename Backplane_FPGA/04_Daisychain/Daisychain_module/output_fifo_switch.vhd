----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson
--
-- Create Date:    01/09/2014 
-- Design Name:
-- Module Name:    output_fifo_switch
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--     Choose an output FIFO using the use_output_# signals to select (possibly
--     multiple outputs), immediately set them using the "set" signal.
--
--     Outside of this component, short the din ports of all the controlled
--     FIFOs together. This component steers the data using the wr_en signals.
--
--     Setting a channel causes the wr_en signal to be connected to the
--     appropriate version of wr_en_# for the channel.  Otherwise that wr_en_#
--     is held at 0.
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

entity output_fifo_switch is
	port (
		reset         : in std_logic;
		clk           : in std_logic;
		-- control logic
		en_ch_1 : in std_logic; -- one-hot source selectors, act immediately
		en_ch_2 : in std_logic;
		en_ch_3 : in std_logic;
		set_channels : in std_logic;
		-- input signal
		in_wr_en      : in std_logic;
		-- output signal
		out_wr_en_1    : out std_logic;
		out_wr_en_2    : out std_logic;
		out_wr_en_3    : out std_logic
	);
end output_fifo_switch;

architecture Behavioral of output_fifo_switch is
	attribute keep : string;  
	attribute S: string;

	-- individual inputs to array signal
	signal en_ch            : std_logic_vector(3 downto 1);
	-- array signals to individual outputs
	signal out_wr_en        : std_logic_vector(3 downto 1);
	
	-- state signals, which store the most recently selected channels, so
	-- that we can hold these channesl on until switching to the next.
	signal previous_en_ch      : std_logic_vector(3 downto 1);
	signal previous_en_ch_next : std_logic_vector(3 downto 1);

begin
	-- convert individual inputs into array
	en_ch <= (en_ch_3, en_ch_2, en_ch_1);

	-- convert array signal to individual outputs
	out_wr_en_1 <= out_wr_en(1);
	out_wr_en_2 <= out_wr_en(2);
	out_wr_en_3 <= out_wr_en(3);

	-------------------------------------------------------------------------------
	-- State Machine
	-------------------------------------------------------------------------------
	
	state_flipflop_process: process(reset, clk)
	begin
		if reset = '1' then
			previous_en_ch <= "000";
		elsif clk 'event and clk = '1' then
			previous_en_ch <= previous_en_ch_next;
		end if;
	end process;

	state_async_logic_process: process(set_channels, in_wr_en, en_ch, previous_en_ch)
	begin
		-- if set_channels = '1', immediately connect the newly selected channels to the in_wr_en signal.
		if set_channels = '1' then
			case in_wr_en is
				when '1'    => out_wr_en <= en_ch;
				when others => out_wr_en <= "000";
			end case;
			previous_en_ch_next <= en_ch;
		-- if set_channels = '0', connect the previously selected channels to the in_wr_en signal.
		else
			case in_wr_en is
				when '1'    => out_wr_en <= previous_en_ch;
				when others => out_wr_en <= "000";
			end case;
			previous_en_ch_next <= previous_en_ch;
		end if;
	end process;

end Behavioral;
