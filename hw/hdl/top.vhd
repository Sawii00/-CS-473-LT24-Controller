LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.register_file_pkg.ALL;
ENTITY TOP IS
	PORT (
		--GLOBAL
		clk    : IN STD_LOGIC;
		nReset : IN STD_LOGIC;

		-- Avalon Master
		address       : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		read          : OUT STD_LOGIC;
		readdata      : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		readdatavalid : IN STD_LOGIC;
		waitRequest   : IN STD_LOGIC;
		burstcount    : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
		--AVALON SLAVE
		address_slave  : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
		write          : IN STD_LOGIC;
		read_slave     : IN STD_LOGIC;
		writedata      : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		readdata_slave : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);

		--LCD
		D    : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		D_CX : OUT STD_LOGIC;
		WRX  : OUT STD_LOGIC;
		CSX  : OUT STD_LOGIC;
		RESX : OUT STD_LOGIC

	);
END TOP;

ARCHITECTURE A OF TOP IS
	COMPONENT LCDController
		PORT (
			-- Global signals
			clk    : IN STD_LOGIC;
			nReset : IN STD_LOGIC;

			-- Signals From Register File
			ImageLength      : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			Flags            : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
			CommandReg       : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
			NParamReg        : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
			Params           : IN RF;

			reset_flag_reset : OUT STD_LOGIC;
			reset_flag_cmd   : OUT STD_LOGIC;

			-- Input Signals from FIFO
			q     : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
			rdreq : OUT STD_LOGIC;
			empty : IN STD_LOGIC;

			-- Outputs to GPIO
			D    : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			D_CX : OUT STD_LOGIC;
			WRX  : OUT STD_LOGIC;
			CSX  : OUT STD_LOGIC;
			RESX : OUT STD_LOGIC
		);
	END COMPONENT;

	COMPONENT DMAController
		PORT (

			-- Global signals
			clk    : IN STD_LOGIC;
			nReset : IN STD_LOGIC;

			-- Signals From Register File
			Flags                : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
			ImageAddress         : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			ImageLength          : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
			reset_flag_lcdenable : OUT STD_LOGIC;

			-- Avalon Master
			address       : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			read          : OUT STD_LOGIC;
			readdata      : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
			readdatavalid : IN STD_LOGIC;
			waitRequest   : IN STD_LOGIC;
			burstcount    : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);

			-- Output signals to FIFO
			data        : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			wrreq       : OUT STD_LOGIC;
			almost_full : IN STD_LOGIC
		);

	END COMPONENT;

	COMPONENT RegisterFile
		PORT (
			clk    : IN STD_LOGIC;
			nReset : IN STD_LOGIC;
			-- Internal interface (i.e. Avalon slave).
			address   : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
			write     : IN STD_LOGIC;
			read      : IN STD_LOGIC;
			writedata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
			readdata  : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);

			--output registers for DMA and LCDController
			ImageAddress         : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			ImageLength          : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
			Flags                : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			CommandReg           : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			NParamReg            : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			Params               : OUT RF;

			reset_flag_reset     : IN STD_LOGIC;
			reset_flag_cmd       : IN STD_LOGIC;
			reset_flag_lcdenable : IN STD_LOGIC
		);
	END COMPONENT;

	COMPONENT fifo
		PORT (
			clock       : IN STD_LOGIC;
			data        : IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			rdreq       : IN STD_LOGIC;
			wrreq       : IN STD_LOGIC;
			almost_full : OUT STD_LOGIC;
			empty       : OUT STD_LOGIC;
			q           : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
			aclr        : IN STD_LOGIC
		);
	END COMPONENT;

	SIGNAL ImageLength_temp          : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL Flags_temp                : STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL ImageAddress_temp         : STD_LOGIC_VECTOR(31 DOWNTO 0);
	SIGNAL CommandReg_temp           : STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL NParamReg_temp            : STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL Params_temp               : RF(0 TO 63);
	SIGNAL reset_flag_reset_temp     : STD_LOGIC;
	SIGNAL reset_flag_cmd_temp       : STD_LOGIC;
	SIGNAL reset_flag_lcdenable_temp : STD_LOGIC;

	SIGNAL data_tmp                  : std_logic_vector(15 DOWNTO 0);
	SIGNAL wrreq_tmp                 : std_logic;
	SIGNAL rdreq_tmp                 : std_logic;
	SIGNAL almost_full_tmp           : std_logic;
	SIGNAL empty_tmp                 : std_logic;
	SIGNAL q_tmp                     : std_logic_vector(15 DOWNTO 0);

	SIGNAL resetFifo                 : std_logic; -- FIFO has active high asynchronous flush

BEGIN
	registerfile_instance : COMPONENT RegisterFile
	PORT MAP(
		clk                  => clk, 
		nReset               => nReset, 
		address              => address_slave, --top -> register file
		write                => write, --top -> register file
		read                 => read_slave, --top -> register file
		writedata            => writedata, --top -> register file
		readdata             => readdata_slave, --register file -> register file
		ImageAddress         => ImageAddress_temp, -- register file -> dma
		ImageLength          => ImageLength_temp, --register file -> dma, register file -> lcd
		Flags                => Flags_temp, --register file -> dma, register file -> lcd
		CommandReg           => CommandReg_temp, --register file -> lcd
		NParamReg            => NParamReg_temp, --register file -> lcd
		Params               => Params_temp, --register file -> lcd
		reset_flag_reset     => reset_flag_reset_temp, -- lcd controller -> regfile
		reset_flag_cmd       => reset_flag_cmd_temp, --lcd controller -> register file
		reset_flag_lcdenable => reset_flag_lcdenable_temp --dma -> register file
	);
 
	resetFifo <= NOT nReset;
 
	fifo_instance : COMPONENT fifo
	PORT MAP(
		clock       => clk, 
		data        => data_tmp, -- data is the output of dma controller towards fifo
		wrreq       => wrreq_tmp, -- wrreq is the output of dma controller
		rdreq       => rdreq_tmp, -- rdreq is the output of lcd controller
		almost_full => almost_full_tmp, --almost full is the input in dma controller
		empty       => empty_tmp, --lcd -> fifo
		aclr        => resetFifo, 
		q           => q_tmp --fifo -> lcd 
	);
 
	dma_instance : COMPONENT DMAController
	PORT MAP(
		clk                  => clk, 
		nReset               => nReset, 
		Flags                => Flags_temp, --register file -> dma
		ImageAddress         => ImageAddress_temp, -- register file -> dma
		ImageLength          => ImageLength_temp, --register file -> dma
		reset_flag_lcdenable => reset_flag_lcdenable_temp, --dma -> register file
		address              => address, --dma -> top
		read                 => read, --dma -> top
		readdata             => readdata, --top -> dma
		readdatavalid        => readdatavalid, --top -> dma
		waitRequest          => waitRequest, --top -> dma
		burstcount           => burstcount, --dma ->top
		data                 => data_tmp, --dma -> fifo
		wrreq                => wrreq_tmp, --dma->fifo
		almost_full          => almost_full_tmp
	);

	lcd_instance : COMPONENT LCDController
	PORT MAP(
		clk              => clk, 
		nReset           => nReset, 
		ImageLength      => ImageLength_temp, --register file -> lcd
		Flags            => Flags_temp, -- register file -> lcd
		CommandReg       => CommandReg_temp, --register file -> lcd
		NParamReg        => NParamReg_temp, --register file -> lcd
		Params           => Params_temp, --register file -> lcd
		reset_flag_reset => reset_flag_reset_temp, -- lcd controller -> regfile
		reset_flag_cmd   => reset_flag_cmd_temp, --lcd controller -> register file
		q                => q_tmp, --fifo -> lcd
		rdreq            => rdreq_tmp, --lcd -> fifo
		empty            => empty_tmp, --fifo -> lcd
		D                => D, --lcd -> top
		D_CX             => D_CX, --lcd ->top
		WRX              => WRX, --lcd ->top
		CSX              => CSX, --lcd -> top
		RESX             => RESX
	);

END ARCHITECTURE A;