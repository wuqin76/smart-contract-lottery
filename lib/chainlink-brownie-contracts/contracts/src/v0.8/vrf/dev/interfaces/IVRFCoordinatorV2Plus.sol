// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {VRFV2PlusClient} from "../libraries/VRFV2PlusClient.sol";
import {IVRFSubscriptionV2Plus} from "./IVRFSubscriptionV2Plus.sol";

// Interface that enables consumers of VRFCoordinatorV2Plus to be future-proof for upgrades
// This interface is supported by subsequent versions of VRFCoordinatorV2Plus
interface IVRFCoordinatorV2Plus is IVRFSubscriptionV2Plus {
  /**
   * @notice Request a set of random words.
   * @param req - a struct containing following fields for randomness request:
   * keyHash - Corresponds to a particular oracle job which uses
   * that key for generating the VRF proof. Different keyHash's have different gas price
   * ceilings, so you can select a specific one to bound your maximum per request cost.
   * subId  - The ID of the VRF subscription. Must be funded
   * with the minimum subscription balance required for the selected keyHash.
   * requestConfirmations - How many blocks you'd like the
   * oracle to wait before responding to the request. See SECURITY CONSIDERATIONS
   * for why you may want to request more. The acceptable range is
   * [minimumRequestBlockConfirmations, 200].
   * callbackGasLimit - How much gas you'd like to receive in your
   * fulfillRandomWords callback. Note that gasleft() inside fulfillRandomWords
   * may be slightly less than this amount because of gas used calling the function
   * (argument decoding etc.), so you may need to request slightly more than you expect
   * to have inside fulfillRandomWords. The acceptable range is
   * [0, maxGasLimit]
   * numWords - The number of uint256 random values you'd like to receive
   * in your fulfillRandomWords callback. Note these numbers are expanded in a
   * secure way by the VRFCoordinator from a single random value supplied by the oracle.
   * extraArgs - abi-encoded extra args
   * @return requestId - A unique identifier of the request. Can be used to match
   * a request to a response in fulfillRandomWords.
   */
  function requestRandomWords(VRFV2PlusClient.RandomWordsRequest calldata req) external returns (uint256 requestId);
}
// 一、这段代码在做什么

// 定义了一个接口 IVRFCoordinatorV2Plus，供消费者合约向 VRF 协调器请求随机数。
// 它继承了 IVRFSubscriptionV2Plus（说明该协调器同时支持订阅管理相关能力，比如创建、资金充值、添加消费者等）。
// 真正的实现部署在链上协调器合约里；你的合约只需要拿到该协调器地址，按这个接口调用即可。
// 使用 VRFV2PlusClient.RandomWordsRequest 结构体一次性传入请求参数，返回一个 requestId 用于匹配回调结果。
// 二、核心函数与参数翻译 函数： function requestRandomWords(VRFV2PlusClient.RandomWordsRequest calldata req) external returns (uint256 requestId);

// 作用：向 VRF 协调器发起“请求一组随机数”的调用。
// 参数 req（结构体内字段及含义）：
// keyHash：指定预言机所用的密钥对标识。不同 keyHash 代表不同的 gas 价格上限/费率档，选择它可以帮你控制单次请求的最高成本。它也与网络和 oracle 集群绑定，需使用官方公布的值。
// subId：你的 VRF 订阅 ID。必须先创建并为该订阅充值（balance ≥ 该 keyHash 要求的最低余额），并把你的消费者合约地址加入为该订阅的 consumer。
// requestConfirmations：预言机在响应请求前等待的区块确认数。范围 [minimumRequestBlockConfirmations, 200]。更大的确认数可降低重组风险，但回调更慢；常见取值 3～10（视网络而定）。
// callbackGasLimit：回调 fulfillRandomWords 可用的 gas 上限。回调里可用的实际 gas 会略少于该值（因为函数调用/解码本身也消耗 gas），因此通常要比预估稍微放大一些。范围 [0, maxGasLimit]，其中 maxGasLimit 由协调器/网络配置决定。
// numWords：回调中希望返回的随机数数量（uint256 的个数）。协调器会从单个随机种子安全扩展出你需要的多个随机数。
// extraArgs：ABI 编码的附加参数（VRF V2+ 新增），常见是指定是否使用原生币支付等。通常用 VRFV2PlusClient 的工具函数来构建。
// 返回值：
// requestId：本次请求的唯一标识。你可以用它在 fulfillRandomWords 里做结果关联（例如把请求上下文存到 mapping，再在回调里取出）。
// 三、与回调的关系

// 当预言机生成并提交了有效证明，协调器会回调你的合约的 fulfillRandomWords(uint256 requestId, uint256[] randomWords)。
// 为了安全，建议让你的合约继承 VRFConsumerBaseV2Plus，它会：
// 限制 rawFulfillRandomWords 的调用者必须是当前协调器地址；
// 强制你实现 fulfillRandomWords，并在其中处理随机数。