library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.register_file_pkg.all;

ENTITY RegisterFile IS

	PORT (	
		clk : IN STD_LOGIC;
		nReset : IN STD_LOGIC;
		-- Internal interface (i.e. Avalon slave).
		address : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
		write : IN STD_LOGIC;
		read : IN STD_LOGIC;
		writedata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		readdata : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);

		--output registers for DMA and LCDController
		ImageAddress : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		ImageLength : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		Flags : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		CommandReg : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		NParamReg : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		Params : OUT RF(0 to 63);

		reset_flag_reset : IN STD_LOGIC;
		reset_flag_cmd: IN STD_LOGIC;
		reset_flag_lcdenable: IN STD_LOGIC

	);
END RegisterFile;

ARCHITECTURE register_file_arch OF RegisterFile IS
	--signals
	signal registers : RF(0 to 70);

BEGIN
	-- Avalon slave write to registers.
	PROCESS (clk, nReset)

	variable temp_regs : RF(0 to 70);
	BEGIN
		IF nReset = '0' THEN
			temp_regs := (others=>(others=>'0'));
		ELSIF rising_edge(clk) THEN
			temp_regs := registers;
			IF write = '1' THEN
				CASE to_integer(unsigned(address)) IS
					--WHEN 0 to 3 => registers(to_integer(unsigned(address))) <= writedata;
					--WHEN 4 => registers(4) <= writedata(15 downto 3) & (writedata(2) and reset_flag_reset) & (writedata(1) and reset_flag_cmd) & (writedata(0) and reset_flag_lcdenable);
					WHEN 0 to 70 => temp_regs(to_integer(unsigned(address))) := writedata;
					WHEN OTHERS => NULL;
				END CASE;
			END IF;

			if reset_flag_cmd = '0' then
				temp_regs(4)(1) := '0';
			END IF;
			if reset_flag_reset= '0' then
				temp_regs(4)(2) := '0';
			END IF;
			if reset_flag_lcdenable = '0' then
				temp_regs(4)(0) := '0';
			END IF;
			registers <= temp_regs;
		END IF;
	END PROCESS;

	-- Avalon slave read from registers.
	PROCESS (clk)
	BEGIN
		IF rising_edge(clk) THEN
			readdata <= (OTHERS => '0');
			IF read = '1' THEN
				CASE to_integer(unsigned(address)) IS
					WHEN 0 to 70 => readdata <= registers(to_integer(unsigned(address)));
					WHEN OTHERS => NULL;
				END CASE;
			END IF;
		END IF;
	END PROCESS;

	-- Write Register Content to Output
	--PROCESS (clk, nReset)
	--BEGIN
		--IF rising_edge(clk) THEN
			-- TODO: check this concatenation
			--ImageAddress <= registers(0) & registers(1);
			--ImageLength <= registers(2) & registers(3);
			--Flags <= registers(4);
			--CommandReg <= registers(5); 
			--NParamReg <= registers(6);
			--Params <= registers(7 to 70); 
	--END IF;
	--END PROCESS;

	--registers(4)(1) <= registers(4)(1) and reset_flag_cmd;
	--registers(4)(2) <= registers(4)(2) and reset_flag_reset; 
	--registers(4)(0) <= registers(4)(0) and reset_flag_lcdenable; 

	ImageAddress <= registers(1) & registers(0);
	ImageLength <= registers(3) & registers(2);
	Flags <= registers(4);
	CommandReg <= registers(5); 
	NParamReg <= registers(6);
	Params <= registers(7 to 70); 
	

END ;
