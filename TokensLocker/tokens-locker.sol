// SPDX-License-Identifier: MIT

// Use the solidity compiler version 0.8.0 or later
pragma solidity >=0.8.0;

/*
 * @dev
 * -----------------------------------------------------
 * Interface to ERC20
 * -----------------------------------------------------
 */
interface IERC20 {
    function balanceOf(address owner) external view returns (uint);
    function transfer(address to, uint value) external returns (bool);
    function burn(uint256 _value) external;
}

/*
 * @dev
 * -------------------------------
 * Tokens Locker contract
 * -------------------------------
 * This contract allows you to lock tokens on its balance until a specified date,
 * as well as share the locked tokens among several addresses. The contract does 
 * not allow to withdraw tokens before the unlock date under any conditions to any
 * member of the contract.
 */
contract TokensLocker {
    /* @dev Contract constants and variables:
     * "public" means that the variable can be read by any bscscan.com user (for example).
     * "immutable" means that the variable can be set once when the contract is created and cannot be changed after that.
     */

    // ERC20 token contract address.
    // It can only be set once when creating a contract.
    address public immutable token;

    // The owner of the locker contract.
    address public owner;

    // User balances
    mapping(address => uint256) public balances;
    uint256 public totalUsersBalance;

    // Unlock date as a unix timestamp. The default value is 0.
    // You can convert the timestamp to a readable date-time at https://www.unixtimestamp.com/.
    uint public unlockDate;

    // Allow share tokens for users
    bool public  allowShareTokens = true;

    // Definition of events.
    // If event is emitted, it stores the arguments passed in transaction logs.
    // These logs are stored on blockchain and are accessible using address of the
    // contract till the contract is present on the blockchain.
    event OwnerChanged(address oldOwner, address newOwner);
    event TokensLocked(uint256 amount, uint until);
    event TokensUnlocked(address addr, uint256 amount, uint date);
    event TokensAllocated(address user, uint256 amount, uint256 userBalance);
    event TokensReturnedByUser(address user, uint256 amount, uint256 userBalance);

    /**
     * @notice Locker contract constructor. It will only be called once when deploying
     * contract.
     */
     constructor(address _token) {
        // Set the locker contract owner to the creator of the contract (msg.sender)
        owner = msg.sender;

        // Set token address to _token
        token = _token;

        // Simplified check if token is a contract
        tokenBalance();
    }

    /**
     * @notice The modifier will be used later with the lock and unlock functions, so only the owner of
     * contract owner can call these functions.
     */
    modifier onlyOwner() {
        // The function will fail if the contract is not called by its owner
        require (msg.sender == owner);

        // Run the rest of the modified function code
        _;
    }

    modifier tokensShareAllowed() {
        require (allowShareTokens);
        _;
    }

    /**
     * @notice
     * Change locker contract owner (Transfer ownership). 
     * @param _newOwner new owner of the locker contract
     */
    function changeOwner(address _newOwner) external
        // Only owner can call this function
        onlyOwner
    {
        // Emit public event to notify subscribers
        emit OwnerChanged(owner, _newOwner);

        // Set new owner to _newOwner
        owner = _newOwner;
    }

    function disableTokensShare() external 
        onlyOwner
    {
        require (totalUsersBalance == 0, "D"); // Can not lock users with balances
        allowShareTokens = false;
    }

    /*
     * ---------------------------------------------------------------------------------
     * Lock and Unlock functions
     * ---------------------------------------------------------------------------------
     */

    /**
     * @notice Lock function. The owner must call this function to lock or to extend the lock of tokens.
     * @param _unlockDate the unlock date
     */
    function lock(uint _unlockDate) public
        // Only owner can call this function
        onlyOwner
    {

        // The new unlock date must be greater than the last unlock date.
        // This condition guarantees that we cannot reduce the blocking period,
        // but we can increase it.
        require (_unlockDate > unlockDate, "IUD"); // Invalid unlock date

        // The unlock date must be in the future.
        require (_unlockDate > block.timestamp, "IUD"); // Invalid unlock date

        // Set the date to unlock tokens. Before this date, it is
        // not possible to transfer tokens from the contract.
        unlockDate = _unlockDate;

        // Emit a TokensLocked event so that it is visible to any event subscriber
        emit TokensLocked(tokenBalance(), unlockDate);
    }

    /**
     * @notice Unlock tokens. This function will transfer tokens from the contract to the owner.
     * If the function is called before the unlockDate, it will fail.
     */
    function unlockOwner() external
        // Only owner can call the function
        onlyOwner
    {
        // Check if the current date is greater than or equal to unlockDate. Fail if it is not.
        require (block.timestamp >= unlockDate, "NY"); // Not yet

        // Get token balance
        uint256 balance = tokenBalance();

        // Get owner's balance
        uint256 ownerBalance = balance - totalUsersBalance;

        // Require amount > 0
        require (ownerBalance > 0, "ZOB"); // Zero owner balance
        
        // Transfer tokens to the owner's address
        IERC20(token).transfer(owner, ownerBalance);

        // Emit a TokensUnlocked event so that it is visible to any event subscriber
        emit TokensUnlocked(owner, ownerBalance, block.timestamp);
    }

    /**
     * @notice Unlock tokens. This function will transfer tokens from the contract to the owner.
     * If the function is called before the unlockDate, it will fail.
     * @param amount is the amount of tokens to unlock
     */
    function unlockTokensFor(address user, uint amount) public
        tokensShareAllowed
    {
        // Only user or owner can call the function
        if (msg.sender != user) {
            require (msg.sender == owner, "A"); //Access denied
        }

        // Check if the current date is greater than or equal to unlockDate. Fail if it is not.
        require (block.timestamp >= unlockDate, "NY"); // Not yet

        // Get token balance
        uint256 balance = tokenBalance();

        // Require amount > 0
        require (amount > 0, "IA"); // Invalid amount
        
        // Require balance >= amount
        require (balance >= amount, "ITB"); // Insufficient total tokens balance

        // User balance must be >= amount requested
        uint256 userBalance = balances[user];
        require (userBalance >= amount, "IUB"); // Insufficient user balance

        // Transfer tokens to the owner's address
        IERC20(token).transfer(user, amount);
        totalUsersBalance -= amount;
        balances[user] -= amount;

        // Emit a TokensUnlocked event so that it is visible to any event subscriber
        emit TokensUnlocked(user, amount, block.timestamp);
    }

    // Unlock all user tokens
    function unlockTokens() external {
        unlockTokensFor(msg.sender, balances[msg.sender]);
    }


    // Allocate tokens for user by owner
    function allocateTokensFor(address user, uint256 amount) external
        onlyOwner
        tokensShareAllowed 
        returns (uint256 userBalance)
    {
        uint256 ownerBalance = tokenBalance() - totalUsersBalance;

        // Owner token balance must be enough for user token allocation
        require (ownerBalance >= amount, "ITB"); // Insufficient total balance
        
        // Don't allow owner to allocate their own tokens as user tokens
        require (user != owner, "A");

        // Set user balance
        userBalance = balances[user] + amount;
        balances[user] = userBalance;

        // Add to total users balance
        totalUsersBalance += amount;

        emit TokensAllocated(user, amount, userBalance);

        return userBalance;
    }

    // Give up tokens by user allocated before. Only allocated tokens owner (user) can call this function.
    // This feature allows the user to give up all or part of the tokens to the contract owner.
    function givupTokens(uint256 amount) public returns (uint256 userBalance) 
    {
        address user = msg.sender;

        userBalance = balances[user];

        // Require user exists
        require (userBalance > 0, "A"); // Access denied

        require (amount >= userBalance, "IUB"); // Insufficient user balance

        uint256 newBalance = balances[user] - amount;
        
        // Set user balance
        balances[user] = newBalance;

        // Remove balance from total users balance
        totalUsersBalance -= amount;

        emit TokensReturnedByUser(user, amount, newBalance);

        return newBalance;
    }

    // Give up all user tokens. Only allocated tokens owner (user) can call this function.
    function givupAllTokens() external returns (uint256 userBalance) 
    {
        return givupTokens(balances[msg.sender]);
    }

    function burnOwnerTokens(uint256 amount) external
        onlyOwner
    {
        uint256 ownerBalance = tokenBalance() - totalUsersBalance;

        require (ownerBalance > amount, "IOB"); // Insufficient owner balance

        IERC20(token).burn(amount);
    }

    /**
     * @dev
     * -------------------------------------------------------------------------------------------
     * Read-only functions to retrieve information from the contract to make it publicly available
     * -------------------------------------------------------------------------------------------
     */

    // Get the balance of tokens of the locker contract
    function tokenBalance() public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
