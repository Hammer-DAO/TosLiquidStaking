// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ILockTOSDividendProxy} from "interfaces/ILockTOSDividendProxy.sol";
import {IStakingProxy} from "interfaces/IStakingProxy.sol";

contract StakingManagerStorageV1 {
    /// 상호 작용해야 하는 Tokamak Network 컨트랙트 주소
    address TOS;
    ILockTOSDividendProxy lockTOSDividendProxy;
    IStakingProxy stakingProxy;

    /// TOS를 스테이킹하면 할당되는 ID, 컨트랙트에서 위임받은 모든 TOS는 하나의 Stake ID로 관리
    uint256 stakeId;

    /// 에어드랍 토큰 리스트
    /// 이 리스트에 저장된 주소를 순회하면서 보상을 claim해서 컨트랙트에 쌓아두고 사용자들이 claim 해가는 구조
    address[] rewardTokens;

    /// TOS 토큰 1개당 받을 수 있는 에어드랍 토큰 수량
    /// 이 값은 계속 증가하며, 이미 받아간 보상은 claimedRewardTokens으로 별도 관리
    mapping(address => uint256) accRewardsPerTOS;

    /// 사용자별 위임한 TOS 총량과 claim 받아간 에어드랍 토큰 총량 저장
    struct StakerInfo {
        mapping(address => uint256) claimedRewardTokens;
        uint256 stakedTOS;
    }
    mapping(address => StakerInfo) stakerInfos;

    /// 스테이킹된 TOS 총량, TOS를 위임한 사용자들의 에어드랍 지분을 계산할 때 사용
    uint256 totalStakedTOS;
}
