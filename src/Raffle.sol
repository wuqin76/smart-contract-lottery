// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// VRF v2.5/Plus (native payment) imports
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Raffle is VRFConsumerBaseV2Plus {
    // 添加枚举来表示抽奖状态
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    error Raffle_SendMoreToEnterRaffle();
    error Raffle_NotEnoughTimePassed();
    error Raffle_TransferFailed();
    error Raffle_RaffleNotOpen();
    error Raffle_UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    uint256 public immutable ENTRANCE_FEE;
    address payable[] private players;
    uint256 private lastTimestamp;
    uint256 private immutable INTERVAL;

    // VRF related variables (v2.5/Plus)
    IVRFCoordinatorV2Plus private immutable VRF_COORDINATOR;
    bytes32 private immutable KEY_HASH;
    uint256 private immutable SUBSCRIPTION_ID;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable CALLBACK_GAS_LIMIT;
    uint32 private constant NUM_WORDS = 1;

    RaffleState private raffleState;

    // 添加存储最近赢家的状态变量
    address private recentWinner;

    constructor(
        uint256 entranceFee,
        uint256 interval, //interval是多久开奖一次，单位是秒
        address vrfCoordinator,
        bytes32 keyHash, //keyHash是VRF请求的唯一标识符
        uint256 subscriptionId, //subscriptionId是VRF订阅ID
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        //从继承的VRFConsumerBaseV2合约调用构造函数
        ENTRANCE_FEE = entranceFee;
        lastTimestamp = block.timestamp;
        INTERVAL = interval;
        VRF_COORDINATOR = IVRFCoordinatorV2Plus(vrfCoordinator);
        KEY_HASH = keyHash;
        SUBSCRIPTION_ID = subscriptionId;
        CALLBACK_GAS_LIMIT = callbackGasLimit;
        raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < ENTRANCE_FEE) {
            revert Raffle_SendMoreToEnterRaffle();
        }
        if (raffleState != RaffleState.OPEN) {
            revert Raffle_RaffleNotOpen();
        }

        // payable关键字是必需的，因为我们需要将该地址转换为可以接收以太币的地址类型
        // 当我们支付奖金给获胜者时，需要地址是payable类型
        players.push(payable(msg.sender));

        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev 这个函数由Chainlink Keeper网络调用，用于检查是否需要执行upkeep
     * 满足以下条件时返回true：
     * 1. 时间间隔已经过去
     * 2. 抽奖状态是OPEN
     * 3. 合约有玩家
     * 4. 订阅有足够的LINK代币
     */
    function checkUpkeep(
        bytes memory /* checkData */ //bytes memory 是一个动态大小的字节数组，可以用来传递任意长度的二进制数据
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool isOpen = (raffleState == RaffleState.OPEN);
        bool timePassed = ((block.timestamp - lastTimestamp) > INTERVAL);
        bool hasPlayers = (players.length > 0); // 判断合约中有玩家
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance); //一个布尔变量upkeepNeeded用来表示是否需要执行upkeep，当isOpen && timePassed && hasPlayers && hasBalance都为true时，upkeepNeeded为true，否则为false
        return (upkeepNeeded, ""); //为啥这里必须要有个空字串，不能直接return (upkeepNeeded);吗？chainlink keeper的规范
    }

    /**
     * @dev 当checkUpkeep返回true时，这个函数被Chainlink Keeper网络调用
     * 它会启动随机数请求
     */
    function performUpkeep(bytes calldata /* performData */) external {
        //calldata是Solidity中的一种数据位置，表示函数参数是只读的，不能被修改，并且存储在调用数据中，适用于外部函数参数，可以节省gas费用
        (bool upkeepNeeded, ) = checkUpkeep(""); //调用checkUpkeep函数来检查是否需要执行upkeep
        if (!upkeepNeeded) {
            //如果不能执行upkeep，就抛出一个自定义错误Raffle_UpkeepNotNeeded，并传递当前合约的余额、玩家数量和抽奖状态作为参数
            revert Raffle_UpkeepNotNeeded(
                address(this).balance,
                players.length,
                uint256(raffleState)
            );
        }

        raffleState = RaffleState.CALCULATING; // 设置抽奖状态为计算中,防止在计算赢家时有人进入抽奖

        // 构造 VRF v2.5/Plus 请求结构体
        // 本地链使用原生 ETH 支付（与 fundSubscriptionWithNative 匹配）
        // 测试网使用 LINK 支付
        bool useNativePayment = (block.chainid == 31337); // 本地链 ID

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient //request是一个结构体变量，类型是VRFV2PlusClient.RandomWordsRequest
            .RandomWordsRequest({
                keyHash: KEY_HASH, // 选择最大支付能力的keyHash，以提高请求成功率
                subId: SUBSCRIPTION_ID, // 订阅ID，必须是有效的订阅ID
                requestConfirmations: REQUEST_CONFIRMATIONS, //请求确认数，设置为3，表示需要3个区块的确认
                callbackGasLimit: CALLBACK_GAS_LIMIT, // 回调函数的最大耗气量
                numWords: NUM_WORDS, //设置为1，表示只需要一个随机数
                extraArgs: VRFV2PlusClient._argsToBytes( //_argsToBytes是一个内部函数，用于将ExtraArgsV1结构体转换为字节数组
                    // 本地链：使用原生支付（ETH）与 fundSubscriptionWithNative 匹配
                    // 测试网：使用 LINK 支付
                    VRFV2PlusClient.ExtraArgsV1({
                        nativePayment: useNativePayment
                    })
                )
            });

        uint256 requestId = VRF_COORDINATOR.requestRandomWords(request); //requestId这次随机请求的凭证

        emit RequestedRaffleWinner(requestId);
    }

    function pickWinner() public {
        // 为了兼容，保留此函数，但内部调用performUpkeep
        // 使用this来调用external函数
        this.performUpkeep("");
    }

    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] calldata randomWords //NUM_WORDS set to 1, so this array will have exactly one element(元素).
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % players.length;
        address payable _recentWinner = players[indexOfWinner];
        recentWinner = _recentWinner;

        // Reset the lottery
        players = new address payable[](0);
        lastTimestamp = block.timestamp;
        raffleState = RaffleState.OPEN;

        emit WinnerPicked(_recentWinner);

        // Transfer prize to winner
        (bool success, ) = _recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle_TransferFailed();
        }
    }

    function getEntranceFee() public view returns (uint256) {
        return ENTRANCE_FEE;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return players[index];
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return players.length;
    }

    function getLastTimeStamp() public view returns (uint256) {
        return lastTimestamp;
    }

    function getInterval() public view returns (uint256) {
        return INTERVAL;
    }

    function getRaffleState() public view returns (RaffleState) {
        return raffleState;
    }

    function getRecentWinner() public view returns (address) {
        return recentWinner;
    }
}
