-- CP319 AI Milestone 1 - Testbench

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_perceptron is
end tb_perceptron;

architecture Simulation of tb_perceptron is
    signal clk          : STD_LOGIC := '0';
    signal reset        : STD_LOGIC := '1';
    signal start        : STD_LOGIC := '0';
    signal trainingMode : STD_LOGIC := '0';
    signal correctClass : STD_LOGIC := '0';
    signal x1           : signed(7 downto 0) := (others => '0');
    signal x2           : signed(7 downto 0) := (others => '0');
    signal x3           : signed(7 downto 0) := (others => '0');
    signal x4           : signed(7 downto 0) := (others => '0');
    signal prediction   : STD_LOGIC;
    signal done         : STD_LOGIC;
    signal weight1Value : signed(15 downto 0);
    signal weight2Value : signed(15 downto 0);
    signal weight3Value : signed(15 downto 0);
    signal weight4Value : signed(15 downto 0);
    signal biasValue    : signed(15 downto 0);

    signal stopClock : boolean := false;

    -- x1=good, x2=bad, x3=happy, x4=sad; 1 means present.
    type sampleType is record
        x1 : integer;
        x2 : integer;
        x3 : integer;
        x4 : integer;
        correctClass : STD_LOGIC;
    end record;
    type sampleList is array (natural range <>) of sampleType;

    -- Examples used to teach the perceptron.
    constant trainingSamples : sampleList(1 to 8) := (
        (0, 1, 1, 1, '0'),
        (0, 0, 0, 0, '0'),
        (1, 0, 0, 0, '1'),
        (1, 1, 1, 1, '0'),
        (1, 1, 0, 0, '0'),
        (1, 0, 0, 1, '0'),
        (0, 0, 1, 0, '1'),
        (1, 0, 1, 1, '1')
    );

    -- New examples used to check what it learned.
    constant testingSamples : sampleList(1 to 3) := (
        (1, 0, 1, 0, '1'),
        (0, 1, 0, 0, '0'),
        (0, 0, 1, 1, '0')
    );

begin
    perceptronUnit : entity work.perceptron
        port map (
            clk => clk,
            reset => reset,
            start => start,
            trainingMode => trainingMode,
            correctClass => correctClass,
            x1 => x1, x2 => x2, x3 => x3, x4 => x4,
            prediction => prediction,
            done => done,
            weight1Value => weight1Value,
            weight2Value => weight2Value,
            weight3Value => weight3Value,
            weight4Value => weight4Value,
            biasValue => biasValue
        );

    -- Generate a 10 ns clock until testing is complete.
    clockProcess : process
    begin
        while not stopClock loop
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end loop;
        wait;
    end process;

    testProcess : process
        variable mistakeCount : integer := 0;
        variable finalEpoch : integer := 0;
        variable actualClass : STD_LOGIC := '0';

        -- Send one sample and wait for its prediction.
        procedure runSample(
            constant currentSample : in sampleType;
            constant shouldTrain   : in STD_LOGIC;
            variable returnedClass : out STD_LOGIC
        ) is
        begin
            -- 1.0 is encoded as 16 in Q4.4.
            wait until falling_edge(clk);
            x1 <= to_signed(currentSample.x1 * 16, 8);
            x2 <= to_signed(currentSample.x2 * 16, 8);
            x3 <= to_signed(currentSample.x3 * 16, 8);
            x4 <= to_signed(currentSample.x4 * 16, 8);
            correctClass <= currentSample.correctClass;
            trainingMode <= shouldTrain;
            start <= '1';

            wait until rising_edge(clk);
            wait for 1 ns;
            start <= '0';

            wait until done = '1' for 100 ns;
            assert done = '1' report "TIMEOUT: sample never completed" severity failure;
            wait for 1 ns;
            returnedClass := prediction;
        end procedure;

    begin
        wait until rising_edge(clk);
        wait for 1 ns;
        reset <= '0';
        report "Starting hardware training. Learning rate = 0.25";

        -- Train until an entire pass has no mistakes, up to 100 passes.
        for epochNumber in 1 to 100 loop
            mistakeCount := 0;

            for sampleNumber in trainingSamples'range loop
                runSample(trainingSamples(sampleNumber), '1', actualClass);
                if actualClass /= trainingSamples(sampleNumber).correctClass then
                    mistakeCount := mistakeCount + 1;
                end if;
            end loop;

            finalEpoch := epochNumber;
            report "Epoch " & integer'image(epochNumber) &
                ": mistakes=" & integer'image(mistakeCount) &
                ", weight1=" & integer'image(to_integer(weight1Value)) &
                ", weight2=" & integer'image(to_integer(weight2Value)) &
                ", weight3=" & integer'image(to_integer(weight3Value)) &
                ", weight4=" & integer'image(to_integer(weight4Value)) &
                ", biasWeight=" & integer'image(to_integer(biasValue)) &
                " (all weights printed as Q8.8 raw integers; divide by 256)";

            exit when mistakeCount = 0;
        end loop;

        assert mistakeCount = 0
            report "FAIL: did not converge within 100 epochs" severity failure;
        report "TRAINING PASSED after " & integer'image(finalEpoch) & " epochs";

        -- Check the learned model without changing its weights.
        for sampleNumber in trainingSamples'range loop
            runSample(trainingSamples(sampleNumber), '0', actualClass);
            assert actualClass = trainingSamples(sampleNumber).correctClass
                report "FAIL: training sample " & integer'image(sampleNumber)
                severity failure;
        end loop;
        report "ALL 8 TRAINING SAMPLES CLASSIFIED CORRECTLY";

        -- Check the model on examples it has not seen before.
        for sampleNumber in testingSamples'range loop
            runSample(testingSamples(sampleNumber), '0', actualClass);
            assert actualClass = testingSamples(sampleNumber).correctClass
                report "FAIL: new testing sample " & integer'image(sampleNumber)
                severity failure;
            report "NEW SAMPLE " & integer'image(sampleNumber) & ": PASS";
        end loop;
        report "ALL 3 NEW TESTING SAMPLES PASSED";
        report "SIMULATION COMPLETE";
        stopClock <= true;
        wait;
    end process;
end Simulation;
