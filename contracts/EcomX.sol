// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17; // Consider updating to ^0.8.20 for consistency with latest OZ contracts

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EcomXToken is ERC20, Ownable { // Good inheritance setup
    mapping(address => bool) public merchants;
    mapping(address => bool) public customers; // This mapping's utility is questionable as currently used

    event MerchantAdded(address indexed merchant);
    event CustomerRewarded(address indexed customer, uint256 amount);
    // Consider an event for token burning too, e.g., event TokensBurned(address indexed burner, uint256 amount);

    constructor() ERC20("EcomX Loyalty Token", "ECMX") Ownable(msg.sender) { // Add Ownable(msg.sender) to constructor
        _mint(msg.sender, 1_000_000 * 10 ** decimals()); // Initial mint to deployer
    }

    // Function to add a new merchant
    function addMerchant(address merchant) external onlyOwner { // Correct access control for adding merchants
        require(merchant != address(0), "EcomXToken: Invalid merchant address");
        require(!merchants[merchant], "EcomXToken: Merchant already added");
        merchants[merchant] = true;
        emit MerchantAdded(merchant);
    }

    // Core reward function
    function rewardCustomer(address customer, uint256 amount) external {
        require(merchants[msg.sender], "Not an authorized merchant"); // Good check for merchant authorization
        require(customer != address(0), "EcomXToken: Invalid customer address");
        require(amount > 0, "EcomXToken: Reward amount must be greater than zero");

        // MAJOR LOGIC FLAW/DESIGN CHOICE:
        // _transfer(owner(), customer, amount);
        // This transfers tokens from the *contract owner's* balance (i.e., the deployer's initially minted supply)
        // to the customer. This means:
        // 1. The contract owner needs to have enough tokens to distribute all rewards.
        // 2. You are NOT creating new tokens for rewards; you are just redistributing existing ones.
        //    This means your total supply will remain constant unless you add a minting mechanism.
        //    A typical "loyalty program" *mints* new tokens as rewards.
        _transfer(owner(), customer, amount); // Transfer from the contract owner's balance

        customers[customer] = true; // This just marks if they've ever received tokens, but not used elsewhere.
                                    // Its utility depends on future logic.
        emit CustomerRewarded(customer, amount);
    }

    // Function to allow users to burn their own tokens for redemption
    function burnTokens(uint256 amount) external {
        require(amount > 0, "EcomXToken: Burn amount must be greater than zero");
        _burn(msg.sender, amount); // Correctly burns from the caller's balance
        // Consider emitting an event here: emit TokensBurned(msg.sender, amount);
    }

    // Function to check a customer's balance
    function customerBalance(address customer) external view returns (uint256) {
        // You're simply wrapping balanceOf(customer), which is already public/external from ERC20.
        // You could just tell users to call balanceOf(customer) directly.
        // If there's specific loyalty-related logic, it should go here.
        return balanceOf(customer);
    }
}
