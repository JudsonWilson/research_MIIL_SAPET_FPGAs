----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    14:24:00 10/24/2013 
-- Design Name: 
-- Module Name:    BrdCfg_48RENA_50MHzSMA - Structural 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--	    Top level module that wraps the datatransmission component along with board
--     configuration specific components (such as clock PLL) pinout.
--
-- Dependencies: 
--     datatrasmission
--     Clock_Module
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity BrdCfg_48RENA_50MHzSMA is
	port (
		reset                    : in std_logic;
		clk_50MHz_p              : in std_logic;
		clk_50MHz_n              : in std_logic;
		-- debug clock - a signal for probing
		debug_clk_50MHz          : out std_logic;
		-- UDP relative interface
		compare_result           : out std_logic;
		-- Ethernet physical chip device interface
		fpga_0_Hard_Ethernet_MAC_TemacPhy_RST_n_pin     : out std_logic;
		fpga_0_Hard_Ethernet_MAC_GMII_TXD_0_pin         : out std_logic_vector(7 downto 0);
		fpga_0_Hard_Ethernet_MAC_GMII_TX_EN_0_pin       : out std_logic;
		fpga_0_Hard_Ethernet_MAC_GMII_TX_ER_0_pin       : out std_logic;
		fpga_0_Hard_Ethernet_MAC_GMII_TX_CLK_0_pin      : out std_logic;
		fpga_0_Hard_Ethernet_MAC_GMII_RXD_0_pin         : in std_logic_vector(7 downto 0);
		fpga_0_Hard_Ethernet_MAC_GMII_RX_DV_0_pin       : in std_logic;
		fpga_0_Hard_Ethernet_MAC_GMII_RX_ER_0_pin       : in std_logic;
		fpga_0_Hard_Ethernet_MAC_GMII_RX_CLK_0_pin      : in std_logic;
		-- GTP relative interface
		-- GTP transmit
		gtp_txp                  : out std_logic;
		gtp_txn                  : out std_logic;
		-- GTP receive
		gtp_rxp                  : in std_logic;
		gtp_rxn                  : in std_logic;
		-- GTP clock
		gtp_clkp_pin             : in std_logic;
		gtp_clkn_pin             : in std_logic;	
		-- Frontend Board connections
		frontend_tx              : out std_logic;
		frontend_rx_array        : in  std_logic_vector(47 downto 0);
		-- Other
		boardid                  : in std_logic_vector(2 downto 0);
		LED_gtp_tx               : out std_logic;
		LED_gtp_rx               : out std_logic;
		-- The following LEDs indicate problems detected in the FIFOs, where a packet
		-- was too long and overflowed the FIFO.
		LED_fifo_corruption_full_error_UDP_in                : out std_logic;
		LED_fifo_corruption_full_error_gtpj40_in             : out std_logic;
		LED_fifo_corruption_full_error_acquistion_top_in     : out std_logic;
		LED_fifo_corruption_full_error_acquistion_bottom_in  : out std_logic
	);
end BrdCfg_48RENA_50MHzSMA;

architecture Structural of BrdCfg_48RENA_50MHzSMA is
	-- Reset
	signal reset_i                  : std_logic; -- Use this or a derivative for everything in the design.
	signal reset_synch_FFs          : std_logic_vector(2 downto 0); -- For reset synchronization logic.
	-- Clocks
	signal clk_200MHz_i             : std_logic;
	signal clk_125MHz_i             : std_logic;
	signal clk_50MHz_in             : std_logic;
	signal clk_50MHz_sys            : std_logic;
	-- UDP relative interface
	signal compare_result_i         : std_logic;
	-- Ethernet physical chip device interface
	signal fpga_0_Hard_Ethernet_MAC_TemacPhy_RST_n_pin_i   : std_logic;
	signal fpga_0_Hard_Ethernet_MAC_GMII_TXD_0_pin_i       : std_logic_vector(7 downto 0);
	signal fpga_0_Hard_Ethernet_MAC_GMII_TX_EN_0_pin_i     : std_logic;
	signal fpga_0_Hard_Ethernet_MAC_GMII_TX_ER_0_pin_i     : std_logic;
	signal fpga_0_Hard_Ethernet_MAC_GMII_TX_CLK_0_pin_i    : std_logic;
	signal fpga_0_Hard_Ethernet_MAC_GMII_RXD_0_pin_i       : std_logic_vector(7 downto 0);
	signal fpga_0_Hard_Ethernet_MAC_GMII_RX_DV_0_pin_i     : std_logic;
	signal fpga_0_Hard_Ethernet_MAC_GMII_RX_ER_0_pin_i     : std_logic;
	signal fpga_0_Hard_Ethernet_MAC_GMII_RX_CLK_0_pin_i    : std_logic;
	-- GTP relative interface
	-- GTP transmit
	signal gtp_txp_i                : std_logic;
	signal gtp_txn_i                : std_logic;
	-- GTP receive
	signal gtp_rxp_i                : std_logic;
	signal gtp_rxn_i                : std_logic;
	-- GTP clock
	signal gtp_clkp_pin_i           : std_logic;
	signal gtp_clkn_pin_i           : std_logic;	
	-- GTP active signals (for LEDs)
	signal gtp_tx_active            : std_logic;
	signal gtp_rx_active            : std_logic;
	-- Frontend Board connections
	signal frontend_tx_i            : std_logic;
	signal frontend_rx_array_i      : std_logic_vector(47 downto 0);
	-- Other
	signal boardid_i                : std_logic_vector(2 downto 0);
	-- Error Signals for LEDs
	signal fifo_corruption_full_error_UDP_in                : std_logic;
	signal fifo_corruption_full_error_gtpj40_in             : std_logic;
	signal fifo_corruption_full_error_acquistion_top_in     : std_logic;
	signal fifo_corruption_full_error_acquistion_bottom_in  : std_logic;

	component Clock_module_50MHzIn_Differential
		port (
			-- global input
			reset			  : in std_logic;
			clk_source    : in std_logic;
			-- global output
			clk_sample    : out std_logic;
			-- for 125MHz
			clk_125MHz    : out std_logic;
			-- for Spartan3 in current phase of project
			clk_50MHz     : out std_logic;
			-- for USB commnunication (no longer used)
			clk_12MHz     : out std_logic
		);
	end component;

	component LED_extender
		port (
			reset : in  std_logic;
			clk   : in  std_logic;
			din   : in  std_logic;
			dout  : out std_logic
		);
	end component;

	component datatransmission
		port (
			reset                    : in std_logic;
			clk_50MHz                : in std_logic;
			clk_125MHz               : in std_logic;
			-- UDP relative interface
			compare_result           : out std_logic;
			-- Ethernet physical chip device interface
			fpga_0_Hard_Ethernet_MAC_TemacPhy_RST_n_pin     : out std_logic;
			fpga_0_Hard_Ethernet_MAC_GMII_TXD_0_pin         : out std_logic_vector(7 downto 0);
			fpga_0_Hard_Ethernet_MAC_GMII_TX_EN_0_pin       : out std_logic;
			fpga_0_Hard_Ethernet_MAC_GMII_TX_ER_0_pin       : out std_logic;
			fpga_0_Hard_Ethernet_MAC_GMII_TX_CLK_0_pin      : out std_logic;
			fpga_0_Hard_Ethernet_MAC_GMII_RXD_0_pin         : in std_logic_vector(7 downto 0);
			fpga_0_Hard_Ethernet_MAC_GMII_RX_DV_0_pin       : in std_logic;
			fpga_0_Hard_Ethernet_MAC_GMII_RX_ER_0_pin       : in std_logic;
			fpga_0_Hard_Ethernet_MAC_GMII_RX_CLK_0_pin      : in std_logic;
			-- GTP relative interface
			-- GTP transmit
			gtp_txp                  : out std_logic;
			gtp_txn                  : out std_logic;
			-- GTP receive
			gtp_rxp                  : in std_logic;
			gtp_rxn                  : in std_logic;
			-- GTP clock
			gtp_clkp_pin             : in std_logic;
			gtp_clkn_pin             : in std_logic;	
			-- Frontend Board connections
			frontend_tx              : out std_logic;
			frontend_rx_array        : in  std_logic_vector(47 downto 0);
			-- Other
			boardid                  : in std_logic_vector(2 downto 0);
			-- Signals for LEDs/etc.
			gtp_tx_active        : out std_logic;
			gtp_rx_active        : out std_logic;
			fifo_corruption_full_error_UDP_in                : out std_logic;
			fifo_corruption_full_error_gtpj40_in             : out std_logic;
			fifo_corruption_full_error_acquistion_top_in     : out std_logic;
			fifo_corruption_full_error_acquistion_bottom_in  : out std_logic
		);	
	end component;

begin
	--
	-- Port connections
	--
	debug_clk_50MHz <= clk_50MHz_sys;
	-- Other
	boardid_i          <= boardid;
	-- UDP relative interface
	compare_result  <= compare_result_i;
	-- Ethernet physical chip device interface
	fpga_0_Hard_Ethernet_MAC_TemacPhy_RST_n_pin   <= fpga_0_Hard_Ethernet_MAC_TemacPhy_RST_n_pin_i;
	fpga_0_Hard_Ethernet_MAC_GMII_TXD_0_pin       <= fpga_0_Hard_Ethernet_MAC_GMII_TXD_0_pin_i;
	fpga_0_Hard_Ethernet_MAC_GMII_TX_EN_0_pin     <= fpga_0_Hard_Ethernet_MAC_GMII_TX_EN_0_pin_i;
	fpga_0_Hard_Ethernet_MAC_GMII_TX_ER_0_pin     <= fpga_0_Hard_Ethernet_MAC_GMII_TX_ER_0_pin_i;
	fpga_0_Hard_Ethernet_MAC_GMII_TX_CLK_0_pin    <= fpga_0_Hard_Ethernet_MAC_GMII_TX_CLK_0_pin_i;
	fpga_0_Hard_Ethernet_MAC_GMII_RXD_0_pin_i     <= fpga_0_Hard_Ethernet_MAC_GMII_RXD_0_pin;
	fpga_0_Hard_Ethernet_MAC_GMII_RX_DV_0_pin_i   <= fpga_0_Hard_Ethernet_MAC_GMII_RX_DV_0_pin;
	fpga_0_Hard_Ethernet_MAC_GMII_RX_ER_0_pin_i   <= fpga_0_Hard_Ethernet_MAC_GMII_RX_ER_0_pin;
	fpga_0_Hard_Ethernet_MAC_GMII_RX_CLK_0_pin_i  <= fpga_0_Hard_Ethernet_MAC_GMII_RX_CLK_0_pin;
	-- GTP relative interface
	-- GTP transmit
	gtp_txp            <= gtp_txp_i;
	gtp_txn            <= gtp_txn_i;
	-- GTP receive
	gtp_rxp_i          <= gtp_rxp;
	gtp_rxn_i          <= gtp_rxn;
	-- GTP clock
	gtp_clkp_pin_i     <= gtp_clkp_pin;
	gtp_clkn_pin_i     <= gtp_clkn_pin;
	-- Frontend Board connections
	frontend_tx          <= frontend_tx_i;
	frontend_rx_array_i  <=
		'1' & --frontend_rx_array(47) &
		'1' & --frontend_rx_array(46) &
		'1' & --frontend_rx_array(45) &
		'1' & --frontend_rx_array(44) &
		'1' & --frontend_rx_array(43) &
		'1' & --frontend_rx_array(42) &
		'1' & --frontend_rx_array(41) &
		'1' & --frontend_rx_array(40) &
		'1' & --frontend_rx_array(39) &
		'1' & --frontend_rx_array(38) &
		'1' & --frontend_rx_array(37) &
		'1' & --frontend_rx_array(36) &
		frontend_rx_array(35) &
		frontend_rx_array(34) &
		frontend_rx_array(33) &
		frontend_rx_array(32) &
		'1' & --frontend_rx_array(31) &
		'1' & --frontend_rx_array(30) &
		'1' & --frontend_rx_array(29) &
		'1' & --frontend_rx_array(28) &
		'1' & --frontend_rx_array(27) &
		'1' & --frontend_rx_array(26) &
		'1' & --frontend_rx_array(25) &
		'1' & --frontend_rx_array(24) &
		'1' & --frontend_rx_array(23) &
		'1' & --frontend_rx_array(22) &
		'1' & --frontend_rx_array(21) &
		'1' & --frontend_rx_array(20) &
		frontend_rx_array(19) &
		frontend_rx_array(18) &
		frontend_rx_array(17) &
		frontend_rx_array(16) &
		'1' & --frontend_rx_array(15) &
		'1' & --frontend_rx_array(14) &
		'1' & --frontend_rx_array(13) &
		'1' & --frontend_rx_array(12) &
		'1' & --frontend_rx_array(11) &
		'1' & --frontend_rx_array(10) &
		'1' & --frontend_rx_array( 9) &
		'1' & --frontend_rx_array( 8) &
		'1' & --frontend_rx_array( 7) &
		'1' & --frontend_rx_array( 6) &
		'1' & --frontend_rx_array( 5) &
		'1' & --frontend_rx_array( 4) &
		frontend_rx_array( 3) &
		frontend_rx_array( 2) &
		frontend_rx_array( 1) &
		frontend_rx_array( 0);

	----------------------------------------------------------------------------
	-- Reset Synchronizer
	-- - Asynchronously triggered.
	-- - Triple registered to have a great, clean, synchronous release of reset.
	----------------------------------------------------------------------------
	reset_synchronizer: process( clk_50MHz_sys, reset)
	begin
		if ( reset = '1') then
			reset_synch_FFs <= "111";
		elsif ( clk_50MHz_sys'event and clk_50MHz_sys = '1') then
			reset_synch_FFs(0) <= '0';
			reset_synch_FFs(2 downto 1) <= reset_synch_FFs(1 downto 0);
		end if;
	end process;
	reset_i <= reset_synch_FFs(2);

	-------------------------------------------------------------------------------------------
	-- LED extenders
	-- - Take in various signals with possibly tiny pulses, and output a signal
	--   of approximately 1/10th of a second guaranteed minimum pulse for
	--   LEDs. (Should always be visible).
	----------------------------------------------------------------------------
	gtp_tx_LED_extender : LED_extender
		port map (
			reset => reset_i,
			clk   => clk_50MHz_sys,
			din   => gtp_tx_active,
			dout  => LED_gtp_tx
		);

	gtp_rx_LED_extender : LED_extender
		port map (
			reset => reset_i,
			clk   => clk_50MHz_sys,
			din   => gtp_rx_active,
			dout  => LED_gtp_rx
		);

	LED_extender_fifo_corruption_full_error_UDP_in : LED_extender
		port map (
			reset => reset_i,
			clk   => clk_50MHz_sys,
			din   => fifo_corruption_full_error_UDP_in,
			dout  => LED_fifo_corruption_full_error_UDP_in
		);

	LED_extender_fifo_corruption_full_error_gtpj40_in : LED_extender
		port map (
			reset => reset_i,
			clk   => clk_50MHz_sys,
			din   => fifo_corruption_full_error_gtpj40_in,
			dout  => LED_fifo_corruption_full_error_gtpj40_in
		);

	LED_extender_fifo_corruption_full_error_acquistion_top_in : LED_extender
		port map (
			reset => reset_i,
			clk   => clk_50MHz_sys,
			din   => fifo_corruption_full_error_acquistion_top_in,
			dout  => LED_fifo_corruption_full_error_acquistion_top_in
		);

	LED_extender_fifo_corruption_full_error_acquistion_bottom_in : LED_extender
		port map (
			reset => reset_i,
			clk   => clk_50MHz_sys,
			din   => fifo_corruption_full_error_acquistion_bottom_in,
			dout  => LED_fifo_corruption_full_error_acquistion_bottom_in
		);

	----------------------------------------------------------------------------
	-- Internal module instantiation
	-------------------------------------------------------------------------------------------

	-- IBUFGDS: Differential Global Clock Input Buffer - Used for LVDS clock input.
	IBUFGDS_inst : IBUFGDS
		generic map (
			DIFF_TERM => TRUE, -- Differential Termination
			IOSTANDARD => "LVDS_25"
		)
		port map (
			O =>  clk_50MHz_in, -- Clock buffer output
			I =>  clk_50MHz_p, -- Diff_p clock buffer input (connect to top-level port)
			IB => clk_50MHz_n  -- Diff_n clock buffer input (connect to top-level port)
		);

	Inst_ClockModule: Clock_module_50MHzIn_Differential
		port map (
			-- global input
			reset 		=> reset_i,
			clk_source  => clk_50MHz_in,
			-- global output
			clk_sample	=> open, --250MHz clock
			clk_125MHz	=> clk_125MHz_i,
			clk_50MHz	=> clk_50MHz_sys,
			clk_12MHz	=> open
		);

	Inst_datatransmission: datatransmission
		port map (
			reset      => reset_i,
			clk_125MHz => clk_125MHz_i,
			clk_50MHz  => clk_50MHz_sys,
			-- UDP relative interface
			compare_result => compare_result_i,
			-- Ethernet physical chip device interface
			fpga_0_Hard_Ethernet_MAC_TemacPhy_RST_n_pin => fpga_0_Hard_Ethernet_MAC_TemacPhy_RST_n_pin_i,
			fpga_0_Hard_Ethernet_MAC_GMII_TXD_0_pin     => fpga_0_Hard_Ethernet_MAC_GMII_TXD_0_pin_i,
			fpga_0_Hard_Ethernet_MAC_GMII_TX_EN_0_pin   => fpga_0_Hard_Ethernet_MAC_GMII_TX_EN_0_pin_i,
			fpga_0_Hard_Ethernet_MAC_GMII_TX_ER_0_pin   => fpga_0_Hard_Ethernet_MAC_GMII_TX_ER_0_pin_i,
			fpga_0_Hard_Ethernet_MAC_GMII_TX_CLK_0_pin  => fpga_0_Hard_Ethernet_MAC_GMII_TX_CLK_0_pin_i,
			fpga_0_Hard_Ethernet_MAC_GMII_RXD_0_pin     => fpga_0_Hard_Ethernet_MAC_GMII_RXD_0_pin_i,
			fpga_0_Hard_Ethernet_MAC_GMII_RX_DV_0_pin   => fpga_0_Hard_Ethernet_MAC_GMII_RX_DV_0_pin_i,
			fpga_0_Hard_Ethernet_MAC_GMII_RX_ER_0_pin   => fpga_0_Hard_Ethernet_MAC_GMII_RX_ER_0_pin_i,
			fpga_0_Hard_Ethernet_MAC_GMII_RX_CLK_0_pin  => fpga_0_Hard_Ethernet_MAC_GMII_RX_CLK_0_pin_i,
			-- GTP relative interface
			-- GTP transmit
			gtp_txp => gtp_txp_i,
			gtp_txn => gtp_txn_i,
			-- GTP receive
			gtp_rxp => gtp_rxp_i,
			gtp_rxn => gtp_rxn_i,
			-- GTP clock
			gtp_clkp_pin => gtp_clkp_pin_i,
			gtp_clkn_pin => gtp_clkn_pin_i,
			-- Frontend Board connections
			frontend_tx       => frontend_tx_i,
			frontend_rx_array => frontend_rx_array_i,
			-- Other
			boardid         => boardid_i,
			-- Signals for LEDs/etc.
			gtp_tx_active => gtp_tx_active,
			gtp_rx_active => gtp_rx_active,
			fifo_corruption_full_error_UDP_in                => fifo_corruption_full_error_UDP_in,
			fifo_corruption_full_error_gtpj40_in             => fifo_corruption_full_error_gtpj40_in,
			fifo_corruption_full_error_acquistion_top_in     => fifo_corruption_full_error_acquistion_top_in,
			fifo_corruption_full_error_acquistion_bottom_in  => fifo_corruption_full_error_acquistion_bottom_in
		);
end Structural;
