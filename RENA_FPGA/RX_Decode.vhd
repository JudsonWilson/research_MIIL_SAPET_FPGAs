----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    19:15:09 06/27/2011 
-- Design Name: 
-- Module Name:    RX_Decode - Behavioral 
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

entity RX_Decode is
    Port (
			  debugOut            : out  STD_LOGIC_VECTOR(2 downto 0);
			  mclk 			       : in   STD_LOGIC;                     -- Clock signal
			  RX_DATA             : in   STD_LOGIC_VECTOR(7 downto 0);  -- Received data byte
           NEW_RX_DATA         : in   STD_LOGIC;                     -- Flag indicating presence of new data
			  FPGA_ADDRESS        : in   STD_LOGIC_VECTOR(5 downto 0);  -- Specifies which FPGA is the intended recipient
           ENABLE_READOUT1     : out  STD_LOGIC;                     -- Starts the RENA-3 readout state machine
			  ENABLE_READOUT2     : out  STD_LOGIC;                     -- Starts the RENA-3 readout state machine
           OR_MODE_TRIGGER1    : out  STD_LOGIC;
			  OR_MODE_TRIGGER2    : out  STD_LOGIC;
			  FORCE_TRIGGERS1     : out  STD_LOGIC;
			  FORCE_TRIGGERS2     : out  STD_LOGIC;
			  SELECTIVE_READ      : out  STD_LOGIC;
			  COINCIDENCE_READ    : out  STD_LOGIC;
			  RESET_TIMESTAMP     : out  STD_LOGIC;
			  FOLLOWER_MODE1      : out  STD_LOGIC;
			  FOLLOWER_MODE2      : out  STD_LOGIC;
			  FOLLOWER_MODE_CHAN  : out  STD_LOGIC_VECTOR(5 downto 0);
			  FOLLOWER_MODE_TCLK  : out  STD_LOGIC_VECTOR(1 downto 0);
           CS1                 : out  STD_LOGIC;  -- RENA-3 1 chip select
           CSHIFT1             : out  STD_LOGIC;  -- RENA-3 1 configuration clock
           CIN1                : out  STD_LOGIC;  -- RENA-3 1 configuration data
           CS2                 : out  STD_LOGIC;  -- RENA-3 2 chip select
           CSHIFT2             : out  STD_LOGIC;  -- RENA-3 2 configuration clock
           CIN2                : out  STD_LOGIC;  -- RENA-3 2 configuration data
			  ANODE_MASK1         : out  STD_LOGIC_VECTOR(35 downto 0);
			  ANODE_MASK2         : out  STD_LOGIC_VECTOR(35 downto 0);
			  CATHODE_MASK1       : out  STD_LOGIC_VECTOR(35 downto 0);
			  CATHODE_MASK2       : out  STD_LOGIC_VECTOR(35 downto 0);
			  DIAGNOSTIC_RENA1_SETTINGS : out  STD_LOGIC_VECTOR(40 downto 0);
			  DIAGNOSTIC_RENA2_SETTINGS : out  STD_LOGIC_VECTOR(40 downto 0);
			  DIAGNOSTIC_SEND     : out  STD_LOGIC
			 );
end RX_Decode;

architecture Behavioral of RX_Decode is
  type buff is array(6 downto 0) of std_logic_vector(5 downto 0);
  
  signal int_fpga_address_reg  : std_logic_vector (5 downto 0);
  signal next_fpga_address_reg : std_logic_vector (5 downto 0);
  
  signal rx_buffer : buff;       -- Buffer of input data that's then sent as a continuous stream
  signal next_rx_buffer : buff;  -- Buffer of input data that's then sent as a continuous stream
  
  signal rx_counter: natural range 0 to 7 := 0;
  signal next_rx_counter: natural range 0 to 7 := 0;
  
  signal int_reset_timestamp  : std_logic;
  signal next_reset_timestamp : std_logic;
  
  signal rena_settings_data      : std_logic_vector(40 downto 0);
  signal next_rena_settings_data : std_logic_vector(40 downto 0);  
  
  signal rena_settings_chip      : std_logic;
  signal next_rena_settings_chip : std_logic;
  
  signal int_selective_read    : std_logic;
  signal next_selective_read   : std_logic;
  
  signal int_coincidence_read  : std_logic;
  signal next_coincidence_read : std_logic;
  
  signal int_or_mode_trigger1  : std_logic;
  signal next_or_mode_trigger1 : std_logic; 
  
  signal int_or_mode_trigger2  : std_logic;
  signal next_or_mode_trigger2 : std_logic; 
  
  signal int_force_triggers1  : std_logic;
  signal next_force_triggers1 : std_logic; 
  
  signal int_force_triggers2  : std_logic;
  signal next_force_triggers2 : std_logic; 
  
  signal int_follower_mode1   : std_logic;
  signal next_follower_mode1  : std_logic;
  
  signal int_follower_mode2   : std_logic;
  signal next_follower_mode2  : std_logic;
  
  signal int_follower_mode_chan  : std_logic_vector(5 downto 0);
  signal next_follower_mode_chan : std_logic_vector(5 downto 0);
  
  signal int_follower_mode_tclk  : std_logic_vector(1 downto 0);
  signal next_follower_mode_tclk : std_logic_vector(1 downto 0);
  
  signal int_enable_readout1   : std_logic;
  signal next_enable_readout1  : std_logic;
  
  signal int_enable_readout2   : std_logic;
  signal next_enable_readout2  : std_logic;
  
  signal int_cs1     : std_logic;
  signal int_cin1    : std_logic;
  signal int_cshift1 : std_logic;
  
  signal next_cs1     : std_logic := '1';
  signal next_cin1    : std_logic;
  signal next_cshift1 : std_logic;  
  
  signal int_cs2     : std_logic := '1';
  signal int_cin2    : std_logic;
  signal int_cshift2 : std_logic;
  
  signal next_cs2     : std_logic;
  signal next_cin2    : std_logic;
  signal next_cshift2 : std_logic;
  
  signal int_anode_mask1  : std_logic_vector(35 downto 0) := "000000000000000000000000000000000000";
  signal next_anode_mask1 : std_logic_vector(35 downto 0) := "000000000000000000000000000000000000";

  signal int_anode_mask2  : std_logic_vector(35 downto 0) := "000000000000000000000000000000000000";
  signal next_anode_mask2 : std_logic_vector(35 downto 0) := "000000000000000000000000000000000000";
  
  signal int_cathode_mask1  : std_logic_vector(35 downto 0) := "000000000000000000000000000000000000";
  signal next_cathode_mask1 : std_logic_vector(35 downto 0) := "000000000000000000000000000000000000";
  
  signal int_cathode_mask2  : std_logic_vector(35 downto 0) := "000000000000000000000000000000000000";
  signal next_cathode_mask2 : std_logic_vector(35 downto 0) := "000000000000000000000000000000000000";
  
  signal int_diagnostic_rena1_settings  : std_logic_vector(40 downto 0) := "00000000000000000000000000000000000000000";
  signal next_diagnostic_rena1_settings : std_logic_vector(40 downto 0) := "00000000000000000000000000000000000000000";
  signal int_diagnostic_rena2_settings  : std_logic_vector(40 downto 0) := "00000000000000000000000000000000000000000";
  signal next_diagnostic_rena2_settings : std_logic_vector(40 downto 0) := "00000000000000000000000000000000000000000";

  signal int_diagnostic_send : std_logic := '0';
  signal diagnostic_send_next : std_logic := '0';

  signal sync_new_data  : std_logic;
  signal sync_ms_bits   : std_logic_vector(1 downto 0);
  signal sync_fpga_instr_bits : std_logic_vector(5 downto 0);
  signal sync_rena_instr_bits : std_logic_vector(3 downto 0);
  signal sync_data_bits : std_logic_vector(5 downto 0);
  
  signal ccount : natural range 0 to 41 := 0;
  signal next_ccount : natural range 0 to 41 := 0;

  type state_type is (
   IDLE,
	PREP_FOR_TX,
	PREPARE_DATA,
	SEND_DATA,
	CS_HIGH
    );

  signal cstate: state_type := IDLE;
  signal next_cstate : state_type := IDLE;
  
  signal cstate_out : std_logic_vector(2 downto 0);
  signal next_cstate_out : std_logic_vector(2 downto 0);
begin

debugOut <= cstate_out;

RESET_TIMESTAMP <= int_reset_timestamp;
OR_MODE_TRIGGER1 <= int_or_mode_trigger1;
OR_MODE_TRIGGER2 <= int_or_mode_trigger2;
FORCE_TRIGGERS1  <= int_force_triggers1;
FORCE_TRIGGERS2  <= int_force_triggers2;
ENABLE_READOUT1  <= int_enable_readout1;
ENABLE_READOUT2  <= int_enable_readout2;
SELECTIVE_READ   <= int_selective_read;
COINCIDENCE_READ <= int_coincidence_read;
FOLLOWER_MODE1   <= int_follower_mode1;
FOLLOWER_MODE2   <= int_follower_mode2;
FOLLOWER_MODE_CHAN <= int_follower_mode_chan;
FOLLOWER_MODE_TCLK <= int_follower_mode_tclk;
ANODE_MASK1   <= int_anode_mask1;
ANODE_MASK2   <= int_anode_mask2;
CATHODE_MASK1 <= int_cathode_mask1;
CATHODE_MASK2 <= int_cathode_mask2;
DIAGNOSTIC_RENA1_SETTINGS <= int_diagnostic_rena1_settings;
DIAGNOSTIC_RENA2_SETTINGS <= int_diagnostic_rena2_settings;
DIAGNOSTIC_SEND <= int_diagnostic_send;
		
--========================================================================
-- Sequential logic
--========================================================================
process(mclk)
 begin
   -- D flip-flop to keep everything synchronized
	if rising_edge(mclk) then
		sync_new_data <= NEW_RX_DATA;
		sync_ms_bits <= RX_DATA(7 downto 6);
  		sync_fpga_instr_bits <= RX_DATA(5 downto 0);
  		sync_rena_instr_bits <= RX_DATA(3 downto 0);
  		sync_data_bits <= RX_DATA(5 downto 0);
		
		rx_counter <= next_rx_counter;
		rx_buffer <= next_rx_buffer;
		int_fpga_address_reg <= next_fpga_address_reg;
		int_reset_timestamp <= next_reset_timestamp;
		
		rena_settings_data <= next_rena_settings_data;
		rena_settings_chip <= next_rena_settings_chip;
		
		int_or_mode_trigger1   <= next_or_mode_trigger1;
		int_or_mode_trigger2   <= next_or_mode_trigger2;
		int_force_triggers1    <= next_force_triggers1;
		int_force_triggers2    <= next_force_triggers2;
		int_enable_readout1    <= next_enable_readout1;
		int_enable_readout2    <= next_enable_readout2;
		int_follower_mode1     <= next_follower_mode1;
		int_follower_mode2     <= next_follower_mode2;
		int_follower_mode_chan <= next_follower_mode_chan;
		int_follower_mode_tclk <= next_follower_mode_tclk;
		int_selective_read     <= next_selective_read;
		int_coincidence_read   <= next_coincidence_read;
		
		int_anode_mask1 <= next_anode_mask1;
		int_anode_mask2 <= next_anode_mask2;
		int_cathode_mask1 <= next_cathode_mask1;
		int_cathode_mask2 <= next_cathode_mask2;

		int_diagnostic_rena1_settings <= next_diagnostic_rena1_settings;
		int_diagnostic_rena2_settings <= next_diagnostic_rena2_settings;

		int_diagnostic_send <= diagnostic_send_next;
	end if;
end process;

--========================================================================
-- Combinational logic
--========================================================================
process( sync_new_data, sync_ms_bits, sync_fpga_instr_bits, sync_rena_instr_bits, sync_data_bits,
			rx_counter, rx_buffer, rena_settings_data,
			rena_settings_chip, FPGA_ADDRESS, int_or_mode_trigger1, int_or_mode_trigger2,
			int_force_triggers1, int_force_triggers2, int_fpga_address_reg,
			int_enable_readout1,	int_enable_readout2,
			int_follower_mode1, int_follower_mode2, int_follower_mode_chan, int_follower_mode_tclk,
			int_selective_read, int_coincidence_read,
			int_anode_mask1, int_anode_mask2,
			int_cathode_mask1, int_cathode_mask2)
  begin
      next_rx_counter <= rx_counter;
	   next_rx_buffer <= rx_buffer;
		next_fpga_address_reg <= int_fpga_address_reg;
		next_reset_timestamp <= '0';
		
		next_rena_settings_data <= rena_settings_data;
		next_rena_settings_chip <= rena_settings_chip;
		
		next_or_mode_trigger1 <= int_or_mode_trigger1;
		next_or_mode_trigger2 <= int_or_mode_trigger2;
		next_force_triggers1 <= int_force_triggers1;
		next_force_triggers2 <= int_force_triggers2;
		next_enable_readout1  <= int_enable_readout1;
		next_enable_readout2  <= int_enable_readout2;
		next_follower_mode1  <= int_follower_mode1;
		next_follower_mode2  <= int_follower_mode2;
		next_follower_mode_chan <= int_follower_mode_chan;
		next_follower_mode_tclk <= int_follower_mode_tclk;
		next_selective_read     <= int_selective_read;
		next_coincidence_read   <= int_coincidence_read;
		
		next_anode_mask1 <= int_anode_mask1;
		next_anode_mask2 <= int_anode_mask2;
		next_cathode_mask1 <= int_cathode_mask1;
		next_cathode_mask2 <= int_cathode_mask2;
		
		next_diagnostic_rena1_settings <= int_diagnostic_rena1_settings;
		next_diagnostic_rena2_settings <= int_diagnostic_rena2_settings;

		diagnostic_send_next <= '0'; -- A state will pulse this for 1 cycle.
		
		if (sync_new_data = '1') then
		
			case (sync_ms_bits) is
				-- Check the 2 MSB
				when "00" =>
					-- Buffer RX_DATA (configuration data) into 42 bit storage.
					if (rx_counter < 7) then
						next_rx_counter <= rx_counter + 1;
						next_rx_buffer(rx_counter) <= sync_data_bits;
					end if;
				
				-- Check the 2 MSB
				-- This should happen after data buffering
				when "01" =>
					if (int_fpga_address_reg = FPGA_ADDRESS) then

						case (sync_rena_instr_bits) is
							-- Anode masks
							when "0000" =>
								if (rx_buffer(6)(0) = '0') then
									-- Apply RENA 1 anode mask
									-- Bit 5 of rx_buffer(5) corresponds to channel 35, bit 0 of rx_buffer(0) corresponds to channel 0
									next_anode_mask1 <= rx_buffer(5) & rx_buffer(4) & rx_buffer(3) & rx_buffer(2) & rx_buffer(1) & rx_buffer(0);
								else
									-- Apply RENA 2 anode mask
									-- Bit 5 of rx_buffer(5) corresponds to channel 35, bit 0 of rx_buffer(0) corresponds to channel 0
									next_anode_mask2 <= rx_buffer(5) & rx_buffer(4) & rx_buffer(3) & rx_buffer(2) & rx_buffer(1) & rx_buffer(0);
								end if;
							
							-- Cathode masks
							when "0001" =>
								if (rx_buffer(6)(0) = '0') then
									-- Apply RENA 1 cathode mask
									-- Bit 5 of rx_buffer(5) corresponds to channel 35, bit 0 of rx_buffer(0) corresponds to channel 0
									next_cathode_mask1 <= rx_buffer(5) & rx_buffer(4) & rx_buffer(3) & rx_buffer(2) & rx_buffer(1) & rx_buffer(0);
								else
									-- Apply RENA 2 cathode mask
									-- Bit 5 of rx_buffer(5) corresponds to channel 35, bit 0 of rx_buffer(0) corresponds to channel 0
									next_cathode_mask2 <= rx_buffer(5) & rx_buffer(4) & rx_buffer(3) & rx_buffer(2) & rx_buffer(1) & rx_buffer(0);
								end if;
								
							-- Configure RENAs
							when "0101" =>
								next_rena_settings_data <= rx_buffer(6)(4 downto 0) & rx_buffer(5) & rx_buffer(4) & rx_buffer(3) & rx_buffer(2) & rx_buffer(1) & rx_buffer(0);
								next_rena_settings_chip	<= rx_buffer(6)(5);
								-- would be nice to do the following with synchronous outputs, but would require a lot more FFs.
								if rx_buffer(6)(5) = '0' then
									next_diagnostic_rena1_settings <= rx_buffer(6)(4 downto 0) & rx_buffer(5) & rx_buffer(4) & rx_buffer(3) & rx_buffer(2) & rx_buffer(1) & rx_buffer(0);
								else
									next_diagnostic_rena2_settings <= rx_buffer(6)(4 downto 0) & rx_buffer(5) & rx_buffer(4) & rx_buffer(3) & rx_buffer(2) & rx_buffer(1) & rx_buffer(0);
								end if;
							-- OR mode trigger
							when "0110" =>
								next_or_mode_trigger1 <= rx_buffer(0)(0);
								next_or_mode_trigger2 <= rx_buffer(0)(1);
								
							-- Force trigger
							when "0111" =>
								next_force_triggers1 <= rx_buffer(0)(0);
								next_force_triggers2 <= rx_buffer(0)(1);
								
							-- Selective read
							when "1000" =>
								next_selective_read <= rx_buffer(0)(0);
							
							-- Read enable
							when "1001" =>
								next_enable_readout1 <= rx_buffer(0)(0);
								next_enable_readout2 <= rx_buffer(0)(1);
								
							-- Coincidence read
							when "1010" =>
								next_coincidence_read <= rx_buffer(0)(0);
								
							-- Follower mode
							when "1101" =>
								case (rx_buffer(0)(5 downto 0)) is
									-- Turn follower_mode on
									when "000000" =>
										-- RENA follower mode line
										next_follower_mode1 <= rx_buffer(0)(0);
										next_follower_mode2 <= rx_buffer(0)(1);
										-- Which channel in follower mode
										next_follower_mode_chan <= rx_buffer(1);
										-- How many times to toggle tclk
										next_follower_mode_tclk <= rx_buffer(2)(1 downto 0);
									
									-- Turn follower_mode on
									when "000001" =>
										-- RENA follower mode line
										next_follower_mode1 <= rx_buffer(0)(0);
										next_follower_mode2 <= rx_buffer(0)(1);
										-- Which channel in follower mode
										next_follower_mode_chan <= rx_buffer(1);
										-- How many times to toggle tclk
										next_follower_mode_tclk <= rx_buffer(2)(1 downto 0);
										
									-- Turn follower_mode on
									when "000010" =>
										-- RENA follower mode line
										next_follower_mode1 <= rx_buffer(0)(0);
										next_follower_mode2 <= rx_buffer(0)(1);
										-- Which channel in follower mode
										next_follower_mode_chan <= rx_buffer(1);
										-- How many times to toggle tclk
										next_follower_mode_tclk <= rx_buffer(2)(1 downto 0);

									-- Turn follower_mode on
									when "000011" =>
										-- RENA follower mode line
										next_follower_mode1 <= rx_buffer(0)(0);
										next_follower_mode2 <= rx_buffer(0)(1);
										-- Which channel in follower mode
										next_follower_mode_chan <= rx_buffer(1);
										-- How many times to toggle tclk
										next_follower_mode_tclk <= rx_buffer(2)(1 downto 0);
										
									-- Turn follower_mode off
									when "111111" =>
										next_follower_mode1 <= '0';
										next_follower_mode2 <= '0';
										next_follower_mode_chan <= "111111";
										next_follower_mode_tclk <= "00";
										
									when others =>
										next_follower_mode1 <= '0';
										next_follower_mode2 <= '0';
										next_follower_mode_chan <= "111111";
										next_follower_mode_tclk <= "00";
								end case;

							-- Send diagnostic message back to PC.
							when "1110" =>
								diagnostic_send_next <= '1';

							when others =>
								null;
						end case;
					end if;

				-- Check the 2 MSB
				when "10" =>
					case (sync_fpga_instr_bits) is
						-- Command 0b1000 0000: reset coarse timestamp
						when "000000" =>
							next_reset_timestamp <= '1';
							
						-- Start transmission
						-- 0b1000 0001 (0x81)
						-- Special character indicating beginning of data packet.
						-- ALSO
						-- Command to reset buffer index to 0
						when "000001" =>
							next_rx_counter <= 0;
							next_rx_buffer <= rx_buffer;
							
						-- 0b1000 0010 (0x82)
						-- Special character indicating beginning of data packet in OR
						-- mode readout.
						when "000010" =>
							null;
						
						-- 0b1000 0011 (0x83)
						-- Command to latch value of FPGA address field in packet
						when "000011" =>
							next_rx_counter <= 0;
							next_fpga_address_reg <= rx_buffer(0);
							
						when others =>
							null;
					end case;
				
				-- Check the 2 MSB
				-- 0b1111 1111
				-- Special character indication end of data packet.
				when "11" =>
					null;
				when others =>
					null;
			end case;
		end if;
end process;


CS1 <= int_cs1;
CSHIFT1 <= int_cshift1;
CIN1 <= int_cin1;
CS2 <= int_cs2;
CSHIFT2 <= int_cshift2;
CIN2 <= int_cin2;


process( mclk )
 begin
	if rising_edge(mclk) then
		cstate <= next_cstate;
		ccount <= next_ccount;
		cstate_out <= next_cstate_out;
		
		int_cs1 <= next_cs1;
		int_cin1 <= next_cin1;
		int_cshift1 <= next_cshift1;
		int_cs2 <= next_cs2;
		int_cin2 <= next_cin2;
		int_cshift2 <= next_cshift2;
	end if;
end process;

process( cstate, sync_new_data, sync_ms_bits, sync_rena_instr_bits, rx_buffer, ccount,  rena_settings_chip, rena_settings_data,int_cs1,int_cin1,int_cshift1,
						int_cs2,int_cin2,int_cshift2, FPGA_ADDRESS, int_fpga_address_reg, cstate_out )
  begin
		next_cs1 <= int_cs1;
		next_cin1 <= int_cin1;
		next_cshift1 <= int_cshift1;
		next_cs2 <= int_cs2;
		next_cin2 <= int_cin2;
		next_cshift2 <= int_cshift2;
		next_cstate <= cstate;
		next_ccount <= ccount;
		next_cstate_out <= cstate_out;
    
	  -- Configuration state machine
     case cstate is
		 when IDLE =>
			next_cs1 <= '1'; -- Used to be 0
			next_cin1 <= '0';
			next_cshift1 <= '0';
			
			next_cs2 <= '1'; -- Used to be 0
			next_cin2 <= '0';
			next_cshift2 <= '0';
			
			next_ccount <= 40;
			
			if (sync_new_data = '1') and (sync_ms_bits(0) = '1') and (int_fpga_address_reg = FPGA_ADDRESS) and ( sync_rena_instr_bits = "0101" ) then
				next_cstate <= PREP_FOR_TX;
				next_cstate_out <= "001";
			else
				next_cstate <= IDLE;
				next_cstate_out <= "000";
			end if;
			
		 when PREP_FOR_TX => 
			next_cstate <= PREPARE_DATA;
			next_cstate_out <= "010";
			next_ccount <= 41;

		 -- CIN is latched on the rising edge of CSHIFT (page 24 of RENA-3 IC User Specifications)
		 when PREPARE_DATA =>
			if (ccount > 0 ) then
				if (rena_settings_chip = '0') then
					next_cin1 <= rena_settings_data(ccount - 1);
					next_cshift1 <= '0';
					next_cs1 <= '0';
				else
					next_cin2 <= rena_settings_data(ccount - 1);
					next_cshift2 <= '0';
					next_cs2 <= '0';
				end if;
				
				next_ccount <= ccount - 1;
				next_cstate <= SEND_DATA;
				next_cstate_out <= "011";
			else
				if (rena_settings_chip = '0') then
					next_cshift1 <= '0';
					next_cs1 <= '0';
				else
					next_cshift2 <= '0';
					next_cs2 <= '0';
				end if;
				
				next_cstate <= CS_HIGH;
				next_cstate_out <= "100";
			end if;

		 when SEND_DATA =>
			if (rena_settings_chip = '0') then
					next_cshift1 <= '1';
				else
					next_cshift2 <= '1';
				end if;
				
				next_cstate <= PREPARE_DATA;
				next_cstate_out <= "010";
				
		 when CS_HIGH => 	
			if (rena_settings_chip = '0') then
					next_cs1 <= '1';
					next_cshift1 <= '0';
				else
					next_cs2 <= '1';
					next_cshift2 <= '0';
				end if;
				
				next_cstate <= IDLE;
				next_cstate_out <= "000";
			
		when others =>
			 next_cstate <= IDLE;
			 next_cstate_out <= "000";

	  end case;
end process;

end Behavioral;
