// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {ILockTOSDividendProxy} from "interfaces/ILockTOSDividendProxy.sol";
import {IStakingProxy} from "interfaces/IStakingProxy.sol";

contract StakingManager is Ownable {
    uint256 stakeId;

    uint256 lastUpdateBlockNumber;

    address[] rewardTokens;

    mapping(address => uint256) accRewardsPerTOS;

    address TOS;
    ILockTOSDividendProxy lockTOSDividendProxy;
    IStakingProxy stakingProxy;

    struct StakerInfo {
        mapping(address => uint256) claimedRewardTokens;
        uint256 stakedTOS;
    }
    mapping(address => StakerInfo) stakerInfos;

    uint256 totalStakedTOS;

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

    function setTOS(address _tos) external onlyOwner {
        TOS = _tos;
    }

    function initialize() public onlyOwner {
        require(stakeId == 0, "StakingManager: already initialized");
        stakeId = stakingProxy.stake(1000 * 1e18);
    }

    function addTOS(uint256 amount) external initialized {
        StakerInfo storage info = stakerInfos[_msgSender()];

        IERC20(TOS).transferFrom(_msgSender(), address(this), amount);
        stakingProxy.increaseBeforeEndOrNonEnd(stakeId, amount);

        info.stakedTOS += amount;
        totalStakedTOS += amount;
    }

    function increasePeriod(uint256 additionalWeeks) external initialized {
        stakingProxy.increaseBeforeEndOrNonEnd(stakeId, 0, additionalWeeks);
    }

    function update() external initialized {
        for (uint8 idx = 0; idx < rewardTokens.length; idx++) {
            address rewardToken = rewardTokens[idx];

            uint256 claimable = lockTOSDividendProxy.claimable(
                address(this),
                rewardToken
            );

            if (claimable > 0) {
                uint256 beforeBalance = IERC20(rewardToken).balanceOf(
                    address(this)
                );
                lockTOSDividendProxy.claim(rewardToken);
                uint256 afterBalance = IERC20(rewardToken).balanceOf(
                    address(this)
                );

                accRewardsPerTOS[rewardToken] +=
                    afterBalance -
                    beforeBalance /
                    totalStakedTOS;
            }
        }
    }

    function claim(address rewardToken) external initialized {
        StakerInfo storage info = stakerInfos[_msgSender()];
        uint256 claimableTokens = ((info.stakedTOS *
            accRewardsPerTOS[rewardToken]) / 1e18) -
            info.claimedRewardTokens[rewardToken];

        info.claimedRewardTokens[rewardToken] += claimableTokens;
        IERC20(rewardToken).transfer(_msgSender(), claimableTokens);
    }
}
