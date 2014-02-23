----------------------------------------------------------------------------------
-- Company:      Stanford MIIL (Molecular Imaging Instrumentation Lab)
-- Engineer:     Judson Wilson, based on code by Hua Liu.
--
-- Create Date:    02/12/2014 
-- Design Name:
-- Module Name:    acquisition_module
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--     Takes two serial UART port inputs and produces a parallel output. The
-- output signals are meant to directly interface to a FIFO. There is no flow
-- control.
--     Code originates from the Acquisition module by Hua Liu, but has been
-- mostly revamped and had many pieces removed.
--     Presently this interfaces with two frontend boards (via two serial
-- ports), but will scale up to more in the future.
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.input_chooser_N_sources_package.all;

entity acquisition_module is
	generic (N_sources : positive);
	port(
		reset       : in std_logic;
		boardid     : in std_logic_vector(2 downto 0);
		clk_50MHz   : in std_logic;
		-- Interface with Daisychain
		dout_wr_en  : out std_logic;
		dout        : out std_logic_vector(15 downto 0);
		-- Input from IOBs
		Rx          : in std_logic_vector(N_sources-1 downto 0)
	);
end acquisition_module;

architecture Behavioral of acquisition_module is
	-- global
	signal reset_fifo      : std_logic;
	signal reset_fifo_vec  : std_logic_vector(3 downto 0);
	
	signal fifos_din_wr            : std_logic_vector(N_sources-1 downto 0);
	signal fifos_din               : multi_bus_16_bit(N_sources-1 downto 0);
	signal fifos_rd_en             : std_logic_vector(N_sources-1 downto 0);
	signal fifos_packet_available  : std_logic_vector(N_sources-1 downto 0);
	signal fifos_empty_notready    : std_logic_vector(N_sources-1 downto 0);
	signal fifos_dout              : multi_bus_16_bit(N_sources-1 downto 0);
	signal fifos_end_of_packet     : std_logic_vector(N_sources-1 downto 0);

	signal chooser_dout_rd_en          : std_logic;
	signal chooser_dout_empty_notready : std_logic;
	signal chooser_dout                : std_logic_vector(15 downto 0);

	component deserializer is
		port(
			reset         : in std_logic;
			clk_50MHz     : in std_logic;
			boardid       : in std_logic_vector(2 downto 0);
			-- Interface, serial input, parallel output
			s_in          : in std_logic;
			p_out_wr      : out std_logic;
			p_out_data    : out std_logic_vector(15 downto 0)
		);
	end component;

	component packets_fifo_1024_16 is
		port (
			reset       : in std_logic;
			clk         : in std_logic;
			din_wr_en   : in std_logic;
			din         : in std_logic_vector(15 downto 0);
			dout_rd_en  : in std_logic;
			dout_packet_available : out std_logic; -- Goes to '1' before first word of packet is read, goes to '0' immediately afterwards.
			dout_empty_notready   : out std_logic; -- Indicates the user should not try and read (rd_en). May happen mid-packet! Always check this!
			dout        : out std_logic_vector(15 downto 0);
			dout_end_of_packet : out std_logic;
			bytes_received     : out std_logic_vector(63 downto 0) -- includes those that are thrown away to preempt buffer overflow
		);
	end component;

	component input_chooser_N_sources is
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
	end component;

begin

	-------------------------------------------------------------------------------
	-- FIFO Reset
	-- - Not sure why we do this, but gives a longer reset signal to the FIFOs. 
	--   I believe if a partial packet is recieved when coming out of reset, will
	--   be ignored. Only after the first valid start byte is recieved will any
	--   data pass.
	-------------------------------------------------------------------------------
	process ( reset, clk_50MHz)
	begin
		if ( reset = '1') then
			reset_fifo <= '1';
			reset_fifo_vec <= x"F";
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			reset_fifo_vec <= '0' & reset_fifo_vec(3 downto 1);
			reset_fifo <= reset_fifo_vec(0);
		end if;
	end process;


	--====================================================================
	--====================================================================
	-- Frontend Serial Recievers
	-- - For every input source, connect a deserializer to a packet FIFO.
	--====================================================================
	--====================================================================
	deserializer_buffer_array : for i in 0 to N_sources-1 generate

		deserializers: deserializer
		port map (
			reset         => reset,
			clk_50MHz     => clk_50Mhz,
			boardid       => boardid,
			-- Interface, serial input, parallel output
			s_in          => Rx(i),
			p_out_wr      => fifos_din_wr(i),
			p_out_data    => fifos_din(i)
		);

		deserializer_fifos: packets_fifo_1024_16
		port map (
			reset       => reset_fifo,
			clk         => clk_50MHz,
			din_wr_en   => fifos_din_wr(i),
			din         => fifos_din(i),
			dout_rd_en  => fifos_rd_en(i),
			dout_packet_available => fifos_packet_available(i),
			dout_empty_notready   => fifos_empty_notready(i),
			dout        => fifos_dout(i),
			dout_end_of_packet => fifos_end_of_packet(i),
			bytes_received     => open
		);

	end generate;


	--====================================================================
	--====================================================================
	-- Input Chooser:
	--     Data can flow from one and only one input channel to the
	--     output. This component produces a single interface output
	--     for multiple fifos, and the output side is designed to work
	--     exactly like packet fifo would.
	--====================================================================
	--====================================================================

	input_chooser: input_chooser_N_sources
	generic map ( N => N_sources)
	port map (
		reset                 => reset,
		clk                   => clk_50MHz,
		-- Input, Source Port 0
		din_rd_en             => fifos_rd_en,
		din_packet_available  => fifos_packet_available,
		din_empty_notready    => fifos_empty_notready,
		din                   => fifos_dout,
		din_end_of_packet     => fifos_end_of_packet,
		-- Output Port
		dout_rd_en            => chooser_dout_rd_en,
		dout_packet_available => open,
		dout_empty_notready   => chooser_dout_empty_notready,
		dout                  => chooser_dout,
		dout_end_of_packet    => open
	);


	--====================================================================
	--====================================================================
	-- Output Machine
	--     All of the FIFO hardware in this component relies on other
	-- logic to actuate it's output, once it signals that data is ready.
	-- i.e. hardware needs to read the flags and feed rd_en pulses.
	--     This "Output Machine" pulls the data out of the input chooser
	-- and pushes it out the ouput port of this component into whatever
	-- is recieving on the other side - most likely the input of a FIFO.
	--====================================================================
	--====================================================================

	-- We use a cheap trick - when empty_notready flag is false, then
	-- can read the fifo and output it next turn.
	dout <= chooser_dout;
	
	chooser_dout_rd_en <= not chooser_dout_empty_notready;

	output_machine_flipflop_process: process(reset, clk_50MHz)
	begin
		if reset = '1' then
			dout_wr_en <= '0';
		elsif clk_50MHz'event and clk_50MHz = '1' then
			dout_wr_en <= chooser_dout_rd_en;
		end if;
	end process;


end Behavioral;

