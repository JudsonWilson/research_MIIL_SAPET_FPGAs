--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   14:31:10 02/24/2014
-- Design Name:   
-- Module Name:   C:/Users/Judson/Desktop/research/repo-multiboard/Backplane_FPGA/05_acquisition/acquisition_module/input_choosers/input_chooser_N_sources_testbench.vhd
-- Project Name:  BrdCfg_48RENA_50MHzSMA
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: input_chooser_N_sources
--
-- I only use this to make an instance of the tree and check for the correct
-- instantiate of the recursive hardware in the simulator. I don't actually
-- run the simulations.
--    -- Judson Wilson
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
use work.input_chooser_N_sources_package.all;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY input_chooser_N_sources_testbench IS
END input_chooser_N_sources_testbench;
 
ARCHITECTURE behavior OF input_chooser_N_sources_testbench IS 
 
	constant N : positive := 9;
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT input_chooser_N_sources
	 GENERIC (N : positive);
    PORT(
         reset : IN  std_logic;
         clk : IN  std_logic;
         din_rd_en : OUT  std_logic_vector(N-1 downto 0);
         din_packet_available : IN  std_logic_vector(N-1 downto 0);
         din_empty_notready : IN  std_logic_vector(N-1 downto 0);
         din : in  multi_bus_16_bit(N-1 downto 0);
         din_end_of_packet : IN  std_logic_vector(N-1 downto 0);
         dout_rd_en : IN  std_logic;
         dout_packet_available : OUT  std_logic;
         dout_empty_notready : OUT  std_logic;
         dout : OUT  std_logic_vector(15 downto 0);
         dout_end_of_packet : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal reset : std_logic := '0';
   signal clk : std_logic := '0';
   signal din_packet_available : std_logic_vector(N-1 downto 0) := (others => '0');
   signal din_empty_notready : std_logic_vector(N-1 downto 0) := (others => '0');
   signal din : multi_bus_16_bit(N-1 downto 0) := (others => x"0000");
   signal din_end_of_packet : std_logic_vector(N-1 downto 0) := (others => '0');
   signal dout_rd_en : std_logic := '0';

 	--Outputs
   signal din_rd_en : std_logic_vector(N-1 downto 0);
   signal dout_packet_available : std_logic;
   signal dout_empty_notready : std_logic;
   signal dout : std_logic_vector(15 downto 0);
   signal dout_end_of_packet : std_logic;

   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: input_chooser_N_sources 
			GENERIC MAP (N => N)
			PORT MAP (
          reset => reset,
          clk => clk,
          din_rd_en => din_rd_en,
          din_packet_available => din_packet_available,
          din_empty_notready => din_empty_notready,
          din => din,
          din_end_of_packet => din_end_of_packet,
          dout_rd_en => dout_rd_en,
          dout_packet_available => dout_packet_available,
          dout_empty_notready => dout_empty_notready,
          dout => dout,
          dout_end_of_packet => dout_end_of_packet
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 100 ns;	

      wait for clk_period*10;

      -- insert stimulus here 

      wait;
   end process;

END;
