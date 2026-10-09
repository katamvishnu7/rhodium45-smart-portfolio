// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


interface IRhodiumVesting {

    function unlockStage1() external;

    function unlockAndClaimStage2() external;

    function unlockAndClaimStage3() external;
}


interface IRhodiumLiquidity {

    function initializeLiquidityFromSale()
        external
        payable;
}


contract RhodiumSale is Ownable2Step, ReentrancyGuard {

    using SafeERC20 for IERC20;


    // =========================================================
    // CONTRACT REFERENCES
    // =========================================================

    IERC20 public RH;

    bool public rhConfigured;

    IRhodiumVesting public immutable vesting;

    address public immutable creator;

    address public immutable liquidityManager;


    // =========================================================
    // SALE TOKENOMICS
    // =========================================================

    // Total public sale allocation
    uint256 public constant PUBLIC_ALLOCATION =
        30_000_000 ether;


    // Each stage sells 10M RH
    uint256 public constant STAGE_SIZE =
        10_000_000 ether;


    // Stage 1 price:
    // 1 RH = 0.0001 BNB
    uint256 public constant STAGE1_PRICE =
        0.0001 ether;


    // 40% creator
    uint256 public constant CREATOR_BPS =
        4_000;


    // 60% liquidity
    uint256 public constant LIQUIDITY_BPS =
        6_000;


    uint256 public constant BPS =
        10_000;


    // Stage 2 lasts 30 days
    uint256 public constant STAGE2_DURATION =
        30 days;


    // Stage 3 lasts 60 days
    uint256 public constant STAGE3_DURATION =
        60 days;


    // =========================================================
    // SALE STATE
    // =========================================================

    /*
        1 = Stage 1
        2 = Stage 2
        3 = Stage 3
        4 = Launch completed
    */
    uint8 public currentStage = 1;


    // RH sold during Stage 1
    uint256 public stage1Sold;


    // Timestamp Stage 2 begins
    uint256 public stage2Start;


    // Timestamp Stage 3 begins
    uint256 public stage3Start;


    // Timestamp launch completes
    uint256 public launchCompletedAt;


    // Creator's accumulated BNB
    uint256 public creatorBNB;


    // BNB reserved for initial liquidity
    uint256 public liquidityBNB;


    // =========================================================
    // EVENTS
    // =========================================================

    event Stage1Purchase(
        address indexed buyer,
        uint256 rhAmount,
        uint256 bnbPaid
    );


    event Stage1Completed(
        uint256 timestamp
    );


    event Stage2Started(
        uint256 timestamp
    );


    event Stage2Claimed(
        uint256 amount,
        uint256 timestamp
    );


    event Stage3Started(
        uint256 timestamp
    );


    event Stage3Claimed(
        uint256 amount,
        uint256 timestamp
    );


    event LaunchCompleted(
        uint256 timestamp
    );


    event AutomaticLiquidityInitialized(
        uint256 rhAmount,
        uint256 bnbAmount
    );


    event CreatorBNBClaimed(
        address indexed creator,
        uint256 amount
    );


    // =========================================================
    // CONSTRUCTOR
    // =========================================================

    constructor(
        address initialOwner,
        address vestingContract,
        address creatorAddress,
        address liquidityManagerAddress
    )
        Ownable(initialOwner)
    {
        require(
            initialOwner != address(0),
            "Invalid owner"
        );

        require(
            vestingContract != address(0),
            "Invalid vesting"
        );

        require(
            creatorAddress != address(0),
            "Invalid creator"
        );

        require(
            liquidityManagerAddress != address(0),
            "Invalid liquidity manager"
        );


        vesting =
            IRhodiumVesting(
                vestingContract
            );


        creator =
            creatorAddress;


        liquidityManager =
            liquidityManagerAddress;
    }


    // =========================================================
    // CONFIGURE RH
    // =========================================================

    function configureRH(
        address rhToken_
    )
        external
        onlyOwner
    {
        require(
            !rhConfigured,
            "RH already configured"
        );

        require(
            rhToken_ != address(0),
            "Invalid RH token"
        );


        RH =
            IERC20(
                rhToken_
            );


        rhConfigured = true;
    }


    // =========================================================
    // STAGE 1 PURCHASE
    // =========================================================

    function buyStage1()
        external
        payable
        nonReentrant
    {
        require(
            currentStage == 1,
            "Stage 1 inactive"
        );

        require(
            rhConfigured,
            "RH not configured"
        );

        require(
            msg.value > 0,
            "Send BNB"
        );


        /*
            Calculate RH amount.

            Example:

            1 BNB / 0.0001 BNB
            = 10,000 RH
        */
        uint256 rhAmount =
            (msg.value * 1 ether)
            / STAGE1_PRICE;


        require(
            rhAmount > 0,
            "Amount too small"
        );


        require(
            stage1Sold + rhAmount <= STAGE_SIZE,
            "Stage 1 sold out"
        );


        // Record RH sold
        stage1Sold += rhAmount;


        /*
            40% creator
            60% liquidity
        */
        uint256 creatorShare =
            (msg.value * CREATOR_BPS)
            / BPS;


        uint256 liquidityShare =
            msg.value - creatorShare;


        creatorBNB +=
            creatorShare;


        liquidityBNB +=
            liquidityShare;


        // Send RH to buyer
        RH.safeTransfer(
            msg.sender,
            rhAmount
        );


        emit Stage1Purchase(
            msg.sender,
            rhAmount,
            msg.value
        );


        /*
            When exactly 10M RH have been sold,
            Stage 1 automatically completes.
        */
        if (
            stage1Sold ==
            STAGE_SIZE
        ) {

            _completeStage1();

        }
    }


    // =========================================================
    // COMPLETE STAGE 1
    // =========================================================

    function _completeStage1()
        internal
    {

        /*
            At exactly 10M RH sold:

            Total BNB:
                10M × 0.0001
                = 1,000 BNB

            Creator:
                400 BNB

            Liquidity:
                600 BNB
        */

        require(
            liquidityBNB == 600 ether,
            "Liquidity amount incorrect"
        );


        uint256 amount =
            liquidityBNB;


        /*
            Clear the accounting before
            making the external call.
        */
        liquidityBNB = 0;


        /*
            Automatically send 600 BNB to
            RhodiumLiquidity.

            RhodiumLiquidity then adds:

                6,000,000 RH
                +
                600 BNB
        */
        IRhodiumLiquidity(
            liquidityManager
        )
        .initializeLiquidityFromSale{
            value: amount
        }();


        /*
            Only after successful liquidity
            initialization do we move to Stage 2.
        */
        currentStage = 2;


        stage2Start =
            block.timestamp;


        /*
            Unlock Stage 1 vesting:

            3.6M RH
        */
        vesting.unlockStage1();


        emit AutomaticLiquidityInitialized(
            6_000_000 ether,
            amount
        );


        emit Stage1Completed(
            block.timestamp
        );


        emit Stage2Started(
            block.timestamp
        );
    }


    // =========================================================
    // STAGE 2 → STAGE 3
    // =========================================================

    /*
        After 30 days:

        1. Stage 2 vesting unlocks
        2. 3.6M RH automatically goes
           to the creator wallet
        3. Stage 3 begins
    */
    function advanceToStage3()
        external
        nonReentrant
    {
        require(
            currentStage == 2,
            "Not Stage 2"
        );


        require(
            block.timestamp >=
                stage2Start +
                STAGE2_DURATION,
            "Stage 2 still active"
        );


        /*
            This function is restricted inside
            RhodiumVesting to the Sale contract.

            It unlocks and transfers:

                3,600,000 RH

            directly to creator.
        */
        vesting.unlockAndClaimStage2();


        currentStage = 3;


        stage3Start =
            block.timestamp;


        emit Stage2Claimed(
            3_600_000 ether,
            block.timestamp
        );


        emit Stage3Started(
            block.timestamp
        );
    }


    // =========================================================
    // COMPLETE STAGE 3
    // =========================================================

    /*
        After 60 days of Stage 3:

        1. Stage 3 vesting unlocks
        2. 1.8M RH automatically goes
           to creator wallet
        3. Launch becomes complete
    */
    function completeStage3()
        external
        nonReentrant
    {
        require(
            currentStage == 3,
            "Not Stage 3"
        );


        require(
            block.timestamp >=
                stage3Start +
                STAGE3_DURATION,
            "Stage 3 still active"
        );


        /*
            Unlock and automatically transfer:

                1,800,000 RH

            directly to creator.
        */
        vesting.unlockAndClaimStage3();


        currentStage = 4;


        launchCompletedAt =
            block.timestamp;


        emit Stage3Claimed(
            1_800_000 ether,
            block.timestamp
        );


        emit LaunchCompleted(
            block.timestamp
        );
    }


    // =========================================================
    // CREATOR BNB
    // =========================================================

    function claimCreatorBNB()
        external
        nonReentrant
    {
        require(
            msg.sender == creator,
            "Not creator"
        );


        uint256 amount =
            creatorBNB;


        require(
            amount > 0,
            "Nothing to claim"
        );


        creatorBNB = 0;


        (
            bool success,
        ) =
            payable(creator).call{
                value: amount
            }("");


        require(
            success,
            "BNB transfer failed"
        );


        emit CreatorBNBClaimed(
            creator,
            amount
        );
    }


    // =========================================================
    // VIEW FUNCTIONS
    // =========================================================

    function stage1Remaining()
        external
        view
        returns (uint256)
    {
        return
            STAGE_SIZE -
            stage1Sold;
    }


    function stage2End()
        external
        view
        returns (uint256)
    {
        if (
            stage2Start == 0
        ) {
            return 0;
        }


        return
            stage2Start +
            STAGE2_DURATION;
    }


    function stage3End()
        external
        view
        returns (uint256)
    {
        if (
            stage3Start == 0
        ) {
            return 0;
        }


        return
            stage3Start +
            STAGE3_DURATION;
    }


    function stage1Active()
        external
        view
        returns (bool)
    {
        return
            currentStage == 1;
    }


    function stage2Active()
        external
        view
        returns (bool)
    {
        return
            currentStage == 2;
    }


    function stage3Active()
        external
        view
        returns (bool)
    {
        return
            currentStage == 3;
    }


    function launchFinished()
        external
        view
        returns (bool)
    {
        return
            currentStage == 4;
    }


    // =========================================================
    // BNB PROTECTION
    // =========================================================

    receive()
        external
        payable
    {
        revert(
            "Use buyStage1"
        );
    }


    fallback()
        external
        payable
    {
        revert(
            "Invalid function"
        );
    }
}