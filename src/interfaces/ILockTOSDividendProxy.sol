// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ILockTOSDividendProxy {
    function claim(address _token) external;

    function claimable(
        address _account,
        address _token
    ) external returns (uint256);
}
