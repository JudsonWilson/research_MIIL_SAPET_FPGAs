------------------------------------------------------------------------
-- Title      : Demo testbench
-- Project    : Virtex-5 Embedded Tri-Mode Ethernet MAC Wrapper
-- File       : demo_tb.vhd
-- Version    : 1.7
-------------------------------------------------------------------------------
--
-- (c) Copyright 2004-2010 Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
--
------------------------------------------------------------------------
-- Description: This testbench will exercise the PHY ports of the EMAC
--              to demonstrate the functionality.
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity testbench is
end testbench;


architecture behavioral of testbench is


  ----------------------------------------------------------------------
  -- Component Declaration for ethernetmac_example_design
  --                           (the top level EMAC example deisgn)
  ----------------------------------------------------------------------
  component ethernetmac_example_design
    port(
        -- Client Receiver Interface - EMAC0
        EMAC0CLIENTRXDVLD               : out std_logic;
        EMAC0CLIENTRXFRAMEDROP          : out std_logic;
        EMAC0CLIENTRXSTATS              : out std_logic_vector(6 downto 0);
        EMAC0CLIENTRXSTATSVLD           : out std_logic;
        EMAC0CLIENTRXSTATSBYTEVLD       : out std_logic;

        -- Client Transmitter Interface - EMAC0
        CLIENTEMAC0TXIFGDELAY           : in  std_logic_vector(7 downto 0);
        EMAC0CLIENTTXSTATS              : out std_logic;
        EMAC0CLIENTTXSTATSVLD           : out std_logic;
        EMAC0CLIENTTXSTATSBYTEVLD       : out std_logic;

        -- MAC Control Interface - EMAC0
        CLIENTEMAC0PAUSEREQ             : in  std_logic;
        CLIENTEMAC0PAUSEVAL             : in  std_logic_vector(15 downto 0);

        -- Clock Signal - EMAC0
        GTX_CLK_0                       : in  std_logic;

        -- GMII Interface - EMAC0
        GMII_TXD_0                      : out std_logic_vector(7 downto 0);
        GMII_TX_EN_0                    : out std_logic;
        GMII_TX_ER_0                    : out std_logic;
        GMII_TX_CLK_0                   : out std_logic;
        GMII_RXD_0                      : in  std_logic_vector(7 downto 0);
        GMII_RX_DV_0                    : in  std_logic;
        GMII_RX_ER_0                    : in  std_logic;
        GMII_RX_CLK_0                   : in  std_logic;




        REFCLK                          : in  std_logic;  -- 200 MHz Clock


        -- Asynchronous Reset
        RESET                           : in  std_logic
        );
  end component;


  component configuration_tb is
    port(
      reset                       : out std_logic;
      ------------------------------------------------------------------
      -- Host Interface: host_clk is always required
      ------------------------------------------------------------------
      host_clk                    : out std_logic;

      ------------------------------------------------------------------
      -- Test Bench Semaphores
      ------------------------------------------------------------------

      emac0_configuration_busy    : out boolean;
      emac0_monitor_finished_1g   : in  boolean;
      emac0_monitor_finished_100m : in  boolean;
      emac0_monitor_finished_10m  : in  boolean;

      emac1_configuration_busy    : out boolean;
      emac1_monitor_finished_1g   : in  boolean;
      emac1_monitor_finished_100m : in  boolean;
      emac1_monitor_finished_10m  : in  boolean

      );
  end component;


  ----------------------------------------------------------------------
  -- Component Declaration for the EMAC0 PHY stimulus and monitor
  ----------------------------------------------------------------------

  component emac0_phy_tb is
    port(
      ------------------------------------------------------------------
      -- GMII Interface
      ------------------------------------------------------------------
      gmii_txd              : in  std_logic_vector(7 downto 0); 
      gmii_tx_en            : in  std_logic;    
      gmii_tx_er            : in  std_logic;    
      gmii_tx_clk           : in  std_logic;    
      gmii_rxd              : out std_logic_vector(7 downto 0); 
      gmii_rx_dv            : out std_logic;    
      gmii_rx_er            : out std_logic;    
      gmii_rx_clk           : out std_logic;
      gmii_col              : out std_logic;
      gmii_crs              : out std_logic;
      mii_tx_clk            : out std_logic;

      ------------------------------------------------------------------
      -- Test Bench Semaphores
      ------------------------------------------------------------------
      configuration_busy    : in  boolean;
      monitor_finished_1g   : out boolean;
      monitor_finished_100m : out boolean;
      monitor_finished_10m  : out boolean
      );
  end component;





  ----------------------------------------------------------------------
  -- testbench signals
  ----------------------------------------------------------------------
    signal reset                : std_logic                     := '1';

    -- EMAC0
    signal tx_client_clk_0      : std_logic;
    signal tx_ifg_delay_0       : std_logic_vector(7 downto 0)  := (others => '0'); -- IFG stretching not used in demo.
    signal rx_client_clk_0      : std_logic;
    signal pause_val_0          : std_logic_vector(15 downto 0) := (others => '0');
    signal pause_req_0          : std_logic                     := '0';

    -- GMII Signals
    signal gmii_tx_clk_0        : std_logic;
    signal gmii_tx_en_0         : std_logic;
    signal gmii_tx_er_0         : std_logic;
    signal gmii_txd_0           : std_logic_vector(7 downto 0);
    signal gmii_rx_clk_0        : std_logic;
    signal gmii_rx_dv_0         : std_logic;
    signal gmii_rx_er_0         : std_logic;
    signal gmii_rxd_0           : std_logic_vector(7 downto 0);
    -- Not asserted: full duplex only testbench
    signal mii_tx_clk_0         : std_logic;
    signal gmii_crs_0           : std_logic                     := '0';
    signal gmii_col_0           : std_logic                     := '0';

 

    -- Clock signals
    signal host_clk             : std_logic                     := '0';
    signal gtx_clk              : std_logic;
    signal refclk               : std_logic;


    ------------------------------------------------------------------
    -- Test Bench Semaphores
    ------------------------------------------------------------------
    signal emac0_configuration_busy    : boolean := false;
    signal emac0_monitor_finished_1g   : boolean := false;
    signal emac0_monitor_finished_100m : boolean := false;
    signal emac0_monitor_finished_10m  : boolean := false;

    signal emac1_configuration_busy    : boolean := false;
    signal emac1_monitor_finished_1g   : boolean := false;
    signal emac1_monitor_finished_100m : boolean := false;
    signal emac1_monitor_finished_10m  : boolean := false;


begin


  ----------------------------------------------------------------------
  -- Wire up Device Under Test
  ----------------------------------------------------------------------
  dut : ethernetmac_example_design
  port map (
    -- Client Receiver Interface - EMAC0
    EMAC0CLIENTRXDVLD               => open,
    EMAC0CLIENTRXFRAMEDROP          => open,
    EMAC0CLIENTRXSTATS              => open,
    EMAC0CLIENTRXSTATSVLD           => open,
    EMAC0CLIENTRXSTATSBYTEVLD       => open,

    -- Client Transmitter Interface - EMAC0
    CLIENTEMAC0TXIFGDELAY           => tx_ifg_delay_0,
    EMAC0CLIENTTXSTATS              => open,
    EMAC0CLIENTTXSTATSVLD           => open,
    EMAC0CLIENTTXSTATSBYTEVLD       => open,

    -- MAC Control Interface - EMAC0
    CLIENTEMAC0PAUSEREQ             => pause_req_0,
    CLIENTEMAC0PAUSEVAL             => pause_val_0,

    -- Clock Signal - EMAC0
    GTX_CLK_0                       => gtx_clk,

    -- GMII Interface - EMAC0
    GMII_TXD_0                      => gmii_txd_0,
    GMII_TX_EN_0                    => gmii_tx_en_0,
    GMII_TX_ER_0                    => gmii_tx_er_0,
    GMII_TX_CLK_0                   => gmii_tx_clk_0,
    GMII_RXD_0                      => gmii_rxd_0,
    GMII_RX_DV_0                    => gmii_rx_dv_0,
    GMII_RX_ER_0                    => gmii_rx_er_0,
    GMII_RX_CLK_0                   => gmii_rx_clk_0,


    REFCLK                          => refclk,

        
    -- Asynchronous Reset
    RESET                           => reset
    );


    ----------------------------------------------------------------------------
    -- Flow Control is unused in this demonstration
    ----------------------------------------------------------------------------
    pause_req_0 <= '0';
    pause_val_0 <= "0000000000000000";





    ----------------------------------------------------------------------------
    -- Clock drivers
    ----------------------------------------------------------------------------

    -- Drive GTX_CLK at 125 MHz
    p_gtx_clk : process 
    begin
        gtx_clk <= '0';
        wait for 10 ns;
        loop
            wait for 4 ns;
            gtx_clk <= '1';
            wait for 4 ns;
            gtx_clk <= '0';
        end loop;
    end process p_gtx_clk;


    -- Drive refclk at 200MHz
    p_ref_clk : process
    begin
        refclk <= '0';
        wait for 10 ns;
        loop
            wait for 2.5 ns;
            refclk <= '1';
            wait for 2.5 ns;
            refclk <= '0';
        end loop;
    end process p_ref_clk;

  ----------------------------------------------------------------------
  -- Instantiate the EMAC0 PHY stimulus and monitor
  ----------------------------------------------------------------------

  phy0_test: emac0_phy_tb
    port map (
      ------------------------------------------------------------------
      -- GMII Interface
      ------------------------------------------------------------------
      gmii_txd              => gmii_txd_0, 
      gmii_tx_en            => gmii_tx_en_0,
      gmii_tx_er            => gmii_tx_er_0,
      gmii_tx_clk           => gmii_tx_clk_0,
      gmii_rxd              => gmii_rxd_0, 
      gmii_rx_dv            => gmii_rx_dv_0,
      gmii_rx_er            => gmii_rx_er_0,
      gmii_rx_clk           => gmii_rx_clk_0,
      gmii_col              => gmii_col_0,
      gmii_crs              => gmii_crs_0,
      mii_tx_clk            => mii_tx_clk_0,

      ------------------------------------------------------------------
      -- Test Bench Semaphores
      ------------------------------------------------------------------
      configuration_busy    => emac0_configuration_busy,
      monitor_finished_1g   => emac0_monitor_finished_1g,
      monitor_finished_100m => emac0_monitor_finished_100m,
      monitor_finished_10m  => emac0_monitor_finished_10m
      );






  
  ----------------------------------------------------------------------
  -- Instantiate the No-Host Configuration Stimulus
  ----------------------------------------------------------------------

  config_test: configuration_tb
    port map (
      reset                       => reset,
      ------------------------------------------------------------------
      -- Host Interface: host_clk is always required
      ------------------------------------------------------------------
      host_clk                    => host_clk,


      emac0_configuration_busy    => emac0_configuration_busy,
      emac0_monitor_finished_1g   => emac0_monitor_finished_1g,
      emac0_monitor_finished_100m => emac0_monitor_finished_100m,
      emac0_monitor_finished_10m  => emac0_monitor_finished_10m,

      emac1_configuration_busy    => emac1_configuration_busy,
      emac1_monitor_finished_1g   => emac1_monitor_finished_1g,
      emac1_monitor_finished_100m => emac1_monitor_finished_100m,
      emac1_monitor_finished_10m  => emac1_monitor_finished_10m 

      );



end behavioral;

