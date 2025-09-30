// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20; // Consistent pragma version

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol"; // Imports ERC20 and adds burn functionality
import "@openzeppelin/contracts/access/AccessControl.sol"; // Imports AccessControl for role management
import "@openzeppelin/contracts/utils/Pausable.sol";     // NEW: Imports Pausable for emergency pause functionality


  @title EcomXToken
  @dev ERC20 token for EcomX Loyalty and Reward System.
  Implements ERC20 standard, burn functionality for redemptions,
  role-based access control for managing merchants and minting rewards,
  and a pausable mechanism for emergency control.
  It uses custom errors for more efficient and clearer error handling.
 
contract EcomXToken is ERC20Burnable, AccessControl, Pausable { // NEW: Inherits Pausable for pause/unpause functionality

    // --- Custom Errors ---
    // These provide more gas-efficient and structured error feedback to the frontend (compared to string reverts).
  
    error EcomXToken__InvalidAddress();
    error EcomXToken__ZeroAmount();
    error EcomXToken__InsufficientBalance(uint256 required, uint256 available);
    error EcomXToken__MerchantAlreadyAdded(address merchant); // More specific error for role management
    error EcomXToken__MerchantNotFound(address merchant);     // More specific error for role management
    error EcomXToken__ArraysLengthMismatch(); // For batch operations

    // --- Roles Definitions ---
    // DEFAULT_ADMIN_ROLE is built-in to AccessControl and controls all other roles.
    bytes32 public constant MERCHANT_ROLE = keccak256("MERCHANT_ROLE"); // Role for authorized merchants

    // --- Events ---
    // Events are crucial for off-chain monitoring and frontend updates.
    // While emitting events costs gas, their benefit for transparency and dApp functionality outweighs the cost.
    event MerchantAdded(address indexed merchant);
    event MerchantRemoved(address indexed merchant);
    event CustomerRewarded(address indexed customer, uint256 amount);
    event TokensRedeemed(address indexed burner, uint256 amount);

    /**
     * @dev Constructor to initialize the ERC20 token and set up initial roles.
     * The deployer of this contract automatically becomes the DEFAULT_ADMIN_ROLE.
     * Optionally, a specific initial admin address can be provided, and the deployer
     * can also be granted the MERCHANT_ROLE automatically if acting as the first merchant.
     * @param initialAdmin The address to grant DEFAULT_ADMIN_ROLE to. If address(0), msg.sender will be the admin.
     */
    constructor(address initialAdmin) ERC20("EcomX Loyalty Token", "ECMX") {
        // Determine the initial administrator based on the provided parameter.
        address adminToGrant = (initialAdmin == address(0)) ? msg.sender : initialAdmin;

        // Grant the determined address the DEFAULT_ADMIN_ROLE. This role can then manage all other roles.
        _grantRole(DEFAULT_ADMIN_ROLE, adminToGrant);

        // Optional: If the contract deployer (msg.sender) is also intended to be a merchant from the start,

        if (initialAdmin == address(0)) {
            _grantRole(MERCHANT_ROLE, msg.sender);
        }
    }

    // --- Merchant Management Functions (Callable by DEFAULT_ADMIN_ROLE) ---

    /**
     * @dev Grants the `MERCHANT_ROLE` to a specified address.
     * Only accounts with `DEFAULT_ADMIN_ROLE` can call this function.
     * Reverts if the address is invalid or already has the role.
     * @param merchant The address to grant the merchant role to.
     */
    function addMerchant(address merchant) public onlyRole(DEFAULT_ADMIN_ROLE) {
        // Optimization: Using custom errors (EcomXToken__InvalidAddress, EcomXToken__MerchantAlreadyAdded)
        // for more gas-efficient reverts compared to string messages.
        if (merchant == address(0)) revert EcomXToken__InvalidAddress();
        if (hasRole(MERCHANT_ROLE, merchant)) revert EcomXToken__MerchantAlreadyAdded(merchant);
        _grantRole(MERCHANT_ROLE, merchant);
        emit MerchantAdded(merchant);
    }

    /**
     * @dev Revokes the `MERCHANT_ROLE` from a specified address.
     * Only accounts with `DEFAULT_ADMIN_ROLE` can call this function.
     * Reverts if the address is invalid or does not have the role.
     * @param merchant The address to revoke the merchant role from.
     */
    function removeMerchant(address merchant) public onlyRole(DEFAULT_ADMIN_ROLE) {
        // Optimization: Using custom errors (EcomXToken__InvalidAddress, EcomXToken__MerchantNotFound)
        // for more gas-efficient reverts.
        if (merchant == address(0)) revert EcomXToken__InvalidAddress();
        if (!hasRole(MERCHANT_ROLE, merchant)) revert EcomXToken__MerchantNotFound(merchant);
        _revokeRole(MERCHANT_ROLE, merchant);
        emit MerchantRemoved(merchant);
    }

    // --- Administrative Pause/Unpause Functionality ---

    /**
     * @dev Pauses all token operations that are marked with `whenNotPaused` modifier
     * (e.g., `rewardCustomer`, `rewardCustomersInBatch`, `redeemTokens`).
     * Only callable by an account with `DEFAULT_ADMIN_ROLE`.
     * Emits a `Paused` event.
     */
    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause(); // Inherited from Pausable, handles pausing the contract
    }

    /**
     * @dev Unpauses all token operations, allowing them to resume.
     * Only callable by an account with `DEFAULT_ADMIN_ROLE`.
     * Emits an `Unpaused` event.
     */
    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause(); // Inherited from Pausable, handles unpausing the contract
    }

    // --- Core Loyalty Program Functions ---

    /**
     * @dev Allows an authorized merchant to reward a single customer by minting new ECMX tokens.
     * This function increases the total supply of tokens.
     * Only callable by an account with `MERCHANT_ROLE` and when the contract is not paused.
     * Reverts if the customer address is invalid or the amount is zero.
     * @param customer The address of the customer to reward.
     * @param amount The amount of ECMX tokens to mint as a reward.
     */
    function rewardCustomer(address customer, uint256 amount) public onlyRole(MERCHANT_ROLE) whenNotPaused { // Optimization: `whenNotPaused` modifier saves gas by reverting early if paused
        // Optimization: Using custom errors (EcomXToken__InvalidAddress, EcomXToken__ZeroAmount)
        // for more gas-efficient reverts.
        if (customer == address(0)) revert EcomXToken__InvalidAddress();
        if (amount == 0) revert EcomXToken__ZeroAmount();

        _mint(customer, amount); // Mints new tokens to the customer's address (inherently involves storage writes, which are costly but necessary)
        emit CustomerRewarded(customer, amount);
    }

    /**
     * @dev Allows authorized merchants to reward multiple customers in a single transaction.
     * This improves gas efficiency for batch operations compared to multiple individual transactions.
     * Only callable by an account with `MERCHANT_ROLE` and when the contract is not paused.
     * Reverts if array lengths mismatch, or if any customer address is invalid or amount is zero.
     * @param customers An array of customer addresses to reward.
     * @param amounts An array of amounts corresponding to each customer, same order as `customers`.
     */
    function rewardCustomersInBatch(address[] calldata customers, uint256[] calldata amounts)
        public
        onlyRole(MERCHANT_ROLE)
        whenNotPaused // Optimization: `whenNotPaused` modifier saves gas by reverting early if paused
    {
        // Optimization: Using custom errors (EcomXToken__ArraysLengthMismatch, EcomXToken__InvalidAddress, EcomXToken__ZeroAmount)
        // for more gas-efficient reverts.
        if (customers.length != amounts.length) revert EcomXToken__ArraysLengthMismatch();

        // Major Gas Optimization: Processing multiple rewards in a single transaction.
        // This amortizes fixed transaction costs (like transaction header, signature verification)
        // over many operations, making it significantly cheaper than N individual transactions.
        for (uint256 i = 0; i < customers.length; i++) {
            if (customers[i] == address(0)) revert EcomXToken__InvalidAddress();
            if (amounts[i] == 0) revert EcomXToken__ZeroAmount();
            _mint(customers[i], amounts[i]); // Each mint involves storage writes, which are the primary cost here.
            emit CustomerRewarded(customers[i], amounts[i]); // Emit for each successful reward (adds gas cost, but crucial for transparency)
        }
    }

    /**
     * @dev Allows a token holder (customer) to redeem their ECMX tokens by burning them.
     * The tokens are permanently removed from circulation, reducing the total supply.
     * Only callable when the contract is not paused.
     * Reverts if the amount is zero or if the caller has insufficient balance.
     * @param amount The amount of ECMX tokens to burn for redemption.
     */
    function redeemTokens(uint256 amount) public whenNotPaused { // Optimization: `whenNotPaused` modifier saves gas by reverting early if paused
        // Optimization: Using custom errors (EcomXToken__ZeroAmount, EcomXToken__InsufficientBalance)
        // for more gas-efficient reverts.
        if (amount == 0) revert EcomXToken__ZeroAmount();
        // Check for sufficient balance using a custom error with details
        if (balanceOf(msg.sender) < amount) {
            revert EcomXToken__InsufficientBalance(amount, balanceOf(msg.sender));
        }

        _burn(msg.sender, amount); // Burns tokens from the caller's balance (inherently involves storage writes)
        emit TokensRedeemed(msg.sender, amount); // Emitting event (adds gas cost, but crucial for transparency)
    }

    // --- Helper Function ---

    /**
     * @dev Checks if a given address has the `MERCHANT_ROLE`.
     * This is a public view function, accessible off-chain (e.g., by the frontend)
     * to determine a user's merchant status. View functions are free to call (no gas cost for reads).
     * @param account The address to check.
     * @return True if the account has the `MERCHANT_ROLE`, false otherwise.
     */
    function isMerchant(address account) public view returns (bool) {
        return hasRole(MERCHANT_ROLE, account); // Inherited from AccessControl
    }
}        // 1. The contract owner needs to have enough tokens to distribute all rewards.
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
