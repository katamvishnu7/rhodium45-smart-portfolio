// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IPancakeRouterV2 {
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );
}

contract RhodiumLiquidity is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Initial RH liquidity
    uint256 public constant RH_LIQUIDITY = 6_000_000 ether;

    // Initial BNB/tBNB liquidity
    uint256 public constant BNB_LIQUIDITY = 600 ether;

    IERC20 public RH;

    IPancakeRouterV2 public immutable router;

    // Sale contract is allowed to trigger automatic liquidity.
    address public saleContract;

    // LP tokens are sent here.
    address public immutable lpReceiver;

    bool public rhConfigured;
    bool public liquidityInitialized;

    uint256 public rhUsed;
    uint256 public bnbUsed;
    uint256 public lpTokensReceived;

    event RHConfigured(address indexed token);

    event SaleContractConfigured(
        address indexed saleContract
    );

    event BNBReceived(
        address indexed sender,
        uint256 amount
    );

    event InitialLiquidityAdded(
        uint256 rhAmount,
        uint256 bnbAmount,
        uint256 lpTokens
    );

    constructor(
        address router_,
        address lpReceiver_,
        address initialOwner_
    )
        Ownable(initialOwner_)
    {
        require(
            router_ != address(0),
            "Invalid router"
        );

        require(
            lpReceiver_ != address(0),
            "Invalid LP receiver"
        );

        require(
            initialOwner_ != address(0),
            "Invalid owner"
        );

        router = IPancakeRouterV2(router_);
        lpReceiver = lpReceiver_;
    }

    // =========================================================
    // CONFIGURATION
    // =========================================================

    function configureSaleContract(
        address saleContract_
    )
        external
        onlyOwner
    {
        require(
            saleContract == address(0),
            "Sale already configured"
        );

        require(
            saleContract_ != address(0),
            "Invalid sale"
        );

        saleContract = saleContract_;

        emit SaleContractConfigured(
            saleContract_
        );
    }

    function setRH(
        address rh_
    )
        external
        onlyOwner
    {
        require(
            !rhConfigured,
            "RH already configured"
        );

        require(
            rh_ != address(0),
            "Invalid RH"
        );

        RH = IERC20(rh_);
        rhConfigured = true;

        emit RHConfigured(rh_);
    }

    // =========================================================
    // AUTOMATIC LIQUIDITY
    // =========================================================

    /*
        Called automatically by RhodiumSale when Stage 1
        reaches exactly 10,000,000 RH sold.

        Required:
            6,000,000 RH already held by this contract
            600 BNB/tBNB sent with this call
    */
    function initializeLiquidityFromSale()
        external
        payable
        nonReentrant
    {
        require(
            msg.sender == saleContract,
            "Only sale contract"
        );

        require(
            rhConfigured,
            "RH not configured"
        );

        require(
            !liquidityInitialized,
            "Liquidity already initialized"
        );

        require(
            msg.value == BNB_LIQUIDITY,
            "Incorrect BNB amount"
        );

        require(
            RH.balanceOf(address(this)) >= RH_LIQUIDITY,
            "Insufficient RH"
        );

        // Approve PancakeSwap router to use 6M RH.
        RH.forceApprove(
            address(router),
            RH_LIQUIDITY
        );

        (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        ) = router.addLiquidityETH{
            value: BNB_LIQUIDITY
        }(
            address(RH),
            RH_LIQUIDITY,
            RH_LIQUIDITY,
            BNB_LIQUIDITY,
            lpReceiver,
            block.timestamp + 30 minutes
        );

        /*
            For the initial pool we require the complete
            6M RH + 600 BNB to be used.
        */
        require(
            amountToken == RH_LIQUIDITY,
            "Not all RH used"
        );

        require(
            amountETH == BNB_LIQUIDITY,
            "Not all BNB used"
        );

        // Remove router approval after use.
        RH.forceApprove(
            address(router),
            0
        );

        rhUsed = amountToken;
        bnbUsed = amountETH;
        lpTokensReceived = liquidity;

        liquidityInitialized = true;

        emit InitialLiquidityAdded(
            amountToken,
            amountETH,
            liquidity
        );
    }

    // =========================================================
    // RECEIVE
    // =========================================================

    /*
        BNB/tBNB can only enter this contract from:
        1. RhodiumSale
        2. PancakeSwap router
    */
    receive()
        external
        payable
    {
        require(
            msg.sender == saleContract ||
            msg.sender == address(router),
            "BNB sender not allowed"
        );

        emit BNBReceived(
            msg.sender,
            msg.value
        );
    }

    fallback()
        external
        payable
    {
        revert("Invalid function");
    }
}