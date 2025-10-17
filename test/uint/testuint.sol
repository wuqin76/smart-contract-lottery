// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {console} from "lib/forge-std/src/console.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 keyHash;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployRaffle();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        subscriptionId = config.subscriptionId;
        keyHash = config.keyHash;
        entranceFee = config.entranceFee;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinator = config.vrfCoordinator;
        interval = config.interval;
        console.log("Interval in test setup:", interval);
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_USER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + interval + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testRaffleInitializesInOpenState() public view {
        //测试Raffle合约初始化状态是否为初始化OPEN
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWWhenYouDontPayEnough() public {
        //测试入场费不足时，enterRaffle函数会revert
        // Arrange
        vm.prank(PLAYER); //vm.prank的作用是设置下一个调用的msg.sender为PLAYER
        vm.deal(PLAYER, STARTING_USER_BALANCE); //vm.deal的作用是给指定地址充值以太币，这里给PLAYER充值10个以太币
        // Act / Assert
        vm.expectRevert(Raffle.Raffle_SendMoreToEnterRaffle.selector); //vm.expectRevert的作用是期待下一笔交易会revert，这里期待revert的原因是因为入场费不足
        raffle.enterRaffle();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCaculating()
        public
        raffleEntered
    {
        console.log("Interval:", interval);
        console.log("Current timestamp:", block.timestamp);
        console.log("Last timestamp:", raffle.getLastTimeStamp());
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle_RaffleNotOpen.selector);
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_USER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
    }

    /////////////////////////////////////////////////////////////////////////////////////
    //check upkeep
    /////////////////////////////////////////////////////////////////////////////////////
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        //arange
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + interval + 1);

        //act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //assert
        assert(!upkeepNeeded);
    }

    //老师写的和我这个又不一样了，
    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen()
        public
        raffleEntered
    {
        raffle.performUpkeep("");
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded);
    } //我感觉不对吧，他这个测试的意思不是当Raffle还没有开启得時候吗，应该是时间还没到呀，他這個測的是什么

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        //Arrange
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_USER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval - 20);
        //Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        //Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreGood()
        public
        raffleEntered
    {
        //Arrange

        //Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        //Assert
        assert(upkeepNeeded);
    }

    //////////////////////////////////////////////////////////////////////////////////////
    //perform upkeep
    //////////////////////////////////////////////////////////////////////////////////////

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue()
        public
        raffleEntered
    {
        //Arrange

        //Act/Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 numPlayer = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.prank(PLAYER);
        vm.deal(PLAYER, entranceFee);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayer = numPlayer + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle_UpkeepNotNeeded.selector,
                currentBalance,
                numPlayer,
                uint256(rState)
            )
        );
        raffle.performUpkeep("");
    } //abi.encodeWithSelector的作用是将一个函数选择器和参数编码成字节数组，这里用来模拟Raffle_UpkeepNotNeeded错误的返回值

    function testPerformUpkeepUpdatasRaffleStateAndEmitsRequestId()
        public
        raffleEntered
    {
        vm.recordLogs(); //记录日志
        raffle.performUpkeep(""); //执行performUpkeep
        Vm.Log[] memory entries = vm.getRecordedLogs(); //获取记录的日志,将数据存放在entries数组中
        bytes32 requestId = entries[1].topics[1]; //获取第二条日志的第一个主题，即requestId
        Raffle.RaffleState raffleState = raffle.getRaffleState(); //获取当前的Raffle状态
        assert(uint256(requestId) > 0); //断言requestId大于0
        assert(uint256(raffleState) == 1);
    }

    //////////////////////////////////////////////////////////////////////////////////
    //fulfillRandomWords
    //////////////////////////////////////////////////////////////////////////////////
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public skipFork {
        //Arrange
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector); //期待下一笔交易会revert，原因是请求不存在
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        ); //调用VRFCoordinatorV2_5Mock合约的fulfillRandomWords函数，传入随机请求ID和Raffle合约地址
    }

    function testFulfillRandomWordsPicksWinnerAndSendsMoney()
        public
        raffleEntered
        skipFork
    {
        uint256 additionalEntrants = 3;
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (
            uint256 i = startingIndex;
            i < additionalEntrants + startingIndex;
            i++
        ) {
            address newplayer = address(uint160(i));
            hoax(newplayer, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimestamp = raffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        console.log("Starting timestamp:", startingTimestamp);
        console.log("Starting balance:", startingBalance);
        console.log("Requesting upkeep...");
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        console2.log("Logs recorded:", entries.length);
        for (uint256 i = 0; i < entries.length; i++) {
            console2.log("Log index:", i);
            console2.log("Topic 0:", uint256(entries[i].topics[0]));
            if (entries[i].topics.length > 1) {
                console2.log("Topic 1:", uint256(entries[i].topics[1]));
            }
        }
        bytes32 requestId = entries[1].topics[1];
        console2.log("Request ID:", uint256(requestId));
        console2.log("Fulfilling random words...");
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        //assert
        console2.log("Asserting results...");
        address recentWinner = raffle.getRecentWinner();
        console2.log("Recent winner:", recentWinner);
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        console2.log("Raffle state:", uint256(raffleState));
        uint256 winnerBalance = recentWinner.balance;
        console2.log("Winner balance:", winnerBalance);
        uint256 endingTimestamp = raffle.getLastTimeStamp();
        console2.log("Ending timestamp:", endingTimestamp);
        uint256 prize = entranceFee * (additionalEntrants + 1);
        console2.log("Prize:", prize);

        assert(recentWinner == expectedWinner);
        assert(winnerBalance == startingBalance + prize);
        assert(uint256(raffleState) == 0);
        assert(endingTimestamp > startingTimestamp);
    }
}

// 测试命令
//forge coverage 查看测试覆盖度
//forge coverage --report debug > coverage.txt 生成覆盖率报告
