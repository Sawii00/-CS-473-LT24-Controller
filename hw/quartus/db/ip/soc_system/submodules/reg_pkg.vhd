LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

PACKAGE register_file_pkg IS
	TYPE RF IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
	TYPE LCDState IS (Idle, Reset, ReadCmd, Send, FetchParam, ResetRegs, IdleImageDisplay, PutWriteCmd, WritePixel, PutPixel);
	TYPE DMAState IS (Idle, WaitFifo, Request, WaitData, CheckData, ResetFlag);
END PACKAGE;