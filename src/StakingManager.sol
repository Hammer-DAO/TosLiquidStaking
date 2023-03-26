// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "./proxy/ProxyBaseStorage.sol";
import "./StakingManagerStorageV1.sol";

contract StakingManager is ProxyBaseStorage, StakingManagerStorageV1 {
    event Update(address rewardToken, uint256 rewardAmount);

    modifier initialized() {
        require(stakeId != 0, "StakingManager: not initialized");
        _;
    }

    function setLockTOSDividendProxy(
        address _lockTOSDividendProxy
    ) external onlyOwner {
        lockTOSDividendProxy = ILockTOSDividendProxy(_lockTOSDividendProxy);
    }

    function setStakingProxy(address _stakingProxy) external onlyOwner {
        stakingProxy = IStakingProxy(_stakingProxy);
    }

    /// @notice TOS 주소 설정
    function setTOS(address _tos) external onlyOwner {
        TOS = _tos;
    }

    function initialize() public onlyOwner {
        require(stakeId == 0, "StakingManager: already initialized");
        stakeId = stakingProxy.stake(1000 * 1e18);
    }

    function addTOS(uint256 amount) external {
        StakerInfo storage info = stakerInfos[_msgSender()];

        IERC20(TOS).transferFrom(_msgSender(), address(this), amount);
        stakingProxy.increaseBeforeEndOrNonEnd(stakeId, amount);

        info.stakedTOS += amount;
        totalStakedTOS += amount;
    }

    function increasePeriod(uint256 additionalWeeks) external {
        stakingProxy.increaseBeforeEndOrNonEnd(stakeId, 0, additionalWeeks);
    }

    /// @notice LockTOSDividend 컨트랙트에서 TOS 락업 보상을 가져와서 staker에게 분배
    function update(address rewardToken) external {
        uint256 claimable = lockTOSDividendProxy.claimable(
            address(this),
            rewardToken
        );

        if (claimable > 0) {
            uint256 beforeBalance = IERC20(rewardToken).balanceOf(
                address(this)
            );
            lockTOSDividendProxy.claim(rewardToken);
            uint256 afterBalance = IERC20(rewardToken).balanceOf(address(this));

            uint256 rewardAmount = afterBalance - beforeBalance;
            accRewardsPerTOS[rewardToken] += rewardAmount / totalStakedTOS;

            emit Update(rewardToken, rewardAmount);
        }
    }

    /// @notice 특정 리워드 토큰만 claim 할 때 사용
    function claimToken(address token) external {
        StakerInfo storage info = stakerInfos[_msgSender()];
        uint256 claimableTokens = ((info.stakedTOS * accRewardsPerTOS[token]) /
            1e18) - info.claimedRewardTokens[token];

        info.claimedRewardTokens[token] += claimableTokens;
        IERC20(token).transfer(_msgSender(), claimableTokens);
    }

    /// @notice 여러 리워드 토큰을 한번에 claim 할 때 사용
    function claimTokens(address[] calldata tokens) external {
        for (uint8 idx = 0; idx < tokens.length; idx++) {
            address token = tokens[idx];

            StakerInfo storage info = stakerInfos[_msgSender()];
            uint256 claimableTokens = ((info.stakedTOS *
                accRewardsPerTOS[token]) / 1e18) -
                info.claimedRewardTokens[token];

            info.claimedRewardTokens[token] += claimableTokens;
            IERC20(token).transfer(_msgSender(), claimableTokens);
        }
    }
}
