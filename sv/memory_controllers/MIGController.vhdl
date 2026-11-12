library xpm;
use xpm.vcomponents.all;

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.NUMERIC_STD.all;

entity MMIGController_v1_0_0 is
    port (
        PIWriteClk        : in std_logic;
        PIReadClk         : in std_logic;
        -----AXI-----
        ----Write
        POAxiSlaveWrReady : out std_logic;
        PIAxiSlaveWrValid : in std_logic;
        PIAxiSlaveWrAddr  : in std_logic_vector(24 downto 0);
        PIAxiSlaveWrData  : in std_logic_vector(127 downto 0);
        ----Read
        --Slave
        POAxiSlaveRdReady : out std_logic;
        PIAxiSlaveRdValid : in std_logic;
        PIAxiSlaveRdAddr  : in std_logic_vector(24 downto 0);
        --Master
        PIAxiMasterRdReady : in std_logic;
        POAxiMasterRdValid : out std_logic;
        POAxiMasterRdData  : out std_logic_vector(127 downto 0);

        -----app-----
        PIAppRdy  : in std_logic;
        POAppEn   : out std_logic;
        POAppAddr : out std_logic_vector(24 downto 0);
        POAppCmd  : out std_logic_vector(2 downto 0);

        PIAppWrRdy  : in std_logic;
        POAppWrEn   : out std_logic;
        POAppWrData : out std_logic_vector(127 downto 0);
        POAppWrEnd  : out std_logic;
        POAppWrMask : out std_logic_vector(15 downto 0);

        PIAppRdDataValid : in std_logic;
        PIAppRdData      : in std_logic_vector(127 downto 0);
        PIAppRdDataEnd   : in std_logic;

        POAppSrReq    : out std_logic;
        POAppRefReq   : out std_logic;
        POAppZqReq    : out std_logic;
        PIAppSrActive : in std_logic;
        PIappRefAck   : in std_logic;
        PIAppZqAck    : in std_logic;

        PIUiClk        : in std_logic;
        PIUiClkSyncRst : in std_logic
    );
end MMIGController_v1_0_0;

architecture Behavioral of MMIGController_v1_0_0 is
    ----AXI
    --Write
    signal SAxiSlaveWrReady : std_logic;
    signal SAxiSlaveWrValid : std_logic;
    signal SAxiSlaveWrAddr  : std_logic_vector(24 downto 0);
    signal SAxiSlaveWrData  : std_logic_vector(127 downto 0);
    --Slave Read
    signal SAxiSlaveRdReady : std_logic;
    signal SAxiSlaveRdValid : std_logic;
    signal SAxiSlaveRdAddr  : std_logic_vector(24 downto 0);
    --Master Read
    signal SAxiMasterRdReady : std_logic                      := '0';
    signal SAxiMasterRdValid : std_logic                      := '0';
    signal SAxiMasterRdData  : std_logic_vector(127 downto 0) := (others => '0');
    ---SYNC FIFO Write
    --Slave
    signal SWrSyncFifoSlaveReady : std_logic                      := '0';
    signal SWrSyncFifoSlaveValid : std_logic                      := '0';
    signal SWrSyncFifoSlaveAddr  : std_logic_vector(24 downto 0)  := (others => '0');
    signal SWrSyncFifoSlaveData  : std_logic_vector(127 downto 0) := (others => '0');
    --Master
    signal SWrSyncFifoMasterReady : std_logic                      := '0';
    signal SWrSyncFifoMasterValid : std_logic                      := '0';
    signal SWrSyncFifoMasterAddr  : std_logic_vector(24 downto 0)  := (others => '0');
    signal SWrSyncFifoMasterData  : std_logic_vector(127 downto 0) := (others => '0');
    ---SYNC FIFO Slave Read
    --Slave
    signal SSlaveRdSyncFifoSlaveReady : std_logic                     := '0';
    signal SSlaveRdSyncFifoSlaveValid : std_logic                     := '0';
    signal SSlaveRdSyncFifoSlaveAddr  : std_logic_vector(24 downto 0) := (others => '0');
    --Master
    signal SSlaveRdSyncFifoMasterReady : std_logic                     := '0';
    signal SSlaveRdSyncFifoMasterValid : std_logic                     := '0';
    signal SSlaveRdSyncFifoMasterAddr  : std_logic_vector(24 downto 0) := (others => '0');
    ----SYNC FIFO Master Read
    --Slave
    signal SMasterRdSyncFifoSlaveReady : std_logic                      := '0';
    signal SMasterRdSyncFifoSlaveValid : std_logic                      := '0';
    signal SMasterRdSyncFifoSlaveData  : std_logic_vector(127 downto 0) := (others => '0');
    --Master
    signal SMasterRdSyncFifoMasterReady : std_logic                      := '0';
    signal SMasterRdSyncFifoMasterValid : std_logic                      := '0';
    signal SMasterRdSyncFifoMasterData  : std_logic_vector(127 downto 0) := (others => '0');
    ---Buffer FIFO Master Read
    --Slave
    signal SMasterRdBufferFifoSlaveReady : std_logic                      := '0';
    signal SMasterRdBufferFifoSlaveValid : std_logic                      := '0';
    signal SMasterRdBufferFifoSlaveData  : std_logic_vector(127 downto 0) := (others => '0');
    --Master
    signal SMasterRdBufferFifoMasterReady : std_logic                      := '0';
    signal SMasterRdBufferFifoMasterValid : std_logic                      := '0';
    signal SMasterRdBufferFifoMasterData  : std_logic_vector(127 downto 0) := (others => '0');
    --APP Interface
    signal SAppAddr        : std_logic_vector(24 downto 0)  := (others => '0');
    signal SAppCmd         : std_logic_vector(2 downto 0)   := (others => '0');
    signal SAppEn          : std_logic                      := '0';
    signal SAppRdy         : std_logic                      := '0';
    signal SAppWrData      : std_logic_vector(127 downto 0) := (others => '0');
    signal SAppWrEnd       : std_logic                      := '1';
    signal SAppWrEn        : std_logic                      := '0';
    signal SAppWrRdy       : std_logic                      := '0';
    signal SAppRdData      : std_logic_vector(127 downto 0) := (others => '0');
    signal SAppWrMask      : std_logic_vector(15 downto 0)  := (others => '0');
    signal SAppRdDataEnd   : std_logic                      := '0';
    signal SAppRdDataValid : std_logic                      := '0';
    signal SAppSrReq       : std_logic                      := '0';
    signal SAppRefReq      : std_logic                      := '0';
    signal SAppZqReq       : std_logic                      := '0';
    signal SAppSrActive    : std_logic                      := '0';
    signal SAppRefAck      : std_logic                      := '0';
    signal SAppZqAck       : std_logic                      := '0';

    signal SUiClkSyncRst                : std_logic := '1';
    signal SUiClk                       : std_logic := '0';
    signal SUiClkSyncRstNSyncWriteClock : std_logic := '0';
    signal SUiClkSyncRstNSyncReadClock  : std_logic := '0';

    signal SWriteWaitingFlag : std_logic                      := '0';
    signal SReadFIFOFullFlag : std_logic                      := '0';
    signal SReadInCounter    : std_logic_vector(7 downto 0)   := (others => '0');
    signal SReadOutCounter   : std_logic_vector(7 downto 0)   := (others => '0');
    signal SWriteWaitingAddr : std_logic_vector(24 downto 0)  := (others => '0');
    signal SWriteWaitingData : std_logic_vector(127 downto 0) := (others => '0');

begin

    SUiClk        <= PIUiClk;
    SUiClkSyncRst <= PIUiClkSyncRst;

    --APP INTERFACE
    POAppAddr       <= SAppAddr;
    POAppCmd        <= SAppCmd;
    POAppEn         <= SAppEn;
    SAppRdy         <= PIAppRdy;
    SAppWrRdy       <= PIAppWrRdy;
    POAppWrEn       <= SAppWrEn;
    POAppWrData     <= SAppWrData;
    POAppWrEnd      <= SAppWrEnd;
    POAppWrMask     <= SAppWrMask;
    SAppRdDataValid <= PIAppRdDataValid;
    SAppRdData      <= PIAppRdData;
    SAppRdDataEnd   <= PIAppRdDataEnd;
    POAppSrReq      <= SAppSrReq;
    POAppRefReq     <= SAppRefReq;
    POAppZqReq      <= SAppZqReq;
    SAppSrActive    <= PIAppSrActive;
    SappRefAck      <= PIappRefAck;
    SAppZqAck       <= PIAppZqAck;

    --AXI INTERFACE
    POAxiSlaveWrReady <= SAxiSlaveWrReady;
    SAxiSlaveWrValid  <= PIAxiSlaveWrValid;
    SAxiSlaveWrAddr   <= PIAxiSlaveWrAddr;
    SAxiSlaveWrData   <= PIAxiSlaveWrData;

    POAxiSlaveRdReady <= SAxiSlaveRdReady;
    SAxiSlaveRdValid  <= PIAxiSlaveRdValid;
    SAxiSlaveRdAddr   <= PIAxiSlaveRdAddr;

    POAxiMasterRdValid <= SAxiMasterRdValid;
    SAxiMasterRdReady  <= PIAxiMasterRdReady;
    POAxiMasterRdData  <= SAxiMasterRdData;

    --Write Sync Fifo Slave
    SWrSyncFifoSlaveValid <= SAxiSlaveWrValid;
    SAxiSlaveWrReady      <= SWrSyncFifoSlaveReady and SUiClkSyncRstNSyncWriteClock;
    SWrSyncFifoSlaveAddr  <= SAxiSlaveWrAddr;
    SWrSyncFifoSlaveData  <= SAxiSlaveWrData;

    --Slave Read Sync Fifo Slave
    SSlaveRdSyncFifoSlaveValid <= SAxiSlaveRdValid;
    SAxiSlaveRdReady           <= SSlaveRdSyncFifoSlaveReady and SUiClkSyncRstNSyncReadClock;
    SSlaveRdSyncFifoSlaveAddr  <= SAxiSlaveRdAddr;

    --Connections between Master Read Buffer and Master Read SYNC Fifo
    SMasterRdSyncFifoSlaveValid    <= SMasterRdBufferFifoMasterValid;
    SMasterRdBufferFifoMasterReady <= SMasterRdSyncFifoSlaveReady;
    SMasterRdSyncFifoSlaveData     <= SMasterRdBufferFifoMasterData;

    --Master Read Sync Fifo Master (connected with AXI)
    SAxiMasterRdValid            <= SMasterRdSyncFifoMasterValid;
    SMasterRdSyncFifoMasterReady <= SAxiMasterRdReady;
    SAxiMasterRdData             <= SMasterRdSyncFifoMasterData;

    --Ready signals that with App Interface between Sync Fifo Master
    SWrSyncFifoMasterReady      <= (SAppRdy or not(SAppEn)) and (SAppWrRdy or not(SAppWrEn)) and not(SWriteWaitingFlag);
    SSlaveRdSyncFifoMasterReady <= (SAppRdy or not(SAppEn)) and (SAppWrRdy or not(SAppWrEn)) and not(SWriteWaitingFlag) and not(SReadFIFOFullFlag);

    LUiClkSyncRstNSyncWriteClock : xpm_cdc_single
    generic map(
        DEST_SYNC_FF   => 4, -- DECIMAL; range: 2-10
        INIT_SYNC_FF   => 1, -- DECIMAL; 0=disable simulation init values, 1=enable simulation init values
        SIM_ASSERT_CHK => 0, -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        SRC_INPUT_REG  => 1  -- DECIMAL; 0=do not register input, 1=register input
    )
    port map(
        dest_out => SUiClkSyncRstNSyncWriteClock, -- 1-bit output: src_in synchronized to the destination clock domain. This output
        -- is registered.

        dest_clk => PIWriteClk,        -- 1-bit input: Clock signal for the destination clock domain.
        src_clk  => SUiClk,            -- 1-bit input: optional; required when SRC_INPUT_REG = 1
        src_in   => not(SUiClkSyncRst) -- 1-bit input: Input signal to be synchronized to dest_clk domain.
    );

    LUiClkSyncRstNSyncReadClock : xpm_cdc_single
    generic map(
        DEST_SYNC_FF   => 4, -- DECIMAL; range: 2-10
        INIT_SYNC_FF   => 1, -- DECIMAL; 0=disable simulation init values, 1=enable simulation init values
        SIM_ASSERT_CHK => 0, -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        SRC_INPUT_REG  => 1  -- DECIMAL; 0=do not register input, 1=register input
    )
    port map(
        dest_out => SUiClkSyncRstNSyncReadClock, -- 1-bit output: src_in synchronized to the destination clock domain. This output
        -- is registered.

        dest_clk => PIReadClk,        -- 1-bit input: Clock signal for the destination clock domain.
        src_clk  => SUiClk,            -- 1-bit input: optional; required when SRC_INPUT_REG = 1
        src_in   => not(SUiClkSyncRst) -- 1-bit input: Input signal to be synchronized to dest_clk domain.
    );


    SlaveWriteReadProc : process (SUiClk) --1.process (slave write-read)
    begin
        if (rising_edge(SUiClk)) then

            if ((SAppRdy or not(SAppEn)) = '1') then
                if ((SWrSyncFifoMasterValid and SWrSyncFifoMasterReady and SSlaveRdSyncFifoMasterValid and SSlaveRdSyncFifoMasterReady) = '1') then --wr ve rd ayni anda gelirse
                    SWriteWaitingFlag <= '1';
                    SWriteWaitingAddr <= SWrSyncFifoMasterAddr; --rd komutunu beklerken gelen data'nin kaybolmamasi icin adres register'da saklanir.
                elsif (SWriteWaitingFlag and SAppEn and SAppRdy) = '1' then
                    SWriteWaitingFlag <= '0';
                end if;

                -- write ve read icin adres yonetimi
                if (SAppWrEn = '1' and SAppWrRdy = '0') then --wr komutunda adres gonderildikten sonra datanin gonderilmesini beklemek gerekirse
                    SAppAddr <= (others => '0');
                    SAppEn   <= '0';
                    SAppCmd  <= "000";
                elsif (SWriteWaitingFlag and SAppEn and SAppRdy) = '1' then --wr valid ve rd valid ayni anda geldikten sonra rd komutu gittikten sonra
                    SAppAddr <= SWriteWaitingAddr;
                    SAppEn   <= '1';
                    SAppCmd  <= "000";
                elsif (SSlaveRdSyncFifoMasterValid and SSlaveRdSyncFifoMasterReady) = '1' then --wr valid yok iken rd gelirse
                    SAppAddr <= SSlaveRdSyncFifoMasterAddr;
                    SAppEn   <= '1';
                    SAppCmd  <= "001";
                elsif (SWrSyncFifoMasterValid and SWrSyncFifoMasterReady) = '1' then --wr valid geldiyse
                    SAppAddr <= SWrSyncFifoMasterAddr;
                    SAppEn   <= '1';
                    SAppCmd  <= "000";
                else
                    SAppAddr <= SAppAddr;
                    SAppEn   <= '0';
                    SAppCmd  <= SAppCmd;
                end if;
            else
                SAppEn            <= SAppEn;
                SAppAddr          <= SAppAddr;
                SAppCmd           <= SAppCmd;
                SWriteWaitingAddr <= SWriteWaitingAddr;
                SWriteWaitingFlag <= SWriteWaitingFlag;
            end if;

            -- write icin data yonetimi
            if ((SAppWrRdy or not(SAppWrEn)) = '1') then
                if (SAppEn = '1' and SAppRdy = '0') then
                    SAppWrEn   <= '0';
                    SAppWrData <= SAppWrData;
                elsif ((SWrSyncFifoMasterValid and SWrSyncFifoMasterReady and SSlaveRdSyncFifoMasterValid and SSlaveRdSyncFifoMasterReady) = '1') then --wr ve rd ayni anda gelirse
                    SAppWrEn          <= '0';
                    SWriteWaitingData <= SWrSyncFifoMasterData; --rd komutunu beklerken gelen data'nin kaybolmamasi icin data register'da saklanir.
                    SAppWrData        <= SAppWrData;
                elsif (SWriteWaitingFlag and SAppEn and SAppRdy) = '1' then --wr valid ve rd valid ayni anda geldikten sonra rd komutu gittikten sonra
                    SAppWrEn   <= '1';
                    SAppWrData <= SWriteWaitingData;
                else
                    SAppWrEn   <= SWrSyncFifoMasterValid and SWrSyncFifoMasterReady;
                    SAppWrData <= SWrSyncFifoMasterData;
                end if;
            else
                SAppWrEn   <= SAppWrEn;
                SAppWrData <= SAppWrData;
            end if;
        end if;
    end process;

    MasterReadProc : process (SUiClk) --2.process (master read)
    begin
        if (rising_edge(SUiClk)) then
            if ((SMasterRdBufferFifoSlaveReady or not(SMasterRdBufferFifoSlaveValid)) = '1') then
                SMasterRdBufferFifoSlaveValid <= SAppRdDataValid;
                SMasterRdBufferFifoSlaveData  <= SAppRdData;
            else
                SMasterRdBufferFifoSlaveValid <= SMasterRdBufferFifoSlaveValid;
                SMasterRdBufferFifoSlaveData  <= SMasterRdBufferFifoSlaveData;
            end if;
        end if;
    end process;

    ReadInCountProc : process (SUiClk)
    begin
        if (rising_edge(SUiClk)) then
            if (SSlaveRdSyncFifoMasterValid and SSlaveRdSyncFifoMasterReady) = '1' then
                SReadInCounter <= SReadInCounter + 1;
            else
                SReadInCounter <= SReadInCounter;
            end if;
        end if;
    end process;

    ReadOutCountProc : process (SUiClk)
    begin
        if (rising_edge(SUiClk)) then
            if (SMasterRdBufferFifoMasterValid and SMasterRdBufferFifoMasterReady) = '1' then
                SReadOutCounter <= SReadOutCounter + 1;
            else
                SReadOutCounter <= SReadOutCounter;
            end if;
        end if;
    end process;

    ReadFifoFullFlagProc : process (SUiClk)
    begin
        if (rising_edge(SUiClk)) then
            if (SReadInCounter + 1 = SReadOutCounter) then
                SReadFIFOFullFlag <= '1';
            elsif (SReadInCounter + 2 = SReadOutCounter) then
                SReadFIFOFullFlag <= '1';
            else
                SReadFIFOFullFlag <= '0';
            end if;
        end if;
    end process;

    LSlaveWriteSyncFifo : xpm_fifo_axis
    generic map(
        CDC_SYNC_STAGES => 2,                   -- DECIMAL
        CLOCKING_MODE   => "independent_clock", -- String
        FIFO_DEPTH      => 16,                  -- DECIMAL
        PACKET_FIFO     => "false",             -- String
        TDATA_WIDTH     => 128,                 -- DECIMAL
        TUSER_WIDTH     => 25                   -- DECIMAL
    )
    port map(
        m_aclk             => SUiClk,
        s_aclk             => PIWriteClk,
        s_aresetn          => SUiClkSyncRstNSyncWriteClock,
        m_axis_tready      => SWrSyncFifoMasterReady, --input
        m_axis_tvalid      => SWrSyncFifoMasterValid, --output
        m_axis_tdata       => SWrSyncFifoMasterData,  --output
        m_axis_tuser       => SWrSyncFifoMasterAddr,  --output
        s_axis_tready      => SWrSyncFifoSlaveReady,  --output
        s_axis_tvalid      => SWrSyncFifoSlaveValid,  --input
        s_axis_tdata       => SWrSyncFifoSlaveData,   --input
        s_axis_tuser       => SWrSyncFifoSlaveAddr,   --input
        s_axis_tlast       => '1',
        almost_empty_axis  => open,
        almost_full_axis   => open,
        dbiterr_axis       => open,
        m_axis_tlast       => open,
        m_axis_tdest       => open,
        m_axis_tid         => open,
        m_axis_tkeep       => open,
        m_axis_tstrb       => open,
        prog_empty_axis    => open,
        prog_full_axis     => open,
        rd_data_count_axis => open,
        sbiterr_axis       => open,
        wr_data_count_axis => open,
        injectdbiterr_axis => '0',
        injectsbiterr_axis => '0',
        s_axis_tdest       => "0",
        s_axis_tid         => "0",
        s_axis_tkeep => (others => '0'),
        s_axis_tstrb => (others => '0')
    );

    LSlaveReadSyncFifo : xpm_fifo_axis
    generic map(
        CDC_SYNC_STAGES => 2,                   -- DECIMAL
        CLOCKING_MODE   => "independent_clock", -- String
        FIFO_DEPTH      => 16,                  -- DECIMAL
        PACKET_FIFO     => "false",             -- String
        TDATA_WIDTH     => 8,                   -- DECIMAL
        TUSER_WIDTH     => 25                   -- DECIMAL
    )
    port map(
        m_aclk             => SUiClk,
        s_aclk             => PIReadClk,
        s_aresetn          => SUiClkSyncRstNSyncReadClock,
        m_axis_tready      => SSlaveRdSyncFifoMasterReady, --input
        m_axis_tvalid      => SSlaveRdSyncFifoMasterValid, --output
        m_axis_tuser       => SSlaveRdSyncFifoMasterAddr,  --output
        m_axis_tdata       => open,                        --output
        s_axis_tready      => SSlaveRdSyncFifoSlaveReady,  --output
        s_axis_tvalid      => SSlaveRdSyncFifoSlaveValid,  --input
        s_axis_tuser       => SSlaveRdSyncFifoSlaveAddr,   --input
        s_axis_tdata => (others => '0'),                   --input
        s_axis_tlast       => '1',
        almost_empty_axis  => open,
        almost_full_axis   => open,
        dbiterr_axis       => open,
        m_axis_tlast       => open,
        m_axis_tdest       => open,
        m_axis_tid         => open,
        m_axis_tkeep       => open,
        m_axis_tstrb       => open,
        prog_empty_axis    => open,
        prog_full_axis     => open,
        rd_data_count_axis => open,
        sbiterr_axis       => open,
        wr_data_count_axis => open,
        injectdbiterr_axis => '0',
        injectsbiterr_axis => '0',
        s_axis_tdest       => "0",
        s_axis_tid         => "0",
        s_axis_tkeep => (others => '0'),
        s_axis_tstrb => (others => '0')
    );

    LMasterReadSyncFifo : xpm_fifo_axis
    generic map(
        CDC_SYNC_STAGES => 2,                   -- DECIMAL
        CLOCKING_MODE   => "independent_clock", -- String
        FIFO_DEPTH      => 16,                  -- DECIMAL
        PACKET_FIFO     => "false",             -- String
        TDATA_WIDTH     => 128,                 -- DECIMAL
        TUSER_WIDTH     => 1                    -- DECIMAL
    )
    port map(
        m_aclk             => PIReadClk,
        s_aclk             => SUiClk,
        s_aresetn          => not(SUiClkSyncRst),
        m_axis_tready      => SMasterRdSyncFifoMasterReady, --input
        m_axis_tvalid      => SMasterRdSyncFifoMasterValid, --output
        m_axis_tdata       => SMasterRdSyncFifoMasterData,  --output
        m_axis_tuser       => open,                         --output
        s_axis_tready      => SMasterRdSyncFifoSlaveReady,  --output
        s_axis_tvalid      => SMasterRdSyncFifoSlaveValid,  --input
        s_axis_tdata       => SMasterRdSyncFifoSlaveData,   --input
        s_axis_tuser       => "0",                          --input
        s_axis_tlast       => '1',
        almost_empty_axis  => open,
        almost_full_axis   => open,
        dbiterr_axis       => open,
        m_axis_tlast       => open,
        m_axis_tdest       => open,
        m_axis_tid         => open,
        m_axis_tkeep       => open,
        m_axis_tstrb       => open,
        prog_empty_axis    => open,
        prog_full_axis     => open,
        rd_data_count_axis => open,
        sbiterr_axis       => open,
        wr_data_count_axis => open,
        injectdbiterr_axis => '0',
        injectsbiterr_axis => '0',
        s_axis_tdest       => "0",
        s_axis_tid         => "0",
        s_axis_tkeep => (others => '0'),
        s_axis_tstrb => (others => '0')
    );

    LMasterReadBufferFifo : xpm_fifo_axis
    generic map(
        CDC_SYNC_STAGES => 2,              -- DECIMAL
        CLOCKING_MODE   => "common_clock", -- String
        FIFO_DEPTH      => 256,            -- DECIMAL
        PACKET_FIFO     => "false",        -- String
        TDATA_WIDTH     => 128,            -- DECIMAL
        TUSER_WIDTH     => 1               -- DECIMAL
    )
    port map(
        m_aclk             => SUiClk,
        s_aclk             => SUiClk,
        s_aresetn          => not(SUiClkSyncRst),
        m_axis_tready      => SMasterRdBufferFifoMasterReady, --input
        m_axis_tvalid      => SMasterRdBufferFifoMasterValid, --output
        m_axis_tdata       => SMasterRdBufferFifoMasterData,  --output
        m_axis_tuser       => open,                           --output
        s_axis_tready      => SMasterRdBufferFifoSlaveReady,  --output
        s_axis_tvalid      => SMasterRdBufferFifoSlaveValid,  --input
        s_axis_tdata       => SMasterRdBufferFifoSlaveData,   --input
        s_axis_tuser       => "0",                            --input
        s_axis_tlast       => '1',
        almost_empty_axis  => open,
        almost_full_axis   => open,
        dbiterr_axis       => open,
        m_axis_tlast       => open,
        m_axis_tdest       => open,
        m_axis_tid         => open,
        m_axis_tkeep       => open,
        m_axis_tstrb       => open,
        prog_empty_axis    => open,
        prog_full_axis     => open,
        rd_data_count_axis => open,
        sbiterr_axis       => open,
        wr_data_count_axis => open,
        injectdbiterr_axis => '0',
        injectsbiterr_axis => '0',
        s_axis_tdest       => "0",
        s_axis_tid         => "0",
        s_axis_tkeep => (others => '0'),
        s_axis_tstrb => (others => '0')
    );

end Behavioral;
