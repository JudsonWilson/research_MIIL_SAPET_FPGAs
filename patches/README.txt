These are patches that you can apply for various purposes (usually debug tools).

50MHz_LVDS_Out_Backplane.patch
 - Apply this to produce a 50MHz LVDS output clock out of one of the SMA connectors.
   This is a useful source for testing LVDS clock input on another board.

RENA_diagnostic_led_hack.patch
 - Apply this to change the LED behavior on the RENA frontend board, such that each
   time a diagnostic packet request is received, the LED will toggle states. (The
   LED stays constant otherwise).
