LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.register_file_pkg.ALL;

ENTITY LCDController IS

	PORT (
		-- Global signals
		clk    : IN STD_LOGIC;
		nReset : IN STD_LOGIC;

		-- Signals From Register File
		ImageLength      : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		Flags            : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		CommandReg       : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		NParamReg        : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		Params           : IN RF(0 TO 63);

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

		-- Debug
		--lcd_state_out : OUT LCDState

	);

END LCDController;

ARCHITECTURE lcd_controller_arch OF LCDController IS

	SIGNAL reset_counter : unsigned(31 DOWNTO 0); -- Used to keep track of time within the reset procedure
	SIGNAL k             : unsigned(7 DOWNTO 0); -- Keeps track of the currently read parameter to be sent
	SIGNAL cc4           : unsigned(2 DOWNTO 0); -- Used to enforce a delay before transitioning to next state
	SIGNAL BytesLeft     : unsigned(31 DOWNTO 0); -- Number of bytes left to send to the display

	SIGNAL state         : LCDState;
BEGIN
	CSX <= '0'; -- We keep CSX to LOW to select the LT24

	-- LCD FSM.
	PROCESS (clk, nReset, state, Flags, CommandReg, NParamReg, Params, q, empty, ImageLength)
	VARIABLE bytes_left : unsigned(31 DOWNTO 0);

	BEGIN
		-- Flags(2) is the asynchronous reset flag that can be set via software by the NIOS
		IF Flags(2) = '1' AND state /= Reset THEN
			state <= Reset;
			--reset_counter <= x"00000000";
		ELSIF nReset = '0' THEN
			state            <= Idle;
			reset_counter    <= x"00000000";
			D                <= x"0000";
			D_CX             <= '0';
			WRX              <= '0';
			RESX             <= '0';
			k                <= x"00";
			cc4              <= "000";
			reset_flag_reset <= '1';
			reset_flag_cmd   <= '1';
		ELSIF rising_edge(clk) THEN
			CASE state IS
				WHEN Idle => 
					WRX              <= '0';
					reset_flag_reset <= '1';
					reset_flag_cmd   <= '1';
					IF Flags(1) = '1' THEN
						-- send_command is HIGH, we start sending the command
						state <= ReadCmd;
					ELSIF Flags(0) = '1' THEN
						-- lcd_enable is HIGH, we start displaying
						state <= IdleImageDisplay;
					ELSE
						state <= Idle;
					END IF;
				WHEN Reset => 
					WRX <= '0';
					IF (reset_counter) < 50000 THEN
						-- Wait for 1ms (50 MHz clock) with RESX HIGH
						RESX             <= '1';
						reset_counter    <= reset_counter + 1;
						reset_flag_reset <= '1';
						state            <= Reset;
					ELSIF (reset_counter) < 550000 THEN
						-- Wait for 10ms with RESX LOW
						RESX             <= '0';
						reset_counter    <= reset_counter + 1;
						reset_flag_reset <= '1';
						state            <= Reset;
					ELSIF (reset_counter) < 6550000 THEN
						-- Wait for 120ms with RESX HIGH
						RESX             <= '1';
						reset_counter    <= reset_counter + 1;
						reset_flag_reset <= '1';
						state            <= Reset;
					ELSIF (reset_counter) = 6550000 THEN
						RESX             <= '1';
						reset_flag_reset <= '0'; -- Reset the reset flag (Flags(2))
						state            <= Reset;
						reset_counter    <= reset_counter + 1;
					ELSE
						RESX             <= '1';
						reset_flag_reset <= '0';
						reset_counter    <= x"00000000";
						state            <= Idle;
					END IF;
				WHEN ReadCmd => 
					D_CX <= '0';
					WRX  <= '0';
					D    <= CommandReg;
					k    <= x"00";
					IF (cc4) < 4 THEN
						cc4   <= cc4 + 1;
						state <= ReadCmd;
					ELSE
						cc4   <= "000";
						state <= Send;
					END IF;
				WHEN Send => 
					WRX <= '1';
					-- We check if we have any parameter left to send
					IF k = unsigned(NParamReg) THEN
						state          <= ResetRegs;
						cc4            <= "000";
						reset_flag_cmd <= '0'; -- We should probably move this to the ResetRegs state
					ELSIF (cc4) < 4 THEN
						cc4   <= cc4 + 1;
						state <= Send;
					ELSE
						cc4   <= "000";
						state <= FetchParam;
					END IF;
				WHEN FetchParam => 
					D_CX <= '1';
					WRX  <= '0';
					IF (cc4) < 4 THEN
						D     <= Params(to_integer(k)); -- Extract the parameter to be sent
						cc4   <= cc4 + 1;
						state <= FetchParam;
					ELSE
						state <= Send;
						k     <= k + 1; -- Increment the param index
						cc4   <= "000";
					END IF;
				WHEN ResetRegs => 
					-- Transition state to keep WRX to HIGH for the usual delay when sending the last parameter
					-- Without this, we would transition back to Idle and put WRX to 0 without respecting the time constraint
					IF cc4 < 4 THEN
						cc4   <= cc4 + 1;
						state <= ResetRegs;
					ELSE
						cc4   <= "000";
						state <= Idle;
					END IF;
				WHEN IdleImageDisplay => 
					WRX       <= '0';
					BytesLeft <= unsigned(ImageLength); -- Bytes to be sent to the display
					IF Flags(0) = '0' THEN
						state <= Idle;
					ELSIF empty = '0' THEN
						-- There are pixels ready to be sent
						state <= PutWriteCmd;
					ELSE
						state <= IdleImageDisplay;
					END IF;
				WHEN PutWriteCmd => 
					-- We send the command 0x2C as a preamble to image data
					WRX  <= '0';
					D_CX <= '0';
					D    <= x"002c";
					IF (cc4) < 4 THEN
						state <= PutWriteCmd;
						cc4   <= cc4 + 1;
					ELSE
						state <= WritePixel;
						cc4   <= "000";
					END IF;
				WHEN WritePixel => 
					WRX <= '1';
					-- Check if we have sent the whole image
					IF BytesLeft = 0 THEN
						rdreq <= '0';
						IF (cc4) < 4 THEN
							state <= WritePixel;
							cc4   <= cc4 + 1;
						ELSE
							-- Transition back to IdleImageDisplay after usual delay
							state <= IdleImageDisplay;
							cc4   <= "000";
						END IF;
					ELSIF empty = '0' THEN
						-- We have pixels ready to be sent
						IF (cc4) < 4 THEN
							cc4   <= cc4 + 1;
							state <= WritePixel;
						ELSE
							state     <= PutPixel;
							cc4       <= "000";
							BytesLeft <= BytesLeft - 2;
						END IF;
					ELSE
						state <= WritePixel;
						cc4   <= "000";
					END IF;
				WHEN PutPixel => 
					D_CX <= '1';
					WRX  <= '0';
					IF (cc4) < 2 THEN
						cc4   <= cc4 + 1;
						state <= PutPixel;
						rdreq <= '0';
					ELSIF (cc4) = 2 THEN
						-- At the third cycle we request a word from the FIFO
						cc4   <= cc4 + 1;
						state <= PutPixel;
						rdreq <= '1';
					ELSIF (cc4) = 3 THEN
						-- In this cycle the FIFO has read the request and provides the value onto the bus
						cc4   <= cc4 + 1;
						state <= PutPixel;
						rdreq <= '0';
					ELSE
						-- In this final cycle we have the value ready on the q bus
						cc4   <= "000";
						D     <= q;
						state <= WritePixel;
						rdreq <= '0';
					END IF;
			END CASE;
		END IF;
	END PROCESS;

	--lcd_state_out <= state;
END lcd_controller_arch;