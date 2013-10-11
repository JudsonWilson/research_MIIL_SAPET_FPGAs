----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    17:52:21 10/19/2012 
-- Design Name: 
-- Module Name:    UDP_module - Behavioral 
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

entity UDP_module is
	port(
	bug_in_xx_8102_xx_from_Daisychain_to_UDP 	: out std_logic;
	bug_in_UDP_transfer				: out std_logic;
		bug_out_put_from_Daisychain_to_UDP	: out std_logic;
		     acquisition_data_receive_data_number : in std_logic_vector(15 downto 0);
		acquisition_data_number			: in std_logic_vector(15 downto 0);

		    reset			: in std_logic;
		    clk_125MHz			: in std_logic;
		    clk_50MHz			: in std_logic;
		    clk_12MHz			: in std_logic;
		    compare_result		: out std_logic;
		    GTP_receive_byte_number	: in std_logic_vector(15 downto 0);
		    GTP_transmit_byte_number 	: in std_logic_vector(15 downto 0);
		    is_GTP_ready		: in std_logic;
		    --Interface with Daisychain
		    data_from_DaisyChain 	: in std_logic_vector(15 downto 0);
		    data_from_DaisyChain_wr 	: in std_logic;
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
		    fpga_0_Hard_Ethernet_MAC_GMII_RX_CLK_0_pin		: in std_logic
);

end UDP_module;

architecture Behavioral of UDP_module is
	signal formal_word		: std_logic_vector(15 downto 0);
	signal formal_word1		: std_logic_vector(15 downto 0);
	signal bug_bit3 		: std_logic_vector(1 downto 0);
	signal bug_bit4			: std_logic_vector(2 downto 0);
	signal bug_bit2 		: std_logic_vector(1 downto 0);
	signal formal_word2		: std_logic_vector(15 downto 0);
	signal data_from_DaisyChain_i	: std_logic_vector(15 downto 0);
	signal data_from_DaisyChain_wr_i : std_logic;
	type simulation_state_machine_value is (idle, write_state_machine);
	signal simulation_state_machine : simulation_state_machine_value := idle;
	signal bug_bit			: std_logic;
	signal bug_in_UDP_transfer_i	: std_logic;
	signal bug_bit1			: std_logic_vector(2 downto 0);
	-- global
	signal reset_i			: std_logic;
	signal fifo_vector_reset	: std_logic;
	signal fifo_vector		: std_logic_vector(5 downto 0);
	signal Daisychain_status_i 	: std_logic := '0';

	-- Receiving fifo from PC
	signal PC_to_Virtex_din_i	: std_logic_vector(7 downto 0);
	signal PC_to_Virtex_wr_en_i     : std_logic;
	signal PC_to_Virtex_dout_i	: std_logic_vector(7 downto 0);
	signal PC_to_Virtex_empty_i	: std_logic;
	signal PC_to_Virtex_rd_en_i     : std_logic;
	-- Receiving fifo from GTP
	-- To decide the even fifo or odd fifo
	signal byte_number 		: std_logic;

	signal Rx_receive_fifo_even_wr_en_i : std_logic;
	signal Rx_receive_fifo_even_rd_en_i : std_logic;
	signal Rx_receive_fifo_odd_wr_en_i  : std_logic;
	signal Rx_receive_fifo_odd_rd_en_i : std_logic;
	signal Rx_receive_fifo_even_empty_i : std_logic;
	signal Rx_receive_fifo_odd_empty_i : std_logic;
	signal din_from_Daisychain 	: std_logic_vector(15 downto 0);
	signal Rx_receive_fifo_even_dout_i : std_logic_vector(15 downto 0);
	signal Rx_receive_fifo_odd_dout_i : std_logic_vector(15 downto 0);
	signal receive_data_number	: std_logic_vector(9 downto 0) := (others => '0');
	signal UDP_combine_byte_to_word_number_i : std_logic_vector(15 downto 0) := (others => '0');
	signal PC_write_data_byte_number_i	: std_logic_vector(15 downto 0) := (others => '0');
	signal UDP_receive_data_from_Daisychain : std_logic_vector(15 downto 0) := (others => '0');
	signal transfer_fifo_token	: std_logic;
	signal fifo_full		: std_logic_vector(1 downto 0) := "00";

	-- EMAC and UDP/IP core related. Do not change!
	signal source_ready_i		: std_logic := '1';
	signal usr_data_output_bus      : std_logic_vector(7 downto 0);
	signal valid_out_usr_data	: std_logic;
	signal transmit_data_output_bus : std_logic_vector(7 downto 0) := (others => '0');
	signal rx_sof			: std_logic := '0';
	signal rx_eof			: std_logic := '0';
	signal input_bus		: std_logic_vector(7 downto 0) := (others => '0');
	signal ll_pre_reset_0_i		: std_logic_vector(5 downto 0) := (others => '0');
	signal ll_reset_0_i		: std_logic := '1';
	signal tx_ll_dst_rdy_n_0_i	: std_logic := '0';
	signal rx_ll_dst_rdy_n_0_i	: std_logic := '0';
	signal rx_clk_0_i		: std_logic;
	signal tx_clk_0			: std_logic;
	signal rx_ll_src_rdy_n_0_i	: std_logic := '0';
	signal tx_clk_out		: std_logic;
	signal input_bus_i		: std_logic_vector(7 downto 0);
	signal rx_sof_i			: std_logic;
	signal rx_eof_i			: std_logic;
	signal start_of_frame_0_i	: std_logic;
	signal end_of_frame_0_i		: std_logic;
	signal transmit_data_output_bus_i : std_logic_vector(7 downto 0);
	signal transmit_data_input_bus_i: std_logic_vector(7 downto 0);

	-- Sending data to GTP Interface
	type Sending_data_to_GTP_Interface_state_type is (idle, start_signal_judge, sending_data);
	signal Sending_data_to_GTP_Interface_state: Sending_data_to_GTP_Interface_state_type := idle;

	-- transmit data signals
	signal transmit_data_length_i   : std_logic_vector(15 downto 0);
	type transmit_state_type is ( ready, even_fifo_header, odd_fifo_header, even_fifo_data, odd_fifo_data);
	signal current_state : transmit_state_type := ready;
	type receive_fifo_type is ( even, odd);
	signal receive_fifo_state : receive_fifo_type := even;
	signal transmit_start_enable_i	: std_logic := '0';
	signal counter 			: std_logic_vector(10 downto 0);
	signal transfer_even_or_odd_fifo : std_logic := '0';
	type is_there_config_data_or_not_state is ( idle, config_data);
	signal is_there_config_data_or_not : is_there_config_data_or_not_state := idle;
	signal sending_config_data_complete : std_logic := '0';
	--------------------------------------------------------------------------------------------------
	-- UDP interface (16 bits bus -> UDP/IP) ( UDP/IP -> 16 bit bus)
	--------------------------------------------------------------------------------------------------
	-- Local Link Fifo
	component ethernetmac_locallink is
		port(
			    -- EMAC0 Clocking
			    -- TX Clock ouput from EMAC
			    TX_CLK_OUT					: out std_logic;
			    -- EMAC0 TX Clock input from BUFG
			    TX_CLK_0					: in std_logic;
			    -- Local link Receiver Interface - EMAC0
			    RX_LL_CLOCK_0				: in std_logic;
			    RX_LL_RESET_0				: in std_logic;
			    RX_LL_DATA_0				: out std_logic_vector(7 downto 0);
			    RX_LL_SOF_N_0				: out std_logic;
			    RX_LL_EOF_N_0				: out std_logic;
			    RX_LL_SRC_RDY_N_0				: out std_logic;
			    RX_LL_DST_RDY_N_0				: in std_logic;
			    RX_LL_FIFO_STATUS_0				: out std_logic_vector(3 downto 0);
			    -- Local link Transmitter Interface - EMAC0
			    TX_LL_CLOCK_0				: in std_logic;
			    TX_LL_RESET_0				: in std_logic;
			    TX_LL_DATA_0				: in std_logic_vector(7 downto 0);
			    TX_LL_SOF_N_0				: in std_logic;
			    TX_LL_EOF_N_0				: in std_logic;
			    TX_LL_SRC_RDY_N_0				: in std_logic;
			    TX_LL_DST_RDY_N_0				: out std_logic;
			    -- Client Receiver Interface - EMAC0
			    EMAC0CLIENTRXDVLD				: out std_logic;
			    EMAC0CLIENTRXFRAMEDROP			: out std_logic;
			    EMAC0CLIENTRXSTATS				: out std_logic_vector(6 downto 0);
			    EMAC0CLIENTRXSTATSVLD			: out std_logic;
			    EMAC0CLIENTRXSTATSBYTEVLD			: out std_logic;
			    -- Client Transmitter Interface - EMAC0
			    CLIENTEMAC0TXIFGDELAY			: in std_logic_vector(7 downto 0);
			    EMAC0CLIENTTXSTATS				: out std_logic;
			    EMAC0CLIENTTXSTATSVLD			: out std_logic;
			    EMAC0CLIENTTXSTATSBYTEVLD			: out std_logic;
			    -- MAC Control Interface - EMAC0
			    CLIENTEMAC0PAUSEREQ				: in std_logic;
			    CLIENTEMAC0PAUSEVAL				: in std_logic_vector(15 downto 0);
		            --Clock Signals - EMAC0
			    GTX_CLK_0					: in std_logic;
			    -- GMII Interface - EMAC0
			    GMII_TXD_0					: out std_logic_vector(7 downto 0);
			    GMII_TX_EN_0				: out std_logic;
			    GMII_TX_ER_0				: out std_logic;
			    GMII_TX_CLK_0				: out std_logic;
			    GMII_RXD_0					: in std_logic_vector(7 downto 0);
			    GMII_RX_DV_0				: in std_logic;
			    GMII_RX_ER_0				: in std_logic;
			    GMII_RX_CLK_0				: in std_logic;

	               	    -- Asynchronous Reset
			    RESET					: in std_logic
	);
	end component;
	-------------------------------------------------------------------------------------------------------------
	-- Component Declration for UDP_IP_Core module
	-------------------------------------------------------------------------------------------------------------
	component UDP_IP_Core is
		Port ( 
			     rst 				: in  STD_LOGIC;    -- active-high
			     clk_125MHz 			: in  STD_LOGIC;

			     -- Transmit signals
			     transmit_start_enable 		: in  STD_LOGIC;
			     transmit_data_length 		: in  STD_LOGIC_VECTOR (15 downto 0);
			     usr_data_trans_phase_on 		: out STD_LOGIC;
			     transmit_data_input_bus 		: in  STD_LOGIC_VECTOR (7 downto 0);
			     start_of_frame_O 			: out  STD_LOGIC;
			     end_of_frame_O 			: out  STD_LOGIC;
			     source_ready 			: out STD_LOGIC;
			     transmit_data_output_bus 		: out STD_LOGIC_VECTOR (7 downto 0);

			     --Receive Signals
			     rx_sof 				: in  STD_LOGIC;
			     rx_eof 				: in  STD_LOGIC;
			     input_bus 				: in  STD_LOGIC_VECTOR(7 downto 0);
			     valid_out_usr_data 		: out  STD_LOGIC;
			     usr_data_output_bus 		: out  STD_LOGIC_VECTOR (7 downto 0)
		     );
	end component;
	--------------------------------------------------------------------------------------------------------------
	-- fifo_16
	--------------------------------------------------------------------------------------------------------------
	component fifo_block_512_16 is
		port (
			     rst		: IN std_logic;
			     wr_clk		: IN std_logic;
			     rd_clk		: IN std_logic;
			     din		: IN std_logic_VECTOR(15 downto 0);
			     wr_en		: IN std_logic;
			     rd_en		: IN std_logic;
			     dout		: OUT std_logic_VECTOR(15 downto 0);
			     full		: OUT std_logic;
			     empty		: OUT std_logic
	);
	end component;

	--------------------------------------------------------------------------------------------------------------
	-- fifo_block_1024_8
	--------------------------------------------------------------------------------------------------------------
	component fifo_block_1024_8 is
		port (
			rst			: in std_logic;
			wr_clk			: in std_logic;
			rd_clk			: in std_logic;
			din 			: in std_logic_vector(7 downto 0);
			wr_en 			: in std_logic;
			rd_en 			: in std_logic;
			dout			: out std_logic_vector(7 downto 0);
			full			: out std_logic;
			empty			: out std_logic
		);
	end component;	

begin
	bug_in_UDP_transfer <= bug_in_UDP_transfer_i;



	bug_from_Daisychain_to_UDP_process: process ( reset, clk_50MHz)
	begin
		if ( reset = '1') then
			bug_out_put_from_Daisychain_to_UDP <= '0';
			formal_word1 <= x"0000";
			bug_bit4 <= "000";
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			case bug_bit4 is
				when "000" =>
					if ( data_from_DaisyChain_wr = '0') then
						formal_word1 <= x"0000"; 
						bug_bit4 <= "000";
					else
						bug_bit4 <= "001";
						formal_word1 <= data_from_DaisyChain;
					end if;
					bug_out_put_from_Daisychain_to_UDP <= '0';
				when "001" =>
					if ( data_from_DaisyChain_wr = '0') then
						formal_word1 <= formal_word1;
						bug_bit4 <= "001";
					else
						if ( data_from_DaisyChain = x"FF00") then
							formal_word1 <= formal_word1;
							bug_bit4 <= "010";
						else
							formal_word1 <= data_from_DaisyChain;
							bug_bit4 <= "001";
						end if;
					end if;
					bug_out_put_from_Daisychain_to_UDP <= '0';
				when "010" =>
					if (data_from_DaisyChain_wr = '0')  then
						formal_word1 <= formal_word1;
						bug_bit4 <= "010";
						bug_out_put_from_Daisychain_to_UDP <= '0';
					else
						if (( data_from_DaisyChain = x"FF00")) then
							formal_word1 <= formal_word1;
							bug_bit4 <= "011";
							bug_out_put_from_Daisychain_to_UDP <= '1';
						else
							formal_word1 <= data_from_DaisyChain;
							bug_bit4 <= "001";
							bug_out_put_from_Daisychain_to_UDP <= '0';
						end if;
					end if;
				when "011" =>
					if (data_from_DaisyChain_wr = '0')  then
						formal_word1 <= formal_word1;
						bug_out_put_from_Daisychain_to_UDP <= '0';
					else
						if (( data_from_DaisyChain = x"FF00")) then
							formal_word1 <= formal_word1;
							bug_out_put_from_Daisychain_to_UDP <= '1';
						else
							formal_word1 <= data_from_DaisyChain;
						end if;
					end if;
					bug_bit4 <= "001";
				when others =>
					null;
			end case;
		end if;
	end process;






	-------------------------------------------------------------------------------------------------------------
	-- Global logics
	-------------------------------------------------------------------------------------------------------------
	reset_i			<= reset;

	gen_ll_reset_emac0: process( clk_125MHz, reset_i)
	begin
		if (reset_i = '1') then
			ll_pre_reset_0_i <= (others => '1');
			ll_reset_0_i	<= '1';
		elsif (clk_125MHz 'event and clk_125MHz = '1') then
			ll_pre_reset_0_i <= ll_pre_reset_0_i(4 downto 0) & '0';
			ll_reset_0_i	 <= ll_pre_reset_0_i(5);
		end if;
	end process gen_ll_reset_emac0;
	-- create asynchronous reset for fifo
	gen_fifo_reset: process ( clk_125MHz, reset_i)
	begin
		if ( reset_i = '1') then
			fifo_vector_reset <= '1';
			fifo_vector <=(others => '1');
		elsif (clk_125MHz 'event and clk_125MHz = '1') then
			fifo_vector <= '0' & fifo_vector(5 downto 1);
			fifo_vector_reset <= fifo_vector(0);
		end if;
	end process;


	-- IDELAYCTRL for the iodelays
	inst_idelaytrl: IDELAYCTRL
	port map (
			REFCLK 		=> clk_125MHz,
			RST		=> RESET,
			RDY		=> open
		);
	bufg_rx_0: BUFG
	port map (
			-- I => clk_125MHz,
			I => fpga_0_Hard_Ethernet_MAC_GMII_RX_CLK_0_pin,
			O => rx_clk_0_i
		);
	txclk_bufg : BUF
	port map (
			-- I => clk_125MHz,
			I => tx_clk_out,
			O => tx_clk_0
		);

	------------------------------------------------------------------------------------------------------
	--Instantiate teh EMAC Wrapper with LL FIFO
	-- (ethernetmac_locallink.vhd)
	------------------------------------------------------------------------------------------------------
	v5_emal_ll : ethernetmac_locallink
	port map(
			-- EMAC0 Clocking
			-- TX Clock output from EMAC
			TX_CLK_OUT					=> tx_clk_out, 
			-- EMAC0 TX Clock input from BUFG
			TX_CLK_0					=> tx_clk_0,
			-- IPV4_PACKET_TRANSMITTER link Receiver Interface - EMAC0
			RX_LL_CLOCK_0					=> clk_125MHz,
			RX_LL_RESET_0					=> ll_reset_0_i,
			RX_LL_DATA_0					=> input_bus_i,
			RX_LL_SOF_N_0					=> rx_sof_i,
			RX_LL_EOF_N_0					=> rx_eof_i,
			RX_LL_SRC_RDY_N_0				=> rx_ll_src_rdy_n_0_i,
			RX_LL_DST_RDY_N_0				=> rx_ll_dst_rdy_n_0_i, 
			RX_LL_FIFO_STATUS_0				=> open,
			-- IPV4_PACKET_TRANSMITTER link Transmitter Interface - EMAC0
			TX_LL_CLOCK_0					=> clk_125MHz,
			TX_LL_RESET_0					=> ll_reset_0_i,
			TX_LL_DATA_0					=> transmit_data_output_bus_i,
			TX_LL_SOF_N_0					=> start_of_frame_0_i,
			TX_LL_EOF_N_0					=> end_of_frame_0_i,
			TX_LL_SRC_RDY_N_0				=> source_ready_i,
			TX_LL_DST_RDY_N_0				=> tx_ll_dst_rdy_n_0_i,


			-- Unused Receiver siggnals - EMAC0
			EMAC0CLIENTRXDVLD				=> open,
			EMAC0CLIENTRXFRAMEDROP				=> open,
			EMAC0CLIENTRXSTATS				=> open,
			EMAC0CLIENTRXSTATSVLD				=> open,
			EMAC0CLIENTRXSTATSBYTEVLD			=> open,
			-- Unsed Transmitter signals - EMAC0
			CLIENTEMAC0TXIFGDELAY				=> x"00",
			EMAC0CLIENTTXSTATS				=> open,
			EMAC0CLIENTTXSTATSVLD				=> open,
			EMAC0CLIENTTXSTATSBYTEVLD			=> open,
			-- Unsed control Interface - EMAC0
			CLIENTEMAC0PAUSEREQ				=> '0',
			CLIENTEMAC0PAUSEVAL				=> x"0000",
			-- Clockk Signals - EMAC0
			GTX_CLK_0					=> clk_125MHz,
			-- GMII Interface - EMAC0
			GMII_TXD_0					=> fpga_0_Hard_Ethernet_MAC_GMII_TXD_0_pin,
			GMII_TX_EN_0					=> fpga_0_Hard_Ethernet_MAC_GMII_TX_EN_0_pin,
			GMII_TX_ER_0					=> fpga_0_Hard_Ethernet_MAC_GMII_TX_ER_0_pin,
			GMII_TX_CLK_0					=> fpga_0_Hard_Ethernet_MAC_GMII_TX_CLK_0_pin,
			GMII_RXD_0				 	=> fpga_0_Hard_Ethernet_MAC_GMII_RXD_0_pin,
			GMII_RX_DV_0					=> fpga_0_Hard_Ethernet_MAC_GMII_RX_DV_0_pin,
			GMII_RX_ER_0					=> fpga_0_Hard_Ethernet_MAC_GMII_RX_ER_0_pin,
			GMII_RX_CLK_0					=> rx_clk_0_i,
			-- Asynchronous Reset
			RESET						=> reset_i
		);

	--------------------------------------------------------------------------------
	-- UDP_IP_Core wrapper
	--------------------------------------------------------------------------------
	Inst_IPV4_PACKET_TRANSMITTER: UDP_IP_Core
	port map(
			rst						=> ll_reset_0_i,
			clk_125MHz					=> clk_125MHz,
			-- transmit
			source_ready					=> source_ready_i,
			transmit_start_enable				=> transmit_start_enable_i,
			transmit_data_length				=> transmit_data_length_i,
			usr_data_trans_phase_on				=> open,
			transmit_data_input_bus				=> transmit_data_input_bus_i,
			start_of_frame_O				=> start_of_frame_0_i,
			end_of_frame_O					=> end_of_frame_0_i,
			transmit_data_output_bus			=> transmit_data_output_bus_i,
			-- receive
			rx_sof						=> rx_sof_i,
			rx_eof						=> rx_eof_i,
			input_bus					=> input_bus_i,
			valid_out_usr_data				=> PC_to_Virtex_wr_en_i,
			usr_data_output_bus				=> PC_to_Virtex_din_i
		);
	---------------------------------------------------------------------------------
	-- PC_to_Virtex-5 board fifo
	---------------------------------------------------------------------------------
	Inst_PC_to_Virtex_5_board: fifo_block_1024_8
	port map (
			rst						=> fifo_vector_reset,
			wr_clk						=> clk_125MHz,
			rd_clk						=> clk_50MHz,
			din						=> PC_to_Virtex_din_i,
			wr_en						=> PC_to_Virtex_wr_en_i,
			rd_en						=> PC_to_Virtex_rd_en_i,
			dout						=> PC_to_Virtex_dout_i,
			full						=> open,
			empty						=> PC_to_Virtex_empty_i
		);
	---------------------------------------------------------------------------------
	-- This process is to count the received data from PC.
	---------------------------------------------------------------------------------
	Inst_process_received_data_from_PC: process( reset, clk_125MHz)
	begin
		if ( reset = '1') then
			PC_write_data_byte_number_i <= x"0000";
		elsif ( clk_125MHz 'event and clk_125MHz = '1') then
			if (PC_to_Virtex_wr_en_i = '1') then
				PC_write_data_byte_number_i <= PC_write_data_byte_number_i + x"01";
			end if;
		end if;
	end process;

	Sending_data_to_GTP_Interface: process( clk_50MHz, reset)
	begin
	-- {
		if ( reset = '1') then
			Sending_data_to_GTP_Interface_state <= idle;
			byte_number <= '0';
			config_data_from_UDP_to_GTP <= x"0000";
			config_data_from_UDP_to_GTP_wr <= '0';
			PC_to_Virtex_rd_en_i <= '0';
			sending_config_data_complete <= '0';
			UDP_combine_byte_to_word_number_i <= x"0000";
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			case Sending_data_to_GTP_Interface_state is
				when idle =>
					if (PC_to_Virtex_empty_i = '0') then
						PC_to_Virtex_rd_en_i <= '1';
						Sending_data_to_GTP_Interface_state <= start_signal_judge;
					else
						PC_to_Virtex_rd_en_i <= '0';
					end if;
					sending_config_data_complete <= '0';
					config_data_from_UDP_to_GTP_wr <= '0';
					config_data_from_UDP_to_GTP <= x"0000";
				when start_signal_judge =>
					if ( PC_to_Virtex_dout_i = x"81") then
						byte_number <= '1';
						sending_config_data_complete <= '0';
						config_data_from_UDP_to_GTP_wr <= '0';
						config_data_from_UDP_to_GTP <= PC_to_Virtex_dout_i & x"00";
						Sending_data_to_GTP_Interface_state <= sending_data;
					else
						PC_to_Virtex_rd_en_i <= '0';
						Sending_data_to_GTP_Interface_state <= idle;
					end if;
				when sending_data =>
					if ( PC_to_Virtex_dout_i = x"FF" )then 
						PC_to_Virtex_rd_en_i <= '0';
						if ( byte_number = '0') then
							config_data_from_UDP_to_GTP_wr <= '1';
							config_data_from_UDP_to_GTP <= PC_to_Virtex_dout_i & x"00";
							UDP_combine_byte_to_word_number_i <= UDP_combine_byte_to_word_number_i + x"01";
						else
							config_data_from_UDP_to_GTP_wr <= '1';
							config_data_from_UDP_to_GTP (7 downto 0) <= PC_to_Virtex_dout_i;
							UDP_combine_byte_to_word_number_i <= UDP_combine_byte_to_word_number_i + x"02";
						end if;
						sending_config_data_complete <= '1';
						Sending_data_to_GTP_Interface_state <= idle;
					else
						PC_to_Virtex_rd_en_i <= '1';
						if ( byte_number = '0') then
							byte_number <= '1';
							config_data_from_UDP_to_GTP_wr <= '0';
							config_data_from_UDP_to_GTP( 15 downto 8) <= PC_to_Virtex_dout_i;
						else
							byte_number <= '0';
							config_data_from_UDP_to_GTP_wr <= '1';
							config_data_from_UDP_to_GTP( 7 downto 0) <= PC_to_Virtex_dout_i;
							UDP_combine_byte_to_word_number_i <= UDP_combine_byte_to_word_number_i + x"02";
						end if;
					end if;
			-- After the process goes into idle-state, is_config_data_UDP will be '0';
			end case;
		end if;
	-- }
	end process;

	---------------------------------------------------------------------------------
	-- data from Virtex-5 board to PC
	-- to receive acquistion data from Virtex-5 board through GTP interface, then send
	-- to Giga_ethernet interface
	-- To meet the speed, there is two fifo to receie the acquisited data.
	-- The size of the fifo_16 is 512 (15 downto 0). It is 1024 byte. 
	---------------------------------------------------------------------------------
	Inst_data_from_Virtex_5_board_fifo_even: fifo_block_512_16
	port map (
			rst						=> fifo_vector_reset,
			wr_clk						=> clk_50MHz,
			rd_clk						=> clk_125MHz,
			din						=> din_from_Daisychain,
			wr_en						=> Rx_receive_fifo_even_wr_en_i,
			rd_en						=> Rx_receive_fifo_even_rd_en_i,
			dout						=> Rx_receive_fifo_even_dout_i,
			full						=> open, 
			empty						=> Rx_receive_fifo_even_empty_i
		);
	Inst_data_from_Virtex_5_board_fifo_odd: fifo_block_512_16
	port map (
			 rst						=> fifo_vector_reset,
			 wr_clk						=> clk_50MHz,
			 rd_clk						=> clk_125MHz,
			 din						=> din_from_Daisychain,
			 wr_en						=> Rx_receive_fifo_odd_wr_en_i,
			 rd_en						=> Rx_receive_fifo_odd_rd_en_i,
			 dout						=> Rx_receive_fifo_odd_dout_i,
			 full						=> open,
			 empty						=> Rx_receive_fifo_odd_empty_i 
		 );
	-----------------------------------------------------------------------------------	
	-- Receiving data from Daisychain. To design even and odd fifo to ensure recieving
	-- all the data during the time UDP interfacing
	-----------------------------------------------------------------------------------	
	--- This process is just for looking for the bug.
	simulatio_process: process ( clk_50MHz, reset)
	begin
		if ( reset = '1') then
			data_from_DaisyChain_wr_i <= '0';
			data_from_DaisyChain_i <= x"0000";
			simulation_state_machine <= idle;
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			case simulation_state_machine is
				when idle =>
					data_from_DaisyChain_wr_i <= '0';
					data_from_DaisyChain_i <= data_from_DaisyChain_i;
					simulation_state_machine <= write_state_machine;
				when write_state_machine =>
					data_from_DaisyChain_wr_i <= '1';
					if ( data_from_DaisyChain_i < x"201") then 
						data_from_DaisyChain_i <= data_from_DaisyChain_i + x"0001";
					else
						data_from_DaisyChain_i <= x"0000";
					end if;
					simulation_state_machine <= idle;
			end case;
		end if;
	end process;
	--- This process is just for looking for the bug.




	Receiving_data_from_Daisychain: process( clk_50MHz, reset)
	begin
		if ( reset = '1') then
			Rx_receive_fifo_even_wr_en_i <= '0';
			Rx_receive_fifo_odd_wr_en_i <= '0';
			receive_fifo_state <= even;
			receive_data_number <= "00" & x"00";
			fifo_full <= "00";
			UDP_receive_data_from_Daisychain <= x"0000";
		elsif (clk_50MHz 'event and clk_50MHz = '1') then
			-- din_from_Daisychain <= data_from_DaisyChain_i;
			din_from_Daisychain <= data_from_DaisyChain;
			----------------------------------------------------------
			-- counter the received data from Daisychain
			if ( data_from_DaisyChain_wr = '1') then
				if ( data_from_DaisyChain(15 downto 8) = x"FF") then
					UDP_receive_data_from_Daisychain <= UDP_receive_data_from_Daisychain + x"1";
				else
					UDP_receive_data_from_Daisychain <= UDP_receive_data_from_Daisychain + x"2";
				end if;
			end if;
			----------------------------------------------------------

			case receive_fifo_state is 
				when even =>
					if ( data_from_DaisyChain_wr = '1') then
						if (receive_data_number < x"1FF") then
							fifo_full <= "00";
							receive_data_number <= receive_data_number + x"01";
							receive_fifo_state <= even;
						elsif ( receive_data_number = x"1FF") then
							-- "01" even fifo is full.
							fifo_full <= "01";
							receive_data_number <= "00" & x"00";
							receive_fifo_state <= odd;
						end if;
					else
						fifo_full <= "00";
						receive_data_number <= receive_data_number;
						receive_fifo_state <= even;
					end if;
					Rx_receive_fifo_odd_wr_en_i <= '0';
					Rx_receive_fifo_even_wr_en_i <= data_from_DaisyChain_wr;
				when odd =>
					if ( data_from_DaisyChain_wr = '1') then
						if ( receive_data_number < x"1FF") then
							fifo_full <= "00";
							receive_data_number <= receive_data_number + x"01";
							receive_fifo_state <= odd;
						elsif( receive_data_number = x"1FF") then
							-- "10" odd fifo is full.
							fifo_full <= "10";
							receive_data_number <= "00" & x"00";
							receive_fifo_state <= even;
						end if;
					else
						fifo_full <= "00";
						receive_data_number <= receive_data_number;
						receive_fifo_state <= odd;
					end if;
					Rx_receive_fifo_even_wr_en_i <= '0';
					Rx_receive_fifo_odd_wr_en_i <= data_from_DaisyChain_wr;
			end case;
		end if;
	end process;



	----------------------------------------------------------------------------------	
	-- To transmit the receiving data to PC through UDP Interface
	-----------------------------------------------------------------------------------	
	Transmit: process(clk_125MHz, reset)
	begin
		if ( reset = '1') then
			transmit_start_enable_i <= '0';
			transmit_data_length_i <= x"0000";
			transmit_data_input_bus_i <= x"00";
			counter <= "000" & x"00";
			Rx_receive_fifo_even_rd_en_i <= '0';
			Rx_receive_fifo_odd_rd_en_i <= '0';
			current_state <= ready;
		elsif (clk_125MHz 'event and clk_125MHz = '1') then
			case current_state is
				when ready =>
					Rx_receive_fifo_even_rd_en_i <= '0';
					Rx_receive_fifo_odd_rd_en_i <= '0';
					counter <= "000" & x"00";
					transmit_data_input_bus_i <= x"00";
					transmit_data_length_i <= x"0400";
					case fifo_full is
						when "01" =>
							transmit_start_enable_i <= '1';
							current_state <= even_fifo_header;
						when "10" =>
							transmit_start_enable_i <= '1';
							current_state <= odd_fifo_header;
						when "00" =>
							transmit_start_enable_i <= '0';
							current_state <= ready;
						when others =>
							null;
					end case;
				when even_fifo_header =>
					Rx_receive_fifo_odd_rd_en_i <= '0';
					counter <= counter + x"01";
					transmit_start_enable_i <= '0';
					transmit_data_length_i <= x"0400";
					if ( counter = "000" & x"27") then 
						Rx_receive_fifo_even_rd_en_i <= '1';
						current_state <= even_fifo_header;
					elsif ( counter = "000" & x"29") then
						counter <= "000" & x"00";
						Rx_receive_fifo_even_rd_en_i <= '0';
						current_state <= even_fifo_data;
					else
						Rx_receive_fifo_even_rd_en_i <= '0';
						current_state <= even_fifo_header;
					end if;
				when odd_fifo_header =>
					Rx_receive_fifo_even_rd_en_i <= '0';
					counter <= counter + x"01";
					transmit_start_enable_i <= '0';
					transmit_data_length_i <= x"0400";
					if ( counter = "000" & x"27") then
						Rx_receive_fifo_odd_rd_en_i <= '1';
						current_state <= odd_fifo_header;
					elsif ( counter = "000" & x"29") then
						counter <= "000" & x"00";
						Rx_receive_fifo_odd_rd_en_i <= '0';
						current_state <= odd_fifo_data;
					else
						Rx_receive_fifo_odd_rd_en_i <= '0';
						current_state <= odd_fifo_header;
					end if;
				when even_fifo_data =>
					if ( counter = x"400") then
						counter <= "000" & x"00";
						current_state <= ready;
					else
						counter <= counter + x"01";
						current_state <= even_fifo_data;
					end if;
					if ( counter(0) = '0') then
						transmit_data_input_bus_i <= Rx_receive_fifo_even_dout_i (15 downto 8);
					else
						transmit_data_input_bus_i <= Rx_receive_fifo_even_dout_i (7 downto 0);
					end if;
					if ( (counter(0) = '0') and (counter < x"3FE")) then
						Rx_receive_fifo_even_rd_en_i <= '1';
					else
						Rx_receive_fifo_even_rd_en_i <= '0';
					end if;
				when odd_fifo_data =>
					if ( counter = x"400") then
						counter <= "000" & x"00";
						current_state <= ready;
					else
						counter <= counter + x"01";
						current_state <= odd_fifo_data;
					end if;
					if ( counter(0) = '0') then
						transmit_data_input_bus_i <= Rx_receive_fifo_odd_dout_i (15 downto 8);
					else
						transmit_data_input_bus_i <= Rx_receive_fifo_odd_dout_i (7 downto 0);
					end if;
					if ( (counter(0) = '0') and (counter < x"3FE")) then
						Rx_receive_fifo_odd_rd_en_i <= '1';
					else
						Rx_receive_fifo_odd_rd_en_i <= '0';
					end if;
			end case;
		end if;
	end process;

	bug_in_xx_8102_xx_from_Daisychain_to_UDP_process: process ( reset, clk_50MHz)
	begin
		if ( reset = '1') then
			bug_in_xx_8102_xx_from_Daisychain_to_UDP <= '0';
			formal_word <= x"0000";
			bug_bit3 <= "00";
		elsif( clk_50MHz 'event and clk_50MHz = '1') then
			case bug_bit3 is
				when "00" =>
					if ( data_from_Daisychain_wr = '0') then
						bug_bit3 <= "00";
						formal_word <= formal_word;
					else
						bug_bit3 <= "01";
						formal_word <= data_from_Daisychain;
					end if;
					bug_in_xx_8102_xx_from_Daisychain_to_UDP <= '0';
				when "01" =>
					if ( data_from_Daisychain_wr = '0') then
						bug_bit3 <= "01";
						formal_word <= formal_word;
						bug_in_xx_8102_xx_from_Daisychain_to_UDP <= '0';
					elsif ( (data_from_Daisychain_wr = '1') and (data_from_Daisychain /= x"8102")) then
						bug_bit3 <= "01";
						formal_word <= data_from_Daisychain;
						bug_in_xx_8102_xx_from_Daisychain_to_UDP <= '0';
					elsif ( (data_from_Daisychain_wr = '1') and (data_from_Daisychain = x"8102") and ((formal_word(15 downto 8) = x"FF") or (formal_word(7 downto 0) = x"FF"))) then
						bug_bit3 <= "01";
						formal_word <= data_from_Daisychain;
						bug_in_xx_8102_xx_from_Daisychain_to_UDP <= '0';
					elsif ( (data_from_Daisychain_wr = '1') and (data_from_Daisychain = x"8102") and ((formal_word(15 downto 8) /= x"FF") or ( formal_word(7 downto 0) /= x"FF"))) then
						bug_bit3 <= "00";
						formal_word <= formal_word;
						bug_in_xx_8102_xx_from_Daisychain_to_UDP <= '1';
					end if;
				when others =>
					null;
			end case;
		end if;
	end process;



	bug_capture_in_UDP_transfer: process ( reset, clk_125MHz)
	begin
		if ( reset = '1') then
			bug_in_UDP_transfer_i <= '0';
			bug_bit1 <= "000";
		elsif( clk_125MHz 'event and clk_125MHz = '1') then
			case bug_bit1 is
				when "000" =>
					if (transmit_data_input_bus_i = x"FF") then 
						if ((current_state = even_fifo_data) or (current_state = odd_fifo_data)) then
							bug_bit1 <= "001";
						else
							bug_bit1 <= "000";
						end if;
					else
							bug_bit1 <= "000";
					end if;
					bug_in_UDP_transfer_i <= '0';
				when "001" =>
					if (transmit_data_input_bus_i = x"00") then 
						if ((current_state = even_fifo_data) or (current_state = odd_fifo_data)) then
							bug_bit1 <= "010";
						else
							bug_bit1 <= "000";
						end if;
					else
							bug_bit1 <= "000";
					end if;
					bug_in_UDP_transfer_i <= '0';
				when "010" =>
					if (transmit_data_input_bus_i = x"FF") then 
						if ((current_state = even_fifo_data) or (current_state = odd_fifo_data)) then
							bug_bit1 <= "011";
						else
							bug_bit1 <= "000";
						end if;
					else
							bug_bit1 <= "000";
					end if;
					bug_in_UDP_transfer_i <= '0';
				when "011" =>
					if (transmit_data_input_bus_i = x"00") then 
						if ((current_state = even_fifo_data) or (current_state = odd_fifo_data)) then
							bug_bit1 <= "100";
						else
							bug_bit1 <= "000";
						end if;
					else
							bug_bit1 <= "000";
					end if;
					bug_in_UDP_transfer_i <= '0';
				when "100" =>
					if (transmit_data_input_bus_i = x"ff") then 
						if ((current_state = even_fifo_data) or (current_state = odd_fifo_data)) then
							bug_bit1 <= "101";
						else
							bug_bit1 <= "000";
						end if;
					else
							bug_bit1 <= "000";
					end if;
					bug_in_UDP_transfer_i <= '0';
				when "101" =>
					if (transmit_data_input_bus_i = x"00") then 
						if ((current_state = even_fifo_data) or (current_state = odd_fifo_data)) then
							bug_bit1 <= "000";
							bug_in_UDP_transfer_i <= '1';
						else
							bug_bit1 <= "000";
							bug_in_UDP_transfer_i <= '0';
						end if;
					else
							bug_bit1 <= "000";
							bug_in_UDP_transfer_i <= '0';
					end if;
				when others =>
					null;
			end case;
		end if;
	end process;




	Inst_process_compare: process( reset, clk_125MHz)
	begin
		if (reset = '1') then
			compare_result <= '0';
		else
			if ( UDP_combine_byte_to_word_number_i > GTP_receive_byte_number and PC_write_data_byte_number_i < GTP_transmit_byte_number and is_GTP_ready = '1' and UDP_receive_data_from_Daisychain > UDP_combine_byte_to_word_number_i) then
				if ( acquisition_data_receive_data_number > acquisition_data_number ) then
					compare_result <= '1';
				else
					compare_result <= '0';
				end if;
			end if;
		end if;
	end process;

end Behavioral;
