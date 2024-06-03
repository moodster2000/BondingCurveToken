// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title BondingCurveToken
 * @dev ERC20 token contract with a linear bonding curve and administrative controls.
 */
contract BondingCurveToken is ERC20, AccessControl {
    uint256 public constant INCREMENT_PER_TOKEN = 0.01 ether;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 public constant TIMELOCK_DURATION = 1 minutes;
    mapping(address => uint256) private lastTransactionTime;

    /**
     * @notice Constructor that grants the deployer the admin roles.
     */
    constructor() ERC20("BondingCurveToken", "BCT") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Modifier to enforce a time lock between transactions.
     */
    modifier timeLock() {
        if (lastTransactionTime[msg.sender] != 0) {
            require(block.timestamp >= lastTransactionTime[msg.sender] + TIMELOCK_DURATION, "Transaction too soon");
        }
        _;
        lastTransactionTime[msg.sender] = block.timestamp;
    }

    /**
     * @notice Buy tokens according to the bonding curve price.
     * @param amount The amount of tokens to buy.
     * @param maxCost The maximum cost the buyer is willing to pay to handle slippage.
     * @dev The cost is determined by the current supply and the bonding curve.
     */
    function buy(uint256 amount, uint256 maxCost) public payable {
        uint256 cost = getCostForTokens(amount);
        require(cost <= maxCost, "Slippage exceeded");
        require(msg.value >= cost, "Insufficient ETH sent");

        lastTransactionTime[msg.sender] = block.timestamp;
        _mint(msg.sender, amount);

        // Refund any excess ETH
        if (msg.value > cost) {
            payable(msg.sender).transfer(msg.value - cost);
        }
    }

    /**
     * @notice Sell tokens back to the contract according to the bonding curve price.
     * @param amount The amount of tokens to sell.
     * @param minRevenue The minimum revenue the seller expects to handle slippage.
     * @dev Enforces a time lock between transactions to mitigate sandwich attacks.
     */
    function buyback(uint256 amount, uint256 minRevenue) public timeLock {
        require(balanceOf(msg.sender) >= amount, "Insufficient token balance");

        uint256 revenue = getRevenueForTokens(amount);
        require(revenue >= minRevenue, "Slippage exceeded");

        _burn(msg.sender, amount);

        payable(msg.sender).transfer(revenue);
    }

    /**
     * @notice Get the cost to buy a given amount of tokens.
     * @param amount The amount of tokens to buy.
     * @return The cost in ETH to buy the specified amount of tokens.
     */
    function getCostForTokens(uint256 amount) public view returns (uint256) {
        uint256 currentSupply = totalSupply();
        uint256 cost = 0;

        for (uint256 i = 1; i <= amount; i++) {
            cost += INCREMENT_PER_TOKEN * (currentSupply + i);
        }

        return cost;
    }

    /**
     * @notice Get the revenue for selling a given amount of tokens.
     * @param amount The amount of tokens to sell.
     * @return The revenue in ETH for selling the specified amount of tokens.
     */
    function getRevenueForTokens(uint256 amount) public view returns (uint256) {
        uint256 currentSupply = totalSupply();
        uint256 revenue = 0;

        for (uint256 i = 0; i < amount; i++) {
            revenue += INCREMENT_PER_TOKEN * (currentSupply - i);
        }

        return revenue;
    }

    /**
     * @notice Withdraw ETH from the contract.
     * @dev Can only be called by an account with the ADMIN_ROLE.
     */
    function withdraw() external onlyRole(ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
}
