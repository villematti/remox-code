// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Importing the Uniswap Router Interface
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SnipingBot {

    string private constant WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
    string private constant UNISWAP_CONTRACT_ADDRESS = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
    address private immutable uniswapRouterAddress;

    event Sniped(string token, uint amountETH, uint amountToken, uint slippage);

    constructor() {
        uniswapRouterAddress = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    }

    // Fallback function to accept ETH deposits
    receive() external payable {}

    // Struct to hold token data during sniping
    struct TokenData {
        string token;
        uint256 amountETH;
        uint256 slippage;
    }

    address[] private path;

    // Snipe function to identify and execute opportunities
    function snipeToken(TokenData memory tokenData) external {
        address tokenAddress = stringToAddress(tokenData.token);
        uint256 tokenBalanceBefore = getTokenBalance(tokenAddress);

        // Setting up Uniswap path (WETH -> token)
        path[0] = stringToAddress(WETH);
        path[1] = tokenAddress;

        // Swap ETH for the target token
        IUniswapV2Router02(uniswapRouterAddress).swapExactETHForTokens{value: tokenData.amountETH}(
            0, // accept any amount of tokens (sniping implies quick action)
            path,
            address(this),
            block.timestamp + 300 // 5 minutes deadline
        );

        uint256 tokenBalanceAfter = getTokenBalance(tokenAddress);
        require(tokenBalanceAfter > tokenBalanceBefore, "No tokens acquired");

        uint256 tokensAcquired = tokenBalanceAfter - tokenBalanceBefore;

        // Calculate slippage by comparing the expected vs acquired tokens
        uint256 slippage = calculateSlippage(tokenData.amountETH, tokensAcquired);

        require(slippage <= tokenData.slippage, "Excessive slippage");

        // Emit an event with sniping details
        emit Sniped(tokenData.token, tokenData.amountETH, tokensAcquired, slippage);
    }

    // Function to withdraw ETH from the contract
    function withdrawETH(uint256 amount) external {
        require(address(this).balance >= amount, "Insufficient balance");
        payable(msg.sender).transfer(amount);
    }

    // Withdraw any ERC20 tokens acquired during sniping
    function withdrawToken(string memory token, uint256 amount) external {
        address tokenAddress = stringToAddress(token);
        require(getTokenBalance(tokenAddress) >= amount, "Insufficient token balance");
        IERC20(tokenAddress).transfer(msg.sender, amount);
    }

    // Helper function to get balance of a specific token held by the contract
    function getTokenBalance(address token) public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    // Helper function to calculate slippage (simplified for this contract)
    function calculateSlippage(uint256 ethAmount, uint256 tokenAmount) internal pure returns (uint256) {
        return (ethAmount * 100) / tokenAmount;
    }

    // Function to start sniping with ETH, specifying target token and slippage tolerance
    function startSniping(string memory token, uint256 amountETH, uint256 slippageTolerance) external payable {
        require(msg.value >= amountETH, "Insufficient ETH sent");

        TokenData memory tokenData = TokenData({
            token: token,
            amountETH: amountETH,
            slippage: slippageTolerance
        });

        this.snipeToken(tokenData);
    }

    // Utility function to convert string address to actual address
    function stringToAddress(string memory _a) internal pure returns (address) {
        bytes memory tmp = bytes(_a);
        uint160 iaddr = 0;
        uint160 b1;
        uint160 b2;
        for (uint i = 2; i < 2 + 2 * 20; i += 2) {
            iaddr *= 256;
            b1 = uint160(uint8(tmp[i]));
            b2 = uint160(uint8(tmp[i + 1]));
            if ((b1 >= 97) && (b1 <= 102)) {
                b1 -= 87;
            } else if ((b1 >= 65) && (b1 <= 70)) {
                b1 -= 55;
            } else if ((b1 >= 48) && (b1 <= 57)) {
                b1 -= 48;
            }
            if ((b2 >= 97) && (b2 <= 102)) {
                b2 -= 87;
            } else if ((b2 >= 65) && (b2 <= 70)) {
                b2 -= 55;
            } else if ((b2 >= 48) && (b2 <= 57)) {
                b2 -= 48;
            }
            iaddr += (b1 * 16 + b2);
        }
        return address(iaddr);
    }
}
