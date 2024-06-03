// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../src/BondingCurveToken.sol";
import "forge-std/Test.sol";

contract BondingCurveTokenTest is Test {
    BondingCurveToken token;

    address admin = address(1);
    address user1 = address(2);

    function setUp() public {
        // Deploy the contract as admin
        vm.prank(admin);
        token = new BondingCurveToken();

        // Deal some ETH to admin and user1
        vm.deal(admin, 10 ether);
        vm.deal(user1, 10 ether);
    }

    function testInitialSupply() public {
        assertEq(token.totalSupply(), 0);
    }

    function testBuy() public {
        vm.prank(user1);
        uint256 maxCost = 0.03 ether;
        token.buy{value: 0.03 ether}(2, maxCost);
        assertEq(token.balanceOf(user1), 2);
    }

    function testBuyInsufficientEth() public {
        vm.prank(user1);
        uint256 maxCost = 0.03 ether;
        vm.expectRevert("Insufficient ETH sent");
        token.buy{value: 0.01 ether}(2, maxCost);
    }

    function testBuySlippageExceeded() public {
        vm.prank(user1);
        uint256 maxCost = 0.02 ether;
        vm.expectRevert("Slippage exceeded");
        token.buy{value: 0.03 ether}(2, maxCost);
    }

    function testBuyback() public {
        vm.prank(user1);
        uint256 maxCost = 0.03 ether;
        token.buy{value: 0.03 ether}(2, maxCost);
        assertEq(token.balanceOf(user1), 2);

        vm.warp(block.timestamp + 60 seconds); // Fast-forward time by 60 seconds

        vm.prank(user1);
        uint256 minRevenue = 0.02 ether;
        token.buyback(1, minRevenue);
        assertEq(token.balanceOf(user1), 1);
        assertEq(user1.balance, 10 ether - 0.03 ether + 0.02 ether); // user1 should get back 0.02 ether for selling 1 token
    }

    function testBuybackSlippageExceeded() public {
        vm.prank(user1);
        uint256 maxCost = 0.03 ether;
        token.buy{value: 0.03 ether}(2, maxCost);
        assertEq(token.balanceOf(user1), 2);

        vm.warp(block.timestamp + 60 seconds); // Fast-forward time by 60 seconds

        vm.prank(user1);
        uint256 minRevenue = 0.03 ether;
        vm.expectRevert("Slippage exceeded");
        token.buyback(1, minRevenue);
    }

    function testGetCostForTokens() public {
        assertEq(token.getCostForTokens(1), 0.01 ether); // 0.01 ether for 1 token
        assertEq(token.getCostForTokens(2), 0.03 ether); // 0.01 ether + 0.02 ether
        assertEq(token.getCostForTokens(10), 0.55 ether); // Sum of 0.01 ether + 0.02 ether + ... + 0.10 ether
    }

    function testGetRevenueForTokens() public {
        vm.prank(user1);
        uint256 maxCost = 0.03 ether;
        token.buy{value: 0.03 ether}(2, maxCost);
        assertEq(token.getRevenueForTokens(1), 0.02 ether); // 0.02 ether for the second token
        assertEq(token.getRevenueForTokens(2), 0.03 ether); // 0.02 ether + 0.01 ether
    }

    function testTimeLockBuy() public {
        // Ensure the contract has ETH from a user1 buy transaction
        vm.prank(user1);
        uint256 maxCost = 0.01 ether;
        token.buy{value: 0.01 ether}(1, maxCost);

        // Try to buy again within the cooldown period, expect revert
        vm.warp(block.timestamp + 30 seconds); // Fast-forward time by 30 seconds
        vm.prank(user1);
        vm.expectRevert("Transaction too soon");
        token.buyback(1, 0.01 ether);

        // Wait for the cooldown period to pass
        vm.warp(block.timestamp + 60 seconds); // Fast-forward time by 60 seconds
        vm.prank(user1);
        token.buyback(1, 0.01 ether);
    }
}
