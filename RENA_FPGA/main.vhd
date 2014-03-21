----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:02:55 07/13/2011 
-- Design Name: 
-- Module Name:    main - Behavioral 
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

library UNISIM;
use UNISIM.VComponents.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity main is
    Port (
				-- Debug
				debugOutMain     : out STD_LOGIC;
				
				MCLKp 	: 	in STD_LOGIC;
				MCLKn 	: 	in STD_LOGIC;
				RST      :  in STD_LOGIC;
	 
				TXp : out  STD_LOGIC;
				TXn : out  STD_LOGIC;
				rx  : in  STD_LOGIC;

				ADDR : in STD_LOGIC_VECTOR(5 downto 0);  -- Identifies which FPGA the data is associated with
				
			   -- RENA #1 controls
				nCS1  : out STD_LOGIC;			--ADC1 chip select
				SDO1  : in  STD_LOGIC;			--ADC1 Serial data
				SCLK1 :out  STD_LOGIC;			--ADC1 clock
						
				TOUT1     : in STD_LOGIC;
				FOUT1     : in STD_LOGIC;
				SOUT1     : in STD_LOGIC;
				
				CS1     : out STD_LOGIC;
				CSHIFT1 : out STD_LOGIC;
				CIN1    : out STD_LOGIC;
				
				CLF1    : out STD_LOGIC;
				
				TCLK1 : out STD_LOGIC;
				FHRCLK_SHRCLK1 : out STD_LOGIC;
			   SIN1 : out STD_LOGIC;
				FIN1 : out STD_LOGIC;
				TIN1 : out STD_LOGIC;
				
				nTF1p : in STD_LOGIC;
				nTF1n : in STD_LOGIC;
				nTS1p : in STD_LOGIC;
				nTS1n : in STD_LOGIC;
				
				CLS1p : out STD_LOGIC;
				CLS1n : out STD_LOGIC;
								
				ACQUIRE1p : out STD_LOGIC;	
				ACQUIRE1n : out STD_LOGIC;			
				
			   -- RENA #2 controls	
				nCS2  : out STD_LOGIC;			--ADC2 chip select
				SDO2  : in STD_LOGIC;			--ADC2 Serial data
				SCLK2 :out STD_LOGIC;			--ADC2 clock
						
				TOUT2     : in STD_LOGIC;
				FOUT2     : in STD_LOGIC;
				SOUT2     : in STD_LOGIC;
				
				CS2     : out STD_LOGIC;
				CSHIFT2 : out STD_LOGIC;
				CIN2    : out STD_LOGIC;
				
				CLF2 : out STD_LOGIC;
				
				TCLK2 : out STD_LOGIC;
				FHRCLK_SHRCLK2 : out STD_LOGIC;
			   SIN2 : out STD_LOGIC;
				FIN2 : out STD_LOGIC;
				TIN2 : out STD_LOGIC;
				
				nTF2p : in STD_LOGIC;
				nTF2n : in STD_LOGIC;
				nTS2p : in STD_LOGIC;
				nTS2n : in STD_LOGIC;
								
				CLS2p : out STD_LOGIC;
				CLS2n : out STD_LOGIC;
								
				ACQUIRE2p : out STD_LOGIC;	
				ACQUIRE2n : out STD_LOGIC
			  );
end main;

architecture Behavioral of main is

--========================================================================
-- DCM 4x debug clock
-- Remember to regenerate DCM using differential inputs if we are using
-- differential inputs.
-- DCM 2x debug clock
component systemClkX2DiffIn
   port ( CLKIN_N_IN        : in    std_logic; 
          CLKIN_P_IN        : in    std_logic; 
          RST_IN            : in    std_logic; 
          CLKFX_OUT         : out   std_logic; 
          CLKIN_IBUFGDS_OUT : out   std_logic; 
          CLK0_OUT          : out   std_logic; 
          CLK2X_OUT         : out   std_logic; 
          LOCKED_OUT        : out   std_logic);
end component;

component LED
port (
	mclk   : in  STD_LOGIC;
   ledOut : out  STD_LOGIC
	);
end component;

component Serial_rx
	port(
		mclkx2   : in std_logic;
		rx       : in std_logic;          
		data     : out std_logic_vector(7 downto 0);
		new_data : out std_logic
		);
	end component;

component RX_Decode
	port( 
		debugOut: out STD_LOGIC_VECTOR(2 downto 0);
		mclk    : in std_logic;
		RX_DATA : in  STD_LOGIC_VECTOR (7 downto 0);
		NEW_RX_DATA      : in  STD_LOGIC;
		FPGA_ADDRESS     : in STD_LOGIC_VECTOR(5 downto 0);
		ENABLE_READOUT1  : out  STD_LOGIC;
		ENABLE_READOUT2  : out  STD_LOGIC;
		OR_MODE_TRIGGER1 : out  STD_LOGIC;
		OR_MODE_TRIGGER2 : out  STD_LOGIC;
		FORCE_TRIGGERS1  : out STD_LOGIC;
		FORCE_TRIGGERS2  : out STD_LOGIC;
		RESET_TIMESTAMP  : out STD_LOGIC;
		FOLLOWER_MODE1   : out  STD_LOGIC;
		FOLLOWER_MODE2      : out  STD_LOGIC;
		FOLLOWER_MODE_CHAN  : out  STD_LOGIC_VECTOR(5 downto 0);
		FOLLOWER_MODE_TCLK  : out  STD_LOGIC_VECTOR(1 downto 0);
		CS1                 : out  STD_LOGIC;
		CSHIFT1             : out  STD_LOGIC;
		CIN1                : out  STD_LOGIC;
		CS2                 : out  STD_LOGIC;
		CSHIFT2             : out  STD_LOGIC;
		CIN2                : out  STD_LOGIC;
		DIAGNOSTIC_RENA1_SETTINGS : out  STD_LOGIC_VECTOR(41 downto 0);
		DIAGNOSTIC_RENA2_SETTINGS : out  STD_LOGIC_VECTOR(41 downto 0);
		DIAGNOSTIC_SEND     : out  STD_LOGIC
	);
end component;

component RS232_tx_buffered
	port(
		debugOut       : out STD_LOGIC_VECTOR(2 downto 0);
		mclk           : IN std_logic;
		data_diag      : IN std_logic_vector(7 downto 0);
		new_data_diag  : IN std_logic;	
		data_diag_full : OUT std_logic;
		data1          : IN std_logic_vector(7 downto 0);
		new_data1      : IN std_logic;
		data2          : IN std_logic_vector(7 downto 0);
		new_data2      : IN std_logic;	
		tx_busy        : OUT std_logic;
		tx             : OUT std_logic);
end component;

component OperationalStateController is
Port (
	-- Basic signals
	-- TO DO: remove debug ports in final implementation
	debugOut           : out std_logic_vector(3 downto 0);
	mclk 	             : in std_logic;
	reset              : in std_logic;
	
	-- Configuration
	CHIP_ID            : in std_logic;
	FPGA_ADDR          : in std_logic_vector(5 downto 0);
	
	-- Readout settings
	ENABLE             : in std_logic; -- Arms the FPGA to wait for RENA-3 triggers
	OR_MODE_TRIGGER    : in std_logic;
	FORCE_TRIGGER      : in std_logic;
	FOLLOWER_MODE      : in std_logic;
	FOLLOWER_MODE_CHAN : in std_logic_vector(5 downto 0);
	FOLLOWER_MODE_TCLK : in std_logic_vector(1 downto 0);
	
	-- Data transmit
	TX_BUSY            : in std_logic;
	TX_DATA            : out std_logic_vector(7 downto 0);
	SEND_TX_DATA       : out std_logic; -- One shot signal indicating there's data to send
	
	SLOW_TIMESTAMP     : in std_logic_vector(41 downto 0);
	
	-- Crosstalk blocking
	DONT_TRIG_IN       : in std_logic;
	DONT_TRIG_OUT      : out std_logic;

	-- Shaper reset
	CLF                : out std_logic;
	CLS                : out std_logic;
	
	-- Trigger
	nTF                : in std_logic; -- Fast trigger
	nTS                : in std_logic; -- Slow trigger
	
	-- Start acquire
	ACQUIRE            : out std_logic;
	-- READ_SIG : out std_logic;
	
	-- Readout token
	TOUT               : in  std_logic; -- Signals end of AOUT data shift when high
	TIN                : out std_logic;
	TCLK               : out std_logic;
	
	-- Read/write list
	FOUT               : in  std_logic;
	SOUT               : in  std_logic;
	FIN                : out std_logic;
	SIN                : out std_logic;
	FHRCLK_SHRCLK      : out std_logic;
	
	-- ADC
	nCS                : out std_logic; -- ADC chip select ("select" in the sense that data is read from it when nCS = 0)
	SDO                : in  std_logic; -- ADC Serial data
	SCLK               : out std_logic  -- ADC clock
		);
end component;

constant num_rena_settings_bits: INTEGER := 129;

component diagnostic_messenger is
	Generic (
		num_bug_bits : INTEGER
	);
	Port (
		clk   : in STD_LOGIC;
		reset : in STD_LOGIC;

		fpga_addr      : in std_logic_vector(5 downto 0);

		send  : in  STD_LOGIC; -- Pulse to send the current state out to the TX, and reset the state

		packet_data      : out STD_LOGIC_VECTOR (7 downto 0); -- Output packet data to the TX
		packet_data_wr   : out STD_LOGIC;                     -- Tells the TX that data is valid. Pulse once per byte.
		packet_fifo_full : in STD_LOGIC;                      -- Notification that the receiving FIFO is full and data should not be written.

		rena1_settings    : in STD_LOGIC_VECTOR (num_rena_settings_bits-1 downto 0); --Last value that was programmed to rena1
		rena2_settings    : in STD_LOGIC_VECTOR (num_rena_settings_bits-1 downto 0); --Last value that was programmed to rena2
		bug_notifications : in STD_LOGIC_VECTOR (num_bug_bits-1 downto 0) --Pulse a bit to notify that an occurence of that bug happened.
	);
end component;

signal ledOut : std_logic;

signal systemClk   : std_logic;
signal systemClkX2Wire : std_logic;

signal tx : std_logic;

signal fpga_address : std_logic_vector(5 downto 0);

signal data1 : std_logic_vector(7 downto 0);
signal new_data1 : std_logic;
signal data2 : std_logic_vector(7 downto 0);
signal new_data2 : std_logic;
signal tx_busy : std_logic;

signal reset_timestamp : std_logic;

signal slow_timestamp : std_logic_vector(41 downto 0);
signal next_slow_timestamp : std_logic_vector(41 downto 0);

signal dont_trig_from_rena1 : std_logic;
signal dont_trig_from_rena2 : std_logic;

signal nTF1 : std_logic;
signal nTF1clked : std_logic;
signal nTS1 : std_logic;
signal nTS1clked : std_logic;

signal CLS1 : std_logic;
signal ACQUIRE1 : std_logic;

signal nTF2 : std_logic;
signal nTF2clked : std_logic;
signal nTS2 : std_logic;
signal nTS2clked : std_logic;

signal CLS2 : std_logic;
signal ACQUIRE2 : std_logic;

signal rx_data : std_logic_vector(7 downto 0);
signal new_rx_data : std_logic;

signal enable_readout1    : std_logic;
signal enable_readout2    : std_logic;
signal or_mode_trigger1   : std_logic;
signal or_mode_trigger2   : std_logic;
signal force_trigger1     : std_logic;
signal force_trigger2     : std_logic;
signal follower_mode1     : std_logic;
signal follower_mode2     : std_logic;
signal follower_mode_chan : std_logic_vector(5 downto 0);
signal follower_mode_tclk : std_logic_vector(1 downto 0);

signal anTrig_1To2 : std_logic;
signal anTrig_2To1 : std_logic;
signal caTrig_1To2 : std_logic;
signal caTrig_2To1 : std_logic;

signal i_read1    : std_logic;
signal i_read2    : std_logic;
signal int_ITRIG  : std_logic;
signal next_ITRIG : std_logic;

signal decoderDebug : std_logic_vector(2 downto 0);
signal txDebug : std_logic_vector(2 downto 0);

signal diagnostic_rena1_settings : std_logic_vector(41 downto 0);
signal diagnostic_rena2_settings : std_logic_vector(41 downto 0);
signal diagnostic_full_rena1_settings : std_logic_vector(129-1 downto 0);
signal diagnostic_full_rena2_settings : std_logic_vector(129-1 downto 0);
signal diagnostic_bug_notifications : std_logic_vector(29 downto 0);
signal diagnostic_packet_data    : std_logic_vector(7 downto 0);
signal diagnostic_packet_data_wr : std_logic;
signal diagnostic_packet_fifo_full    : std_logic;
signal diagnostic_send : std_logic;

begin

--========================================================================
-- Get signal from differential pairs
--========================================================================

IBUFDS_instTF1 : IBUFDS
generic map (
	CAPACITANCE => "DONT_CARE", -- "LOW", "NORMAL", "DONT_CARE" (Virtex-4 only)
	DIFF_TERM => FALSE,         -- Differential Termination (Virtex-4/5, Spartan-3E/3A)  --was true
	IBUF_DELAY_VALUE => "0",    -- Specify the amount of added input delay for buffer, "0"-"16" (Spartan-3E/3A only)
	IFD_DELAY_VALUE => "AUTO",  -- Specify the amount of added delay for input register, "AUTO", "0"-"8" (Spartan-3E/3A only)
	IOSTANDARD => "LVDS_25")
port map (
	O => nTF1,  -- Clock buffer output
	I => nTF1p,  -- Diff_p clock buffer input (connect directly to top-level port)
	IB => nTF1n  -- Diff_n clock buffer input (connect directly to top-level port)
);

IBUFDS_instTF2 : IBUFDS
generic map (
	CAPACITANCE => "DONT_CARE", -- "LOW", "NORMAL", "DONT_CARE" (Virtex-4 only)
	DIFF_TERM => FALSE,         -- Differential Termination (Virtex-4/5, Spartan-3E/3A) --was true
	IBUF_DELAY_VALUE => "0",    -- Specify the amount of added input delay for buffer, "0"-"16" (Spartan-3E/3A only)
	IFD_DELAY_VALUE => "AUTO",  -- Specify the amount of added delay for input register, "AUTO", "0"-"8" (Spartan-3E/3A only)
	IOSTANDARD => "LVDS_25")
port map (
	O => nTF2,  -- Clock buffer output
	I => nTF2p,  -- Diff_p clock buffer input (connect directly to top-level port)
	IB => nTF2n  -- Diff_n clock buffer input (connect directly to top-level port)
);

IBUFDS_instTF3 : IBUFDS
generic map (
	CAPACITANCE => "DONT_CARE", -- "LOW", "NORMAL", "DONT_CARE" (Virtex-4 only)
	DIFF_TERM => FALSE,         -- Differential Termination (Virtex-4/5, Spartan-3E/3A)  --was true
	IBUF_DELAY_VALUE => "0",    -- Specify the amount of added input delay for buffer, "0"-"16" (Spartan-3E/3A only)
	IFD_DELAY_VALUE => "AUTO",  -- Specify the amount of added delay for input register, "AUTO", "0"-"8" (Spartan-3E/3A only)
	IOSTANDARD => "LVDS_25")
port map (
	O => nTS1,  -- Clock buffer output
	I => nTS1p,  -- Diff_p clock buffer input (connect directly to top-level port)
	IB => nTS1n  -- Diff_n clock buffer input (connect directly to top-level port)
);

IBUFDS_instTF4 : IBUFDS
generic map (
	CAPACITANCE => "DONT_CARE", -- "LOW", "NORMAL", "DONT_CARE" (Virtex-4 only)
	DIFF_TERM => FALSE,         -- Differential Termination (Virtex-4/5, Spartan-3E/3A)  --was true
	IBUF_DELAY_VALUE => "0",    -- Specify the amount of added input delay for buffer, "0"-"16" (Spartan-3E/3A only)
	IFD_DELAY_VALUE => "AUTO",  -- Specify the amount of added delay for input register, "AUTO", "0"-"8" (Spartan-3E/3A only)
	IOSTANDARD => "LVDS_25")
port map (
	O => nTS2,  -- Clock buffer output
	I => nTS2p,  -- Diff_p clock buffer input (connect directly to top-level port)
	IB => nTS2n  -- Diff_n clock buffer input (connect directly to top-level port)
);

OBUFDS_instCLS1 : OBUFDS
generic map (
	IOSTANDARD => "DEFAULT")
port map (
	O => CLS1p,   -- Diff_p output (connect directly to top-level port)
	OB => CLS1n,  -- Diff_n output (connect directly to top-level port)
	I => CLS1     -- Buffer input 
);
  
OBUFDS_instCLS2 : OBUFDS
generic map (
	IOSTANDARD => "DEFAULT")
port map (
	O => CLS2p,   -- Diff_p output (connect directly to top-level port)
	OB => CLS2n,  -- Diff_n output (connect directly to top-level port)
	I => CLS2     -- Buffer input 
);
  
OBUFDS_instACQ1 : OBUFDS
generic map (
	IOSTANDARD => "DEFAULT")
port map (
	O => ACQUIRE1p,   -- Diff_p output (connect directly to top-level port)
	OB => ACQUIRE1n,  -- Diff_n output (connect directly to top-level port)
	I => ACQUIRE1     -- Buffer input 
);
  
OBUFDS_instACQ2 : OBUFDS
generic map (
	IOSTANDARD => "DEFAULT")
port map (
	O => ACQUIRE2p,   -- Diff_p output (connect directly to top-level port)
	OB => ACQUIRE2n,  -- Diff_n output (connect directly to top-level port)
	I => ACQUIRE2     -- Buffer input 
);

--=========================================================================
-- Digital Clock Manager:
--=========================================================================			 
clockSource : systemClkX2DiffIn port map(
          CLKIN_N_IN => MCLKn,
			 CLKIN_P_IN => MCLKp,
          RST_IN => RST,
          CLKFX_OUT => open, 
          CLKIN_IBUFGDS_OUT => open,
          CLK0_OUT => systemClk, 
          CLK2X_OUT => systemClkX2Wire, 
          LOCKED_OUT => open);

--========================================================================
-- Miscellaneous connections
--========================================================================
--debugOutMain <= force_trigger1;
debugOutMain <= ledOut;
fpga_address <= ADDR;

--========================================================================
-- D flip flops
--========================================================================
process(systemClk)
begin
	if rising_edge(systemClk) then
		if reset_timestamp = '0' then
				slow_timestamp <= next_slow_timestamp;
		else
				slow_timestamp <= "000000000000000000000000000000000000000000";
		end if;
	end if;						  
end process;

next_slow_timestamp <= slow_timestamp + 1;

process(systemClk)
begin
	if rising_edge(systemClk) then
		nTF1clked <= nTF1;
		nTS1clked <= nTS1;
		nTF2clked <= nTF2;
		nTS2clked <= nTS2;
	end if;
end process;
	
--========================================================================
-- This module blinks the LEDs
--========================================================================
LEDDriver : LED port map(
		  mclk => systemClk, 
		  ledOut => ledOut
		  );

-- OBUFDS: Differential Output Buffer
instTXpn : OBUFDS
generic map (
	IOSTANDARD => "DEFAULT")
port map (
	O  => TXp,  -- Diff_p output (connect directly to top-level port)
	OB => TXn,  -- Diff_n output (connect directly to top-level port)
	I  => tx    -- Buffer input 
);

--========================================================================
-- Data receive interface module
--========================================================================
UART : Serial_rx port map(
		  mclkx2   => systemClkX2Wire,
		  rx 	     => rx,
		  data     => rx_data,
		  new_data => new_rx_data
	 );

--========================================================================
-- Decode received configuration data
--========================================================================
RX_Decoder:  RX_Decode port map(
			  debugOut => decoderDebug,
			  mclk => systemClk,
			  RX_DATA => rx_data,
           NEW_RX_DATA => new_rx_data,
			  FPGA_ADDRESS => fpga_address,
           ENABLE_READOUT1 => enable_readout1,
			  ENABLE_READOUT2 => enable_readout2,
           OR_MODE_TRIGGER1 => or_mode_trigger1,
			  OR_MODE_TRIGGER2 => or_mode_trigger2,
			  FORCE_TRIGGERS1  => force_trigger1,
			  FORCE_TRIGGERS2  => force_trigger2,
			  RESET_TIMESTAMP => reset_timestamp, 
			  FOLLOWER_MODE1 => follower_mode1,
			  FOLLOWER_MODE2 => follower_mode2,
			  FOLLOWER_MODE_CHAN => follower_mode_chan,
			  FOLLOWER_MODE_TCLK => follower_mode_tclk,
           CS1  => CS1,
           CSHIFT1  => CSHIFT1,
           CIN1  => CIN1,
           CS2  => CS2,
           CSHIFT2  => CSHIFT2,
           CIN2  => CIN2,
			  diagnostic_rena1_settings => diagnostic_rena1_settings,
			  diagnostic_rena2_settings => diagnostic_rena2_settings,
			  DIAGNOSTIC_SEND => diagnostic_send
			  );

--========================================================================
-- Data transmit interface module
--========================================================================
TX_2buffers: RS232_tx_buffered PORT MAP(
		debugOut => txDebug,
		mclk => systemClk,
		data_diag => diagnostic_packet_data,
		new_data_diag => diagnostic_packet_data_wr,
		data_diag_full => diagnostic_packet_fifo_full,
		data1 => data1,
		new_data1 => new_data1,
		data2 => data2,
		new_data2 => new_data2,
		tx_busy => tx_busy,
		tx => tx
	);
	
--========================================================================
-- Readout logic modules
--========================================================================
RENA_MODULE_1: OperationalStateController PORT MAP(
	-- Debug
	debugOut => open,
	
	OR_MODE_TRIGGER => or_mode_trigger1,
	FORCE_TRIGGER => force_trigger1,
	FOLLOWER_MODE => follower_mode1,
	FOLLOWER_MODE_CHAN => follower_mode_chan,
	FOLLOWER_MODE_TCLK => follower_mode_tclk,
	
	mclk => systemClk,
	reset => '0',
	ENABLE => enable_readout1,
	TX_BUSY => tx_busy,
	TX_DATA => data1,
	SEND_TX_DATA => new_data1,
	CHIP_ID => '0',
	FPGA_ADDR => fpga_address,
	SLOW_TIMESTAMP => slow_timestamp,
	DONT_TRIG_IN => dont_trig_from_rena2,
	DONT_TRIG_OUT => dont_trig_from_rena1,
	nCS => nCS1,
	SDO => SDO1,
	SCLK => SCLK1,
	TOUT => TOUT1,
	TIN => TIN1,
	TCLK => TCLK1,
	FOUT => FOUT1,
	FIN => FIN1,
	SOUT => SOUT1,
	SIN => SIN1,
	FHRCLK_SHRCLK => FHRCLK_SHRCLK1,
	ACQUIRE => ACQUIRE1,
	nTF => nTF1clked,
	nTS => nTS1clked,
	CLF => CLF1,
	CLS => CLS1
);

RENA_MODULE_2: OperationalStateController PORT MAP(
	-- Debug
	debugOut => open,
	
	OR_MODE_TRIGGER => or_mode_trigger2,
	FORCE_TRIGGER => force_trigger2,
	FOLLOWER_MODE => follower_mode2,
	FOLLOWER_MODE_CHAN => follower_mode_chan,
	FOLLOWER_MODE_TCLK => follower_mode_tclk,
	
	mclk => systemClk,
	reset => '0',
	ENABLE => enable_readout2,
	TX_BUSY => tx_busy,
	TX_DATA => data2,
	SEND_TX_DATA => new_data2,
	CHIP_ID => '1',
	FPGA_ADDR => fpga_address,
	SLOW_TIMESTAMP => slow_timestamp,
	DONT_TRIG_IN => dont_trig_from_rena1,
	DONT_TRIG_OUT => dont_trig_from_rena2,
	nCS => nCS2,
	SDO => SDO2,
	SCLK => SCLK2,
	TOUT => TOUT2,
	TIN => TIN2,
	TCLK => TCLK2,
	FOUT => FOUT2,
	FIN => FIN2,
	SOUT => SOUT2,
	SIN => SIN2,
	FHRCLK_SHRCLK => FHRCLK_SHRCLK2,
	ACQUIRE => ACQUIRE2,
	nTF => nTF2clked,
	nTS => nTS2clked,
	CLF => CLF2,
	CLS => CLS2
);

-- Assemble bits into vectors
diagnostic_bug_notifications <= diagnostic_full_rena1_settings(100 downto 71); ---- HACK!!!!!!!!!!!
diagnostic_full_rena1_settings
   <= "000000000000000000000000000000000000" & "000000000000000000000000000000000000" & diagnostic_rena1_settings
     & or_mode_trigger1 & force_trigger1 & '0' & enable_readout1 & '0'
     & follower_mode1 & follower_mode2 & follower_mode_chan & follower_mode_tclk;
diagnostic_full_rena2_settings
   <= "000000000000000000000000000000000000" & "000000000000000000000000000000000000" & diagnostic_rena2_settings
     & or_mode_trigger1 & force_trigger1 & '0' & enable_readout1 & '0'            -- redundant, but oh well
     & follower_mode1 & follower_mode2 & follower_mode_chan & follower_mode_tclk; -- redundant, but oh well

DIAGNOSTIC_MESSENGER_MODULE: diagnostic_messenger
	GENERIC MAP(
		num_bug_bits => 30
	)
	PORT MAP (
		clk   => systemClk,
		reset => rst,
		fpga_addr => fpga_address,
		send  => diagnostic_send,
		packet_data    => diagnostic_packet_data,
		packet_data_wr => diagnostic_packet_data_wr,
		packet_fifo_full => diagnostic_packet_fifo_full,
		rena1_settings    => diagnostic_full_rena1_settings,
		rena2_settings    => diagnostic_full_rena2_settings,
		bug_notifications => diagnostic_bug_notifications
	);

end Behavioral;
