// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MindsyncEscrow is Ownable {
    using SafeMath for uint8;
    using SafeMath for uint64;
    using SafeMath for uint256;

    event AccountantChanged(address oldAccountant, address newAccountant);
    event CommissionPercentChanged(Float percent);
    event Deposit(address indexed sender, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Refund(address indexed customer, uint256 amount);

    struct Float {
        uint64 number;
        uint8 floatDecimal;
    }

    /* *******
     * Globals
     * *******
     */
    // Mapping from customer address to its balance
    mapping(address => uint256) private customers;

    // Mapping from miner address to its balance
    mapping(address => uint256) private miners;

    // Fee percent per transaction
    Float private commissionPercent;

    // Balance of fee amounts
    uint256 private commissionAmount;

    // Address of accountant
    address private accountant;

    // Total balance of customers
    uint256 private customersBalance;

    // Total balance of miners
    uint256 private minersBalance;

    address public mediaContract;

    /**
     * @dev Throws if called by any account other than the accountant
     */
    modifier onlyAccountant() {
        require(
            msg.sender == accountant,
            "Only accountant can call this function."
        );
        _;
    }

    /**
     * @dev Throws if called by any account other than miner
     */
    modifier onlyMiner() {
        require(miners[msg.sender] > 0, "You are not miner or your balance is zero");
        _;
    }

    /**
     * @dev Throws if given amount is less than zero or greater than balance of this contract.
     */
    modifier isValidateAmount(uint256 amount) {
        require(amount > 0, "Sending amount must be greater than zero.");
        require(
            amount <= _getTotalBalance(),
            "Sending amount must be less than total balance."
        );
        _;
    }

    /**
     * @dev Throws if media contract is empty.
     */
    modifier isMediaContract() {
        require(mediaContract != address(0), "You must set media contract");
        _;
    }

    constructor() {
        // Set commission percent to 2%
        _setCommissionPercent(20, 1);
    }

    /**
     * @notice Sets the media contract address.
     */
    function configure(address mediaContractAddress) external onlyOwner {
        require(
            mediaContractAddress != address(0),
            "Cannot set media contract as zero address"
        );
        mediaContract = mediaContractAddress;
    }

    /**
     * @dev Change accountant address.
     * @param newAccountant new accountant address
     */
    function setAccountant(address newAccountant) public onlyOwner {
        _setAccountant(newAccountant);
    }

    function _setAccountant(address _newAccountant) internal {
        require(_newAccountant != address(0));
        accountant = _newAccountant;
        emit AccountantChanged(accountant, _newAccountant);
    }

    /**
     * @dev Change commission percentage.
     * @param num percentage number without floating point
     * @param decimal floating place for percentage number
     */
    function setCommissionPercent(uint64 num, uint8 decimal)
        external
        onlyOwner
    {
        _setCommissionPercent(num, decimal);
    }

    function _setCommissionPercent(uint64 _num, uint8 _decimal) internal {
        require(_num >= 0, "Commission percent can't be less than zero.");
        require(_decimal >= 0, "Decimal place can't be negative number.");
        require(
            _num / 10**_decimal < 100,
            "Commission percent can't be greater than 100."
        );
        commissionPercent.number = _num;
        commissionPercent.floatDecimal = _decimal;
        emit CommissionPercentChanged(commissionPercent);
    }

    /**
     * @dev Deposit MAI for customers to use service of Mindsync platform.
     */
    function deposit(uint256 amount) external isMediaContract {
        bool sent = IERC20(mediaContract).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        require(sent, "Failed to send MAI");
        customers[msg.sender] += amount;
        customersBalance += amount;
        emit Deposit(msg.sender, amount);
    }

    /**
     * @dev Transfer an arbitrary amount of MAI from the balance of
     * one customer's address to another miner's address.
     */
    function transfer(
        address from,
        address to,
        uint256 amount
    ) external onlyAccountant {
        require(
            customers[from] > 0,
            "The sender is not in list of customers or its balance is zero."
        );
        require(
            customers[from] >= amount,
            "The sender's balance is not enough."
        );
        uint256 fee = (amount * commissionPercent.number) /
            10**commissionPercent.floatDecimal /
            100;
        commissionAmount += fee;
        customers[from] -= amount;
        customersBalance -= amount;
        miners[to] += amount - fee;
        minersBalance += amount - fee;
        emit Transfer(from, to, amount);
    }

    function _transfer(address to, uint256 amount)
        internal
        isValidateAmount(amount)
        isMediaContract
    {
        bool sent = IERC20(mediaContract).transfer(to, amount);
        require(sent, "Failed to send MAI");
    }

    /**
     * @dev Return the given customer's balance to his/her wallet.
     */
    function refund(address customerAddress) external onlyAccountant {
        require(
            customers[customerAddress] > 0,
            "Balance of the customer is zero"
        );
        _transfer(customerAddress, customers[customerAddress]);
        customersBalance -= customers[customerAddress];
        customers[customerAddress] = 0;
        emit Refund(customerAddress, customers[customerAddress]);
    }

    /**
     * @dev Transfer some of commission to given address
     */
    function transferCommission(address recipientAddress, uint256 amount)
        external
        onlyOwner
    {
        require(
            amount <= commissionAmount,
            "Sending amount must be less than commission amount."
        );
        _transfer(recipientAddress, amount);
        commissionAmount -= amount;
    }

    /**
     * @dev Transfer MAI to miner
     */
    function transferToMiner(address recipientAddress, uint256 amount)
        external
        onlyMiner
    {
        require(
            amount <= miners[msg.sender],
            "The miner's balance is not enough."
        );
        _transfer(recipientAddress, amount);
        miners[msg.sender] -= amount;
        minersBalance -= amount;
    }

    /**
     * @dev Get total balance
     */
    function getTotalBalance() external view returns (uint256) {
        return _getTotalBalance();
    }

    function _getTotalBalance() internal view isMediaContract returns (uint256) {
        return IERC20(mediaContract).balanceOf(address(this));
    }

    /**
     * @dev Get total balance of customers
     */
    function getTotalCustomersBalance() external view returns (uint256) {
        return customersBalance;
    }

    /**
     * @dev Get total balance of miners
     */
    function getTotalMinersBalance() external view returns (uint256) {
        return minersBalance;
    }

    /**
     * @dev Get commision amount
     */
    function getCommissionAmount() external view returns (uint256) {
        return commissionAmount;
    }

    /**
     * @dev Get commision percentage
     */
    function getCommissionPercent() external view returns (Float memory) {
        return commissionPercent;
    }

    /**
     * @dev Get balance of given miner address
     */
    function minerBalanceOf(address minerAddress)
        external
        view
        returns (uint256)
    {
        return miners[minerAddress];
    }

    /**
     * @dev Get balance of given customer address
     */
    function customerBalanceOf(address customerAddress)
        external
        view
        returns (uint256)
    {
        return customers[customerAddress];
    }
}
