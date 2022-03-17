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

contract CustomerContract is Ownable {
    // PancakeSwap v2 router address
    address private PANCAKESWAP_V2_ROUTER = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1;

    // WBNB address
    address private WBNB = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;

    // Mindsync platform contract address. Set by owner
    address public platformContract = 0x3cf8cDEe4c28739d6a5Afff4caC7Bf60524c0B66;

    // BSC MAI token address. Set by owner
    address public mediaContract = 0x3e13482005D3E6Bb5334b7bD6590D7AD5EfBCC66;

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
        uint256 deadline = block.timestamp + 100;
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(mediaContract);

        // Send all balance
        uint256 amount = address(this).balance;
        IPancakeV2Router(PANCAKESWAP_V2_ROUTER).swapExactETHForTokens{
            value: amount
        }(0, path, platformContract, deadline);
    }
}
