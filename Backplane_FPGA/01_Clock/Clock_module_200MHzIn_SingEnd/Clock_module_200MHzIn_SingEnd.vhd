----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    17:04:28 10/19/2012 
-- Design Name: 
-- Module Name:    Clock_module - Behavioral 
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

entity Clock_module_200MHzIn_SingEnd is
	port(
		-- global input
		reset		: in std_logic;
		clk_source      : in std_logic;
		-- global output
		clk_sample	: out std_logic;
		-- 125MHz
		clk_125MHz	: out std_logic;
		-- for Spartan3 in current phase
		clk_50MHz	: out std_logic;
		-- for USB commnunication
		clk_12MHz	: out std_logic
	);
end Clock_module_200MHzIn_SingEnd;

architecture Behavioral of Clock_module_200MHzIn_SingEnd is
	signal reset_i		: std_logic;
	signal reset_l_i	: std_logic;
	signal clk_sample_i	: std_logic;
	signal clk_125MHz_i	: std_logic;
	signal clk_50MHz_i	: std_logic;
	signal clk_12MHz_i 	: std_logic;
	signal reset_vector_i   : std_logic_vector(7 downto 0) := (others => '0');
	component PLL_Module is
		port (
			     CLKIN1_IN   	: in    std_logic; 
			     RST_IN      	: in    std_logic; 
			     CLKOUT0_OUT 	: out   std_logic; 
			     CLKOUT1_OUT 	: out   std_logic; 
			     CLKOUT2_OUT 	: out   std_logic; 
				  CLKOUT3_OUT	: out   std_logic;
			     LOCKED_OUT  	: out   std_logic
		     );
	end component;
begin
	-- global
	reset_i 	<= reset;
	clk_sample	<= clk_sample_i;
	clk_125MHz	<= clk_125MHz_i;
	clk_50MHz	<= clk_50MHz_i;
	clk_12MHz	<= clk_12MHz_i;

	Inst_PLL_Module: PLL_Module
	port map(
			CLKIN1_IN		=> clk_source,
			RST_IN			=> reset_l_i,
			CLKOUT0_OUT		=> clk_sample_i,
			CLKOUT1_OUT	   => clk_125MHz_i,
			CLKOUT2_OUT		=> clk_50MHz_i,
			CLKOUT3_OUT		=> clk_12MHz_i,
			LOCKED_OUT		=> open
		);
end Behavioral;
