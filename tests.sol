// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/StakingContract.sol";

contract StakingContractTest is Test {
    StakingContract stakingContract;
    IERC20 token;
    address user = address(0x123);
    address owner = address(this);

    function setUp() public {
        token = new MockERC20("MockToken", "MTK", 18);
        stakingContract = new StakingContract(token);
        token.mint(owner, 1000 ether);
        token.mint(user, 1000 ether);
        token.approve(address(stakingContract), 1000 ether);
    }

    function testStake() public {
        vm.startPrank(user);
        token.approve(address(stakingContract), 100 ether);
        stakingContract.stake(100 ether, 1);
        (uint256 amount, , , uint256 rewardRate) = stakingContract.stakes(user);
        assertEq(amount, 100 ether);
        assertEq(rewardRate, 25);
        vm.stopPrank();
    }

    function testUnStakeAfterOneYear() public {
        vm.startPrank(user);
        token.approve(address(stakingContract), 100 ether);
        stakingContract.stake(100 ether, 1);
        skip(365 days);
        stakingContract.unStake();
        uint256 balanceAfter = token.balanceOf(user);
        assertEq(balanceAfter, 125 ether);
        vm.stopPrank();
    }

    function testClaimReward() public {
        vm.startPrank(user);
        token.approve(address(stakingContract), 100 ether);
        stakingContract.stake(100 ether, 1);
        skip(365 days);
        stakingContract.claimReward();
        uint256 reward = stakingContract.rewards(user);
        assertEq(reward, 0);
        vm.stopPrank();
    }
}
