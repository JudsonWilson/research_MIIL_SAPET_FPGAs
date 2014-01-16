----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:27:52 11/14/2012 
-- Design Name: 
-- Module Name:    acquisition_module - Behavioral 
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

use work.sapet_packets.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity acquisition_module_tb is
	end acquisition_module_tb;

architecture testbench of acquisition_module_tb is
	signal reset 		: std_logic := '1';
	signal boardid		: std_logic_vector(2 downto 0) := "010";
	signal clk_50MHz	: std_logic := '0';
	signal clk_12MHz	: std_logic := '0';
	signal local_acquisition_data_dout_to_Daisychain_wr : std_logic;
	signal local_acquisition_data_dout_to_Daisychain    : std_logic_vector(15 downto 0);
	signal Rx0		: std_logic;
	signal Rx1		: std_logic;		
		-- signal for input
		signal	parallel_byte			: std_logic_vector(7 downto 0);
		signal data_length_i			: std_logic_vector(15 downto 0);
		type state_machine_value is ( idle, send_start_signal, send_spartan_address, send_data);
		signal parallel_to_serial_state		: state_machine_value := idle;
		signal output_data_i			: std_logic_vector(7 downto 0);
		signal second_channel			: std_logic_vector(7 downto 0);	
		constant DO_ADDRESS_SWAP : boolean := false;
		constant DO_INITIAL_RESET : boolean := true;



	component acquisition_module is
	port(
		reset 					: in std_logic;
		boardid					: in std_logic_vector(2 downto 0);
		clk_50MHz				: in std_logic;
		clk_12MHz				: in std_logic;
		-- Interface with Daisychain
		local_acquisition_data_dout_to_Daisychain_wr : out std_logic;
		local_acquisition_data_dout_to_Daisychain : out std_logic_vector(15 downto 0);
		Rx0					: in std_logic;
		Rx1 					: in std_logic
	);
	end component;
begin 
	Inst_acquisition_module : Acquisition_module
	port map (
								reset 		=> reset,			
                        boardid		=> boardid,			
                        clk_50MHz	=> clk_50MHz,			
                        clk_12MHz	=> clk_12MHz,			
                        -- Interface with Daisychain
                        local_acquisition_data_dout_to_Daisychain_wr => local_acquisition_data_dout_to_Daisychain_wr,
                        local_acquisition_data_dout_to_Daisychain => local_acquisition_data_dout_to_Daisychain,
                        Rx0		=> Rx0,			
                        Rx1 		=> Rx1
		);		
			
	-- Create a clock
	process
	begin
		clk_50MHz <= not clk_50MHz;
		wait for 10ns;
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
	process ( clk_50MHz, reset)
	begin
		if ( reset = '1') then
			parallel_byte <= x"00";
			data_length_i <= x"0000";
			parallel_to_serial_state <= idle;
		elsif ( clk_50MHz'event and clk_50MHz = '1') then
			-- send data module
			case parallel_to_serial_state is
				when idle =>
					Rx0 		<= '1';
					Rx1		<= '1';
					output_data_i   <= packet_start_token_data_AND_mode;
					data_length_i   <= x"0000";
					parallel_to_serial_state <= send_start_signal;
				when send_start_signal =>
				-- {
					case parallel_byte is
					-- start signal packet_start_token_data_AND_mode
						when x"00" =>
							Rx0 <= '0';
							Rx1 <= '0';
							parallel_byte <= parallel_byte + x"01";
						-- LSB 0
						when x"01" =>
							if(( output_data_i and x"01") = x"01") then
								Rx0 <= '1';
								Rx1 <= '1';
							else
								Rx0 <= '0';
								Rx1 <= '0';
							end if;
							parallel_byte <= parallel_byte + x"01";
						-- LSB 1
						when x"02" =>
							if (( output_data_i and x"02") = x"02") then
								Rx0 <= '1';
								Rx1 <= '1';
							else
								Rx0 <= '0';
								Rx1 <= '0';
							end if;
							parallel_byte <= parallel_byte + x"01";
						-- LSB 2
						when x"03" =>
							if (( output_data_i and x"04") = x"04") then
								Rx0 <= '1';
								Rx1 <= '1';
							else
								Rx0 <= '0';
								Rx1 <= '0';
							end if;
							parallel_byte <= parallel_byte + x"01";
						-- LSB 3
						when x"04" =>
							if (( output_data_i and x"08") = x"08") then
								Rx0 <= '1';
								Rx1 <= '1';
							else
								Rx0 <= '0';
								Rx1 <= '0';
							end if;
							parallel_byte <= parallel_byte + x"01";
						-- LSB 4
						when x"05" =>
							if (( output_data_i and x"10") = x"10") then
								Rx0 <= '1';
								Rx1 <= '1';
							else
								Rx0 <= '0';
								Rx1 <= '0';
							end if;
							parallel_byte <= parallel_byte + x"01";
						-- LSB 5
						when x"06" =>
							if (( output_data_i and x"20") = x"20") then
								Rx0 <= '1';
								Rx1 <= '1';
							else
								Rx0 <= '0';
								Rx1 <= '0';
							end if;
							parallel_byte <= parallel_byte + x"01";
						-- LSB 6
						when x"07" =>
							if (( output_data_i and x"40") = x"40") then
								Rx0 <= '1';
								Rx1 <= '1';
							else
								Rx0 <= '0';
								Rx1 <= '0';
							end if;
							parallel_byte <= parallel_byte + x"01";
						-- LSB 7
						when x"08" =>
							if (( output_data_i and x"80") = x"80") then
								Rx0 <= '1';
								Rx1 <= '1';
							else
								Rx0 <= '0';
								Rx1 <= '0';
							end if;
							parallel_byte <= parallel_byte + x"01";
							data_length_i <= data_length_i + x"01";
						when others =>
							Rx0 <= '1';
							Rx1 <= '1';
							parallel_byte <= x"00";
							-- spartan address
							output_data_i <= x"1a";
							second_channel <= x"21";
							parallel_to_serial_state <= send_spartan_address;
					end case;
				-- }
				when send_spartan_address =>
				-- {
					case parallel_byte is
					-- send spartan address
						when x"00" =>
							Rx0 <= '0';
							Rx1 <= '0';
							parallel_byte <= parallel_byte + x"01";
						-- LSB 0
						when x"01" =>
							if(( output_data_i and x"01") = x"01") then
								Rx0 <= '1';
							else
								Rx0 <= '0';
							end if;
							if (( second_channel and x"01") = x"01") then
								Rx1 <= '1';
							else
								Rx1 <= '0';
							end if;
							parallel_byte <= parallel_byte + x"01";
						-- LSB 1
						when x"02" =>
							if (( output_data_i and x"02") = x"02") then
								Rx0 <= '1';
							else
								Rx0 <= '0';
							end if;
							if (( second_channel and x"02") = x"02") then
								Rx1 <= '1';
							else
								Rx1 <= '0';
							end if;
							parallel_byte <= parallel_byte + x"01";
						-- LSB 2
						when x"03" =>
							if (( output_data_i and x"04") = x"04") then
								Rx0 <= '1';
							else
								Rx0 <= '0';
							end if;
							if (( second_channel and x"04") = x"04") then
								Rx1 <= '1';
							else
								Rx1 <= '0';
							end if;
							parallel_byte <= parallel_byte + x"01";
						-- LSB 3
						when x"04" =>
							if (( output_data_i and x"08") = x"08") then
								Rx0 <= '1';
							else
								Rx0 <= '0';
							end if;
							if (( second_channel and x"08") = x"08") then
								Rx1 <= '1';
							else
								Rx1 <= '0';
							end if;
							parallel_byte <= parallel_byte + x"01";
						-- LSB 4
						when x"05" =>
							if (( output_data_i and x"10") = x"10") then
								Rx0 <= '1';
							else
								Rx0 <= '0';
							end if;
							if (( second_channel and x"10") = x"10") then
								Rx1 <= '1';
							else
								Rx1 <= '0';
							end if;
							parallel_byte <= parallel_byte + x"01";
						-- LSB 5
						when x"06" =>
							if (( output_data_i and x"20") = x"20") then
								Rx0 <= '1';
							else
								Rx0 <= '0';
							end if;
							if (( second_channel and x"20") = x"20") then
								Rx1 <= '1';
							else
								Rx1 <= '0';
							end if;
							parallel_byte <= parallel_byte + x"01";
						-- LSB 6
						when x"07" =>
							if (( output_data_i and x"40") = x"40") then
								Rx0 <= '1';
							else
								Rx0 <= '0';
							end if;
							if (( second_channel and x"40") = x"40") then
								Rx1 <= '1';
							else
								Rx1 <= '0';
							end if;
							parallel_byte <= parallel_byte + x"01";
						-- LSB 7
						when x"08" =>
							if (( output_data_i and x"80") = x"80") then
								Rx0 <= '1';
							else
								Rx0 <= '0';
							end if;
							if (( second_channel and x"80") = x"80") then
								Rx1 <= '1';
							else
								Rx1 <= '0';
							end if;
							parallel_byte <= parallel_byte + x"01";
							data_length_i <= data_length_i + x"01";
						when others =>
							Rx0 <= '1';
							Rx1 <= '1';
							parallel_byte <= x"00";
							output_data_i <= x"20";
							second_channel <= x"7F";
							parallel_to_serial_state <= send_data;
					end case;
				when send_data =>
					case parallel_byte is
					-- send spartan address
						when x"00" =>
							Rx0 <= '0';
							Rx1 <= '0';
							parallel_byte <= parallel_byte + x"01";
						-- LSB 0
						when x"01" =>
							if(( output_data_i and x"01") = x"01") then
								Rx0 <= '1';
							else
								Rx0 <= '0';
							end if;
							if (( second_channel and x"01") = x"01") then
								Rx1 <= '1';
							else
								Rx1 <= '0';
							end if;
							parallel_byte <= parallel_byte + x"01";
						-- LSB 1
						when x"02" =>
							if (( output_data_i and x"02") = x"02") then
								Rx0 <= '1';
							else
								Rx0 <= '0';
							end if;
							if (( second_channel and x"02") = x"02") then
								Rx1 <= '1';
							else
								Rx1 <= '0';
							end if;
							parallel_byte <= parallel_byte + x"01";
						-- LSB 2
						when x"03" =>
							if (( output_data_i and x"04") = x"04") then
								Rx0 <= '1';
							else
								Rx0 <= '0';
							end if;
							if (( second_channel and x"04") = x"04") then
								Rx1 <= '1';
							else
								Rx1 <= '0';
							end if;
							parallel_byte <= parallel_byte + x"01";
						-- LSB 3
						when x"04" =>
							if (( output_data_i and x"08") = x"08") then
								Rx0 <= '1';
							else
								Rx0 <= '0';
							end if;
							if (( second_channel and x"08") = x"08") then
								Rx1 <= '1';
							else
								Rx1 <= '0';
							end if;
							parallel_byte <= parallel_byte + x"01";
						-- LSB 4
						when x"05" =>
							if (( output_data_i and x"10") = x"10") then
								Rx0 <= '1';
							else
								Rx0 <= '0';
							end if;
							if (( second_channel and x"10") = x"10") then
								Rx1 <= '1';
							else
								Rx1 <= '0';
							end if;
							parallel_byte <= parallel_byte + x"01";
						-- LSB 5
						when x"06" =>
							if (( output_data_i and x"20") = x"20") then
								Rx0 <= '1';
							else
								Rx0 <= '0';
							end if;
							if (( second_channel and x"20") = x"20") then
								Rx1 <= '1';
							else
								Rx1 <= '0';
							end if;
							parallel_byte <= parallel_byte + x"01";
						-- LSB 6
						when x"07" =>
							if (( output_data_i and x"40") = x"40") then
								Rx0 <= '1';
							else
								Rx0 <= '0';
							end if;
							if (( second_channel and x"40") = x"40") then
								Rx1 <= '1';
							else
								Rx1 <= '0';
							end if;
							parallel_byte <= parallel_byte + x"01";
						-- LSB 7
						when x"08" =>
							if (( output_data_i and x"80") = x"80") then
								Rx0 <= '1';
							else
								Rx0 <= '0';
							end if;
							if (( second_channel and x"80") = x"80") then
								Rx1 <= '1';
							else
								Rx1 <= '0';
							end if;
							parallel_byte <= parallel_byte + x"01";
							data_length_i <= data_length_i + x"01";
						when others =>
							if ( data_length_i < x"71") then
								-- output_data_i <= output_data_i + x"01";
								output_data_i <= output_data_i;
								second_channel <= second_channel - x"01";
							elsif ( data_length_i = x"71") then
								output_data_i <= x"FF";
								second_channel <= x"FF";
							elsif ( data_length_i > x"71") then
								output_data_i <= x"00";
								second_channel <= x"7F";
								parallel_to_serial_state <= idle;
							end if;
							parallel_byte <= x"00";
							Rx0 <= '1';
							Rx1 <= '1';
						end case;
			end case;
		end if;
	end process;
end testbench;
