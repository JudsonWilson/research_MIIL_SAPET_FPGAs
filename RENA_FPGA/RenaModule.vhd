----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    09:08:13 01/12/2010 
-- Design Name: 
-- Module Name:    RenaModule - Behavioral 
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
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity RenaModule is
    Port (  
				mclk : in  STD_LOGIC;
				
				--Slow Timestamp
				slow_timestamp : in STD_LOGIC_VECTOR(41 downto 0);
				
				--Coincidence Processing
				I_HAVE_HIT   : out STD_LOGIC;
				YOU_HAVE_HIT : in STD_LOGIC;
				
				--PC communication
				TX : out  STD_LOGIC;

				--ADC
				nCS : out  STD_LOGIC;				
				SDO : in  STD_LOGIC;
				SCLK : out  STD_LOGIC;
		
				--Token for reading
				TIN : out STD_LOGIC;
				TCLK : out  STD_LOGIC;
				TOUT : in  STD_LOGIC;
				
				--Read which triggers hit/Load Channels to read
				FIN : out STD_LOGIC;
				FOUT : in  STD_LOGIC;
				
				SIN : out STD_LOGIC;
				SOUT : in  STD_LOGIC;
				
				FHRCLK_SHRCLK : out STD_LOGIC;
				
				--Triggers, Clear Triggers
				TF : in STD_LOGIC;
				TS : in STD_LOGIC;
				CLF : out  STD_LOGIC;
				CLS : out STD_LOGIC;
				
				--Control signals
				READ_SIG : out  STD_LOGIC;
				ACQUIRE : out STD_LOGIC	;
				
				--Unused
				OVERFLOW : in  STD_LOGIC;
				
				FAST_HIT_PATTERN : in STD_LOGIC_VECTOR(35 downto 0);
				SLOW_HIT_PATTERN : in STD_LOGIC_VECTOR(35 downto 0);
							
				ENABLE_READOUT : in STD_LOGIC; 
				COINCIDENCE_OVERRIDE : in STD_LOGIC;
				FORCE_TRIGGER : in STD_LOGIC;
				READ_TRIGGERS_NOT_TIMESTAMP : in STD_LOGIC;
				
				test1 : out std_logic;
				test2 : out std_logic;
				test3 : out std_logic
			);
end RenaModule;

architecture Behavioral of RenaModule is

  component RS232_tx_buffered
  port(
			  mclk 			: 	in STD_LOGIC;
           data 			: 	in STD_LOGIC_VECTOR (7 downto 0);
           new_data		:  in STD_LOGIC;
           busy 			: 	out STD_LOGIC;
           tx 				: 	out STD_LOGIC
       );
  end component;

	component OperationalStateController is
	Port ( 
					state_out : out std_logic_vector(4 downto 0);
				
					i_have_hit : out std_logic;
					you_have_hit : in std_logic;
				
					force_trigger : in std_logic;
					read_triggers_not_timestamp : in std_logic;	
				
					mclk 	: 	in STD_LOGIC;
					reset : in STD_LOGIC;
					
					ENABLE : in STD_LOGIC;
					TX_BUSY : in STD_LOGIC;
				
					TX_DATA : out STD_LOGIC_VECTOR(7 downto 0);
					SEND_TX_DATA : out STD_LOGIC;
				
				   SLOW_TIMESTAMP : in STD_LOGIC_VECTOR(41 downto 0);
				
					nCS : out STD_LOGIC;			   --ADC chip select
					SDO : in STD_LOGIC;				--ADC Serial data
					SCLK :out STD_LOGIC;				--ADC clock
					
					TOUT : in STD_LOGIC;
					TIN : out STD_LOGIC;
					TCLK : out STD_LOGIC;
					
					FOUT : in STD_LOGIC;
					FIN : out STD_LOGIC;
					
					SOUT : in STD_LOGIC;
					SIN : out STD_LOGIC;
					
					FHRCLK_SHRCLK : out STD_LOGIC;
					
					OVERFLOW : in STD_LOGIC;
				
					READ_SIG : out STD_LOGIC;
					ACQUIRE : out STD_LOGIC;	
					
					nTF : in STD_LOGIC;
					nTS : in STD_LOGIC;
					CLF : out STD_LOGIC;
					CLS : out STD_LOGIC;
				
					SLOW_HIT_PATTERN_IN : in STD_LOGIC_VECTOR(35 downto 0);
					FAST_HIT_PATTERN_IN : in STD_LOGIC_VECTOR(35 downto 0);			
				
					test1 : out std_logic;
					test2 : out std_logic;
					test3 : out std_logic
			);
	end component;
 
	signal data_for_tx : std_logic_vector(7 downto 0);
	signal new_data_for_tx : std_logic;
	signal tx_busy : std_logic;
	
	signal coincidence : std_logic;
begin


	RS232_tx : RS232_tx_buffered port map(
			  mclk => mclk,
           data => data_for_tx,
           new_data => new_data_for_tx,
           busy => tx_busy,
           tx => TX
       );

	coincidence <= COINCIDENCE_OVERRIDE or YOU_HAVE_HIT;
			
	operator : OperationalStateController port map ( 
					state_out => open,
	
					i_have_hit => I_HAVE_HIT,
					you_have_hit => coincidence,
					
					
					force_trigger => FORCE_TRIGGER,
					read_triggers_not_timestamp => READ_TRIGGERS_NOT_TIMESTAMP,
	
					mclk => mclk,
					reset => '0',
					
					ENABLE => ENABLE_READOUT,
					
					TX_BUSY => 	tx_busy,
					TX_DATA => data_for_tx,
					SEND_TX_DATA => new_data_for_tx,
					
					SLOW_TIMESTAMP => slow_timestamp,	
					
					nCS => nCS,
					SDO => SDO,
					SCLK => SCLK,
					
					TOUT => TOUT,
					TIN => TIN,
					TCLK => TCLK,
					
					FOUT => FOUT,
					FIN => FIN,
					
					SOUT => SOUT,
					SIN => SIN,
					
					FHRCLK_SHRCLK => FHRCLK_SHRCLK, 
					
					OVERFLOW => OVERFLOW,
				
					READ_SIG => READ_SIG,
					ACQUIRE => ACQUIRE,
					
					nTF => TF,
					nTS => TS,
					CLF => CLF,
					CLS => CLS,
					
					SLOW_HIT_PATTERN_IN => SLOW_HIT_PATTERN,
					FAST_HIT_PATTERN_IN => FAST_HIT_PATTERN,
				
					test1 => test1,
					test2 => test2,
					test3 => test3
					
			);

end Behavioral;

