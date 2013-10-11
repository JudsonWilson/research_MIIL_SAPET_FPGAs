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

entity Serializing_module_tb is
	end Serializing_module_tb;

architecture Behavioral of Serializing_module_tb is
	signal reset 	: std_logic := '1';
	signal clk_12MHz : std_logic := '0';
	signal din_from_Daisychain_to_serialzing_wr : std_logic;
	signal din_from_Daisychain_to_serialzing  : std_logic_vector(15 downto 0);
	signal Tx       : std_logic;
	type state_machine_value is (idle, first, second, third, fourth, fifth, sixth, seventh, eighth);
	signal state_machine			: state_machine_value := idle;

	constant DO_INITIAL_RESET : boolean := true;

	component Serializing_module
		port (
			     reset 				: in std_logic;
			     clk_12MHz			: in std_logic;
		-- configure data of the current board from Daisychain
			     din_from_Daisychain_to_serialzing_wr : in std_logic;
			     din_from_Daisychain_to_serialzing   : in std_logic_vector(15 downto 0);
		-- Serialing pin
			     Tx				: out std_logic
		     );
	end component;

begin
	Inst_Serializing_module: Serializing_module
	port map(
			reset	=> reset,
			clk_12MHz => clk_12MHz,
			din_from_Daisychain_to_serialzing_wr => din_from_Daisychain_to_serialzing_wr,
			din_from_Daisychain_to_serialzing => din_from_Daisychain_to_serialzing,
			Tx => Tx
		);
	-- Create clk_12MHz
	process
	begin
		clk_12MHz <= not clk_12MHz;
		wait for 42ns;
	end process;

	Init_reset : if DO_INITIAL_RESET = true generate
		process
		begin
			reset <= '1';
			wait for 20 ns;
			reset <= '0';
			wait;
		end process;
	end generate;
	-- Create the two channel process to drive the input and read the outputs
	process ( clK_12MHz, reset)
	begin
		if ( reset = '1') then
			din_from_Daisychain_to_serialzing <= x"0000";
			din_from_Daisychain_to_serialzing_wr <= '0';
			state_machine <= idle;
		elsif ( clK_12MHz'event and clK_12MHz = '1') then
			case state_machine is
				when idle =>
					din_from_Daisychain_to_serialzing <= x"0000";
					din_from_Daisychain_to_serialzing_wr <= '0';
					state_machine <= first;
				when first =>
					din_from_Daisychain_to_serialzing <= x"8102";
					din_from_Daisychain_to_serialzing_wr <= '1';
					state_machine <= second;
				when second =>
					din_from_Daisychain_to_serialzing <= x"83ff";
					din_from_Daisychain_to_serialzing_wr <= '1';
					state_machine <= third;
				when third =>
					din_from_Daisychain_to_serialzing <= x"8102";
					din_from_Daisychain_to_serialzing_wr <= '1';
					state_machine <= fourth;
				when fourth =>
					din_from_Daisychain_to_serialzing <= x"0034";
					din_from_Daisychain_to_serialzing_wr <= '1';
					state_machine <= fifth;
				when fifth =>
					din_from_Daisychain_to_serialzing <= x"0226";
					din_from_Daisychain_to_serialzing_wr <= '1';
					state_machine <= sixth;
				when sixth =>
					din_from_Daisychain_to_serialzing <= x"2525";
					din_from_Daisychain_to_serialzing_wr <= '1';
					state_machine <= seventh;
				when seventh =>
					din_from_Daisychain_to_serialzing <= x"0900";
					din_from_Daisychain_to_serialzing_wr <= '1';
					state_machine <= eighth;
				when eighth =>
					din_from_Daisychain_to_serialzing <= x"45ff";
					din_from_Daisychain_to_serialzing_wr <= '1';
					state_machine <= idle;
			end case;	
		end if;
	end process;

end Behavioral;

