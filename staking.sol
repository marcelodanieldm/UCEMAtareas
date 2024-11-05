// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "./IStaking.sol";


contract StakingContract is IStaking {
    IERC20 public immutable stakingToken;
    address public owner;
    uint256 public totalStaked;
    mapping(address => StakeInfo) public stakes;
    mapping(address => uint256) public rewards;

    constructor(IERC20 _stakingToken) {
        stakingToken = _stakingToken;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    /**
     * @notice Stake a certain amount of tokens for a certain duration
     * @param _amount The amount of tokens to stake
     * @param _duration The duration of the stake (1 year, 2 years, or 3 years)
     */
    function stake(uint256 _amount, uint256 _duration) external override {
        require(_duration == 1 || _duration == 2 || _duration == 3, "Invalid duration");
        require(_amount > 0, "Amount must be greater than 0");

        uint256 rewardRate;
        if (_duration == 1) rewardRate = 25;
        else if (_duration == 2) rewardRate = 50;
        else if (_duration == 3) rewardRate = 75;

        require(stakingToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");

        stakes[msg.sender] = StakeInfo({
            amount: _amount,
            startTime: block.timestamp,
            duration: _duration * 365 days,
            rewardRate: rewardRate
        });

        totalStaked += _amount;

        emit Staked(msg.sender, _amount, _duration);
    }

    /**
     * @notice Unstake the tokens
     */
    function unStake() external override {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        require(stakeInfo.amount > 0, "No active stake");

        uint256 reward = _calculateReward(msg.sender);
        uint256 amountToReturn = stakeInfo.amount;

        if (block.timestamp < stakeInfo.startTime + stakeInfo.duration) {
            reward = 0; // No reward if unstaking before the duration
        } else {
            rewards[msg.sender] = 0; // Reset reward if unstaking after duration
        }

        delete stakes[msg.sender];
        totalStaked -= amountToReturn;

        require(stakingToken.transfer(msg.sender, amountToReturn + reward), "Transfer failed");

        emit Unstaked(msg.sender, amountToReturn);
        if (reward > 0) emit RewardClaimed(msg.sender, reward);
    }

    /**
     * @notice Claim the rewards without unstaking
     */
    function claimReward() external override {
        uint256 reward = _calculateReward(msg.sender);
        require(reward > 0, "No rewards available");

        rewards[msg.sender] = 0;

        require(stakingToken.transfer(msg.sender, reward), "Transfer failed");

        emit RewardClaimed(msg.sender, reward);
    }

    /**
     * @notice Internal function to calculate the rewards for a given user
     */
    function _calculateReward(address _user) internal view returns (uint256) {
        StakeInfo memory stakeInfo = stakes[_user];
        if (block.timestamp < stakeInfo.startTime + stakeInfo.duration) return 0;

        uint256 rewardAmount = (stakeInfo.amount * stakeInfo.rewardRate) / 100;
        return rewardAmount;
    }

    /**
     * @notice Owner deposits tokens to ensure liquidity
     * @param _amount The amount of tokens to deposit
     */
    function ownerDeposit(uint256 _amount) external override onlyOwner {
        require(stakingToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        emit OwnerDeposited(_amount);
    }
}
