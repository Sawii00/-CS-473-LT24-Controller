LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use work.register_file_pkg.all;

ENTITY DMAController IS

	PORT (

		-- Global signals
		clk : IN STD_LOGIC;
		nReset : IN STD_LOGIC;

		-- Signals From Register File

		Flags : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		ImageAddress : IN STD_LOGIC_VECTOR(31 downto 0);
		ImageLength : IN STD_LOGIC_VECTOR(31 downto 0);

		-- Active low signal to reset Flags(0) lcd_enable of the register file
		reset_flag_lcdenable : OUT STD_LOGIC;

		-- Avalon Master
		address : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
		read : OUT STD_LOGIC;
		readdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		readdatavalid : IN STD_LOGIC;
		waitRequest : IN STD_LOGIC;
		burstcount : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);


		-- Output signals to FIFO
		data : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		wrreq : OUT STD_LOGIC;
		almost_full : IN STD_LOGIC

		-- DEBUG
		--cnt_addr : OUT unsigned(31 downto 0);
		--cnt_len : OUT unsigned(31 downto 0);
        --dma_state_out : OUT DMAState
	);

END DMAController;

ARCHITECTURE dma_control_arch OF DMAController IS
	signal CurrentAddr : unsigned (31 downto 0); -- Contains the current address at which we are currently reading
	signal CurrentLen : unsigned (31 downto 0); -- Contains the current number of bytes left to read from memory
	signal current_burst : unsigned (15 downto 0); -- Contains the current burst counter to keep track of the progress
	constant N : std_logic_vector(4 downto 0) := "10000";
	signal state : DMAState;
BEGIN

	data <= readdata; -- readdata is directly assigned to data to insert values into the FIFO
	wrreq <= readdatavalid; -- wrreq can be set to readdatavalid since we are inserting every pixel received
	
	-- Avalon Master Read.
	PROCESS (clk, nReset, almost_full, waitRequest, readdatavalid, readdata, Flags, ImageAddress, ImageLength)
	BEGIN
		IF nReset = '0' THEN
			CurrentAddr <= (others => '0');
			CurrentLen <= (others => '0');
			state <= Idle;
			current_burst <= x"0001";
			reset_flag_lcdenable <= '1';
		ELSIF rising_edge(clk) THEN
				case state is
					when Idle =>
						reset_flag_lcdenable <= '1';
						CurrentAddr <= unsigned(ImageAddress);
						CurrentLen <= unsigned(ImageLength);
						-- Flags(0) is LCD_enable
						if Flags(0) = '1' and ImageLength /= x"00000000" then
							state <= WaitFifo;
						end if;
					when WaitFifo =>
						-- We check that there is enough space to fit an entire burst of 16 words
						if almost_full = '0' then
							state <= Request;
							read <= '1';
							burstcount <= std_logic_vector(N);
							address <= std_logic_vector(CurrentAddr);
						end if;
					when Request =>
						-- We initialize the counter of the current number of words read within the burst
						current_burst <= x"0001";
						-- When the bus is granted we start waiting for data
						if waitRequest = '0' then
							state <= WaitData;
							read <= '0';
						end if;
					when WaitData =>
						if readdatavalid = '1' then
							-- We read words of 2 bytes, so we must increment the address (byte-addressed) by 2
							CurrentAddr <= CurrentAddr + 2;
							CurrentLen <= CurrentLen - 2;
							current_burst <= current_burst + 1;
						end if;
						-- When we finish an entire burst we check if the image is done in CheckData
						if current_burst = unsigned(N) then
							state <= CheckData;
						end if;
					when CheckData =>
						-- Check if image is finished
						if CurrentLen = 0 then
							state <= ResetFlag;
							-- Resetting the lcdenable flag 
							reset_flag_lcdenable <= '0';
						else 
							-- We still have more bursts to go, so we transition back to WaitFifo
							state <= WaitFifo;
						end if;
					when ResetFlag =>
						state <= Idle;
				end case;
			
		END IF;
	END PROCESS;

	--dma_state_out <= state;
	--cnt_addr <= CurrentAddr;
	--cnt_len <= CurrentLen;

END dma_control_arch;