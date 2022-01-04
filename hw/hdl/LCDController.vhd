library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.register_file_pkg.all;

ENTITY LCDController IS

	PORT (
		-- Global signals
		clk : IN STD_LOGIC;
		nReset : IN STD_LOGIC;

		-- Signals From Register File
        ImageLength : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
		Flags : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		CommandReg : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		NParamReg : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		Params : IN RF(0 to 63);

        reset_flag_reset: OUT STD_LOGIC;
		reset_flag_cmd: OUT STD_LOGIC;

		-- Input Signals from FIFO
		q : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		rdreq : OUT STD_LOGIC;
		empty : IN STD_LOGIC;

        -- Outputs to GPIO
        D : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
        D_CX : OUT STD_LOGIC;
        WRX : OUT STD_LOGIC;
        CSX : OUT STD_LOGIC;
        RESX : OUT STD_LOGIC

        -- Debug
        --lcd_state_out : OUT LCDState

        );

    END LCDController;

    ARCHITECTURE lcd_controller_arch OF LCDController IS

        signal reset_counter : unsigned(31 downto 0); -- Used to keep track of time within the reset procedure
        signal k : unsigned(7 downto 0); -- Keeps track of the currently read parameter to be sent 
        signal cc4 : unsigned(2 downto 0); -- Used to enforce a delay before transitioning to next state
        signal BytesLeft : unsigned(31 downto 0); -- Number of bytes left to send to the display
        
        signal state : LCDState;
    BEGIN

    CSX <= '0'; -- We keep CSX to LOW to select the LT24

        -- LCD FSM.
    PROCESS (clk, nReset, state, Flags, CommandReg, NParamReg, Params, q, empty, ImageLength)
        variable bytes_left : unsigned(31 downto 0);

	BEGIN
        -- Flags(2) is the asynchronous reset flag that can be set via software by the NIOS
        IF Flags(2) = '1' and state /= Reset then 
            state <= Reset;
		elsIF nReset = '0' THEN
			state <= Idle;
            reset_counter <= x"00000000"; 
            D <= x"0000";
            D_CX <= '0';
            WRX <= '0';
            RESX <= '0';
            k <= x"00";
            cc4 <= "000";
            reset_flag_reset <= '1';
            reset_flag_cmd <= '1';
		ELSIF rising_edge(clk) THEN
            case state is 
                when Idle =>
                    WRX <= '0';
                    reset_flag_reset <= '1';
                    reset_flag_cmd <= '1';
                    if Flags(1) = '1' then
                        -- send_command is HIGH, we start sending the command
                        state <= ReadCmd;
                    elsif Flags(0) = '1' then
                        -- lcd_enable is HIGH, we start displaying
                        state <= IdleImageDisplay;
                    else
                        state <= Idle;
                    end if;
                when Reset =>
                    WRX <= '0';
                    if (reset_counter) < 50000 then
                        -- Wait for 1ms (50 MHz clock) with RESX HIGH
                        RESX <= '1';
                        reset_counter <= reset_counter + 1;
                        reset_flag_reset <= '1';
                        state <= Reset;
                    elsif  (reset_counter)< 550000 then
                        -- Wait for 10ms with RESX LOW
                        RESX <= '0';
                        reset_counter <= reset_counter + 1;
                        reset_flag_reset <= '1';
                        state <= Reset;
                    elsif (reset_counter) < 6550000 then
                        -- Wait for 120ms with RESX HIGH
                        RESX <= '1';
                        reset_counter <= reset_counter + 1;
                        reset_flag_reset <= '1';
                        state <= Reset;
                    elsif (reset_counter) = 6550000 then
                        RESX <= '1';
                        reset_flag_reset <= '0'; -- Reset the reset flag (Flags(2))
                        state <= Reset;
                        reset_counter <= reset_counter + 1;
                    else
                        RESX <= '1';
                        reset_flag_reset <= '0';
                        reset_counter <= x"00000000";
                        state <= Idle;
                    end if;
                when ReadCmd =>
                    D_CX <= '0';
                    WRX <= '0';
                    D <= CommandReg;
                    k <= x"00";
                    if (cc4) < 4 then
                        cc4 <= cc4 + 1;
                        state <= ReadCmd;
                    else
                        cc4 <= "000";
                        state <= Send;
                    end if;
                when Send =>
                    WRX <= '1';
                    -- We check if we have any parameter left to send
                    if k = unsigned(NParamReg) then
                        state <= ResetRegs;
                        cc4 <= "000";
                        reset_flag_cmd <= '0';  -- We should probably move this to the ResetRegs state 
                    elsif (cc4) < 4 then
                        cc4 <= cc4 + 1;
                        state <= Send;
                    else
                        cc4 <= "000";
                        state <= FetchParam;
                    end if;
                when FetchParam =>
                    D_CX <= '1';
                    WRX <= '0';
                    if (cc4) < 4 then
                        D <= Params(to_integer(k)); -- Extract the parameter to be sent
                        cc4 <= cc4 + 1;
                        state <= FetchParam;
                    else
                        state <= Send;
                        k <= k + 1; -- Increment the param index
                        cc4 <= "000";
                    end if;
                when ResetRegs =>
                    -- Transition state to keep WRX to HIGH for the usual delay when sending the last parameter
                    -- Without this, we would transition back to Idle and put WRX to 0 without respecting the time constraint
                    if cc4 < 4 then
                        cc4 <= cc4 + 1;
                        state <= ResetRegs;
                    else
                        cc4 <= "000";
                        state <= Idle;
                    end if;
                when IdleImageDisplay =>
                    WRX <= '0';
                    BytesLeft <= unsigned(ImageLength); -- Bytes to be sent to the display
                    if Flags(0) = '0' then
                        state <= Idle;
                    elsif empty = '0' then
                        -- There are pixels ready to be sent
                        state <= PutWriteCmd;
                    else
                        state <= IdleImageDisplay;
                    end if;
                when PutWriteCmd =>
                    -- We send the command 0x2C as a preamble to image data
                    WRX <= '0';
                    D_CX <= '0';
                    D <= x"002c";
                    if (cc4) < 4 then
                        state <= PutWriteCmd;
                        cc4 <= cc4 + 1;
                    else
                        state <= WritePixel;
                        cc4 <= "000";
                    end if;
                when WritePixel =>
                    WRX <= '1';
                    -- Check if we have sent the whole image
                    if BytesLeft = 0 then
                        rdreq <= '0';
                        if (cc4) < 4 then
                            state <= WritePixel;
                            cc4 <= cc4 + 1;
                        else
                            -- Transition back to IdleImageDisplay after usual delay
                            state <= IdleImageDisplay;
                            cc4 <= "000";
                        end if;
                    elsif empty = '0' then
                        -- We have pixels ready to be sent
                        if (cc4) < 4 then
                            cc4 <= cc4 + 1;
                            state <= WritePixel;
                        else
                            state <= PutPixel;
                            cc4 <= "000";
                            BytesLeft <= BytesLeft - 2; 
                        end if;
                    else
                        state <= WritePixel;
                        cc4 <= "000";
                    end if;
                when PutPixel =>
                    D_CX <= '1';
                    WRX <= '0';
                    if (cc4) < 2 then
                        cc4 <= cc4 + 1;
                        state <= PutPixel;
                        rdreq <= '0';
                    elsif (cc4) = 2 then
                        -- At the third cycle we request a word from the FIFO
                        cc4 <= cc4 + 1;
                        state <= PutPixel;
                        rdreq <= '1';
                    elsif (cc4) = 3 then
                        -- In this cycle the FIFO has read the request and provides the value onto the bus
                        cc4 <= cc4 + 1;
                        state <= PutPixel;
                        rdreq <= '0';
                    else
                        -- In this final cycle we have the value ready on the q bus
                        cc4 <= "000";
                        D <= q; 
                        state <= WritePixel;
                        rdreq <= '0';
                    end if;
            end case;
    	END IF;
	END PROCESS;

        --lcd_state_out <= state;
END lcd_controller_arch;
