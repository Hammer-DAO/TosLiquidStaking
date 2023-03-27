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
        IERC20(TOS).transferFrom(_msgSender(), address(this), 1000 * 1e18);
        IERC20(TOS).approve(address(stakingProxy), 1000 * 1e18);
        stakeId = stakingProxy.stakeGetStos(1000 * 1e18, 156);
    }

    function addRewardToken(address token) external onlyOwner {
        rewardTokens.push(token);
    }

    function removeRewardToken(address token) external onlyOwner {
        for (uint8 idx; idx < rewardTokens.length; idx++) {
            if (rewardTokens[idx] == token) {
                address lastItem = rewardTokens[rewardTokens.length - 1];
                rewardTokens[idx] = lastItem;
                rewardTokens.pop();
                return;
            }
        }
    }

    function addTOS(uint256 amount) external {
        // 새로 추가된 TOS는 기존에 쌓인 에어드랍 물량에 대한 권한이 없음
        for (uint256 idx; idx < rewardTokens.length; idx++) {
            address rewardToken = rewardTokens[idx];

            claimedRewardTokens[rewardToken][_msgSender()] +=
                (accRewardsPerTOS[rewardToken] * amount) /
                1e18;
        }

        stakedTOS[_msgSender()] += amount;
        totalStakedTOS += amount;
        IERC20(TOS).transferFrom(_msgSender(), address(this), amount);
    }

    /// @notice addTOS()로 쌓인 TOS를 한번에 스테이킹하는 method
    /// @dev stake는 목요일 오전 9시 직전에 한번만 호출하는게 가장 좋음
    function stake() external {
        uint256 amount = IERC20(TOS).balanceOf(address(this));
        IERC20(TOS).approve(address(stakingProxy), amount);
        stakingProxy.increaseBeforeEndOrNonEnd(stakeId, amount);
    }

    function increasePeriod(uint256 additionalWeeks) external {
        stakingProxy.increaseBeforeEndOrNonEnd(stakeId, 0, additionalWeeks);
    }

    /// @notice LockTOSDividend 컨트랙트에서 TOS 락업 보상을 가져와서 staker에게 분배
    function update(address rewardToken) external {
        uint256 claimableTokens = lockTOSDividendProxy.claimable(
            address(this),
            rewardToken
        );

        if (claimableTokens > 0) {
            uint256 beforeBalance = IERC20(rewardToken).balanceOf(
                address(this)
            );
            lockTOSDividendProxy.claim(rewardToken);
            uint256 afterBalance = IERC20(rewardToken).balanceOf(address(this));

            uint256 rewardAmount = afterBalance - beforeBalance;
            accRewardsPerTOS[rewardToken] += ((rewardAmount * 1e18) /
                totalStakedTOS);

            emit Update(rewardToken, rewardAmount);
        }
    }

    /// @notice 특정 리워드 토큰만 claim 할 때 사용
    function claimToken(address token) external {
        uint256 claimableTokens = ((stakedTOS[_msgSender()] *
            accRewardsPerTOS[token]) / 1e18) -
            claimedRewardTokens[token][_msgSender()];

        claimedRewardTokens[token][_msgSender()] += claimableTokens;

        IERC20(token).transfer(_msgSender(), claimableTokens);
    }

    /// @notice 여러 리워드 토큰을 한번에 claim 할 때 사용
    function claimTokens(address[] calldata tokens) external {
        for (uint8 idx = 0; idx < tokens.length; idx++) {
            address token = tokens[idx];

            uint256 claimableTokens = ((stakedTOS[_msgSender()] *
                accRewardsPerTOS[token]) / 1e18) -
                claimedRewardTokens[token][_msgSender()];

            claimedRewardTokens[token][_msgSender()] += claimableTokens;
            IERC20(token).transfer(_msgSender(), claimableTokens);
        }
    }

    function claimable(address token) external view returns (uint256) {
        uint256 claimableTokens = ((stakedTOS[_msgSender()] *
            accRewardsPerTOS[token]) / 1e18) -
            claimedRewardTokens[token][_msgSender()];

        return claimableTokens;
    }
}
