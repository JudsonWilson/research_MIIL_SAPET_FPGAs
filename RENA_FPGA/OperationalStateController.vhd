----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:38:18 03/01/2009 
-- Design Name: 
-- Module Name:    OperationalStateController - Behavioral 
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
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_ARITH.ALL;
use IEEE.std_logic_UNSIGNED.ALL;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
-- library UNISIM;
-- use UNISIM.VComponents.all;

entity OperationalStateController is
Port (
	-- Basic signals
	-- TO DO: remove debug ports in final implementation
	debugOut           : out std_logic_vector(3 downto 0);
	mclk 	             : in std_logic;
	reset              : in std_logic;
	
	-- Configuration
	CHIP_ID            : in std_logic;
	FPGA_ADDR          : in std_logic_vector(5 downto 0);
	ANODE_MASK         : in std_logic_vector(35 downto 0);
	CATHODE_MASK       : in std_logic_vector(35 downto 0);
	
	-- Readout settings
	ENABLE             : in std_logic; -- Arms the FPGA to wait for RENA-3 triggers
	OR_MODE_TRIGGER    : in std_logic;
	FORCE_TRIGGER      : in std_logic;
	FOLLOWER_MODE      : in std_logic;
	FOLLOWER_MODE_CHAN : in std_logic_vector(5 downto 0);
	FOLLOWER_MODE_TCLK : in std_logic_vector(1 downto 0);
	SELECTIVE_READ     : in std_logic;
	COINCIDENCE_READ   : in std_logic;
	ANODE_TRIG_IN      : in std_logic;
	ANODE_TRIG_OUT     : out std_logic;
	CATHODE_TRIG_IN    : in std_logic;
	CATHODE_TRIG_OUT   : out std_logic;
	I_READ             : out std_logic;
	U_TRIG             : in std_logic;
	
	-- Data transmit
	TX_BUSY            : in std_logic;
	TX_DATA            : out std_logic_vector(7 downto 0);
	SEND_TX_DATA       : out std_logic; -- One shot signal indicating there's data to send
	
	SLOW_TIMESTAMP     : in std_logic_vector(41 downto 0);

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

	-- Unused
	-- OVERFLOW           : in std_logic
	);
end OperationalStateController;

--========================================================================
-- Readout modes:
-- If multiple readout modes are selected, the order of precedence is as
-- follows (1 being the highest priority):
-- 1. Follower mode (Ignores Readout Enable)
-- 2. Readout enable (Necessary for Force Trigger and OR modes)
-- 3. Force Trigger mode
-- 4. OR mode (Ignored if Force Trigger mode is also on)
--
-- Readout state machine: remains in IDLE state is the follower state
--     machine is running.
-- Send data logic: runs only if the next state is
--     WRITE_HIT_REGISTER_CLK_HI. If the follower mode is on, that state
--     will never be reached, hence no data would be sent.
-- RENA-3 signals: Follower mode has its own case statement for most of
--     the signals, while OR and Force Trigger modes is in the same scope,
--     so the follower mode and the latter two modes are mutually
--     exclusive.
--========================================================================

architecture Behavioral of OperationalStateController is

--========================================================================
-- State definitions for state machines
--========================================================================

-- See page 25 of RENA-3_MB_FPGA_20060907.pdf
-- States for peak-detect mode readout
type state_type is (
	 IDLE,
    CLS_CLF,
    TRAP,
	 WAIT_TRIGGER,
	 ACQ_TEMP,
	 ACQUISITION_DELAY,
	 READ_HIT_REGISTER_CLK_LO,
	 READ_HIT_REGISTER_CLK_HI,
	 WRITE_HIT_REGISTER_CLK_HI,
	 WRITE_HIT_REGISTER_CLK_LO,
	 TIN_HI,
	 nCS_HI,
	 SCLK_HI,
	 SCLK_LO,
	 TX_STOP,
	 WAIT_TX_BUSY
    );

-- States for follower mode readout
type follower_state_type is (
    IDLE,
	 CLS_CLF,
	 WRITE_HIT_REGISTER_CLK_HI,
	 WRITE_HIT_REGISTER_CLK_LO,
	 RAISE_TIN,
	 TOGGLE_TCLK1_HI,
	 TOGGLE_TCLK1_LO,
	 TOGGLE_TCLK2_HI,
	 TOGGLE_TCLK2_LO,
	 TOGGLE_TCLK3_HI,
	 HOLD,
	 FLUSH_HIT_REGISTER_CLK_HI,
	 FLUSH_HIT_REGISTER_CLK_LO
    );

--========================================================================
-- Signal declarations
--========================================================================

	-- Internal coarse time stamp. Can't just use the input as it takes
	-- multiple clock cycles to process the timestamp.
	signal coarse_timestamp_reg  : std_logic_vector(41 downto 0); 
	signal next_coarse_timestamp : std_logic_vector(41 downto 0);

	-- State machine signals
	-- RENA data readout FSM
	signal state                 : state_type := IDLE;
	signal next_state            : state_type := IDLE;
	-- Used to index fast/slow trigger list as they are shifted out.
	signal read_counter          : std_logic_vector(7 downto 0) := "00000000"; 
	signal next_read_counter     : std_logic_vector(7 downto 0) := "00000000";	
	-- Generic FSM timing counter.
	signal counter               : std_logic_vector(10 downto 0) := "00000000000";
	signal next_counter          : std_logic_vector(10 downto 0) := "00000000000";
	
	-- RENA follower mode FSM
	signal state_out                   : std_logic_vector(3 downto 0);
	signal next_state_out              : std_logic_vector(3 downto 0);
	signal follower_state_out          : std_logic_vector(3 downto 0);
	signal next_follower_state_out     : std_logic_vector(3 downto 0);
	signal follower_state              : follower_state_type := IDLE;
	signal next_follower_state         : follower_state_type := IDLE;
	-- Counts clock edges in establishing follower mode.
	signal follower_counter            : std_logic_vector(5 downto 0);
	signal next_follower_counter       : std_logic_vector(5 downto 0);
	-- Keeps track of which channel is in follower mode
	signal follower_mode_chan_reg      : std_logic_vector(5 downto 0);
	signal next_follower_mode_chan_reg : std_logic_vector(5 downto 0);

	-- Shaper reset
	signal next_CLF      : std_logic;
	signal next_CLS      : std_logic;
	
	-- Readout token
	signal next_TIN      : std_logic;
	signal int_TCLK      : std_logic;
	signal next_int_TCLK : std_logic;
	
	-- ADC
	-- AD7276 has 12-bit resolution
	signal adc_data      : std_logic_vector(5 downto 0);
	signal next_adc_data : std_logic_vector(5 downto 0);
	signal next_nCS      : std_logic; --ADC chip select
	signal next_SCLK     : std_logic; --ADC clock
	
	-- Data transmit
	signal previous_SEND_TX_DATA : std_logic;
	signal next_SEND_TX_DATA     : std_logic;
	signal send_tx_data_one_shot : std_logic;
	signal next_TX_DATA          : std_logic_vector(7 downto 0);
	signal TX_DATA_reg           : std_logic_vector(7 downto 0);				

	-- Acquire
	signal next_ACQUIRE     : std_logic;	
	-- signal next_READ_SIG    : std_logic;
	
	-- Trigger
	signal previous_nTF                : std_logic;
	signal valid_AND_mode_trigger      : std_logic;
	signal next_valid_AND_mode_trigger : std_logic;

	-- Read/write list
	signal int_FIN          : std_logic;
	signal int_SIN          : std_logic;
	signal next_int_FIN     : std_logic;
	signal next_int_SIN     : std_logic;
	signal next_SHR_FHR_CLK : std_logic;
	signal SHR_FHR_CLK      : std_logic;		
	
	-- List of triggered channels
	signal fast_triggered      : std_logic_vector(35 downto 0) := "000000000000000000000000000000000000";
	signal next_fast_triggered : std_logic_vector(35 downto 0) := "000000000000000000000000000000000000";	
	signal slow_triggered      : std_logic_vector(35 downto 0) := "000000000000000000000000000000000000";
	signal next_slow_triggered : std_logic_vector(35 downto 0) := "000000000000000000000000000000000000";
	
	-- Selective read signals
	signal int_ANODE_TRIG_OUT       : std_logic;
	signal int_CATHODE_TRIG_OUT     : std_logic;
	signal next_ANODE_TRIG_OUT      : std_logic;
	signal next_CATHODE_TRIG_OUT    : std_logic;
	signal int_anode_trig_out_raw   : std_logic;
	signal int_cathode_trig_out_raw : std_logic;
	signal anodes_triggered         : std_logic_vector(35 downto 0);
	signal fast_anodes_triggered    : std_logic_vector(35 downto 0);
	signal slow_anodes_triggered    : std_logic_vector(35 downto 0);
	signal cathodes_triggered       : std_logic_vector(35 downto 0);
	signal fast_cathodes_triggered  : std_logic_vector(35 downto 0);
	signal slow_cathodes_triggered  : std_logic_vector(35 downto 0);
	signal int_IREAD                : std_logic;
	
--========================================================================
-- Module body
--========================================================================
begin

-- Debug
debugOut <= state_out;
-- debugOut <= follower_state_out;

--========================================================================
-- Miscellaneous connections
--========================================================================
FHRCLK_SHRCLK <= SHR_FHR_CLK; --POTENTIAL GLITCH--PDO
next_valid_AND_mode_trigger <= '0' when (fast_triggered = (fast_triggered'range => '0')) else '1';

--========================================================================
-- Selective read signals
--========================================================================
ANODE_TRIG_OUT   <= int_ANODE_TRIG_OUT;
CATHODE_TRIG_OUT <= int_CATHODE_TRIG_OUT;
I_READ <= int_IREAD;

process (fast_triggered, slow_triggered, FORCE_TRIGGER, OR_MODE_TRIGGER, ANODE_MASK, CATHODE_MASK)
begin
	fast_anodes_triggered <= ANODE_MASK and fast_triggered;
	slow_anodes_triggered <= ANODE_MASK and slow_triggered;

	fast_cathodes_triggered <= CATHODE_MASK and fast_triggered;
	slow_cathodes_triggered <= CATHODE_MASK and slow_triggered;

	if ((FORCE_TRIGGER = '0') and (OR_MODE_TRIGGER = '1')) then
		anodes_triggered   <= fast_anodes_triggered or slow_anodes_triggered;
		cathodes_triggered <= fast_cathodes_triggered or slow_cathodes_triggered;
	else
		anodes_triggered   <= fast_anodes_triggered and slow_anodes_triggered;
		cathodes_triggered <= fast_cathodes_triggered and slow_cathodes_triggered;
	end if;
end process;

int_anode_trig_out_raw   <= '0' when (anodes_triggered = (anodes_triggered'range => '0')) else '1';
int_cathode_trig_out_raw <= '0' when (cathodes_triggered = (cathodes_triggered'range => '0')) else '1';

process (int_anode_trig_out_raw, int_cathode_trig_out_raw, next_state, next_read_counter)
begin
	if ((int_anode_trig_out_raw = '1') and (next_state = READ_HIT_REGISTER_CLK_LO) and (next_read_counter > 35)) then
		next_ANODE_TRIG_OUT <= '1';
	else
		next_ANODE_TRIG_OUT <= '0';
	end if;
	
	if ((int_cathode_trig_out_raw = '1') and (next_state = READ_HIT_REGISTER_CLK_LO) and (next_read_counter > 35)) then
		next_CATHODE_TRIG_OUT <= '1';
	else
		next_CATHODE_TRIG_OUT <= '0';
	end if;
end process;

process (int_ANODE_TRIG_OUT, ANODE_TRIG_IN, int_CATHODE_TRIG_OUT, CATHODE_TRIG_IN, COINCIDENCE_READ, U_TRIG)
begin
	if (COINCIDENCE_READ = '0') then
		int_IREAD <= (int_ANODE_TRIG_OUT or ANODE_TRIG_IN) and (int_CATHODE_TRIG_OUT or CATHODE_TRIG_IN);
	else
		int_IREAD <= (int_ANODE_TRIG_OUT or ANODE_TRIG_IN) and (int_CATHODE_TRIG_OUT or CATHODE_TRIG_IN) and U_TRIG;
	end if;
end process;

--========================================================================
-- This portion of code sets up a one-shot reg for the send data signal
-- into the FIFO buffer.
-- This means next_SEND_TX_DATA needs to be lowered after each high for
-- data to be sent, i.e.   _
--                      __| |__________________
--       instead of        ____________________
--                      __|
--========================================================================
TX_DATA <= TX_DATA_reg;
FIN     <= int_FIN;
SIN     <= int_SIN;
TCLK    <= int_TCLK;

process(mclk)
begin
	if rising_edge(mclk) then
		previous_SEND_TX_DATA <= next_SEND_TX_DATA;		
		SEND_TX_DATA <= send_tx_data_one_shot;
		
		-- TX_DATA_reg is a stand-in for TX_DATA
		TX_DATA_reg <= next_TX_DATA;
	end if;
end process;

process(previous_SEND_TX_DATA, next_SEND_TX_DATA)
begin
	if previous_SEND_TX_DATA = '0' and next_SEND_TX_DATA = '1' then
		send_tx_data_one_shot <= '1';
	else
		send_tx_data_one_shot <= '0';
end if;
end process;

--========================================================================
-- MAIN D FLIP FLOP FOR SEQUENTIAL LOGIC
--========================================================================
process(mclk)
begin
	if rising_edge(mclk) then
		-- Time stamp
		coarse_timestamp_reg <= next_coarse_timestamp;
		
		-- Readout state machine
		state     <= next_state;
		state_out <= next_state_out;
		counter   <= next_counter;
		read_counter <= next_read_counter;
		
		-- Follower state machine
		follower_state     <= next_follower_state;
		follower_counter   <= next_follower_counter;
		follower_state_out <= next_follower_state_out;
		follower_mode_chan_reg <= next_follower_mode_chan_reg;

		-- Shaper reset
		CLF <= next_CLF;
		CLS <= next_CLS;
		
		-- Trigger
		previous_nTF <= nTF;

		-- Data acquire
		ACQUIRE  <= next_ACQUIRE;
		-- READ_SIG <= next_READ_SIG;

		-- Read/write hit list
		int_FIN <= next_int_FIN;
		int_SIN <= next_int_SIN;
		fast_triggered <= next_fast_triggered;
		slow_triggered <= next_slow_triggered;
		SHR_FHR_CLK <= next_SHR_FHR_CLK;
		valid_AND_mode_trigger <= next_valid_AND_mode_trigger;
		
		-- ADC
		nCS  <= next_nCS;
		SCLK <= next_SCLK;
		adc_data <= next_adc_data;

		-- Token
		TIN  <= next_TIN;
		int_TCLK <= next_int_TCLK;
		
		-- Selective readout mode
		int_ANODE_TRIG_OUT   <= next_ANODE_TRIG_OUT;
		int_CATHODE_TRIG_OUT <= next_CATHODE_TRIG_OUT;
	end if;
end process;

--========================================================================
-- COARSE TIME STAMP
--========================================================================
-- next_coarse_timestamp either preserves its value, or latches onto a new
-- value if there has been a fast trigger.
process(state, nTF, SLOW_TIMESTAMP, previous_nTF, coarse_timestamp_reg, FORCE_TRIGGER)
begin
	if state = WAIT_TRIGGER and ((previous_nTF = '1' and nTF = '0') or FORCE_TRIGGER = '1') then
		next_coarse_timestamp <= SLOW_TIMESTAMP;
	else
		next_coarse_timestamp <= coarse_timestamp_reg;
	end if;
end process;

--========================================================================
-- DATA PACKET FORMATION LOGIC
--========================================================================
process(next_state, coarse_timestamp_reg, adc_data, next_read_counter,
		  counter, CHIP_ID, FPGA_ADDR, fast_triggered, FORCE_TRIGGER,
		  OR_MODE_TRIGGER, slow_triggered)
begin
	-- IMPORTANT: we start sending data in the write hit register state, we
	-- cannot start any sooner because up to this point, triggers can still
	-- result in no readout being performed.
	
	-- We know the counter counts from 35 so we can use this time to set up
	-- the packet start
	
	-- state_out = "0111" for WRITE_HIT_REGISTER_CLK_HI
	if next_state = WRITE_HIT_REGISTER_CLK_HI then
		case next_read_counter is
			-- Byte 0: special character for packet start.
			-- Decimal 35
			when "00100011" =>
				-- The first byte used to always be 0x80
				if ((FORCE_TRIGGER = '0') and (OR_MODE_TRIGGER = '1')) then
					-- Packet start byte 0x82 indicating OR mode readout
					next_TX_DATA <= "10000010"; --start transmission
					next_SEND_TX_DATA <= '1';
				else
					-- Packet start byte 0x81 indicating AND mode readout
					next_TX_DATA <= "10000001";
					next_SEND_TX_DATA <= '1';
				end if;
				
			-- Bytes 1 and 2 are inserted by the daisy chain
			
			-- Byte 3: board and rena number
			-- Decimal 34
			when "00100010" =>
				-- Header with RENA-3 ID and FPGA ID
				next_TX_DATA <= "0" & FPGA_ADDR & CHIP_ID;
				next_SEND_TX_DATA <= '1';
				
			-- Bytes 4-9: coarse time stamp.
			-- Decimal 33
			when "00100001" =>
				-- 6 bytes of coarse time stamp
				next_TX_DATA <= "0" & coarse_timestamp_reg(41 downto 35);
				next_SEND_TX_DATA <= '1';
			-- Decimal 32
			when "00100000" => 
				next_TX_DATA <= "0" & coarse_timestamp_reg(34 downto 28);
				next_SEND_TX_DATA <= '1';
			-- Decimal 31
			when "00011111" =>
				next_TX_DATA <= "0" & coarse_timestamp_reg(27 downto 21);
				next_SEND_TX_DATA <= '1';
			-- Decimal 30
			when "00011110" =>
				next_TX_DATA <= "0" & coarse_timestamp_reg(20 downto 14);
				next_SEND_TX_DATA <= '1';
			-- Decimal 29
			when "00011101" => 
				next_TX_DATA <= "0" & coarse_timestamp_reg(13 downto 7);
				next_SEND_TX_DATA <= '1';
			-- Decimal 28
			when "00011100" =>
				next_TX_DATA <= "0" & coarse_timestamp_reg(6 downto 0);
				next_SEND_TX_DATA <= '1';
				
			-- Bytes 10-15: fast trigger list.
			-- Decimal 27
			when "00011011" =>
				-- 6 bytes of one-hot trigger data that covers all 36 channels
				next_TX_DATA <= "00" & fast_triggered(35 downto 30);
				next_SEND_TX_DATA <= '1';
			-- Decimal 26
			when "00011010" =>
				next_TX_DATA <= "00" & fast_triggered(29 downto 24);
				next_SEND_TX_DATA <= '1';
			-- Decimal 25
			when "00011001" =>
				next_TX_DATA <= "00" & fast_triggered(23 downto 18);
				next_SEND_TX_DATA <= '1';
			-- Decimal 24
			when "00011000" =>
				next_TX_DATA <= "00" & fast_triggered(17 downto 12);
				next_SEND_TX_DATA <= '1';
			-- Decimal 23
			when "00010111" =>
				next_TX_DATA <= "00" & fast_triggered(11 downto 6);
				next_SEND_TX_DATA <= '1';
			-- Decimal 22
			when "00010110" =>
				next_TX_DATA <= "00" & fast_triggered(5 downto 0);
				next_SEND_TX_DATA <= '1';
				
			-- Bytes 16-21: slow trigger list in OR mode.
			-- Decimal 21
			when "00010101" =>
				if ((FORCE_TRIGGER = '0') and (OR_MODE_TRIGGER = '1')) then
					next_TX_DATA <= "00" & slow_triggered(35 downto 30);
					next_SEND_TX_DATA <= '1';
				else
					next_TX_DATA <= "00000000";
					next_SEND_TX_DATA <= '0';
				end if;
			-- Decimal 20
			when "00010100" =>
				if ((FORCE_TRIGGER = '0') and (OR_MODE_TRIGGER = '1')) then
					next_TX_DATA <= "00" & slow_triggered(29 downto 24);
					next_SEND_TX_DATA <= '1';
				else
					next_TX_DATA <= "00000000";
					next_SEND_TX_DATA <= '0';
				end if;
			-- Decimal 19
			when "00010011" =>
				if ((FORCE_TRIGGER = '0') and (OR_MODE_TRIGGER = '1')) then
					next_TX_DATA <= "00" & slow_triggered(23 downto 18);
					next_SEND_TX_DATA <= '1';
				else
					next_TX_DATA <= "00000000";
					next_SEND_TX_DATA <= '0';
				end if;
			-- Decimal 18
			when "00010010" =>
				if ((FORCE_TRIGGER = '0') and (OR_MODE_TRIGGER = '1')) then
					next_TX_DATA <= "00" & slow_triggered(17 downto 12);
					next_SEND_TX_DATA <= '1';
				else
					next_TX_DATA <= "00000000";
					next_SEND_TX_DATA <= '0';
				end if;
			-- Decimal 17
			when "00010001" =>
				if ((FORCE_TRIGGER = '0') and (OR_MODE_TRIGGER = '1')) then
					next_TX_DATA <= "00" & slow_triggered(11 downto 6);
					next_SEND_TX_DATA <= '1';
				else
					next_TX_DATA <= "00000000";
					next_SEND_TX_DATA <= '0';
				end if;
			-- Decimal 16
			when "00010000" =>
				if ((FORCE_TRIGGER = '0') and (OR_MODE_TRIGGER = '1')) then
					next_TX_DATA <= "00" & slow_triggered(5 downto 0);
					next_SEND_TX_DATA <= '1';
				else
					next_TX_DATA <= "00000000";
					next_SEND_TX_DATA <= '0';
				end if;
			when others =>
				next_TX_DATA <= "00000000";
				next_SEND_TX_DATA <= '0';
		end case;

	-- ADC bytes.
	-- state_out = "1100" for SCLK_HI
	elsif next_state = SCLK_HI then  --TCLK_HI
		case counter is
			-- Send most significant 6 bits the on 8th edge of SCLK. This
			-- includes 2 SCLK cycles for the leading 00 from AD7276.
			-- First PHA packet
			when "00000001000" =>
				next_TX_DATA <= "00" & adc_data(5 downto 0);
				next_SEND_TX_DATA <= '1';
			-- Send least significant 6 bits on the 14th edge of SCLK.
			-- Second PHA packet.
			when "00000001110" =>
				next_TX_DATA <= "00" & adc_data(5 downto 0);
				next_SEND_TX_DATA <= '1';
			when others =>
				next_TX_DATA <= "00000000";
				next_SEND_TX_DATA <= '0';
			end case;
			
	-- Last byte.
	-- state_out == "1101" for TX_STOP
	elsif next_state = TX_STOP then
		-- Packet termination byte 0xFF (used to always be 0x81)
		next_TX_DATA <= "11111111"; --end transmission
		next_SEND_TX_DATA <= '1';		
	else
		next_TX_DATA <= "00000000";
		next_SEND_TX_DATA <= '0';
	end if;
end process;

--========================================================================
-- Check if we should go ahead with read
--any_fast_triggered <= '0' when (fast_triggered = (fast_triggered'range => '0')) else '1';
--any_slow_triggered <= '0' when (slow_triggered = (slow_triggered'range => '0')) else '1';
--next_do_read <= any_fast_triggered or any_slow_triggered;

--========================================================================
-- READOUT SIGNAL BEHAVIOR BLOCK.
-- 
-- This block defines the signal behavior for each state i.e. the actual
-- signal assignments, which is not done in the readout state machine.
--========================================================================
process(next_state, state, next_counter, SDO, adc_data, state,  counter,
		  read_counter, next_read_counter, FORCE_TRIGGER, int_FIN, int_SIN,
		  fast_triggered, slow_triggered, FOUT, SOUT, int_TCLK, OR_MODE_TRIGGER, 
		  next_follower_state, FOLLOWER_MODE, FOLLOWER_MODE_CHAN,
		  FOLLOWER_MODE_TCLK, follower_counter)
begin

	--=====================================================================
	-- Toggle SHR_FHR_CLK (same as SHRCLK on pages 18 and 24 of NOVA RENA-3
	-- FPGA Design Document).
	-- 
	-- Follower mode
	if (FOLLOWER_MODE = '1') then
		if (next_follower_state = WRITE_HIT_REGISTER_CLK_HI) or (next_follower_state = FLUSH_HIT_REGISTER_CLK_HI) then
			next_SHR_FHR_CLK <= '1';
		else
			next_SHR_FHR_CLK <= '0';
		end if;
	-- Peak-detect mode
	else
		-- Do not assert SHR_FHR_CLK when we just emerged from READ_HIT_REGISTER_CLK_LO	
		if ((next_state = WRITE_HIT_REGISTER_CLK_HI) and (state /= READ_HIT_REGISTER_CLK_LO)) or
		   (next_state = READ_HIT_REGISTER_CLK_HI) or (next_follower_state = FLUSH_HIT_REGISTER_CLK_HI) then
			next_SHR_FHR_CLK <= '1';
		else
			next_SHR_FHR_CLK <= '0';
		end if;
	end if;
	
	--=====================================================================
	-- Read channel trigger list.
	-- 
	-- Along with toggling between READ_HIT_REGISTER_CLK_HI and
	-- READ_HIT_REGISTER_CLK_LO in the state machine, this reads/shifts
	-- the 36-bit channel tirgger list from the RENA.
	--
	-- Note: in terms of bit order, data for channel 35 is shifted in
	-- first and that for channel 0 is shifted out last.
	-- In the current implementation, the two sets of triggers should be
	-- equal.
	if (next_state = READ_HIT_REGISTER_CLK_HI) then
		-- OR mode trigger, i.e. readout if either the slow or fast channel
		-- triggers
		if ((FORCE_TRIGGER = '0') and (OR_MODE_TRIGGER = '1')) then
			next_fast_triggered <= fast_triggered(34 downto 0) & FOUT;
			next_slow_triggered <= slow_triggered(34 downto 0) & SOUT;
		-- AND mode trigger, i.e. readout if both the slow and fast channels
		-- trigger
		else
			next_fast_triggered <= fast_triggered(34 downto 0) & (FOUT and SOUT);
			next_slow_triggered <= slow_triggered(34 downto 0) & (FOUT and SOUT);
		end if;
	else
			next_fast_triggered <= fast_triggered;
			next_slow_triggered <= slow_triggered;
	end if;
	
	--=====================================================================
	-- Write channel readout list.
	-- 
	-- Along with toggling between WRITE_HIT_REGISTER_CLK_HI and
	-- WRITE_HIT_REGISTER_CLK_LO in the state machine, this writes/shifts
	-- the 36-bit channel readout list into the RENA.
	-- 
	-- Note: in terms of bit order, data for channel 35 is shifted out
	-- first and that for channel 0 is shifted out last (see pg 21 of
	-- RENA-3 IC User Specifications).
	-- 
	-- Follower mode
	if (FOLLOWER_MODE = '1') then
		next_int_FIN <= '0';
		if ((next_follower_state = WRITE_HIT_REGISTER_CLK_LO) or (next_follower_state = WRITE_HIT_REGISTER_CLK_HI)) and
		   (follower_counter = FOLLOWER_MODE_CHAN + 1) then
			next_int_SIN <= '1';
		else
			next_int_SIN <= '0';
		end if;
	-- Peak-detect mode
	else
		-- Change this code to modify how we want to read out channels.
		if (next_state = WRITE_HIT_REGISTER_CLK_LO) or (next_state = WRITE_HIT_REGISTER_CLK_HI) then
			-- Use the following lines to read out only the channels that
			-- triggered. Also, we do not read channels 0, 1, 34 and 35.
			-- Push out the MSB first, read_counter counts up from 0.
			if (FORCE_TRIGGER = '0') then
				next_int_FIN <= fast_triggered(conv_integer(read_counter));
				next_int_SIN <= slow_triggered(conv_integer(read_counter));
			else
				next_int_FIN <= '1';
				next_int_SIN <= '1';
			end if;
		else  
			next_int_FIN <= int_FIN;
			next_int_SIN <= int_SIN;
		end if;
	end if;

	--=====================================================================	
	-- ACQUIRE arms the RENA
	-- Follower mode
	if (FOLLOWER_MODE = '1') then
		if (next_follower_state = CLS_CLF) or (next_follower_state = WRITE_HIT_REGISTER_CLK_HI) or
		   (next_follower_state = WRITE_HIT_REGISTER_CLK_LO) or (next_follower_state = RAISE_TIN) or
		   (next_follower_state = TOGGLE_TCLK1_HI) or (next_follower_state = TOGGLE_TCLK1_LO) or
			(next_follower_state = TOGGLE_TCLK2_HI) or (next_follower_state = TOGGLE_TCLK2_LO) or
			(next_follower_state = TOGGLE_TCLK3_HI) or (next_follower_state = HOLD) then
			next_ACQUIRE <= '1';
		else
			next_ACQUIRE <= '0';
		end if;
	-- Peak-detect mode
	else
		-- Asserted during arming of the RENA, refer to page 24 of
		-- NOVA RENA-3 FPGA Design Document
		if (next_state = IDLE) or (next_state = CLS_CLF) or (next_state = TRAP) or 
			(next_state = WAIT_TRIGGER) or (next_state = ACQ_TEMP) or 
			(next_state = ACQUISITION_DELAY) then
			next_ACQUIRE <= '1';
		else
			next_ACQUIRE <= '0';
		end if;
	end if;
	
	--=====================================================================
	-- CLS and CLF signals clear the peak detect circuitry
	-- Follower mode
	if (FOLLOWER_MODE = '1') then
		if (next_follower_state = CLS_CLF) then
			next_CLS <= '1';
			next_CLF <= '1';
		else
			next_CLS <= '0';
			next_CLF <= '0';
		end if;
	-- Peak-detect mode
	else
		-- The CLS and CLF signals resets the sample and hold circuit, asserted
		-- only in the CLS_CLF state.
		if (next_state = CLS_CLF) then
			next_CLF <= '1';
			next_CLS <= '1';
		else
			next_CLF <= '0';
			next_CLS <= '0';
		end if;
	end if;

	--=====================================================================
	-- TIN
	-- 
	-- Enables the AOUT for readout, but also the token bit of each RENA.
	-- If there are multiple RENA's the TOUT of one RENA should be
	-- connected to the TIN of the next RENA. While the TIN of a RENA is
	-- high, TCLK should be toggled to shift out data via the AOUT, once
	-- all the data are shifted out, the RENA's TOUT automatically asserts.
	--
	-- As soon as TIN and READ are asserted, AOUT is made available for
	-- readout once it's settled (333 ns wait min.). A new AOUT is shifted
	-- out on every positive edge of TCLK, such that the second item (PHA,
	-- U or V) on AOUT is made available on the 1st TCLK positive edge, the
	-- third item on the 2nd edge and so on. To read n items, we need just
	-- n-1 TCLK edges because the first item is available by default after
	-- READ is asserted. However we do need an n-th TCLK positive edge to
	-- make TOUT go high, so a total of n TCLK cycles are still needed.
	--
	-- Follower mode
	if (FOLLOWER_MODE = '1') then
		if (next_follower_state = RAISE_TIN) or (next_follower_state = TOGGLE_TCLK1_HI) or
		   (next_follower_state = TOGGLE_TCLK1_LO) or (next_follower_state = TOGGLE_TCLK2_HI) or
		   (next_follower_state = TOGGLE_TCLK2_LO) or (next_follower_state = TOGGLE_TCLK3_HI) or
			(next_follower_state = HOLD) then
			next_TIN <= '1';
		else
			next_TIN <= '0';
		end if;
	-- Peak-detect mode
	else
		if (next_state = TIN_HI) or (next_state = nCS_HI) or(next_state = SCLK_HI) or (next_state = SCLK_LO) then
			next_TIN <= '1';
		else
			next_TIN <= '0';
		end if;
	end if;
	
--	--=====================================================================
--	-- Turns out AOUT needs to be enabled earlier than the signaling
--	-- specification indicates to allow sufficient time for the AOUT bus
--	-- inside the RENA-3 to charge up. So assert it during trigger list
--	-- read.
--	--
--	-- Follower mode
--	if (FOLLOWER_MODE = '1') then
--		if (next_follower_state = WRITE_HIT_REGISTER_CLK_HI) or (next_follower_state = WRITE_HIT_REGISTER_CLK_LO) or
--		   (next_follower_state = RAISE_TIN) or (next_follower_state = TOGGLE_TCLK1_HI) or
--			(next_follower_state = TOGGLE_TCLK1_LO) or (next_follower_state = TOGGLE_TCLK2_HI) or
--			(next_follower_state = TOGGLE_TCLK2_LO) or (next_follower_state = TOGGLE_TCLK3_HI) or
--			(next_follower_state = HOLD) then
--			next_READ_SIG <= '1';
--		else
--			next_READ_SIG <= '0';
--		end if;
--	-- Peak-detect mode
--	else
--		next_READ_SIG <= '1';
--	end if;

	--=====================================================================
	-- Token clock, data is shifted out via AOUT on every clock edge and
	-- should be latched on the rising edges.
	--
	-- Follower mode
	if (FOLLOWER_MODE = '1') then
		if ((next_follower_state = TOGGLE_TCLK1_HI) and ((FOLLOWER_MODE_TCLK(0) = '1') or (FOLLOWER_MODE_TCLK(1) = '1'))) or
		   ((next_follower_state = TOGGLE_TCLK2_HI) and (FOLLOWER_MODE_TCLK(1) = '1')) or
			((next_follower_state = TOGGLE_TCLK3_HI) and (FOLLOWER_MODE_TCLK(1 downto 0) = "11")) then
			next_int_TCLK <= '1';
		else
			next_int_TCLK <= '0';
		end if;
	-- Peak-detect mode
	else
		if (next_state = SCLK_HI) and (next_counter = "00000000001") then
			next_int_TCLK <= '1';
		elsif ((next_state = SCLK_HI) or (next_state = SCLK_LO)) and (next_counter = "00000001000") then
			next_int_TCLK <= '0';
		else
			next_int_TCLK <= int_TCLK;
		end if;
	end if;
	
	--=====================================================================
	-- ADC clock.
	if (next_state = SCLK_LO) or (next_state = nCS_HI) then
		next_SCLK <= '0';
	else
		next_SCLK <= '1';
	end if;
	
	--=====================================================================
	-- ADC chip select. Note that this signal is NOT toggled, but held low
	-- for the duration of the data shift.
	if (next_state = SCLK_HI) or (next_state = SCLK_LO) then
		next_nCS <= '0';
	else
		next_nCS <= '1';
	end if;
	
	--=====================================================================
	-- Constructing the 12-bit ADC data as they come in serially. MSB comes in first.
	-- We do not shift on the first and last 2 clock edges because SDO is
	-- just 0s in that time.
	-- Data is clocked out from the AD7276 on negative edges of SCLK, so
	-- it's good to read data out on the positive edge.
	if ((next_state = SCLK_HI) and (next_counter > 1) and (next_counter < 14)) then
			next_adc_data <= adc_data(4 downto 0) & SDO;
	else
			next_adc_data <= adc_data;
	end if;
end process;

--========================================================================
-- ACTUAL READOUT STATE MACHINE
-- 
-- Data readout state machine. This block only degfines the state
-- transitions and not the signal behavior associated with each state,
-- the latter is done is the block above.
--========================================================================
process(reset, state, TOUT, nTF, nTS, counter, TX_BUSY, ENABLE,
		  read_counter, FORCE_TRIGGER, FOLLOWER_MODE,
		  next_follower_state, OR_MODE_TRIGGER, SELECTIVE_READ, int_IREAD,
		  valid_AND_mode_trigger)
begin
  if (reset = '1') or (FOLLOWER_MODE = '1') then
    next_state <= IDLE;
	 next_state_out <= "0000";
	 next_counter <= "00000000000";
	 next_read_counter <= "00000000";
  else
    case state is
	 
      -------------------------------------------------------------------
		-- state_out = "0000"
      when IDLE =>
        if  (ENABLE = '1') and (next_follower_state = IDLE) then
          next_state <= CLS_CLF;
			 next_state_out <= "0001";
			 next_counter <= "00000000000";
			 next_read_counter <= "00000000";
		  else
			 next_state <= IDLE;
			 next_state_out <= "0000";
			 next_counter <= "00000000000";
			 next_read_counter <= "00000000";
        end if;
		  
      -------------------------------------------------------------------
		-- state_out = "0001"
      when CLS_CLF =>
			if counter <= 48 then --1 microsecond at 48 MHz --was 6
				next_counter <= counter + 1;
				next_state <= CLS_CLF;
				next_state_out <= "0001";
			else
				next_counter <= "00000000000";
				next_state <= TRAP;
				next_state_out <= "0010";
         end if;
		   next_read_counter <= "00000000";
		  
      -------------------------------------------------------------------
		-- state_out = "0010"
      when TRAP =>
        if counter <= 48 then   --1 microsecond at 48 MHz
			  -- n Trigger Fast = 0 means trigger occurred within the trap
			  -- time, it might have occurred before CLS and CLF were
			  -- de-asserted, in which case go back to idle state.
			  if (FORCE_TRIGGER = '1') then
				  if (nTF = '1') then
					 next_counter <= counter + 1;
					 next_state <= TRAP;
					 next_state_out <= "0010";
				  else
					 next_counter <= "00000000000";
					 next_state <= IDLE;
					 next_state_out <= "0000";
				  end if;
			  else
			  	  if ((OR_MODE_TRIGGER = '0') and (nTF = '1')) or ((OR_MODE_TRIGGER = '1') and (nTF = '1') and (nTS = '1')) then
					 next_counter <= counter + 1;
					 next_state <= TRAP;
					 next_state_out <= "0010";
				  else
					 next_counter <= "00000000000";
					 next_state <= IDLE;
					 next_state_out <= "0000";
				  end if;
			  end if;
		  else
				next_counter <= "00000000000";
				next_state <= WAIT_TRIGGER;
				next_state_out <= "0011";
		  end if;
		  next_read_counter <= "00000000";			
			
      -------------------------------------------------------------------
		-- state_out = "0011"
      when WAIT_TRIGGER =>
		  -- Check to make sure nothing wrong. every tiny bit second or so, reset if no trigger.
		  -- clear every 20 microseconds, in case a low level below trigger happened.
		  if (counter > 960) then
			 next_counter <= "00000000000";
			 next_state <= IDLE;
			 next_state_out <= "0000";
		  else
		     -- Continue to wait for trigger
			  if (FORCE_TRIGGER = '0') then
					if (((OR_MODE_TRIGGER = '0') and (nTF = '1')) or ((OR_MODE_TRIGGER = '1') and (nTS = '1') and (nTF = '1'))) then
					--if ((nTS = '1') and (nTF = '1')) then
							next_counter <= counter + 1;
							next_state <= WAIT_TRIGGER;
							next_state_out <= "0011";
					else
							next_counter <= "00000000000";
							next_state <= ACQ_TEMP; --ACQUISITION_DELAY;
							next_state_out <= "0100";
					end if;
			  -- Always proceed to readout in force trigger mode
			  else
				 next_counter <= "00000000000";
				 next_state <= ACQ_TEMP; --ACQUISITION_DELAY;
				 next_state_out <= "0100";
			  end if;
		  end if;
		  next_read_counter <= "00000000";		  
		  
		--------------------------------------------------------------------
		-- Why is this state necessary?
		when ACQ_TEMP =>
			next_counter <= "00000000000";
		   next_state <= ACQUISITION_DELAY;
			next_state_out <= "0100";
		   next_read_counter <= "00000000";
			
      --------------------------------------------------------------------
		-- state_out = "0100"
		-- Acquisition delay for different shaping times as recommended by
		-- NOVA is:
		-- Shaping time      | Acquisition delay
		---------------------|-------------------
		-- 0.29 us - 0.40us    1.6 us (77)
		-- 0.71 us, 0.81 us    2.0 us (96)
		-- 0.89 us             2.4 us (115)
		-- 1.1 us              4.4 us (211)
		-- 1.9 us              4.8 us (230)
		-- 2.8 us              7.2 us (346)
		-- 4.5 us              10.8 us (518)
		-- 38 us               100 us (4800 needs 12-bit counter)
      when ACQUISITION_DELAY =>
         --if counter <= 48 then  --1 us
			if counter <= 230 then  --4.8 us
			--if counter <= 346 then  --7.2 us
				next_counter <= counter + 1;
				next_state <= ACQUISITION_DELAY;
				next_state_out <= "0100";
		   else
				next_counter <= "00000000000";
				next_state <= READ_HIT_REGISTER_CLK_LO;
				next_state_out <= "0101";
			end if;
			next_read_counter <= "00000000";
		
	   --------------------------------------------------------------------
      -- The next 2 states toggle the hit-read clocking pin, which toggles
		-- SHR_FHR_CLK and shifts out the register data showing who
		-- triggered.
		-- state_out = "0101"
		when READ_HIT_REGISTER_CLK_LO =>
		   if read_counter <= 35 then
				next_read_counter <= read_counter;
				next_state <= READ_HIT_REGISTER_CLK_HI;
				next_state_out <= "0110";
				next_counter <= "00000000000";
			else
				if (FORCE_TRIGGER = '1') then
					-- Set how many times to toggle read write register clock
					-- 35 because we also toggle on 0, so 36 times in total.
					next_read_counter <= "00100011";
					next_state <= WRITE_HIT_REGISTER_CLK_HI;
					next_state_out <= "0111";
					next_counter <= "00000000000";
				else
					-- Selective read on
					if (SELECTIVE_READ = '1') then
						-- Wait 500 ns max for int_IREAD = '1'
						-- TO DO: reduce the wait to 3 cycles for propagation
						-- delay of the U_Trig signal. We don't need to wait the
						-- full 500 ns electron drift time because we already
						-- accounted for it during the acqusition delay.
						if (counter < 25) then
							-- Keep on waiting
							if (int_IREAD = '0') then
								next_read_counter <= read_counter;
								next_state <= READ_HIT_REGISTER_CLK_LO;
								next_state_out <= "0101";
								next_counter <= counter + 1;
							-- Proceed with readout
							else
								next_read_counter <= "00100011";
								next_state <= WRITE_HIT_REGISTER_CLK_HI;
								next_state_out <= "0111";
								next_counter <= "00000000000";
							end if;
						else
							next_read_counter <= "00000000";
							next_state <= IDLE;
							next_state_out <= "0000";
							next_counter <= "00000000000";
						end if;
					-- Selective read off
					else
						-- OR mode on
						if (OR_MODE_TRIGGER = '1') then
							-- Set how many times to toggle read write register clock
							-- 35 because we also toggle on 0, so 36 times in total.
							next_read_counter <= "00100011";
							next_state <= WRITE_HIT_REGISTER_CLK_HI;
							next_state_out <= "0111";
							next_counter <= "00000000000";
						-- OR mode off
						else
							-- Proceed to readout
							if (valid_AND_mode_trigger = '1') then
								-- Set how many times to toggle read write register clock
								-- 35 because we also toggle on 0, so 36 times in total.
								next_read_counter <= "00100011";
								next_state <= WRITE_HIT_REGISTER_CLK_HI;
								next_state_out <= "0111";
								next_counter <= "00000000000";
							-- No channels to be read. We can end up here if only either
							-- the fast or slow channel of a channel triggered in AND mode.
							else
								next_read_counter <= "00000000";
								next_state <= IDLE;
								next_state_out <= "0000";
								next_counter <= "00000000000";
							end if;
						end if; -- If OR mode
					end if; -- If selective read
				end if; -- If force trigger
			end if; --If still reading
		
		--------------------------------------------------------------------
		-- state_out = "0110"		
		when READ_HIT_REGISTER_CLK_HI =>
				next_counter <= counter;
				next_state <= READ_HIT_REGISTER_CLK_LO;
				next_state_out <= "0101";
				next_read_counter <= read_counter + 1;
      
		--------------------------------------------------------------------
		-- The next 2 states continue to toggle the hit-read clocking pin,
		-- shifting in the register data telling the RENA-3 which channels
		-- you want to read.
		-- 
		-- This state also activates the send data logic, for which the
		-- SEND_TX signal is toggled by this and the next state.
		-- state_out = "0111"
      when WRITE_HIT_REGISTER_CLK_HI =>
		  next_counter <= "00000000000";
		  if read_counter /= 255 then
				next_read_counter <= read_counter;
				next_state <= WRITE_HIT_REGISTER_CLK_LO;
				next_state_out <= "1000";
			else
				next_read_counter <= "00000000";
				next_state <= TIN_HI;
				next_state_out <= "1001";
			end if;

		--------------------------------------------------------------------
		-- state_out = "1000"
		when WRITE_HIT_REGISTER_CLK_LO =>
			next_counter <= "00000000000";
			next_state <= WRITE_HIT_REGISTER_CLK_HI;
			next_state_out <= "0111";
			next_read_counter <= read_counter - 1;
		
		--------------------------------------------------------------------
		-- state_out = "1001"
      when TIN_HI =>
		  -- Asserting TIN enables the AOUT, which takes time to settle.
		  -- On page 21 of RENA-3 IC User Specifications, the minimum
		  -- settling time is stated as 333 ns.
		  -- 
		  -- 500 nanosecond for first TIN stablizing
		  -- also during time period of first data point ADC acquiring
		  if counter <= 24 then
				next_state <= TIN_HI;
				next_state_out <= "1001";
				next_counter <= counter + 1;
				next_read_counter <= "00000000";
			else
				next_state <= nCS_HI;
				next_state_out <= "1010";
				next_counter <= "00000000000";
				next_read_counter <= "00000000";
			end if;

		--------------------------------------------------------------------	
		-- state_out = "1010"		
		when nCS_HI =>    --nCS going LO is end of acquiring
			if counter <= 1 then --4 then  --was 48
				next_counter <= counter + 1;
				next_state <= nCS_HI;
				next_state_out <= "1010";
			else
				next_counter <= "00000000000";
				next_state <= SCLK_LO;
				next_state_out <= "1011";
			end if;
			next_read_counter <= read_counter;
		
		---------------------------------------------------------------------	
		-- This and the next state are traversed for EVERY 12-bit AOUT VALUE
		-- LACTHED BY THE ADC, e.g. once for PHA and twice for UV for each
		-- triggered channel.
		-- 
		-- This may be running at half potential speed.
		-- state_out = "1011"		
		when SCLK_LO =>
			next_state <= SCLK_HI;
			next_state_out <= "1100";
			next_counter <= counter;
			next_read_counter <= read_counter;
		
		---------------------------------------------------------------------
		-- This state activates the send data logic as ADC data comes in.
		-- state_out = "1100"
		when SCLK_HI =>
			-- AD7276 requires 16 SCLK cycles for readout of 12-bit data.
			if counter < 15 then
				next_state <= SCLK_LO;
				next_state_out <= "1011";
				next_counter <= counter + 1;
				next_read_counter <= read_counter;	
			else
			   -- Check TOUT to see if that was last read or if it's been too
				-- long.
				if TOUT = '1' or read_counter > 200 then
				   next_read_counter <= "00000000";
					next_counter <= "00000000000";
					next_state <= TX_STOP;
					next_state_out <= "1101";
				-- Keeping on clocking in data if there is more AOUT values.
				else
					next_state <= nCS_HI;
					next_state_out <= "1010";
					next_counter <= "00000000000";
					next_read_counter <= read_counter + 1;
				end if;
			end if;
		
		-------------------------------------------------------------------
		-- state_out = "1101"
      when TX_STOP =>
			next_state <= WAIT_TX_BUSY;
			next_state_out <= "1110";
			next_counter <= "00000000000";
			next_read_counter <= "00000000";
				
		--------------------------------------------------------------------
		-- state_out = "1110"
		when WAIT_TX_BUSY => 
			if TX_BUSY = '1' then
				next_state <= WAIT_TX_BUSY;
				next_state_out <= "1110";
			else	
				next_state <= IDLE;
				next_state_out <= "0000";
			end if;
			next_counter <= "00000000000";
			next_read_counter <= "00000000";
		
		--------------------------------------------------------------------
		-- state_out = "1111"
      when others =>
			next_state <= IDLE;
			next_state_out <= "1111";
			next_counter <= "00000000000";
			next_read_counter <= "00000000";
		--------------------------------------------------------------------
    end case;
  end if;
end process;

--========================================================================
-- FOLLOWER STATE MACHINE IMPLEMENTATION
--
-- Follower mode state machine. This block defines only the state
-- transitions and not the signal behavior associated with each state,
-- the latter is done is the block above.
--========================================================================
process(reset, follower_state, follower_counter, FOLLOWER_MODE, FOLLOWER_MODE_CHAN, follower_mode_chan_reg)
begin
   if reset = '1' then
      next_follower_state_out <= "0000";
      next_follower_state <= IDLE;
      next_follower_counter <= "000000";
		next_follower_mode_chan_reg <= "000000";
   else
	   case follower_state is
      --------------------------------------------------------------------
      -- follower_state_out = "0000"
      when IDLE =>
         next_follower_state_out <= "0000";
         if  (FOLLOWER_MODE = '1') then
            next_follower_state <= CLS_CLF;
				next_follower_counter <= "001111";
				next_follower_mode_chan_reg <= FOLLOWER_MODE_CHAN;
         else
            next_follower_state <= IDLE;
				next_follower_counter <= "000000";
				next_follower_mode_chan_reg <= follower_mode_chan_reg;
         end if;
	   --------------------------------------------------------------------
      -- follower_state_out = "0001"
      when CLS_CLF =>
         next_follower_state_out <= "0001";
			next_follower_mode_chan_reg <= follower_mode_chan_reg;
			if (follower_counter = 0) then
				next_follower_state <= WRITE_HIT_REGISTER_CLK_HI;
				next_follower_counter <= "100011";
			else
				next_follower_state <= CLS_CLF;
				next_follower_counter <= follower_counter - 1;
			end if;
      --------------------------------------------------------------------
      -- follower_state_out = "0010"
		when WRITE_HIT_REGISTER_CLK_HI =>
		   next_follower_state_out <= "0010";
			next_follower_state <= WRITE_HIT_REGISTER_CLK_LO;
			next_follower_counter <= follower_counter;
			next_follower_mode_chan_reg <= follower_mode_chan_reg;
			
      --------------------------------------------------------------------
      -- follower_state_out = "0011"
		when WRITE_HIT_REGISTER_CLK_LO =>
			next_follower_state_out <= "0011";
			next_follower_mode_chan_reg <= follower_mode_chan_reg;
			if (follower_counter = 0) then
				next_follower_state <= RAISE_TIN;
				next_follower_counter <= "001111";
			else
				next_follower_state <= WRITE_HIT_REGISTER_CLK_HI;
				next_follower_counter <= follower_counter - 1;
			end if;
			
      --------------------------------------------------------------------
      -- follower_state_out = "0100"
		when RAISE_TIN =>
			next_follower_state_out <= "0100";
			next_follower_mode_chan_reg <= follower_mode_chan_reg;
			if (follower_counter = 0) then
				next_follower_state <= TOGGLE_TCLK1_HI;
				next_follower_counter <= "000000";
			else
				next_follower_state <= RAISE_TIN;
				next_follower_counter <= follower_counter - 1;
			end if;
			
      --------------------------------------------------------------------
      -- follower_state_out = "0101"
	 	when TOGGLE_TCLK1_HI =>
	 		next_follower_state_out <= "0101";
			next_follower_state <= TOGGLE_TCLK1_LO;
			next_follower_counter <= "000000";
			next_follower_mode_chan_reg <= follower_mode_chan_reg;
			
      --------------------------------------------------------------------
      -- follower_state_out = "0110"
	 	when TOGGLE_TCLK1_LO =>
	 		next_follower_state_out <= "0110";
			next_follower_state <= TOGGLE_TCLK2_HI;
			next_follower_counter <= "000000";
			next_follower_mode_chan_reg <= follower_mode_chan_reg;
			
      --------------------------------------------------------------------
      -- follower_state_out = "0111"
	 	when TOGGLE_TCLK2_HI =>
	 		next_follower_state_out <= "0111";
			next_follower_state <= TOGGLE_TCLK2_LO;
			next_follower_counter <= "000000";
			next_follower_mode_chan_reg <= follower_mode_chan_reg;
			
      --------------------------------------------------------------------
      -- follower_state_out = "1000"
	 	when TOGGLE_TCLK2_LO =>
	 		next_follower_state_out <= "1000";
			next_follower_state <= TOGGLE_TCLK3_HI;
			next_follower_counter <= "000000";
			next_follower_mode_chan_reg <= follower_mode_chan_reg;
			
      --------------------------------------------------------------------
      -- follower_state_out = "1001"
	 	when TOGGLE_TCLK3_HI =>
	 		next_follower_state_out <= "1001";
			next_follower_state <= HOLD;
			next_follower_counter <= "000000";
			next_follower_mode_chan_reg <= follower_mode_chan_reg;
			
      --------------------------------------------------------------------
      -- follower_state_out = "1010"
		when HOLD =>
			next_follower_state_out <= "1010";
			if (FOLLOWER_MODE = '1') and (follower_mode_chan_reg = FOLLOWER_MODE_CHAN) then
				next_follower_state <= HOLD;
				next_follower_counter <= "000000";
				next_follower_mode_chan_reg <= follower_mode_chan_reg;
			else
				next_follower_state <= FLUSH_HIT_REGISTER_CLK_HI;
				next_follower_counter <= "100011";
				if (FOLLOWER_MODE = '1') then
					next_follower_mode_chan_reg <= FOLLOWER_MODE_CHAN;
				else
					next_follower_mode_chan_reg <= "000000";
				end if;
			end if;
		
      --------------------------------------------------------------------
      -- follower_state_out = "1011"
		when FLUSH_HIT_REGISTER_CLK_HI =>
		   next_follower_state_out <= "1011";
			next_follower_state <= FLUSH_HIT_REGISTER_CLK_LO;
			next_follower_counter <= follower_counter;
			next_follower_mode_chan_reg <= follower_mode_chan_reg;

      --------------------------------------------------------------------
      -- follower_state_out = "1100"
		when FLUSH_HIT_REGISTER_CLK_LO =>
			next_follower_state_out <= "1100";
			next_follower_mode_chan_reg <= follower_mode_chan_reg;
			if (follower_counter = 0) then
				next_follower_state <= IDLE;
				next_follower_counter <= "000000";
			else
				next_follower_state <= FLUSH_HIT_REGISTER_CLK_HI;
				next_follower_counter <= follower_counter - 1;
			end if;
			
      --------------------------------------------------------------------
      -- follower_state_out = "1111"
      when others =>
      	next_follower_state_out <= "1111";
		   next_follower_state <= IDLE;
			next_follower_counter <= "000000";
			next_follower_mode_chan_reg <= "000000";
      end case;
   end if;
end process;

end Behavioral;