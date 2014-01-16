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

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;
entity Daisychain_module_tb is
	end Daisychain_module_tb;
architecture testbench of Daisychain_module_tb is
		-- signal for Daisychain_module input and output
		signal reset				: std_logic := '1';
		signal clk_12MHz			: std_logic := '0';
		signal clk_50MHz			: std_logic;
		signal boardid				: std_logic_vector(2 downto 0) := "100";
		signal Daisychain_status		: std_logic;
		signal din_from_GTP			: std_logic_vector(15 downto 0);
		signal din_from_GTP_wr			: std_logic;
		signal dout_to_GTP			: std_logic_vector(15 downto 0);
		signal dout_to_GTP_wr			: std_logic;
		signal is_GTP_ready			: std_logic;
		signal dout_to_UDP			: std_logic_vector(15 downto 0);
		signal dout_to_UDP_wr			: std_logic;
		signal is_UDP_config_data 		: std_logic := '0';
		signal config_data_from_UDP_to_GTP	: std_logic_vector(15 downto 0);
		signal config_data_from_UDP_to_GTP_wr	: std_logic;
		signal din_from_acquisition             : std_logic_vector(15 downto 0);
		signal din_from_acquisition_wr          : std_logic;
		signal dout_to_serializing              : std_logic_vector(15 downto 0);
		signal dout_to_serializing_wr           : std_logic;
		type state_machine_value is (idle, first, second, third, fourth, fifth, sixth, seventh, eighth, ninth);
		signal state_machine			: state_machine_value := idle;

		constant DO_INITIAL_RESET : boolean := true;


		component Daisychain_module is
			port (
				     reset				: in std_logic;
				     clk_50MHz				: in std_logic;
				     clk_12MHz				: in std_logic;
				     boardid				: in std_logic_vector(2 downto 0);
				     Daisychain_status			: out std_logic;
		     -- to get the config data and acquisition data from GTP interface for serializing
		     -- data receiving from GTP interface
				     din_from_GTP			: in std_logic_vector(15 downto 0);
				     din_from_GTP_wr			: in std_logic;
		     -- to send the config data and acquisition data to GTP interface for transfer
				     dout_to_GTP			: out std_logic_vector(15 downto 0);
				     dout_to_GTP_wr			: out std_logic;
				     is_GTP_ready			: in std_logic;
		     -- data to UDP interface
				     dout_to_UDP			: out std_logic_vector(15 downto 0);
				     dout_to_UDP_wr			: out std_logic;
		     -- config_data_from_UDP_to_GTP
				     is_UDP_config_data 		: in std_logic;
				     config_data_from_UDP_to_GTP	: in std_logic_vector(15 downto 0);
				     config_data_from_UDP_to_GTP_wr	: in std_logic;
		     -- acquisition_data_from_local_to_GTP
				     din_from_acquisition_wr            : in std_logic;
				     din_from_acquisition               : in std_logic_vector(15 downto 0);
		     -- current board configing data
				     dout_to_serializing_wr		: out std_logic;
				     dout_to_serializing		: out std_logic_vector(15 downto 0)
			     );
		end component;
begin
	Inst_Daisychain_module_map: Daisychain_module
	port map (
			reset				=> reset,
			clk_50MHz			=> clk_50MHz,
			clk_12MHz			=> clk_12MHz,	
			boardid				=> boardid,
			Daisychain_status		=> Daisychain_status,

			din_from_GTP			=> din_from_GTP,
			din_from_GTP_wr			=> din_from_GTP_wr,

			dout_to_GTP			=> dout_to_GTP,
			dout_to_GTP_wr			=> dout_to_GTP_wr,
			is_GTP_ready			=> is_GTP_ready,

			dout_to_UDP			=> dout_to_UDP,
			dout_to_UDP_wr			=> dout_to_UDP_wr,

			is_UDP_config_data 		=> is_UDP_config_data,
			config_data_from_UDP_to_GTP     => config_data_from_UDP_to_GTP,
			config_data_from_UDP_to_GTP_wr	=> config_data_from_UDP_to_GTP_wr,

			din_from_acquisition            => din_from_acquisition, 
			din_from_acquisition_wr         => din_from_acquisition_wr,
		        dout_to_serializing_wr		=> dout_to_serializing_wr,
		        dout_to_serializing		=> dout_to_serializing

 	);
	-- Create a clock
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
			din_from_acquisition <= x"0000";
			din_from_acquisition_wr <= '0';
			state_machine <= idle;
		elsif ( clK_12MHz'event and clK_12MHz = '1') then
			case state_machine is
				when idle =>
					din_from_acquisition <= x"0000";
					din_from_acquisition_wr <= '0';
					din_from_GTP <= x"0000";
					din_from_GTP_wr <= '0';
					state_machine <= first;
				when first =>
					din_from_acquisition <= packet_start_token_data_AND_mode & x"02";
					din_from_acquisition_wr <= '1';
					din_from_GTP <= packet_start_token_frontend_config & x"00";
					din_from_GTP_wr <= '1';
					state_machine <= second;
				when second =>
					din_from_acquisition <= x"0010";
					din_from_acquisition_wr <= '1';
					din_from_GTP <= x"0200";
					din_from_GTP_wr <= '1';
					state_machine <= third;
				when third =>
					din_from_acquisition <= x"83ff";
					din_from_acquisition_wr <= '1';
					din_from_GTP <= x"2828";
					din_from_GTP_wr <= '1';
					state_machine <= fourth;
				when fourth =>
					din_from_acquisition <= packet_start_token_data_AND_mode & x"02";
					din_from_acquisition_wr <= '1';
					din_from_GTP <= x"2525";
					din_from_GTP_wr <= '1';
					state_machine <= fifth;
				when fifth =>
					din_from_acquisition <= x"0034";
					din_from_acquisition_wr <= '1';
					din_from_GTP <= x"2901";
					din_from_GTP_wr <= '1';
					state_machine <= sixth;
				when sixth =>
					din_from_acquisition <= x"0226";
					din_from_acquisition_wr <= '1';
					state_machine <= seventh;
				when seventh =>
					din_from_acquisition <= x"2525";
					din_from_acquisition_wr <= '1';
					din_from_GTP <= x"0901";
					din_from_GTP_wr <= '1';
					state_machine <= eighth;
				when eighth =>
					din_from_acquisition <= x"0900";
					din_from_acquisition_wr <= '1';
					din_from_GTP <= x"45ff";
					din_from_GTP_wr <= '1';
					state_machine <= ninth;
				when ninth =>
					din_from_acquisition <= x"45ff";
					din_from_acquisition_wr <= '1';
					din_from_GTP <= x"0000";
					din_from_GTP_wr <= '0';
					state_machine <= idle;
			end case;	
		end if;
	end process;
end testbench;
