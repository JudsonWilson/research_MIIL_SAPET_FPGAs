----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    16:50:25 10/22/2012 
-- Design Name: 
-- Module Name:    Daisychain_module - Behavioral 
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
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use std.textio.all ;

use work.sapet_packets.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

entity UDP_module_tb is
	end UDP_module_tb;
architecture testbench of UDP_module_tb is
		-- signal for Daisychain_module input and output
		signal reset				: std_logic := '1';
		signal clk_125MHz			: std_logic := '0';
		signal clk_50MHz			: std_logic;
		signal clk_12MHz			: std_logic := '0';
		signal is_UDP_ready			: std_logic;
		signal data_from_DaisyChain 		: std_logic_vector(15 downto 0);
		signal data_from_DaisyChain_wr 		: std_logic;
		signal is_UDP_config_data		: std_logic;
		signal Daisychain_status		: std_logic;
		signal config_data_from_UDP_to_GTP 	: std_logic_vector(15 downto 0);
		signal config_data_from_UDP_to_GTP_wr 	: std_logic;
		-- physical chip device interface
		signal fpga_0_Hard_Ethernet_MAC_GMII_TXD_0_pin		: std_logic_vector(7 downto 0);
		signal fpga_0_Hard_Ethernet_MAC_GMII_TX_EN_0_pin	: std_logic;
		signal fpga_0_Hard_Ethernet_MAC_GMII_TX_ER_0_pin 	: std_logic;
		signal fpga_0_Hard_Ethernet_MAC_GMII_TX_CLK_0_pin	: std_logic;
		signal fpga_0_Hard_Ethernet_MAC_GMII_RXD_0_pin		: std_logic_vector(7 downto 0);
		signal fpga_0_Hard_Ethernet_MAC_GMII_RX_DV_0_pin 	: std_logic;
		signal fpga_0_Hard_Ethernet_MAC_GMII_RX_ER_0_pin 	: std_logic;
		signal fpga_0_Hard_Ethernet_MAC_GMII_RX_CLK_0_pin	: std_logic;
		
		-- sigr input
		type state_machine_value is (idle, first, second, third, fourth, fifth, sixth, seventh, eighth, ninth);
		signal state_machine			: state_machine_value := idle;


		constant DO_INITIAL_RESET : boolean := true;


		component UDP_module is
			port (
				     reset			: in std_logic;
				     clk_125MHz			: in std_logic;
				     clk_50MHz			: in std_logic;
				     clk_12MHz			: in std_logic;
		    --Interface with Daisychain
				     is_UDP_ready		: out std_logic;
				     data_from_DaisyChain 	: in std_logic_vector(15 downto 0);
				     data_from_DaisyChain_wr 	: in std_logic;
				     is_UDP_config_data		: out std_logic;
				     Daisychain_status		: in std_logic;
				     config_data_from_UDP_to_GTP 	: out std_logic_vector(15 downto 0);
				     config_data_from_UDP_to_GTP_wr 	: out std_logic;
		    -- Ethernet physical chip device interface
				     fpga_0_Hard_Ethernet_MAC_GMII_TXD_0_pin		: out std_logic_vector(7 downto 0);
				     fpga_0_Hard_Ethernet_MAC_GMII_TX_EN_0_pin		: out std_logic;
				     fpga_0_Hard_Ethernet_MAC_GMII_TX_ER_0_pin 		: out std_logic;
				     fpga_0_Hard_Ethernet_MAC_GMII_TX_CLK_0_pin		: out std_logic;
				     fpga_0_Hard_Ethernet_MAC_GMII_RXD_0_pin		: in std_logic_vector(7 downto 0);
				     fpga_0_Hard_Ethernet_MAC_GMII_RX_DV_0_pin 		: in std_logic;
				     fpga_0_Hard_Ethernet_MAC_GMII_RX_ER_0_pin 		: in std_logic;
				     fpga_0_Hard_Ethernet_MAC_GMII_RX_CLK_0_pin		: in std_logic			     );
		end component;
begin
	Inst_Daisychain_module_map: UDP_module
	port map (
			 reset			=> reset,
			 clk_125MHz		=> clk_125MHz,
			 clk_50MHz		=> clk_50MHz,	
			 clk_12MHz		=> clk_12MHz,
				     --Interface with Da
			 is_UDP_ready		=> is_UDP_ready,
			 data_from_DaisyChain 	=> data_from_DaisyChain,
			 data_from_DaisyChain_wr => data_from_DaisyChain_wr,	
			 is_UDP_config_data	=> is_UDP_config_data,
			 Daisychain_status	=> Daisychain_status,	
			 config_data_from_UDP_to_GTP => config_data_from_UDP_to_GTP,
			 config_data_from_UDP_to_GTP_wr  => config_data_from_UDP_to_GTP_wr,
				     -- Ethernet physical chip device interface
			 fpga_0_Hard_Ethernet_MAC_GMII_TXD_0_pin 	=> fpga_0_Hard_Ethernet_MAC_GMII_TXD_0_pin,
			 fpga_0_Hard_Ethernet_MAC_GMII_TX_EN_0_pin 	=> fpga_0_Hard_Ethernet_MAC_GMII_TX_EN_0_pin, 		
			 fpga_0_Hard_Ethernet_MAC_GMII_TX_ER_0_pin 	=> fpga_0_Hard_Ethernet_MAC_GMII_TX_ER_0_pin,	
			 fpga_0_Hard_Ethernet_MAC_GMII_TX_CLK_0_pin 	=> fpga_0_Hard_Ethernet_MAC_GMII_TX_CLK_0_pin, 	
			 fpga_0_Hard_Ethernet_MAC_GMII_RXD_0_pin	=> fpga_0_Hard_Ethernet_MAC_GMII_RXD_0_pin,
			 fpga_0_Hard_Ethernet_MAC_GMII_RX_DV_0_pin 	=> fpga_0_Hard_Ethernet_MAC_GMII_RX_DV_0_pin,	
			 fpga_0_Hard_Ethernet_MAC_GMII_RX_ER_0_pin 	=> fpga_0_Hard_Ethernet_MAC_GMII_RX_ER_0_pin,	
			 fpga_0_Hard_Ethernet_MAC_GMII_RX_CLK_0_pin	=> fpga_0_Hard_Ethernet_MAC_GMII_RX_CLK_0_pin	
		);
	-- Create 12MHz clock
	process
	begin
		clk_12MHz <= not clk_12MHz;
		wait for 42ns;
	end process;
	-- create 125MHz
	process
	begin
		clk_125MHz <= not clk_125MHz;
		wait for 4ns;
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
			data_from_DaisyChain <= x"0000";
			data_from_DaisyChain_wr <= '0';
			state_machine <= idle;
		elsif ( clK_12MHz'event and clK_12MHz = '1') then
			case state_machine is
				when idle =>
					data_from_DaisyChain <= x"0000";
					data_from_DaisyChain_wr <= '0';
					state_machine <= first;
				when first =>
					data_from_DaisyChain <= packet_start_token_frontend_config & x"00";
					data_from_DaisyChain_wr <= '1';
					state_machine <= second;
				when second =>
					data_from_DaisyChain <= x"0210";
					data_from_DaisyChain_wr <= '1';
					state_machine <= third;
				when third =>
					data_from_DaisyChain <= x"83ff";
					data_from_DaisyChain_wr <= '1';
					state_machine <= fourth;
				when fourth =>
					data_from_DaisyChain <= packet_start_token_frontend_config & x"00";
					data_from_DaisyChain_wr <= '1';
					state_machine <= fifth;
				when fifth =>
					data_from_DaisyChain <= x"0234";
					data_from_DaisyChain_wr <= '1';
					state_machine <= sixth;
				when sixth =>
					data_from_DaisyChain <= x"0226";
					data_from_DaisyChain_wr <= '1';
					state_machine <= seventh;
				when seventh =>
					data_from_DaisyChain <= x"2525";
					data_from_DaisyChain_wr <= '1';
					state_machine <= eighth;
				when eighth =>
					data_from_DaisyChain <= x"0900";
					data_from_DaisyChain_wr <= '1';
					state_machine <= ninth;
				when ninth =>
					data_from_DaisyChain <= x"45ff";
					data_from_DaisyChain_wr <= '1';
					state_machine <= idle;
			end case;	
		end if;
	end process;
end testbench;
