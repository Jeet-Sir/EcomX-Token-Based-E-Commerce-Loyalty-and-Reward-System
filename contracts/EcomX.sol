// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EcomXToken is ERC20, Ownable {
    mapping(address => bool) public merchants;
    mapping(address => bool) public customers;

    event MerchantAdded(address indexed merchant);
    event CustomerRewarded(address indexed customer, uint256 amount);

    constructor() ERC20("EcomX Loyalty Token", "ECMX") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    function addMerchant(address merchant) external onlyOwner {
        merchants[merchant] = true;
        emit MerchantAdded(merchant);
    }

    function rewardCustomer(address customer, uint256 amount) external {
        require(merchants[msg.sender], "Not an authorized merchant");
        _transfer(owner(), customer, amount);
        customers[customer] = true;
        emit CustomerRewarded(customer, amount);
    }

    function burnTokens(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function customerBalance(address customer) external view returns (uint256) {
        return balanceOf(customer);
    }
}
