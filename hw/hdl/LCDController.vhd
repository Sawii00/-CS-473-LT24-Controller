library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.register_file_pkg.all;

-- we need tri-state for flag registers
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
        --signals

        --NOTE: we might wanna duplicate the command value and n param registers to avoid the possibility that the user changes them mid execution
        signal reset_counter : unsigned(31 downto 0);
        signal k : unsigned(7 downto 0); 

        signal cc4 : unsigned(2 downto 0);

        signal BytesLeft : unsigned(31 downto 0);
        
        signal state : LCDState;
        signal last_val : std_logic;

    BEGIN

    CSX <= '0';

        -- LCD FSM.
    PROCESS (clk, nReset, state, Flags, CommandReg, NParamReg, Params, q, empty, ImageLength)
        variable bytes_left : unsigned(31 downto 0);

	BEGIN
        IF Flags(2) = '1' and state /= Reset then 
            state <= Reset;
		elsIF nReset = '0' THEN
			state <= Idle;
            reset_counter <= x"00000000"; 
            D <= x"0000";
            D_CX <= '0';
            WRX <= '0';
            --CSX <= '0';
            RESX <= '0';
            k <= x"00";
            cc4 <= "000";
            reset_flag_reset <= '1';
            reset_flag_cmd <= '1';
		ELSIF rising_edge(clk) THEN
            case state is 
                when Idle =>
                    --CSX <= '1';
                    WRX <= '0';
                    reset_flag_reset <= '1';
                    reset_flag_cmd <= '1';
                    if Flags(1) = '1' then
                        -- send_command is HIGH, we start sending the command
                        state <= ReadCmd;
                    elsif Flags(0) = '1' then
                        -- enable is HIGH, we start displaying
                        state <= IdleImageDisplay;
                    else
                        state <= Idle;
                    end if;
                when Reset =>
                    WRX <= '0';
                    if (reset_counter) < 50000 then
                        RESX <= '1';
                        reset_counter <= reset_counter + 1;
                        reset_flag_reset <= '1';
                        state <= Reset;
                    elsif  (reset_counter)< 550000 then
                        RESX <= '0';
                        reset_counter <= reset_counter + 1;
                        reset_flag_reset <= '1';
                        state <= Reset;
                    elsif (reset_counter) < 6550000 then
                        RESX <= '1';
                        reset_counter <= reset_counter + 1;
                        reset_flag_reset <= '1';
                        state <= Reset;
                    elsif (reset_counter) = 6550000 then
                        RESX <= '1';
                        reset_flag_reset <= '0';
                        state <= Reset;
                        reset_counter <= reset_counter + 1;
                    else
                        RESX <= '1';
                        reset_flag_reset <= '0';
                        reset_counter <= x"00000000";
                        state <= Idle;
                        --flush the FIFO: sclr <= '1';
                        --signal to dma to reset the state
                    end if;
                when ReadCmd =>
                    --CSX <= '0';
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
                    if k = unsigned(NParamReg) then
                        state <= ResetRegs;
                        cc4 <= "000";
                        reset_flag_cmd <= '0'; -- WE must clear it here or it comes 1 cycle too late
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
                        D <= Params(to_integer(k));
                        cc4 <= cc4 + 1;
                        state <= FetchParam;
                    else
                        state <= Send;
                        k <= k + 1;
                        cc4 <= "000";
                    end if;
                when ResetRegs =>
                --possibly make reset_flag_cmd = 1 here 
                    --WRX <= '0';
                    if cc4 < 4 then
                        cc4 <= cc4 + 1;
                        state <= ResetRegs;
                    else
                        cc4 <= "000";
                        state <= Idle;
                    end if;
                    -- I do not reset WRX because I would need to add the usual delay
                when IdleImageDisplay =>
                    WRX <= '0';
                    BytesLeft <= unsigned(ImageLength);
                    if Flags(0) = '0' then
                        state <= Idle;
                    elsif empty = '0' then
                        state <= PutWriteCmd;
                    else
                        state <= IdleImageDisplay;
                    end if;
                when PutWriteCmd =>
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
                    if BytesLeft = 0 then
                        rdreq <= '0';
                        if (cc4) < 4 then
                            state <= WritePixel;
                            cc4 <= cc4 + 1;
                        else
                            state <= IdleImageDisplay;
                            cc4 <= "000";
                        end if;
                    elsif empty = '0' then
                        if (cc4) < 4 then
                            cc4 <= cc4 + 1;
                            state <= WritePixel;
                        else
                            state <= PutPixel;
                            cc4 <= "000";
                            BytesLeft <= BytesLeft - 2; --potential problem here... we are decrementing even when we first send the command
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
                        cc4 <= cc4 + 1;
                        state <= PutPixel;
                        rdreq <= '1';
                    elsif (cc4) = 3 then
                        cc4 <= cc4 + 1;
                        state <= PutPixel;
                        rdreq <= '0';
                    else
                        cc4 <= "000";
                        D <= q; -- here or in the prev cycle???
                        state <= WritePixel;
                        rdreq <= '0';
                    end if;
            end case;
    	END IF;
	END PROCESS;

        --lcd_state_out <= state;
END lcd_controller_arch;
