-- CP319 AI Milestone 1 - Perceptron

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity perceptron is
    Port (
        clk          : in  STD_LOGIC;
        reset        : in  STD_LOGIC;
        start        : in  STD_LOGIC;
        trainingMode : in  STD_LOGIC;
        correctClass : in  STD_LOGIC;

        x1           : in  signed(7 downto 0);
        x2           : in  signed(7 downto 0);
        x3           : in  signed(7 downto 0);
        x4           : in  signed(7 downto 0);

        prediction   : out STD_LOGIC;
        done         : out STD_LOGIC;
        weight1Value : out signed(15 downto 0);
        weight2Value : out signed(15 downto 0);
        weight3Value : out signed(15 downto 0);
        weight4Value : out signed(15 downto 0);
        biasValue    : out signed(15 downto 0)
    );
end perceptron;

architecture Behavioral of perceptron is
    -- Learning rate 0.25 is stored as 64 in Q8.8.
    constant learningRate : signed(15 downto 0) := to_signed(64, 16);

    signal weight1    : signed(15 downto 0) := (others => '0');
    signal weight2    : signed(15 downto 0) := (others => '0');
    signal weight3    : signed(15 downto 0) := (others => '0');
    signal weight4    : signed(15 downto 0) := (others => '0');
    signal biasWeight : signed(15 downto 0) := (others => '0');

    -- Latch inputs so each sample stays stable through the FSM.
    signal savedX1 : signed(7 downto 0) := (others => '0');
    signal savedX2 : signed(7 downto 0) := (others => '0');
    signal savedX3 : signed(7 downto 0) := (others => '0');
    signal savedX4 : signed(7 downto 0) := (others => '0');
    signal savedCorrectClass : STD_LOGIC := '0';
    signal savedTrainingMode : STD_LOGIC := '0';
    signal savedPrediction   : STD_LOGIC := '0';

    -- Process one sample across four clocked stages.
    type stateType is (WAITING, CALCULATING, UPDATING, COMPLETED);
    signal currentState : stateType := WAITING;

    -- Input is Q4.4; shift the product by 4 to return Q8.8.
    function calculateWeightChange(inputValue : signed(7 downto 0))
        return signed is
        variable multiplyResult : signed(23 downto 0);
    begin
        multiplyResult := inputValue * learningRate;
        return resize(shift_right(multiplyResult, 4), 16);
    end function;

begin
    prediction <= savedPrediction;
    weight1Value <= weight1;
    weight2Value <= weight2;
    weight3Value <= weight3;
    weight4Value <= weight4;
    biasValue <= biasWeight;

    -- Advance the sample and update weights on rising clock edges.
    process(clk)
        variable weightedSum : signed(26 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                weight1 <= (others => '0');
                weight2 <= (others => '0');
                weight3 <= (others => '0');
                weight4 <= (others => '0');
                biasWeight <= (others => '0');
                savedX1 <= (others => '0');
                savedX2 <= (others => '0');
                savedX3 <= (others => '0');
                savedX4 <= (others => '0');
                savedCorrectClass <= '0';
                savedTrainingMode <= '0';
                savedPrediction <= '0';
                currentState <= WAITING;
                done <= '0';
            else
                done <= '0';
                case currentState is
                    -- Capture a new sample when start is high.
                    when WAITING =>
                        if start = '1' then
                            savedX1 <= x1;
                            savedX2 <= x2;
                            savedX3 <= x3;
                            savedX4 <= x4;
                            savedCorrectClass <= correctClass;
                            savedTrainingMode <= trainingMode;
                            currentState <= CALCULATING;
                        end if;

                    -- Compute the weighted sum and choose class 0 or 1.
                    when CALCULATING =>
                        -- Align the Q8.8 bias with the Q12.12 products.
                        weightedSum :=
                            resize(savedX1 * weight1, 27) +
                            resize(savedX2 * weight2, 27) +
                            resize(savedX3 * weight3, 27) +
                            resize(savedX4 * weight4, 27) +
                            shift_left(resize(biasWeight, 27), 4);

                        if weightedSum >= to_signed(0, 27) then
                            savedPrediction <= '1';
                        else
                            savedPrediction <= '0';
                        end if;

                        if savedTrainingMode = '1' then
                            currentState <= UPDATING;
                        else
                            currentState <= COMPLETED;
                        end if;

                    -- Correct the weights only when the prediction was wrong.
                    when UPDATING =>
                        if savedCorrectClass /= savedPrediction then
                            if savedCorrectClass = '1' then
                                weight1 <= weight1 + calculateWeightChange(savedX1);
                                weight2 <= weight2 + calculateWeightChange(savedX2);
                                weight3 <= weight3 + calculateWeightChange(savedX3);
                                weight4 <= weight4 + calculateWeightChange(savedX4);
                                biasWeight <= biasWeight + learningRate;
                            else
                                weight1 <= weight1 - calculateWeightChange(savedX1);
                                weight2 <= weight2 - calculateWeightChange(savedX2);
                                weight3 <= weight3 - calculateWeightChange(savedX3);
                                weight4 <= weight4 - calculateWeightChange(savedX4);
                                biasWeight <= biasWeight - learningRate;
                            end if;
                        end if;
                        currentState <= COMPLETED;

                    -- Signal that the sample is ready to read.
                    when COMPLETED =>
                        done <= '1';
                        currentState <= WAITING;
                end case;
            end if;
        end if;
    end process;
end Behavioral;
