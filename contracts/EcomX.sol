// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20; // Pragma remains at ^0.8.20



import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol"; // Imports ERC20 and adds burn functionality

import "@openzeppelin/contracts/access/AccessControl.sol"; // Imports AccessControl for role management

import "@openzeppelin/contracts/utils/Pausable.sol"; // NEW: Imports Pausable for emergency pause functionality



/**

 * @title EcomXToken

 * @dev ERC20 token for EcomX Loyalty and Reward System.

 * Implements ERC20 standard, burn functionality for redemptions,

 * role-based access control for managing merchants and minting rewards,

 * and a pausable mechanism for emergency control.

 */

contract EcomXToken is ERC20Burnable, AccessControl, Pausable { // NEW: Inherits Pausable

    // --- Custom Errors (NEW) ---

    // These provide more gas-efficient and structured error feedback to the frontend.

    error EcomXToken__InvalidAddress();

    error EcomXToken__ZeroAmount();

    error EcomXToken__InsufficientBalance(uint256 required, uint256 available);

    error EcomXToken__AlreadyAdded(); // For addMerchant if merchant already has role

    error EcomXToken__RoleDoesNotExist(); // For removeMerchant if merchant doesn't have role

    error EcomXToken__ArraysLengthMismatch(); // For batch operations



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

     * The deployer of this contract will be the initial DEFAULT_ADMIN_ROLE.

     * Optionally, the deployer can also be granted the MERCHANT_ROLE here.

     * @param initialAdmin Optional: Address to grant initial DEFAULT_ADMIN_ROLE if not msg.sender.

     */

    constructor(address initialAdmin) ERC20("EcomX Loyalty Token", "ECMX") {

        // The deployer (msg.sender) gets the DEFAULT_ADMIN_ROLE if no specific admin is provided.

        // This admin can then grant/revoke other roles (like MERCHANT_ROLE).

        if (initialAdmin == address(0)) {

            _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

            // Optionally, grant the deployer the MERCHANT_ROLE automatically if they are also the first merchant.

            // This is useful if the deployer is also directly operating as a merchant.

            _grantRole(MERCHANT_ROLE, msg.sender);

        } else {

            _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);

            // If an initialAdmin is specified, they might also be the first merchant,

            // or another address might receive the MERCHANT_ROLE separately after deployment.

        }

    }



    // The following functions are inherited from AccessControl and are available:

    // - hasRole(bytes32 role, address account) returns (bool)

    // - getRoleAdmin(bytes32 role) returns (bytes32)

    // - grantRole(bytes32 role, address account)

    // - revokeRole(bytes32 role, address account)

    // - renounceRole(bytes32 role, address account)



    // --- Merchant Management Functions (Callable by DEFAULT_ADMIN_ROLE) ---



    /**

     * @dev Grants the MERCHANT_ROLE to an address, allowing them to reward customers.

     * Only callable by an account with DEFAULT_ADMIN_ROLE.

     * @param merchant The address to grant merchant role to.

     */

    function addMerchant(address merchant) public onlyRole(DEFAULT_ADMIN_ROLE) {

        // NEW: Use custom error and check if role is already granted via hasRole

        if (merchant == address(0)) revert EcomXToken__InvalidAddress();

        if (hasRole(MERCHANT_ROLE, merchant)) revert EcomXToken__AlreadyAdded();

        _grantRole(MERCHANT_ROLE, merchant);

        emit MerchantAdded(merchant);

    }



    /**

     * @dev Revokes the MERCHANT_ROLE from an address, preventing them from rewarding customers.

     * Only callable by an account with DEFAULT_ADMIN_ROLE.

     * @param merchant The address to revoke merchant role from.

     */

    function removeMerchant(address merchant) public onlyRole(DEFAULT_ADMIN_ROLE) {

        // NEW: Use custom error and check if role exists before revoking

        if (merchant == address(0)) revert EcomXToken__InvalidAddress();

        if (!hasRole(MERCHANT_ROLE, merchant)) revert EcomXToken__RoleDoesNotExist();

        _revokeRole(MERCHANT_ROLE, merchant);

        emit MerchantRemoved(merchant);

    }



    // --- Pause/Unpause Functionality (NEW) ---



    /**

     * @dev Pauses all token operations (rewarding, redeeming).

     * Only callable by an account with DEFAULT_ADMIN_ROLE.

     */

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {

        _pause();

    }



    /**

     * @dev Unpauses all token operations.

     * Only callable by an account with DEFAULT_ADMIN_ROLE.

     */

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {

        _unpause();

    }



    // --- Core Loyalty Program Functions ---



    /**

     * @dev Allows an authorized merchant to reward a customer by minting new ECMX tokens.

     * This function increases the total supply of tokens.

     * Only callable by an account with MERCHANT_ROLE and when the contract is not paused.

     * @param customer The address of the customer to reward.

     * @param amount The amount of ECMX tokens to mint as a reward.

     */

    function rewardCustomer(address customer, uint256 amount) public onlyRole(MERCHANT_ROLE) whenNotPaused { // NEW: added whenNotPaused

        if (customer == address(0)) revert EcomXToken__InvalidAddress();

        if (amount == 0) revert EcomXToken__ZeroAmount();



        // Mint new tokens to the customer's address.

        _mint(customer, amount);



        emit CustomerRewarded(customer, amount);

    }



    /**

     * @dev Allows authorized merchants to reward multiple customers in a single transaction.

     * This improves gas efficiency for batch operations.

     * Only callable by an account with MERCHANT_ROLE and when the contract is not paused.

     * @param customers An array of customer addresses to reward.

     * @param amounts An array of amounts corresponding to each customer.

     */

    function rewardCustomersInBatch(address[] calldata customers, uint256[] calldata amounts)

        public

        onlyRole(MERCHANT_ROLE)

        whenNotPaused // NEW: added whenNotPaused

    {

        if (customers.length != amounts.length) revert EcomXToken__ArraysLengthMismatch();



        for (uint256 i = 0; i < customers.length; i++) {

            if (customers[i] == address(0)) revert EcomXToken__InvalidAddress(); // Check individual address

            if (amounts[i] == 0) revert EcomXToken__ZeroAmount(); // Check individual amount

            _mint(customers[i], amounts[i]);

            emit CustomerRewarded(customers[i], amounts[i]);

        }

    }



    /**

     * @dev Allows a token holder (customer) to redeem their ECMX tokens by burning them.

     * The tokens are permanently removed from circulation.

     * Only callable when the contract is not paused.

     * @param amount The amount of ECMX tokens to burn for redemption.

     */

    function redeemTokens(uint256 amount) public whenNotPaused { // NEW: added whenNotPaused

        if (amount == 0) revert EcomXToken__ZeroAmount();

        // NEW: Use custom error with parameters for more detail

        if (balanceOf(msg.sender) < amount) revert EcomXToken__InsufficientBalance(amount, balanceOf(msg.sender));



        // _burn is inherited from ERC20Burnable and burns from msg.sender's balance.

        _burn(msg.sender, amount);

        emit TokensRedeemed(msg.sender, amount);

    }



    // --- Helper Function ---



    /**

     * @dev Checks if an address has the MERCHANT_ROLE.

     * @param account The address to check.

     * @return True if the account has the MERCHANT_ROLE, false otherwise.

     */

    function isMerchant(address account) public view returns (bool) {

        return hasRole(MERCHANT_ROLE, account);

    }

}
