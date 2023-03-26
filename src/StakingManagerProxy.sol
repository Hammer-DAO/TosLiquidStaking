// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

import "./proxy/ProxyBaseStorage.sol";

/// @dev 상호 작용하는 컨트랙트 변경으로 인해 업그레이드가 필요할 수 있으므로 업그레이드 가능한 proxy 패턴으로 개발
/// @dev 특정 개인이 독점하는 이슈를 제거하기 위해 Tokamak Network 재단에서 컨트랙트를 배포하도록 요청할 계획
contract StakingManagerProxy is ProxyBaseStorage, Ownable {
    function setImplementation(address _impl) external onlyOwner {
        implementation = _impl;
    }

    function _implementation() private view returns (address) {
        return implementation;
    }

    function delegate() internal {
        address impl = _implementation();
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    fallback() external payable {
        require(msg.value == 0, "cannot receive Ether");
        delegate();
    }

    receive() external payable {
        revert("cannot receive Ether");
    }
}
