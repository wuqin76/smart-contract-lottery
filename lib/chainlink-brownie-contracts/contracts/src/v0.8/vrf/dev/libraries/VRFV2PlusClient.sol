// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// End consumer library.
library VRFV2PlusClient {
  // extraArgs will evolve to support new features
  bytes4 public constant EXTRA_ARGS_V1_TAG = bytes4(keccak256("VRF ExtraArgsV1"));
  struct ExtraArgsV1 {
    bool nativePayment;
  }

  struct RandomWordsRequest {
    bytes32 keyHash;
    uint256 subId;
    uint16 requestConfirmations;
    uint32 callbackGasLimit;
    uint32 numWords;
    bytes extraArgs;//（额外参数）
  }

  function _argsToBytes(ExtraArgsV1 memory extraArgs) internal pure returns (bytes memory bts) {
    return abi.encodeWithSelector(EXTRA_ARGS_V1_TAG, extraArgs);
  }
}


//VRFV2PlusClient是一个库，提供了与Chainlink VRF v2.5/Plus版本交互的功能
//它定义了一个结构体RandomWordsRequest，用于封装请求随机数所需的参数
//并提供了一个函数_argsToBytes，用于将额外参数ExtraArgsV1转换为字节数组
//这个库简化了与Chainlink VRF v2.5/Plus的集成，使得请求随机数更加方便
//它支持使用原生代币（如ETH）支付请求费用，而不是仅限于LINK代币