----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson
--
-- Create Date:    02/22/2014
-- Design Name:
-- Module Name:    input_chooser_N_sources
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--    Currently wrapper for input_chooser_2_sources to test port interfaces,
-- etc. Soon will do what's listed in Future Description below.
--
-- Future Description
--     The output port works just like the output port of a packet fifo, but
-- under-the-hood it uses an "often" fair priority scheme to choose between N
-- inputs that also have a packet fifo output interface.
--     The component is "often" fair, in that it is only truly fair when N
-- is a power of 2. Otherwise, consider H to be the nearest larger power of 2.
-- Divide the inputs into two sets, one set which has H/2 inputs, and the other
-- smaller set which has N-H/2 inputs. The smaller set has twice the pri
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

entity input_chooser_N_sources is
	generic ( N : positive ); -- Number of input ports
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
end input_chooser_N_sources;

architecture Behavioral of input_chooser_N_sources is
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

	-- Subtree connections
	signal subtree_dout_rd_en             : std_logic_vector(1 downto 0);
	signal subtree_dout_packet_available  : std_logic_vector(1 downto 0);
	signal subtree_dout_empty_notready    : std_logic_vector(1 downto 0);
	signal subtree_dout                   : multi_bus_16_bit(1 downto 0);
	signal subtree_dout_end_of_packet     : std_logic_vector(1 downto 0);

	-- Number of sources in the low and high subsets of inputs.
	constant N_low  : natural := input_chooser_N_sources_calculate_N_low(N); --note can be zero in base case, in which it is ignored.
	constant N_high : natural := N-N_low;

	component input_chooser_2_sources
		port (
			reset       : in std_logic;
			clk         : in std_logic;
			-- Input, Source Port 0
			din_0_rd_en  : out std_logic;
			din_0_packet_available : in std_logic; -- Goes to '1' before first word of packet is read, goes to '0' immediately afterwards.
			din_0_empty_notready   : in std_logic; -- Indicates the user should not try and read (rd_en). May happen mid-packet! Always check this!
			din_0        : in std_logic_vector(15 downto 0);
			din_0_end_of_packet : in std_logic;
			-- Input, Source Port 1
			din_1_rd_en  : out std_logic;
			din_1_packet_available : in std_logic; -- Goes to '1' before first word of packet is read, goes to '0' immediately afterwards.
			din_1_empty_notready   : in std_logic; -- Indicates the user should not try and read (rd_en). May happen mid-packet! Always check this!
			din_1        : in std_logic_vector(15 downto 0);
			din_1_end_of_packet : in std_logic;
			-- Output Port
			dout_rd_en  : in std_logic;
			dout_packet_available : out std_logic; -- Goes to '1' before first word of packet is read, goes to '0' immediately afterwards.
			dout_empty_notready   : out std_logic; -- Indicates the user should not try and read (rd_en). May happen mid-packet! Always check this!
			dout        : out std_logic_vector(15 downto 0);
			dout_end_of_packet : out std_logic
		);
	end component;

	component input_chooser_N_sources_wrapper
		generic ( N : positive ); -- Number of input ports
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
	-- Report the recursive split size of this tree into two subtrees.
	assert false report "input_chooser_N_sources recursive instantiation: N = " & integer'image(N) & "   N_low = " & integer'image(N_low) & " - N_high = " & integer'image(N_high) severity note;

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


	-------------------------------------------------------------------------------
	-- base case: if N = 1 do a direct connect from input to output
	-------------------------------------------------------------------------------
	direct_connect: if N = 1 generate
		assert false report "Instantiating direct_connect." severity note;
		din_rd_en_i(0)           <= dout_rd_en_i;
		dout_packet_available_i  <= din_packet_available_i(0);
		dout_empty_notready_i    <= din_empty_notready_i(0);
		dout_i                   <= din_i(0);
		dout_end_of_packet_i     <= din_end_of_packet_i(0);
	end generate direct_connect;


	-------------------------------------------------------------------------------
	-- recursive case: create two subtrees and connect them together with an
	--   input_chooser_2_sources
	----------------------------------------------------------------------------------
	subtree_split: if N > 1 generate
		assert false report "Instantiating subtree_split." severity note;

		--"Low" Subtree
		low_tree : input_chooser_N_sources_wrapper
		generic map ( N => N_low )
		port map (
			reset                 => reset_i,
			clk                   => clk_i,
			din_rd_en             => din_rd_en_i           (N_low-1 downto 0),
			din_packet_available  => din_packet_available_i(N_low-1 downto 0),
			din_empty_notready    => din_empty_notready_i  (N_low-1 downto 0),
			din                   => din_i                 (N_low-1 downto 0),
			din_end_of_packet     => din_end_of_packet_i   (N_low-1 downto 0),
			dout_rd_en            => subtree_dout_rd_en(0),
			dout_packet_available => subtree_dout_packet_available(0),
			dout_empty_notready   => subtree_dout_empty_notready(0),
			dout                  => subtree_dout(0),
			dout_end_of_packet    => subtree_dout_end_of_packet(0)
		);

		--"High" Subtree
		high_tree : input_chooser_N_sources_wrapper
		generic map ( N => N_high )
		port map (
			reset                 => reset_i,
			clk                   => clk_i,
			din_rd_en             => din_rd_en_i           (N-1 downto N_low),
			din_packet_available  => din_packet_available_i(N-1 downto N_low),
			din_empty_notready    => din_empty_notready_i  (N-1 downto N_low),
			din                   => din_i                 (N-1 downto N_low),
			din_end_of_packet     => din_end_of_packet_i   (N-1 downto N_low),
			dout_rd_en            => subtree_dout_rd_en(1),
			dout_packet_available => subtree_dout_packet_available(1),
			dout_empty_notready   => subtree_dout_empty_notready(1),
			dout                  => subtree_dout(1),
			dout_end_of_packet    => subtree_dout_end_of_packet(1)
		);

		--Input Chooser to select between roots of two subtrees
		subtree_chooser : input_chooser_2_sources
		port map (
			reset                  => reset_i,
			clk                    => clk_i,
			din_0_rd_en            => subtree_dout_rd_en(0),
			din_0_packet_available => subtree_dout_packet_available(0),
			din_0_empty_notready   => subtree_dout_empty_notready(0),
			din_0                  => subtree_dout(0),
			din_0_end_of_packet    => subtree_dout_end_of_packet(0),
			din_1_rd_en            => subtree_dout_rd_en(1),
			din_1_packet_available => subtree_dout_packet_available(1),
			din_1_empty_notready   => subtree_dout_empty_notready(1),
			din_1                  => subtree_dout(1),
			din_1_end_of_packet    => subtree_dout_end_of_packet(1),
			dout_rd_en             => dout_rd_en_i,
			dout_packet_available  => dout_packet_available_i,
			dout_empty_notready    => dout_empty_notready_i,
			dout                   => dout_i,
			dout_end_of_packet     => dout_end_of_packet_i
		);

	end generate subtree_split;

end Behavioral;
