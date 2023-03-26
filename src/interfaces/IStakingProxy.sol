// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IStakingProxy {
    function increaseBeforeEndOrNonEnd(
        uint256 _stakeId,
        uint256 _amount
    ) external;

    function increaseBeforeEndOrNonEnd(
        uint256 _stakeId,
        uint256 _amount,
        uint256 _unlockWeeks
    ) external;

    function stakeGetStos(
        uint256 _amount,
        uint256 _periodWeeks
    ) external returns (uint256 stakeId);
}
