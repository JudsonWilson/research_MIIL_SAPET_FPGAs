----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson
--
-- Create Date:    02/22/2014
-- Design Name:
-- Module Name:    input_chooser_N_sources_wrapper
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--    Wraps the input_chooser_N_sources component, because older versions of
-- the VHDL spec do not allow you to instantiate a component in the same file
-- it is declared (recursively). This is needed specifically for the recursion
-- to synthesize.
--
-- Dependencies:
--  - input_chooser_N_sources_package
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

use work.input_chooser_N_sources_package.all;

entity input_chooser_N_sources_wrapper is
	generic (N : positive); -- Number of input ports
	port (
		reset                 : in std_logic;
		clk                   : in std_logic;
		-- Input, Array of Source Ports, as arrays of signals 
		din_rd_en             : out std_logic_vector(N-1 downto 0);
		din_packet_available  : in  std_logic_vector(N-1 downto 0);
		din_empty_notready    : in  std_logic_vector(N-1 downto 0);
		din                   : in  multi_bus_16_bit(N-1 downto 0);
		din_end_of_packet     : in  std_logic_vector(N-1 downto 0);
		-- Output Port
		dout_rd_en            : in  std_logic;
		dout_packet_available : out std_logic; -- Goes to '1' before first word of packet is read, goes to '0' immediately afterwards.
		dout_empty_notready   : out std_logic; -- Indicates the user should not try and read (rd_en). May happen mid-packet! Always check this!
		dout                  : out std_logic_vector(15 downto 0);
		dout_end_of_packet    : out std_logic
	);
end input_chooser_N_sources_wrapper;

architecture Behavioral of input_chooser_N_sources_wrapper is
	attribute keep : string;  
	attribute S: string;

	-- Intermediate signals, to prevent direct port-to-port connections.
	signal reset_i                 : std_logic;
	signal clk_i                   : std_logic;
	signal din_rd_en_i             : std_logic_vector(N-1 downto 0);
	signal din_packet_available_i  : std_logic_vector(N-1 downto 0);
	signal din_empty_notready_i    : std_logic_vector(N-1 downto 0);
	signal din_i                   : multi_bus_16_bit(N-1 downto 0);
	signal din_end_of_packet_i     : std_logic_vector(N-1 downto 0);
	signal dout_rd_en_i            : std_logic;
	signal dout_packet_available_i : std_logic;
	signal dout_empty_notready_i   : std_logic;
	signal dout_i                  : std_logic_vector(15 downto 0);
	signal dout_end_of_packet_i    : std_logic;

	component input_chooser_N_sources
		generic ( N : positive );
		port (
			reset                 : in std_logic;
			clk                   : in std_logic;
			-- Input, Array of Source Ports, as arrays of signals 
			din_rd_en             : out std_logic_vector(N-1 downto 0);
			din_packet_available  : in  std_logic_vector(N-1 downto 0);
			din_empty_notready    : in  std_logic_vector(N-1 downto 0);
			din                   : in  multi_bus_16_bit(N-1 downto 0);
			din_end_of_packet     : in  std_logic_vector(N-1 downto 0);
			-- Output Port
			dout_rd_en            : in  std_logic;
			dout_packet_available : out std_logic; -- Goes to '1' before first word of packet is read, goes to '0' immediately afterwards.
			dout_empty_notready   : out std_logic; -- Indicates the user should not try and read (rd_en). May happen mid-packet! Always check this!
			dout                  : out std_logic_vector(15 downto 0);
			dout_end_of_packet    : out std_logic
		);
	end component;

begin
	-- pass through intermediate signals
	reset_i                 <= reset;
	clk_i                   <= clk;
	din_rd_en               <= din_rd_en_i;
	din_packet_available_i  <= din_packet_available;
	din_empty_notready_i    <= din_empty_notready;
	din_i                   <= din;
	din_end_of_packet_i     <= din_end_of_packet;
	dout_rd_en_i            <= dout_rd_en;
	dout_packet_available   <= dout_packet_available_i;
	dout_empty_notready     <= dout_empty_notready_i;
	dout                    <= dout_i;
	dout_end_of_packet      <= dout_end_of_packet_i;

	--Wrapped component.
	wrapped_input_chooser_N_sources : input_chooser_N_sources
	generic map ( N => N )
	port map (
		reset                 => reset_i,
		clk                   => clk_i,
		din_rd_en             => din_rd_en_i,
		din_packet_available  => din_packet_available_i,
		din_empty_notready    => din_empty_notready_i,
		din                   => din_i,
		din_end_of_packet     => din_end_of_packet_i,
		dout_rd_en            => dout_rd_en_i,
		dout_packet_available => dout_packet_available_i,
		dout_empty_notready   => dout_empty_notready_i,
		dout                  => dout_i,
		dout_end_of_packet    => dout_end_of_packet_i
	);

end Behavioral;					
