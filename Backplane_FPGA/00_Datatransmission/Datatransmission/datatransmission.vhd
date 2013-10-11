----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    09:57:51 10/24/2012 
-- Design Name: 
-- Module Name:    datatransmission - Behavioral 
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

entity datatransmission is
	port (
	bug_from_GTP_to_Daisychain			: out std_logic;
	bug_in_UDP_transfer				: out std_logic;
	bug_in_acqusition_process			: out std_logic;
	bug_in_acqusition_write_fifo 			: out std_logic;
	bug_in_xx_8102_xx_from_Daisychain_to_UDP	: out std_logic;
	bug_in_xx_8102_xx_from_Daisychain_to_GTP	: out std_logic;
	bug_in_write_number_over_flow			: out std_logic;
	bug_in_xx_8102_xx_in_acquisition		: out std_logic;

		     bug_out_put_from_Acquisition_to_Daisychain					: out std_logic;
			bug_out_put_from_Daisychain_to_GTP		: out std_logic;
		     bug_out_put_from_Daisychain_to_UDP			: out std_logic;

		     reset 						: in std_logic;
		     clock_125MHz					: in std_logic;
		     clock_200MHz					: in std_logic;
		     clk_sample						: out std_logic;
		     clk_50MHz						: out std_logic;
		     clk_50MHz_1				 	: out std_logic;
		     clk_12MHz_1					: out std_logic;
		     -- UDP relative interface
		     compare_result					: out std_logic;
		     -- Ethernet physical chip device interface
		     fpga_0_Hard_Ethernet_MAC_TemacPhy_RST_n_pin 	: out std_logic;
		     fpga_0_Hard_Ethernet_MAC_GMII_TXD_0_pin		: out std_logic_vector(7 downto 0);
		     fpga_0_Hard_Ethernet_MAC_GMII_TX_EN_0_pin		: out std_logic;
		     fpga_0_Hard_Ethernet_MAC_GMII_TX_ER_0_pin 		: out std_logic;
		     fpga_0_Hard_Ethernet_MAC_GMII_TX_CLK_0_pin		: out std_logic;
		     fpga_0_Hard_Ethernet_MAC_GMII_RXD_0_pin		: in std_logic_vector(7 downto 0);
		     fpga_0_Hard_Ethernet_MAC_GMII_RX_DV_0_pin 		: in std_logic;
		     fpga_0_Hard_Ethernet_MAC_GMII_RX_ER_0_pin 		: in std_logic;
		     fpga_0_Hard_Ethernet_MAC_GMII_RX_CLK_0_pin		: in std_logic;
		     -- GTP relative interface
		     -- GTP transmit
		     gtp_txp						: out std_logic;
		     gtp_txn						: out std_logic;
		     -- GTP receive
		     gtp_rxp						: in std_logic;
		     gtp_rxn						: in std_logic;
		     -- GTP clock
		     gtp_clkp_pin					: in std_logic;
		     gtp_clkn_pin					: in std_logic;	
		     -- Daisychain relative
		     Tx0						: out std_logic;
		     Tx1						: out std_logic;
		     Tx2						: out std_logic;
		    -- Rx							: in std_logic_vector(1 downto 0);
		     Rx0						: in std_logic;
		     Rx1						: in std_logic;
		     boardid						: in std_logic_vector(2 downto 0);
		     -- My custom spartan board
		     Reset_out						: out std_logic;
		     Spartan_signal_input				: in std_logic;
		     Spartan_signal_output				: out std_logic;
		     clk_12MHz						: out std_logic
	     );

end datatransmission;

architecture Behavioral of datatransmission is
	signal bug_in_xx_8102_xx_from_Daisychain_to_UDP_i : std_logic;
	signal bug_in_xx_8102_xx_from_Daisychain_to_GTP_i : std_logic;
	signal bug_in_write_number_over_flow_i		: std_logic;
	signal bug_in_xx_8102_xx_in_acquisition_i	: std_logic;

	signal bug_from_GTP_to_Daisychain_i 	: std_logic;
	signal bug_in_UDP_transfer_i		: std_logic;
	signal bug_in_acqusition_process_i	: std_logic;
	signal bug_in_acqusition_write_fifo_i 	: std_logic;
	signal acquisition_data_number_i	: std_logic_vector(15 downto 0);
	-- bug_capture
	signal bug_out_put_from_Acquisition_to_Daisychain_i			: std_logic;
	signal bug_out_put_from_Daisychain_to_UDP_i		: std_logic;
	signal bug_out_put_from_Daisychain_to_GTP_i : std_logic;

	signal acquisition_data_receive_data_number_i : std_logic_vector(15 downto 0);
	signal acquisition_data_read_fifo_number_i : std_logic_vector(15 downto 0);
	signal error_check_output		: std_logic_vector(7 downto 0);
	signal Spartan_signal_input_i		: std_logic;
	-- toplevel signal (pin realted)
	signal reset_i				: std_logic;
	signal clk_125MHz_i		: std_logic;
	signal clock_125MHz_i			: std_logic;
	signal clk_200MHz_i			: std_logic;
	signal clk_sample_i			: std_logic;
	signal clk_50MHz_i			: std_logic;
	signal clk_12MHz_i			: std_logic;

	-- Daisychain relative
	signal din_from_GTP			: std_logic_vector(15 downto 0);
	signal din_from_GTP_wr			: std_logic := '0';
	signal din_from_UDP			: std_logic_vector(15 downto 0);
	signal din_from_UDP_wr			: std_logic := '0';
	signal dout_to_GTP			: std_logic_vector(15 downto 0);
	signal dout_to_GTP_wr			: std_logic := '0';
	signal dout_to_UDP			: std_logic_vector(15 downto 0);
	signal dout_to_UDP_wr			: std_logic := '0';
	-- UDP related
	signal GTP_receive_byte_number_i        : std_logic_vector(15 downto 0);
	signal GTP_transmit_byte_number_i 	: std_logic_vector(15 downto 0);
	signal compare_result_i			: std_logic;
	signal config_data_from_UDP_to_GTP      : std_logic_vector(15 downto 0);
	signal config_data_from_UDP_to_GTP_wr   : std_logic;
	-- GTP related
	signal is_GTP_ready			: std_logic := '0';
	signal gtp_clk				: std_logic := '0';

	-- acquisition_data_module related
	signal acquisition_data_from_local_to_GTP : std_logic_vector(15 downto 0);
	signal acquisition_data_from_local_to_GTP_wr : std_logic;
	-- configure data for current board
	signal current_board_configure_data_wr  : std_logic;
	signal current_board_configure_data     : std_logic_vector(15 downto 0);

	--signal Rx_i				: std_logic_vector(1 downto 0);
	signal Tx_i				: std_logic;
	signal Rx0_i				: std_logic;
	signal Rx1_i				: std_logic;
	component clock_module
		port (
		-- global input
			     reset			: in std_logic;
			     clk_source         	: in std_logic;
		-- global output
			     clk_sample	        	: out std_logic;
		-- for 125MHz
			     clk_125MHz				: out std_logic;
		-- for Spartan3 in current phase
			     clk_50MHz	        	: out std_logic;
		-- for USB commnunication
			     clk_12MHz	 		: out std_logic
		     );
	end component;

	component UDP_module
		port (
			     bug_in_xx_8102_xx_from_Daisychain_to_UDP 	: out std_logic;
			     bug_in_UDP_transfer				: out std_logic;
		bug_out_put_from_Daisychain_to_UDP 	: out std_logic;
		     acquisition_data_receive_data_number : in std_logic_vector(15 downto 0);
		acquisition_data_number			: in std_logic_vector(15 downto 0);
			     reset			: in std_logic;
			     clk_125MHz			: in std_logic;
			     clk_50MHz			: in std_logic;
			     clk_12MHz			: in std_logic;
			     compare_result		: out std_logic;
			     GTP_receive_byte_number	: in std_logic_vector(15 downto 0);
			     GTP_transmit_byte_number   : in std_logic_vector(15 downto 0);
			     is_GTP_ready		: in std_logic;
		    --Interface with Daisychain
			     data_from_DaisyChain 	: in std_logic_vector(15 downto 0);
			     data_from_DaisyChain_wr 	: in std_logic;
			     config_data_from_UDP_to_GTP : out std_logic_vector(15 downto 0);
			     config_data_from_UDP_to_GTP_wr : out std_logic;
		    -- Ethernet physical chip device interface
			     fpga_0_Hard_Ethernet_MAC_GMII_TXD_0_pin		: out std_logic_vector(7 downto 0);
			     fpga_0_Hard_Ethernet_MAC_GMII_TX_EN_0_pin		: out std_logic;
			     fpga_0_Hard_Ethernet_MAC_GMII_TX_ER_0_pin 		: out std_logic;
			     fpga_0_Hard_Ethernet_MAC_GMII_TX_CLK_0_pin		: out std_logic;
			     fpga_0_Hard_Ethernet_MAC_GMII_RXD_0_pin		: in std_logic_vector(7 downto 0);
			     fpga_0_Hard_Ethernet_MAC_GMII_RX_DV_0_pin 		: in std_logic;
			     fpga_0_Hard_Ethernet_MAC_GMII_RX_ER_0_pin 		: in std_logic;
			     fpga_0_Hard_Ethernet_MAC_GMII_RX_CLK_0_pin		: in std_logic
		     );
	end component;

	component GTP_module
		port (
				bug_from_GTP_to_Daisychain	: out std_logic;
				bug_out_put_from_Daisychain_to_GTP : out std_logic;
				bug_in_xx_8102_xx_from_Daisychain_to_GTP : out std_logic;
			     reset			: in std_logic;
			     clk_50MHz			: in std_logic;
			     clk_12MHz			: in std_logic;
			     GTP_receive_byte_number    : out std_logic_vector(15 downto 0);
			     GTP_transmit_byte_number   : out std_logic_vector(15 downto 0);
		--transmit
			     din 			: in std_logic_vector(15 downto 0);
			     din_wr 		 	: in std_logic;
			     gtp_txp			: out std_logic;
			     gtp_txn			: out std_logic;
			     is_GTP_ready		: out std_logic;
		-- receive
			     dout			: out std_logic_vector(15 downto 0);
			     dout_wr		 	: out std_logic;
			     gtp_rxp			: in std_logic;
			     gtp_rxn			: in std_logic;
		--- GTP clock
			     gtp_clkp_pin		: in std_logic;
			     gtp_clkn_pin		: in std_logic
		     );
	end component;

	component Daisychain_module
		port (
		     acquisition_data_receive_data_number : out std_logic_vector(15 downto 0);
				bug_out_put_from_Acquisition_to_Daisychain			: out std_logic;
			     reset				: in std_logic;
			     clk_50MHz				: in std_logic;
			     clk_12MHz				: in std_logic;
			     boardid				: in std_logic_vector(2 downto 0);
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
	component acquisition_module is
		port (
	bug_in_acqusition_process			: out std_logic;
	bug_in_acqusition_write_fifo 			: out std_logic;
	bug_in_write_number_over_flow			: out std_logic;
	bug_in_xx_8102_xx_in_acquisition          : out std_logic;
		acquisition_data_number			: out std_logic_vector(15 downto 0);

			     reset 				: in std_logic;
			     boardid				: in std_logic_vector(2 downto 0);
			     clk_50MHz				: in std_logic;
			     clk_12MHz				: in std_logic;
		-- Interface with Daisychain
			     local_acquisition_data_dout_to_Daisychain_wr : out std_logic;
			     local_acquisition_data_dout_to_Daisychain : out std_logic_vector(15 downto 0);
			     Rx0				: in std_logic;
			     Rx1 				: in std_logic
		--	     Rx					: in std_logic_vector(1 downto 0)		
		     );
	end component;
	component Serializing_module is
		port (
			     reset 				: in std_logic;
			     clk_50MHz				: in std_logic;
			     clk_12MHz				: in std_logic;
		-- configure data of the current board from Daisychain
			     din_from_Daisychain_to_serialzing_wr : in std_logic;
			     din_from_Daisychain_to_serialzing  : in std_logic_vector(15 downto 0);
		-- Serialing pin
			     Tx					: out std_logic
		     );

	end component;
begin
	bug_in_xx_8102_xx_from_Daisychain_to_UDP <= bug_in_xx_8102_xx_from_Daisychain_to_UDP_i;
	bug_in_xx_8102_xx_from_Daisychain_to_GTP <= bug_in_xx_8102_xx_from_Daisychain_to_GTP_i;
	bug_in_write_number_over_flow		 <= bug_in_write_number_over_flow_i;
	bug_in_xx_8102_xx_in_acquisition	 <= bug_in_xx_8102_xx_in_acquisition_i;
	bug_from_GTP_to_Daisychain <= bug_from_GTP_to_Daisychain_i;
	bug_in_UDP_transfer <= bug_in_UDP_transfer_i;
	bug_in_acqusition_write_fifo <= bug_in_acqusition_write_fifo_i;
	bug_in_acqusition_process <= bug_in_acqusition_process_i;
	bug_out_put_from_Daisychain_to_UDP <= bug_out_put_from_Daisychain_to_UDP_i;
	bug_out_put_from_Acquisition_to_Daisychain		<= bug_out_put_from_Acquisition_to_Daisychain_i;
	bug_out_put_from_Daisychain_to_GTP <= bug_out_put_from_Daisychain_to_GTP_i;
	reset_i			<= reset;
	clock_125MHz_i		<= clock_125MHz;
	clk_200MHz_i		<= clock_200MHz;
	clk_sample 		<= clk_sample_i;
	Tx0			<= Tx_i;
	Tx1			<= Tx_i;
	Tx2			<= Tx_i;
	clk_50MHz		<= clk_50MHz_i;
	compare_result 		<= compare_result_i;
	clk_50MHz_1		<= clk_50MHz_i;
	clk_12MHz_1		<= clk_12MHz_i;
--	Rx_i			<= Rx;
	Rx0_i			<= Rx0;
	Rx1_i			<= Rx1;
	Spartan_signal_input_i  <= Spartan_signal_input;
	Spartan_signal_output   <= Spartan_signal_input_i;
	Reset_out		<= reset_i;
	clk_12MHz		<= clk_12MHz_i;
	error_check_output <= fpga_0_Hard_Ethernet_MAC_GMII_RXD_0_pin;


	fpga_0_Hard_Ethernet_MAC_TemacPhy_RST_n_pin <= not reset_i;	
	-------------------------------------------------------------------------------------------
	-- Internal module instantiation
	-------------------------------------------------------------------------------------------
	Inst_ClockModule: clock_module
	port map (
		-- global input
			reset 		=> reset_i,
			clk_source	=> clk_200MHz_i,	
		-- global output
			clk_sample	=> clk_sample_i,
			clk_125MHz	=> clk_125MHz_i,
			clk_50MHz	=> clk_50MHz_i,
			clk_12MHz	=> clk_12MHz_i
		);
	Inst_UDP_module: UDP_module
	port map (
						bug_in_xx_8102_xx_from_Daisychain_to_UDP => bug_in_xx_8102_xx_from_Daisychain_to_UDP_i,
						    bug_in_UDP_transfer => bug_in_UDP_transfer_i,
						    bug_out_put_from_Daisychain_to_UDP => bug_out_put_from_Daisychain_to_UDP_i,
						    acquisition_data_number		=> acquisition_data_number_i,	
						    acquisition_data_receive_data_number => acquisition_data_receive_data_number_i,
			reset		=> reset_i,
--			clk_125MHz	=> clock_125MHz_i,
			clk_125MHz       => clk_125MHz_i,
			clk_50MHz	=> clk_50MHz_i,
			clk_12MHz 	=> clk_12MHz_i,
			compare_result  => compare_result_i,
			GTP_receive_byte_number => GTP_receive_byte_number_i,
			GTP_transmit_byte_number => GTP_transmit_byte_number_i,
			is_GTP_ready	=> is_GTP_ready,
			data_from_DaisyChain => dout_to_UDP,
			data_from_DaisyChain_wr => dout_to_UDP_wr,
			config_data_from_UDP_to_GTP => config_data_from_UDP_to_GTP,
			config_data_from_UDP_to_GTP_wr => config_data_from_UDP_to_GTP_wr,
			fpga_0_Hard_Ethernet_MAC_GMII_TXD_0_pin => fpga_0_Hard_Ethernet_MAC_GMII_TXD_0_pin,
			fpga_0_Hard_Ethernet_MAC_GMII_TX_EN_0_pin => fpga_0_Hard_Ethernet_MAC_GMII_TX_EN_0_pin,
			fpga_0_Hard_Ethernet_MAC_GMII_TX_ER_0_pin => fpga_0_Hard_Ethernet_MAC_GMII_TX_ER_0_pin,
			fpga_0_Hard_Ethernet_MAC_GMII_TX_CLK_0_pin => fpga_0_Hard_Ethernet_MAC_GMII_TX_CLK_0_pin,
			fpga_0_Hard_Ethernet_MAC_GMII_RXD_0_pin => fpga_0_Hard_Ethernet_MAC_GMII_RXD_0_pin,
			fpga_0_Hard_Ethernet_MAC_GMII_RX_DV_0_pin => fpga_0_Hard_Ethernet_MAC_GMII_RX_DV_0_pin,
			fpga_0_Hard_Ethernet_MAC_GMII_RX_ER_0_pin => fpga_0_Hard_Ethernet_MAC_GMII_RX_ER_0_pin,
			fpga_0_Hard_Ethernet_MAC_GMII_RX_CLK_0_pin => fpga_0_Hard_Ethernet_MAC_GMII_RX_CLK_0_pin
		);
	Inst_GTP_module: GTP_module
	port map (
		bug_from_GTP_to_Daisychain => bug_from_GTP_to_Daisychain_i,
		bug_out_put_from_Daisychain_to_GTP => bug_out_put_from_Daisychain_to_GTP_i,
		bug_in_xx_8102_xx_from_Daisychain_to_GTP  => bug_in_xx_8102_xx_from_Daisychain_to_GTP_i,
			GTP_receive_byte_number => GTP_receive_byte_number_i,
			GTP_transmit_byte_number => GTP_transmit_byte_number_i,
			reset 		=> reset_i,
			clk_50MHz	=> clk_50MHz_i,
			clk_12MHz	=> clk_12MHz_i,
			din		=> dout_to_GTP,
			din_wr 		=> dout_to_GTP_wr,
			gtp_txp		=> gtp_txp,
			gtp_txn		=> gtp_txn,
			is_GTP_ready	=> is_GTP_ready,
			dout     	=> din_from_GTP,
			dout_wr	 	=> din_from_GTP_wr,
			gtp_rxp		=> gtp_rxp,
			gtp_rxn		=> gtp_rxn,
			gtp_clkp_pin	=> gtp_clkp_pin,
			gtp_clkn_pin	=> gtp_clkn_pin
		);
	Inst_Daisychain_module: Daisychain_module
	port map (
		     acquisition_data_receive_data_number => acquisition_data_receive_data_number_i,
		     bug_out_put_from_Acquisition_to_Daisychain		=> bug_out_put_from_Acquisition_to_Daisychain_i,
			 reset			=> reset_i,
			 clk_50MHz		=> clk_50MHz_i,
			 clk_12MHz		=> clk_12MHz_i,
			 boardid		=> boardid,
			 din_from_GTP		=> din_from_GTP,
			 din_from_GTP_wr	=> din_from_GTP_wr,
			 dout_to_GTP		=> dout_to_GTP,
			 dout_to_GTP_wr		=> dout_to_GTP_wr,
			 is_GTP_ready		=> is_GTP_ready,
			 dout_to_UDP		=> dout_to_UDP,
			 dout_to_UDP_wr		=> dout_to_UDP_wr,
			 config_data_from_UDP_to_GTP => config_data_from_UDP_to_GTP,
			 config_data_from_UDP_to_GTP_wr => config_data_from_UDP_to_GTP_wr,
			 -- acquisition_data_from_local_to_Daisychain
			 din_from_acquisition_wr => acquisition_data_from_local_to_GTP_wr,
			 din_from_acquisition   => acquisition_data_from_local_to_GTP,
			 -- current board configure data
			 dout_to_serializing_wr => current_board_configure_data_wr,
			 dout_to_serializing    => current_board_configure_data
		 );
	Inst_acquisition_module: acquisition_module
	port map (
	bug_in_acqusition_process		=> bug_in_acqusition_process_i,
	bug_in_acqusition_write_fifo		=> bug_in_acqusition_write_fifo_i,
	bug_in_write_number_over_flow		=> bug_in_write_number_over_flow_i,
	bug_in_xx_8102_xx_in_acquisition        => bug_in_xx_8102_xx_in_acquisition_i,

		acquisition_data_number			=> acquisition_data_number_i,
			reset			=> reset_i,
			boardid			=> boardid,
			clk_50MHz		=> clk_50MHz_i,
			clk_12MHz		=> clk_12MHz_i,
			local_acquisition_data_dout_to_Daisychain => acquisition_data_from_local_to_GTP,
			local_acquisition_data_dout_to_Daisychain_wr => acquisition_data_from_local_to_GTP_wr,
--			Rx			=> Rx_i
			Rx0			=> Rx0_i,
			Rx1			=> Rx1_i
		);
	Inst_Serializing_module: Serializing_module
	port map (
			reset 			=> reset_i,
			clk_50MHz		=> clk_50MHz_i,
			clk_12MHz		=> clk_12MHz_i,
		-- configure data of the current board from Daisychain
			din_from_Daisychain_to_serialzing_wr => current_board_configure_data_wr,
			din_from_Daisychain_to_serialzing => current_board_configure_data,
		-- Serialing pin
			Tx			=> Tx_i
		);

end Behavioral;
