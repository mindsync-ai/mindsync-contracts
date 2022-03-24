// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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

contract CustomerContract is Ownable {
    event Deposit(address source, uint256 amount, uint256 tokens);

    // PancakeSwap v2 router address
    // address private PANCAKESWAP_V2_ROUTER = 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3;  // Testnet
    address private PANCAKESWAP_V2_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

    // WBNB address
    // address private WBNB = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;  // Testnet
    address private WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    // Mindsync platform contract address. Set by owner
    // address public platformContract = 0x3cf8cDEe4c28739d6a5Afff4caC7Bf60524c0B66;  // Testnet
    address public platformContract = 0x14A66FBcADf95883802035312AcADb06969ba474;

    // BSC MAI token address. Set by owner
    // address public mediaContract = 0x3e13482005D3E6Bb5334b7bD6590D7AD5EfBCC66;  // Testnet
    address public mediaContract = 0xe985e923b6c52b420DD33549A0ebc2CdeB0AE173;

    /**
     * @dev Set the Mindsync platform contract address.
     */
    function setPlatformContract(address platformContractAddress)
        external
        onlyOwner
    {
        require(
            platformContractAddress != address(0),
            "Cannot set Mindsync platform contract as zero address"
        );
        platformContract = platformContractAddress;
    }

    /**
     * @dev Set the media contract address.
     */
    function setMediaContract(address mediaContractAddress) external onlyOwner {
        require(
            mediaContractAddress != address(0),
            "Cannot set media contract as zero address"
        );
        mediaContract = mediaContractAddress;
    }

    /**
     * @dev receive function that is executed on BNB transfers.
     */
    receive() external payable {
        _swap();
    }

    /**
     * @dev Swap all balance of BNB for getting MAI
     */
    function _swap() internal {
        require(mediaContract != address(0), "You must set media contract address.");
        uint256 deadline = block.timestamp + 50000;
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(mediaContract);

        // Send all balance
        uint256 amount = address(this).balance;
        require(amount != 0, "Can not buy tokens for zero BNB");

        // IERC20(WBNB).approve(PANCAKESWAP_V2_ROUTER, amount);
        IPancakeV2Router(PANCAKESWAP_V2_ROUTER).swapExactETHForTokens{
            value: amount
        }(0, path, address(this), deadline);

        uint256 balance = IERC20(mediaContract).balanceOf(address(this));
        require(balance != 0, "Ups! Tokens not received from Pancakeswap");
        IERC20(mediaContract).approve(platformContract, balance);
        IMindsyncEscrow(platformContract).deposit(balance);

        emit Deposit(msg.sender, amount, balance);
    }
}
