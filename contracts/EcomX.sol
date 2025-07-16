// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20; // Updated pragma to a more recent version



import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol"; // Imports ERC20 and adds burn functionality

import "@openzeppelin/contracts/access/AccessControl.sol"; // Imports AccessControl for role management



/**

 * @title EcomXToken

 * @dev ERC20 token for EcomX Loyalty and Reward System.

 * Implements ERC20 standard, burn functionality for redemptions,

 * and role-based access control for managing merchants and minting rewards.

 */

contract EcomXToken is ERC20Burnable, AccessControl {

    // --- Define Roles ---

    // DEFAULT_ADMIN_ROLE is built-in to AccessControl and controls all other roles.

    // The contract deployer gets this role.



    // Role for authorized merchants who can reward customers by minting tokens.

    bytes32 public constant MERCHANT_ROLE = keccak256("MERCHANT_ROLE");



    // --- Events ---

    event MerchantAdded(address indexed merchant); // Emitted when a merchant is granted the MERCHANT_ROLE

    event MerchantRemoved(address indexed merchant); // Emitted when a merchant's role is revoked

    event CustomerRewarded(address indexed customer, uint256 amount); // Emitted when tokens are minted as a reward

    event TokensRedeemed(address indexed burner, uint256 amount); // Emitted when tokens are burned for redemption



    /**

     * @dev Constructor to initialize the ERC20 token and set up initial roles.

     * @param initialAdmin Optional: Address to grant initial DEFAULT_ADMIN_ROLE if not msg.sender.

     */

    constructor(address initialAdmin) ERC20("EcomX Loyalty Token", "ECMX") {

        // The deployer (msg.sender) gets the DEFAULT_ADMIN_ROLE if no specific admin is provided.

        // This admin can then grant/revoke other roles (like MERCHANT_ROLE).

        if (initialAdmin == address(0)) {

            _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

            // Optionally, grant the deployer the MERCHANT_ROLE automatically if they are also the first merchant.

            _grantRole(MERCHANT_ROLE, msg.sender);

        } else {

            _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);

            // If an initialAdmin is specified, they might also be the first merchant,

            // or another address might receive the MERCHANT_ROLE separately.

        }

    }



    // --- Merchant Management Functions (Callable by DEFAULT_ADMIN_ROLE) ---



    /**

     * @dev Grants the MERCHANT_ROLE to an address, allowing them to reward customers.

     * Only callable by an account with DEFAULT_ADMIN_ROLE.

     * @param merchant The address to grant merchant role to.

     */

    function addMerchant(address merchant) public onlyRole(DEFAULT_ADMIN_ROLE) {

        require(merchant != address(0), "EcomXToken: Invalid merchant address");

        // AccessControl's _grantRole handles checking if role is already granted.

        _grantRole(MERCHANT_ROLE, merchant);

        emit MerchantAdded(merchant);

    }



    /**

     * @dev Revokes the MERCHANT_ROLE from an address, preventing them from rewarding customers.

     * Only callable by an account with DEFAULT_ADMIN_ROLE.

     * @param merchant The address to revoke merchant role from.

     */

    function removeMerchant(address merchant) public onlyRole(DEFAULT_ADMIN_ROLE) {

        require(merchant != address(0), "EcomXToken: Invalid merchant address");

        // AccessControl's _revokeRole handles checking if role exists.

        _revokeRole(MERCHANT_ROLE, merchant);

        emit MerchantRemoved(merchant);

    }



    // --- Core Loyalty Program Functions ---



    /**

     * @dev Allows an authorized merchant to reward a customer by minting new ECMX tokens.

     * This function increases the total supply of tokens.

     * Only callable by an account with MERCHANT_ROLE.

     * @param customer The address of the customer to reward.

     * @param amount The amount of ECMX tokens to mint as a reward.

     */

    function rewardCustomer(address customer, uint256 amount) public onlyRole(MERCHANT_ROLE) {

        require(customer != address(0), "EcomXToken: Invalid customer address");

        require(amount > 0, "EcomXToken: Reward amount must be greater than zero");



        // Mint new tokens to the customer's address.

        // This is the core change: tokens are now created, not transferred from owner's balance.

        _mint(customer, amount);



        emit CustomerRewarded(customer, amount);

    }



    /**

     * @dev Allows a token holder (customer) to redeem their ECMX tokens by burning them.

     * The tokens are permanently removed from circulation.

     * @param amount The amount of ECMX tokens to burn for redemption.

     */

    function redeemTokens(uint256 amount) public {

        require(amount > 0, "EcomXToken: Redemption amount must be greater than zero");

        // _burn is inherited from ERC20Burnable and burns from msg.sender's balance.

        _burn(msg.sender, amount);

        emit TokensRedeemed(msg.sender, amount);

    }



    // --- Helper Functions (inherited from ERC20/ERC20Burnable) ---



    // Note: The `balanceOf(address account)` function is already public and view

    // in the ERC20 standard, so a redundant `customerBalance` function is not needed.

    // Users can simply call `balanceOf(customerAddress)` directly.

    // Similarly, `totalSupply()` and `allowance()` are also available.



    // If you need to check if an address has the merchant role:

    function isMerchant(address account) public view returns (bool) {

        return hasRole(MERCHANT_ROLE, account);

    }

}
