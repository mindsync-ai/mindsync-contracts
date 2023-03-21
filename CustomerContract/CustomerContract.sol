// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Part of interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

}


interface IPancakeV2Router {
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);
}

interface IMindsyncEscrow {
    function deposit(uint256 amount) external;
}

contract CustomerContract {
    address private _owner;

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require (_owner == msg.sender);
        _;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _owner = newOwner;
    }

    event Deposit(address source, uint256 amount, uint256 tokens);

    // PancakeSwap v2 router address
    // address private PANCAKESWAP_V2_ROUTER = 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3;  // Testnet
    address constant PANCAKESWAP_V2_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

    // WBNB address
    // address private WBNB = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;  // Testnet
    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    // Mindsync platform contract address. Set by owner
    // address public platformContract = 0x3cf8cDEe4c28739d6a5Afff4caC7Bf60524c0B66;  // Testnet
    address public platformContract = 0x14A66FBcADf95883802035312AcADb06969ba474;

    // BSC MAI token address. Set by owner
    // address public mediaContract = 0x3e13482005D3E6Bb5334b7bD6590D7AD5EfBCC66;  // Testnet
    address constant mediaContract = 0xe985e923b6c52b420DD33549A0ebc2CdeB0AE173;

    /**
     * @dev Set the Mindsync platform contract address.
     */
    function setPlatformContract(address platformContractAddress)
        external
        onlyOwner
    {
        require(
            platformContractAddress != address(0) // Cannot set Mindsync platform contract as zero address
        );
        platformContract = platformContractAddress;
    }

    /**
     * @dev receive function that is executed on BNB transfers.
     */
    receive() external payable {
        _swap();
    }

    /**
     * @dev Swap all balance of BNB for MAI via Pancakeswap
     */
    function _swap() internal {
        require(mediaContract != address(0), "M"); // You must set media contract address.
        uint256 deadline = block.timestamp + 50000;
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(mediaContract);

        // Send all balance
        uint256 amount = address(this).balance;
        require(amount != 0, "0"); // Can not buy tokens for zero BNB

        // TODO: protect transaction from front runners
        IPancakeV2Router(PANCAKESWAP_V2_ROUTER).swapExactETHForTokens{
            value: amount
        }(0, path, address(this), deadline);

        uint256 balance = IERC20(mediaContract).balanceOf(address(this));
        require(balance != 0, "P"); // Ups! Tokens not received from Pancakeswap
        IERC20(mediaContract).approve(platformContract, balance);
        IMindsyncEscrow(platformContract).deposit(balance);

        emit Deposit(msg.sender, amount, balance);
    }
}
