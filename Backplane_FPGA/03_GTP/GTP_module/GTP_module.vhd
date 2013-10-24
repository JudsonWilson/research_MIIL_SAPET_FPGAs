----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    14:31:07 10/22/2012 
-- Design Name: 
-- Module Name:    GTP_module - Behavioral 
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
use IEEE.STD_LOGIC_unsigned.ALL;
library UNISIM;
use UNISIM.Vcomponents.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity GTP_module is
	port (
		bug_from_GTP_to_Daisychain : out std_logic;
		bug_out_put_from_Daisychain_to_GTP : out std_logic;
	bug_in_xx_8102_xx_from_Daisychain_to_GTP : out std_logic;
		clk_50MHz		: in std_logic;
		reset			: in std_logic;
		GTP_receive_byte_number : out std_logic_vector(15 downto 0);
		GTP_transmit_byte_number : out std_logic_vector(15 downto 0);
		
		--transmit
		-- data from Daisychain to GTP
		din			: in std_logic_vector(15 downto 0);
		din_wr 			: in std_logic;

		gtp_txp			: out std_logic;
		gtp_txn			: out std_logic;
		is_GTP_ready		: out std_logic;
		-- receive
		-- As soon as the gtp interface receives the config data and acquisition data, it will be transfer to Daisychain fifo
		dout			: out std_logic_vector(15 downto 0);
		dout_wr 		: out std_logic;
		gtp_rxp			: in std_logic;
		gtp_rxn			: in std_logic;
		--- GTP clock
		gtp_clkp_pin		: in std_logic;
		gtp_clkn_pin		: in std_logic
	);
end GTP_module;

architecture Behavioral of GTP_module is
	signal formal_word		: std_logic_vector(15 downto 0);
	signal formal_word1		: std_logic_vector(15 downto 0);
	signal formal_word2		: std_logic_vector(15 downto 0);
	signal bug_bit			: std_logic_vector(2 downto 0);
	signal bug_bit1			: std_logic_vector(2 downto 0);
	signal bug_bit2			: std_logic_vector(1 downto 0);
	signal GTP_receive_byte_number_i : std_logic_vector(15 downto 0) := x"0000";
	signal GTP_transmit_byte_number_i : std_logic_vector(15 downto 0) := x"0000";
	-- Global signal
	signal reset_vec		: std_logic_vector(31 downto 0) := (others => '1');
	signal reset_l			: std_logic := '1';
	signal reset_rx_vec		: std_logic_vector(31 downto 0) := (others => '1');
	signal reset_rx_l		: std_logic  := '1';
	signal reset_GTP_vec		: std_logic_vector(31 downto 0) := (others => '1');
	signal reset_GTP_l		: std_logic := '1';
        -- GTP related signal
	signal TILE0_LOOPBACK0_IN		: std_logic_vector( 2 downto 0);
	signal TILE0_LOOPBACK1_IN		: std_logic_vector( 2 downto 0);
	signal TILE0_RXDISPERR0_OUT             : std_logic_vector(1 downto 0);
	signal TILE0_RXNOTINTABLE0_OUT          : std_logic_vector(1 downto 0);
	signal TILE0_RXDATA0_OUT                : std_logic_vector(15 downto 0);
	signal TILE0_RXCHARISCOMMA0_OUT         : std_logic_vector(1 downto 0);
	signal TILE0_RXCHARISK0_OUT             : std_logic_vector(1 downto 0) := "11";
	signal TILE0_RXCLKCORCNT0_OUT           : std_logic_vector(2 downto 0);
	signal TILE0_RXBYTEISALIGNED0_OUT       : std_logic;
	signal TILE0_RXBYTEREALIGN0_OUT         : std_logic;
	signal TILE0_RXCOMMADET0_OUT            : std_logic;
	signal TILE0_RXRECCLK0_OUT              : std_logic;
	signal TILE0_RXUSRCLK0_IN               : std_logic;
	signal TILE0_RXUSRCLK20_IN              : std_logic;
	signal TILE0_RXLOSSOFSYNC0_OUT          : std_logic_vector(1 downto 0);
	signal TILE0_TXCHARISK1_IN              : std_logic_vector(1 downto 0) := "11";
	signal TILE0_TXDATA1_IN                 : std_logic_vector(15 downto 0);
	signal TILE0_TXOUTCLK1_OUT 		: std_logic;
	signal TILE0_TXUSRCLK1_IN 		: std_logic;
	signal TILE0_TXUSRCLK21_IN 		: std_logic;

	
	-- fifo related gisnal
	signal fifo_for_GTP_receive_din		: std_logic_vector(15 downto 0);
	signal fifo_for_GTP_receive_wr		: std_logic;
	signal fifo_for_GTP_receive_full	: std_logic;
	signal fifo_for_GTP_receive_rd		: std_logic;
	signal fifo_for_GTP_receive_rd1		: std_logic;
	signal fifo_for_GTP_receive_dout	: std_logic_vector(15 downto 0);
	signal fifo_for_GTP_receive_empty	: std_logic;
	signal fifo_for_GTP_transmission_full	: std_logic;
	signal fifo_for_GTP_transmission_rd	: std_logic;
	signal fifo_for_GTP_transmission_rd1    : std_logic;
	signal fifo_for_GTP_transmission_dout   : std_logic_vector(15 downto 0);
	signal fifo_for_GTP_transmission_empty  : std_logic;
	signal mask_dout_count 			: std_logic_vector(7 downto 0) := x"FF";
	-- PLL related signal
	signal tx_pll_fb_in			: std_logic;
	signal tx_pll_fb_out			: std_logic;
	signal TILE0_TXOUTCLK1_OUT_pll		: std_logic;
	signal TILE0_TXUSRCLK1_IN_pll		: std_logic;
	signal TILE0_TXUSRCLK21_IN_pll		: std_logic;
	signal tx_pll_locked			: std_logic;

	signal rx_pll_fb_in			: std_logic;
	signal rx_pll_fb_out			: std_logic;
	signal TILE0_RXRECCLK0_OUT_pll		: std_logic;
	signal TILE0_RXUSRCLK0_IN_pll		: std_logic;
	signal TILE0_RXUSRCLK20_IN_pll		: std_logic;
	signal rx_pll_locked			: std_logic;
	signal gtp_clk				: std_logic;
	signal receive_data_number		: std_logic_vector(15 downto 0) := x"0000";
	signal transfer_data_number		: std_logic_vector(15 downto 0) := x"0000";
	component GTP_WRAPPER
		generic
		(
			-- SImulation attributes
			WRAPPER_SIM_GTPRESET_SPEEDUP    : integer   := 0; -- Set to 1 to speed up sim reset
			WRAPPER_SIM_PLL_PERDIV2         : bit_vector:= x"14d" -- Set to the VCO Unit Interval time
		);
		port
		(
    --_________________________________________________________________________
    --_________________________________________________________________________
    --TILE0  (Location)

    ------------------------ Loopback and Powerdown Ports ----------------------
			TILE0_LOOPBACK0_IN                      : in   std_logic_vector(2 downto 0);
			TILE0_LOOPBACK1_IN                      : in   std_logic_vector(2 downto 0);
    ----------------------- Receive Ports - 8b10b Decoder ----------------------
			TILE0_RXCHARISCOMMA0_OUT                : out  std_logic_vector(1 downto 0);
			TILE0_RXCHARISCOMMA1_OUT                : out  std_logic_vector(1 downto 0);
			TILE0_RXCHARISK0_OUT                    : out  std_logic_vector(1 downto 0);
			TILE0_RXCHARISK1_OUT                    : out  std_logic_vector(1 downto 0);
			TILE0_RXDISPERR0_OUT                    : out  std_logic_vector(1 downto 0);
			TILE0_RXDISPERR1_OUT                    : out  std_logic_vector(1 downto 0);
			TILE0_RXNOTINTABLE0_OUT                 : out  std_logic_vector(1 downto 0);
			TILE0_RXNOTINTABLE1_OUT                 : out  std_logic_vector(1 downto 0);
    ------------------- Receive Ports - Clock Correction Ports -----------------
			TILE0_RXCLKCORCNT0_OUT                  : out  std_logic_vector(2 downto 0);
			TILE0_RXCLKCORCNT1_OUT                  : out  std_logic_vector(2 downto 0);
    --------------- Receive Ports - Comma Detection and Alignment --------------
			TILE0_RXBYTEISALIGNED0_OUT              : out  std_logic;
			TILE0_RXBYTEISALIGNED1_OUT              : out  std_logic;
			TILE0_RXBYTEREALIGN0_OUT                : out  std_logic;
			TILE0_RXBYTEREALIGN1_OUT                : out  std_logic;
			TILE0_RXCOMMADET0_OUT                   : out  std_logic;
			TILE0_RXCOMMADET1_OUT                   : out  std_logic;
			TILE0_RXENMCOMMAALIGN0_IN               : in   std_logic;
			TILE0_RXENMCOMMAALIGN1_IN               : in   std_logic;
			TILE0_RXENPCOMMAALIGN0_IN               : in   std_logic;
			TILE0_RXENPCOMMAALIGN1_IN               : in   std_logic;
    ------------------- Receive Ports - RX Data Path interface -----------------
			TILE0_RXDATA0_OUT                       : out  std_logic_vector(15 downto 0);
			TILE0_RXDATA1_OUT                       : out  std_logic_vector(15 downto 0);
			TILE0_RXRECCLK0_OUT                     : out  std_logic;
			TILE0_RXRECCLK1_OUT                     : out  std_logic;
			TILE0_RXRESET0_IN                       : in   std_logic;
			TILE0_RXRESET1_IN                       : in   std_logic;
			TILE0_RXUSRCLK0_IN                      : in   std_logic;
			TILE0_RXUSRCLK1_IN                      : in   std_logic;
			TILE0_RXUSRCLK20_IN                     : in   std_logic;
			TILE0_RXUSRCLK21_IN                     : in   std_logic;
    ------- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
			TILE0_RXN0_IN                           : in   std_logic;
			TILE0_RXN1_IN                           : in   std_logic;
			TILE0_RXP0_IN                           : in   std_logic;
			TILE0_RXP1_IN                           : in   std_logic;
    --------------- Receive Ports - RX Loss-of-sync State Machine --------------
			TILE0_RXLOSSOFSYNC0_OUT                 : out  std_logic_vector(1 downto 0);
			TILE0_RXLOSSOFSYNC1_OUT                 : out  std_logic_vector(1 downto 0);
    --------------------- Shared Ports - Tile and PLL Ports --------------------
			TILE0_CLKIN_IN                          : in   std_logic;
			TILE0_GTPRESET_IN                       : in   std_logic;
			TILE0_PLLLKDET_OUT                      : out  std_logic;
			TILE0_REFCLKOUT_OUT                     : out  std_logic;
			TILE0_RESETDONE0_OUT                    : out  std_logic;
			TILE0_RESETDONE1_OUT                    : out  std_logic;
    ---------------- Transmit Ports - 8b10b Encoder Control Ports --------------
			TILE0_TXCHARISK0_IN                     : in   std_logic_vector(1 downto 0);
			TILE0_TXCHARISK1_IN                     : in   std_logic_vector(1 downto 0);
    ------------------ Transmit Ports - TX Data Path interface -----------------
			TILE0_TXDATA0_IN                        : in   std_logic_vector(15 downto 0);
			TILE0_TXDATA1_IN                        : in   std_logic_vector(15 downto 0);
			TILE0_TXOUTCLK0_OUT                     : out  std_logic;
			TILE0_TXOUTCLK1_OUT                     : out  std_logic;
			TILE0_TXUSRCLK0_IN                      : in   std_logic;
			TILE0_TXUSRCLK1_IN                      : in   std_logic;
			TILE0_TXUSRCLK20_IN                     : in   std_logic;
			TILE0_TXUSRCLK21_IN                     : in   std_logic;
    --------------- Transmit Ports - TX Driver and OOB signalling --------------
			TILE0_TXN0_OUT                          : out  std_logic;
			TILE0_TXN1_OUT                          : out  std_logic;
			TILE0_TXP0_OUT                          : out  std_logic;
			TILE0_TXP1_OUT                          : out  std_logic
		);
	end component;
	component fifo_16
		port (
			rst				: in std_logic;
			wr_clk				: in std_logic;
			rd_clk				: in std_logic;
			din				: in std_logic_vector(15 downto 0);
			wr_en 				: in std_logic;
			rd_en				: in std_logic;
			dout				: out std_logic_vector(15 downto 0);
			full				: out std_logic;
			empty				: out std_logic
		);
	end component;
begin
	GTP_receive_byte_number <= GTP_receive_byte_number_i;
	GTP_transmit_byte_number <= GTP_transmit_byte_number_i;

	bug_find_process : process ( reset, clk_50MHz)
	begin
		if ( reset = '1') then
			bug_out_put_from_Daisychain_to_GTP <= '0';
			formal_word2 <= x"0000";
			bug_bit <= "000";
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			case bug_bit is
				when "000" =>
					if ( din_wr = '0') then
						bug_bit <= "000";
						formal_word2 <= x"0000";
					else
						bug_bit <= "001";
						formal_word2 <= din;
					end if;
					bug_out_put_from_Daisychain_to_GTP <= '0';
				when "001" =>
					if ( din_wr = '0') then
						formal_word2 <= formal_word2;
						bug_bit <= "001";
					else
						if ( din = x"FF00") then
							formal_word2 <= formal_word2;
							bug_bit <= "010";
						else
							formal_word2 <= din;
							bug_bit <= "001";
						end if;
					end if;
					bug_out_put_from_Daisychain_to_GTP <= '0';
				when "010" =>
					if (din_wr = '0')  then
						formal_word2 <= formal_word2;
						bug_bit <= "010";
					else
						if (( din = x"FF00")) then
							formal_word2 <= formal_word2;
							bug_bit <= "011";
						else
							formal_word2 <= din;
							bug_bit <= "001";
						end if;
					end if;
					bug_out_put_from_Daisychain_to_GTP <= '0';
				when "011" =>
					if (din_wr = '0')  then
						formal_word2 <= formal_word2;
						bug_bit <= "011";
						bug_out_put_from_Daisychain_to_GTP <= '0';
					else
						if (( din = x"FF00")) then
							formal_word2 <= formal_word2;
							bug_bit <= "001";
							bug_out_put_from_Daisychain_to_GTP <= '1';
						else
							formal_word2 <= din;
							bug_bit <= "001";
							bug_out_put_from_Daisychain_to_GTP <= '0';
						end if;
					end if;
				when others =>
					null;
			end case;
		end if;
	end process;


	---------------------------------------------------------------------------
	-- Global signals
	---------------------------------------------------------------------------
	reset_process : process( reset, clk_50MHz)
	begin
		if ( reset = '1') then
			reset_vec <= (others => '1');
			reset_l <= '1';
		elsif (clk_50MHz 'event and clk_50MHz = '1') then
			reset_vec <= '0' & reset_vec(31 downto 1);
			reset_l <= reset_vec(0);
		end if;
	end process;
	reset_rx_process: process ( reset, rx_pll_locked, clk_50MHz)
	begin
		if ( reset = '1' or rx_pll_locked = '0') then
			reset_rx_vec <= (others => '1');
			reset_rx_l <= '1';
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			reset_rx_vec <= '0' & reset_rx_vec(31 downto 1);
			reset_rx_l <= reset_rx_vec(0);
		end if;
	end process;

	reset_GTP_process: process ( reset, clk_50MHz)
	begin
		if ( reset = '1') then
			reset_GTP_vec <= (others => '1');
			reset_GTP_l <= '1';
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			reset_GTP_vec <= '0' & reset_GTP_vec(31 downto 1);
			reset_GTP_l <= reset_GTP_vec(0);
		end if;
	end process;

	is_GTP_ready_process: process( reset_l, TILE0_TXUSRCLK21_IN)
	begin
		if ( reset = '1') then
			is_GTP_ready <= '0';
		elsif ( TILE0_TXUSRCLK21_IN 'event and TILE0_TXUSRCLK21_IN = '1') then
			if ( fifo_for_GTP_transmission_full = '1') then
				is_GTP_ready <= '0';
			elsif (fifo_for_GTP_transmission_empty = '1') then
				is_GTP_ready <= '1';
			end if;
		end if;
	end process;
	--------------------------------------------------------------------------------------------------------------
	-- GTP instantiation
	--------------------------------------------------------------------------------------------------------------
	GTPwrapper_i : GTP_WRAPPER
	generic map
	(
		WRAPPER_SIM_GTPRESET_SPEEDUP => 1,
		WRAPPER_SIM_PLL_PERDIV2      => x"14d"
	)
	port map
	(
	-- TILE0 (X0Y3)
		-- "000" normoal model
		-- "010" near-end PMA loopback model
		-- "110" far-end PCS loop back model
		TILE0_LOOPBACK0_IN		=> "000",
		TILE0_LOOPBACK1_IN		=> "000",
	----------------------- Receive Ports - 8b10b Decoder ----------------------
		TILE0_RXCHARISCOMMA0_OUT        => TILE0_RXCHARISCOMMA0_OUT,
		TILE0_RXCHARISCOMMA1_OUT        => open,
		TILE0_RXCHARISK0_OUT            => TILE0_RXCHARISK0_OUT,
		TILE0_RXCHARISK1_OUT            => open,
		TILE0_RXDISPERR0_OUT            => TILE0_RXDISPERR0_OUT,
		TILE0_RXDISPERR1_OUT            => open,
		TILE0_RXNOTINTABLE0_OUT         => TILE0_RXNOTINTABLE0_OUT,
		TILE0_RXNOTINTABLE1_OUT         => open,
	------------------- Receive Ports - Clock Correction Ports -----------------
		TILE0_RXCLKCORCNT0_OUT          => TILE0_RXCLKCORCNT0_OUT,
		TILE0_RXCLKCORCNT1_OUT          => open,
	--------------- Receive Ports - Comma Detection and Alignment --------------
		TILE0_RXBYTEISALIGNED0_OUT      => TILE0_RXBYTEISALIGNED0_OUT,
		TILE0_RXBYTEISALIGNED1_OUT      => open,
		TILE0_RXBYTEREALIGN0_OUT        => TILE0_RXBYTEREALIGN0_OUT,
		TILE0_RXBYTEREALIGN1_OUT        => open,
		TILE0_RXCOMMADET0_OUT           => TILE0_RXCOMMADET0_OUT,
		TILE0_RXCOMMADET1_OUT           => open,
		TILE0_RXENMCOMMAALIGN0_IN       => '1',
		TILE0_RXENMCOMMAALIGN1_IN       => '0',
		TILE0_RXENPCOMMAALIGN0_IN       => '1',
		TILE0_RXENPCOMMAALIGN1_IN       => '0',
	------------------- Receive Ports - RX Data Path interface -----------------
		TILE0_RXDATA0_OUT               => TILE0_RXDATA0_OUT,
		TILE0_RXDATA1_OUT               => open,
		TILE0_RXRECCLK0_OUT             => TILE0_RXRECCLK0_OUT,
		TILE0_RXRECCLK1_OUT             => open ,
		TILE0_RXRESET0_IN               => reset_rx_l,
		TILE0_RXRESET1_IN               => reset_rx_l,
		TILE0_RXUSRCLK0_IN              => TILE0_RXUSRCLK0_IN,
		TILE0_RXUSRCLK1_IN              => '0',
		TILE0_RXUSRCLK20_IN             => TILE0_RXUSRCLK20_IN,
		TILE0_RXUSRCLK21_IN             => '0',
	------- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
		TILE0_RXN0_IN                   => gtp_rxn,
		TILE0_RXN1_IN                   => '1',
		TILE0_RXP0_IN                   => gtp_rxp,
		TILE0_RXP1_IN                   => '0',
	--------------- Receive Ports - RX Loss-of-sync State Machine --------------
		TILE0_RXLOSSOFSYNC0_OUT         => TILE0_RXLOSSOFSYNC0_OUT,
		TILE0_RXLOSSOFSYNC1_OUT         => open,
	--------------------- Shared Ports - Tile and PLL Ports --------------------
		TILE0_CLKIN_IN                  => gtp_clk,
		TILE0_GTPRESET_IN               => reset_GTP_l,
		TILE0_PLLLKDET_OUT              => open,
		TILE0_REFCLKOUT_OUT             => open,
		TILE0_RESETDONE0_OUT            => open,
		TILE0_RESETDONE1_OUT            => open,
	---------------- Transmit Ports - 8b10b Encoder Control Ports --------------
		TILE0_TXCHARISK0_IN             => "00",
		TILE0_TXCHARISK1_IN             => TILE0_TXCHARISK1_IN,
	------------------ Transmit Ports - TX Data Path interface -----------------
		TILE0_TXDATA0_IN                => x"0000",
		TILE0_TXDATA1_IN                => TILE0_TXDATA1_IN,
		TILE0_TXOUTCLK0_OUT             => open,
		TILE0_TXOUTCLK1_OUT             => TILE0_TXOUTCLK1_OUT,
		TILE0_TXUSRCLK0_IN              => '0',
		TILE0_TXUSRCLK1_IN              => TILE0_TXUSRCLK1_IN,
		TILE0_TXUSRCLK20_IN             => '0',
		TILE0_TXUSRCLK21_IN             => TILE0_TXUSRCLK21_IN,
	--------------- Transmit Ports - TX Driver and OOB signalling --------------
		TILE0_TXN0_OUT                  => open, 
		TILE0_TXN1_OUT                  => gtp_txn,
		TILE0_TXP0_OUT                  => open,
		TILE0_TXP1_OUT                  => gtp_txp 
	);
	-- J40 receive interface
	-- Receive Interface
	GTP_receive_data_process: process ( reset_l, TILE0_RXUSRCLK20_IN)
	begin
		if ( reset_l = '1') then
			fifo_for_GTP_receive_din <= (others => '0');
			fifo_for_GTP_receive_wr <= '0';
			mask_dout_count <= x"FF";
		elsif(TILE0_RXUSRCLK20_IN 'event and TILE0_RXUSRCLK20_IN = '1') then
			if ( TILE0_RXCHARISK0_OUT = "00" and TILE0_RXDISPERR0_OUT = "00" and TILE0_RXNOTINTABLE0_OUT = "00" and mask_dout_count = x"00") then
				fifo_for_GTP_receive_din <= TILE0_RXDATA0_OUT;
				fifo_for_GTP_receive_wr <= '1';
			else
				fifo_for_GTP_receive_wr <= '0';
			end if;
			if (TILE0_RXLOSSOFSYNC0_OUT(1) = '1') then
				mask_dout_count <= x"60";
			elsif ( mask_dout_count /= x"00") then
				mask_dout_count <= mask_dout_count - 1;
			end if;
		end if;
	end process;

	fifo_for_GTP_receive: fifo_16
	port map(
			rst		=> reset_l,
			wr_clk		=> TILE0_RXUSRCLK20_IN,
			wr_en		=> fifo_for_GTP_receive_wr,
			din		=> fifo_for_GTP_receive_din,
			full		=> fifo_for_GTP_receive_full,
			rd_clk		=> clk_50MHz,
			rd_en		=> fifo_for_GTP_receive_rd,
			dout		=> fifo_for_GTP_receive_dout,
			empty		=> fifo_for_GTP_receive_empty
		);
	fifo_for_GTP_receive_rd <= not fifo_for_GTP_receive_empty;
	GTP_receive_data_process2 : process(reset_l, clk_50MHz)
	begin
		if ( reset_l = '1') then
			fifo_for_GTP_receive_rd1 <= '0';
			dout <= (others => '0');
			dout_wr <= '0';
			GTP_receive_byte_number_i <= x"0000";
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			fifo_for_GTP_receive_rd1 <= fifo_for_GTP_receive_rd;
			if ( fifo_for_GTP_receive_rd1 = '1') then
				dout <= fifo_for_GTP_receive_dout;
				dout_wr <= '1';
				-- To test the data lost or not.
				if ( fifo_for_GTP_receive_dout = x"FF00") then
					GTP_receive_byte_number_i <= GTP_receive_byte_number_i + x"01";
				else
					GTP_receive_byte_number_i <= GTP_receive_byte_number_i + x"02";
				end if;
			else
				dout <= (others => '0');
				dout_wr <= '0';
			end if;
		end if;
	end process;

	bug_in_xx_8102_xx_from_Daisychin_to_GTP_process: process ( reset, clk_50MHz)
	begin
		if ( reset = '1') then
			bug_in_xx_8102_xx_from_Daisychain_to_GTP <= '0';
			formal_word <= x"0000";
			bug_bit2 <= "00";
		elsif( clk_50MHz 'event and clk_50MHz = '1') then
			case bug_bit2 is
				when "00" =>
					if ( din_wr = '0') then
						bug_bit2 <= "00";
						formal_word <= formal_word;
					else
						bug_bit2 <= "01";
						formal_word <= din;
					end if;
					bug_in_xx_8102_xx_from_Daisychain_to_GTP <= '0';
				when "01" =>
					if ( din_wr = '0') then
						bug_bit2 <= "01";
						formal_word <= formal_word;
						bug_in_xx_8102_xx_from_Daisychain_to_GTP <= '0';
					elsif ( (din_wr = '1') and (din /= x"8102")) then
						bug_bit2 <= "01";
						formal_word <= din;
						bug_in_xx_8102_xx_from_Daisychain_to_GTP <= '0';
					elsif ( (din_wr = '1') and (din = x"8102") and ((formal_word(15 downto 8) = x"FF") or ( formal_word(7 downto 0) = x"FF"))) then
						bug_bit2 <= "01";
						formal_word <= din;
						bug_in_xx_8102_xx_from_Daisychain_to_GTP <= '0';
					elsif ( (din_wr = '1') and (din = x"8102") and ((formal_word(15 downto 8) /= x"FF") or ( formal_word(7 downto 0) /= x"FF"))) then
						bug_bit2 <= "00";
						formal_word <= formal_word;
						bug_in_xx_8102_xx_from_Daisychain_to_GTP <= '1';
					end if;
				when others =>
					null;
			end case;
		end if;
	end process;



	bug_test_from_GTP_to_Daisychain: process ( reset, clk_50MHz)
	begin
		if ( reset = '1') then
			bug_from_GTP_to_Daisychain <= '0';
			formal_word1 <= x"0000";
			bug_bit1 <= "000";
		elsif ( clk_50MHz 'event and clk_50MHz = '1') then
			case bug_bit1 is
				when "000" =>
					if ( fifo_for_GTP_receive_rd1 = '0') then
						bug_bit1 <= "000";
						formal_word1 <= x"0000";
					else
						bug_bit1 <= "001";
						formal_word1 <= fifo_for_GTP_receive_dout;
					end if;
					bug_from_GTP_to_Daisychain <= '0';
				when "001" =>
					if ( fifo_for_GTP_receive_rd1 = '0') then
						formal_word1 <= formal_word1;
						bug_bit1 <= "001";
					elsif ( (fifo_for_GTP_receive_rd1 = '1') and ( fifo_for_GTP_receive_dout = x"FF00")) then
						formal_word1 <= formal_word1;
						bug_bit1 <= "010";
					else
						formal_word1 <= fifo_for_GTP_receive_dout;
						bug_bit1 <= "001";
					end if;
					bug_from_GTP_to_Daisychain <= '0';
				when "010" =>
					if (fifo_for_GTP_receive_rd1 = '0')  then
						formal_word1 <= formal_word1;
						bug_bit1 <= "010";
						bug_from_GTP_to_Daisychain <= '0';
					elsif ( (fifo_for_GTP_receive_rd1 = '1') and ( fifo_for_GTP_receive_dout = x"FF00")) then
						formal_word1 <= formal_word1;
						bug_bit1 <= "011";
						bug_from_GTP_to_Daisychain <= '1';
					else
						formal_word1 <= fifo_for_GTP_receive_dout;
						bug_bit1 <= "001";
						bug_from_GTP_to_Daisychain <= '0';
					end if;
				when "011" =>
					if (fifo_for_GTP_receive_rd1 = '0')  then
						formal_word1 <= formal_word1;
						bug_bit1 <= "011";
						bug_from_GTP_to_Daisychain <= '0';
					elsif ( (fifo_for_GTP_receive_rd1 = '1') and ( fifo_for_GTP_receive_dout = x"FF00")) then
						formal_word1 <= formal_word1;
						bug_bit1 <= "100";
						bug_from_GTP_to_Daisychain <= '1';
					else
						formal_word1 <= fifo_for_GTP_receive_dout;
						bug_bit1 <= "001";
						bug_from_GTP_to_Daisychain <= '0';
					end if;
				when "100" =>
					if (fifo_for_GTP_receive_rd1 = '0')  then
						formal_word1 <= formal_word1;
						bug_bit1 <= "100";
					elsif ( (fifo_for_GTP_receive_rd1 = '1') and ( fifo_for_GTP_receive_dout = formal_word1)) then
						formal_word1 <= formal_word1;
						bug_bit1 <= "101";
					else
						formal_word1 <= fifo_for_GTP_receive_dout;
						bug_bit1 <= "001";
					end if;
					bug_from_GTP_to_Daisychain <= '0';
				when "101" =>
					if (fifo_for_GTP_receive_rd1 = '0')  then
						formal_word1 <= formal_word1;
						bug_bit1 <= "101";
					elsif ( (fifo_for_GTP_receive_rd1 = '1') and ( fifo_for_GTP_receive_dout = formal_word1)) then
						formal_word1 <= formal_word1;
						bug_bit1 <= "110";
					else
						formal_word1 <= fifo_for_GTP_receive_dout;
						bug_bit1 <= "001";
					end if;
					bug_from_GTP_to_Daisychain <= '0';
				when "110" =>
					if (fifo_for_GTP_receive_rd1 = '0')  then
						formal_word1 <= formal_word1;
						bug_from_GTP_to_Daisychain <= '0';
					elsif ( (fifo_for_GTP_receive_rd1 = '1') and ( fifo_for_GTP_receive_dout = formal_word1)) then
						formal_word1 <= formal_word1;
						bug_from_GTP_to_Daisychain <= '1';
					else
						formal_word1 <= fifo_for_GTP_receive_dout;
					end if;
					bug_bit1 <= "001";
				when others =>
					null;
			end case;
		end if;
	end process;



	--------------------------------------------------------------------------------------------------
	-- This process is to count the data sent to GTP transmit_fifo.
	--------------------------------------------------------------------------------------------------
	Inst_count_data_number: process( reset, clk_50MHz)
	begin
		if ( reset = '1') then
			GTP_transmit_byte_number_i <= x"0000";
		elsif( clk_50MHz 'event and clk_50MHz = '1') then
			if ( din_wr = '1') then
				if ( din(15 downto 8) = x"FF") then
					GTP_transmit_byte_number_i <= GTP_transmit_byte_number_i + x"1";
				else
					GTP_transmit_byte_number_i <= GTP_transmit_byte_number_i + x"2";
				end if;
			end if;
		end if;
	end process;



	-- J41 transfer interface
	-- To transfer the config data and acquisition data
	fifo_for_GTP_transmission: fifo_16
	port map(
			rst		=> reset_l,
			wr_clk		=> clk_50MHz,
			rd_clk		=> TILE0_TXUSRCLK21_IN,
			wr_en		=> din_wr,
			din		=> din,
			full		=> fifo_for_GTP_transmission_full,
			rd_en		=> fifo_for_GTP_transmission_rd,
			dout 		=> fifo_for_GTP_transmission_dout,
			empty		=> fifo_for_GTP_transmission_empty
		);
	fifo_for_GTP_transmission_rd <= not fifo_for_GTP_transmission_empty;
	GTP_transmit_data_process : process( reset_l, TILE0_TXUSRCLK21_IN)
	begin
		if ( reset_l = '1') then
			TILE0_TXDATA1_IN <= (others => '0');
			TILE0_TXCHARISK1_IN <= "11";
			fifo_for_GTP_transmission_rd1 <= '0';
		elsif ( TILE0_TXUSRCLK21_IN 'event and TILE0_TXUSRCLK21_IN = '1') then
			fifo_for_GTP_transmission_rd1 <= fifo_for_GTP_transmission_rd;
			if ( fifo_for_GTP_transmission_rd1 = '1') then
				TILE0_TXDATA1_IN <= fifo_for_GTP_transmission_dout;
				TILE0_TXCHARISK1_IN <= "00";
			else
				TILE0_TXDATA1_IN <= x"00BC";
				TILE0_TXCHARISK1_IN <= "11";
			end if;
		end if;
	end process;
	-----------------------------------------------------------------------
	-- shared clock
	-----------------------------------------------------------------------
	inst_diff: IBUFDS
	generic map (DIFF_TERM => TRUE)
	port map (
			I => gtp_clkp_pin,
			IB => gtp_clkn_pin,
			O => gtp_clk
		);
	-- generating tx clocks
	tx_pll_for_GTP: PLL_BASE
	generic map(
			BANDWIDTH => "LOW",
			CLKIN_PERIOD => 3.33,
			CLKFBOUT_MULT => 3,
			CLKOUT0_DIVIDE => 3,    -- USERCLK: 300MHz
			CLKOUT1_DIVIDE => 6	-- USERCLK2: 150MHz
		)
	port map (
			CLKFBIN => tx_pll_fb_in,
			CLKFBOUT => tx_pll_fb_out,
			CLKIN => TILE0_TXOUTCLK1_OUT_pll,
			RST => '0',
			CLKOUT0 => TILE0_TXUSRCLK1_IN_pll,
			CLKOUT1 => TILE0_TXUSRCLK21_IN_pll,
			LOCKED => tx_pll_locked
		);
	inst_GTP_tx_outclk_bufg: bufg
	port map (
			i => TILE0_TXOUTCLK1_OUT,
			o => TILE0_TXOUTCLK1_OUT_pll
		);
	inst_GTP_tx_clkfb_bufg: bufg
	port map (
			i => tx_pll_fb_out,
			o => tx_pll_fb_in
		);
	inst_GTP_tx_userclk_bufg: bufg
	port map (
			i => TILE0_TXUSRCLK1_IN_pll,
			o => TILE0_TXUSRCLK1_IN
		);
	inst_GTP_tx_userclk2_bufg: bufg
	port map(
			i => TILE0_TXUSRCLK21_IN_pll,
			o => TILE0_TXUSRCLK21_IN
		);
	-- generating rx clocks
	rx_pll_for_GTP: PLL_BASE
	generic map (
			BANDWIDTH => "low",
			CLKIN_PERIOD => 3.33,
			CLKFBOUT_MULT => 3,
			CLKOUT0_DIVIDE => 3, -- USERCLK: 300MHz
			CLKOUT1_DIVIDE => 6  -- USERCLK2: 150MHz
		)
	port map (
			CLKFBIN => rx_pll_fb_in,
			CLKFBOUT => rx_pll_fb_out,
			CLKIN => TILE0_RXRECCLK0_OUT_pll,
			RST => '0',
			CLKOUT0 => TILE0_RXUSRCLK0_IN_pll,
			CLKOUT1 => TILE0_RXUSRCLK20_IN_pll,
			LOCKED => rx_pll_locked
		);
	inst_GTP_rx_outclk_bufg: bufg
	port map(
			i => TILE0_RXRECCLK0_OUT,
			o => TILE0_RXRECCLK0_OUT_pll
		);
	inst_GTP_rx_clkfb_bufg: bufg
	port map(
			i => rx_pll_fb_out,
			o => rx_pll_fb_in
		);
	inst_GTP_rx_userclk_bufg: bufg
	port map(
			i => TILE0_RXUSRCLK0_IN_pll,
			o => TILE0_RXUSRCLK0_in
		);
	inst_GTP_rx_userclk2_bufg : bufg
	port map(
			i => TILE0_RXUSRCLK20_IN_pll,
			o => TILE0_RXUSRCLK20_in
		);
end Behavioral;
