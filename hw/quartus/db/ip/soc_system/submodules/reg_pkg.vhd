library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package register_file_pkg is
        type RF is array (natural range <>) of STD_LOGIC_VECTOR(15 DOWNTO 0);
	TYPE LCDState IS (Idle, Reset, ReadCmd, Send, FetchParam, ResetRegs, IdleImageDisplay, PutWriteCmd, WritePixel, PutPixel);
	TYPE DMAState IS (Idle, WaitFifo, Request, WaitData, CheckData, ResetFlag);
end package;
    