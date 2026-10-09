// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";  
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract RhodiumVesting is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant TOTAL_ALLOCATION =
        9_000_000 ether;

    uint256 public constant STAGE1_ALLOCATION =
        3_600_000 ether;

    uint256 public constant STAGE2_ALLOCATION =
        3_600_000 ether;

    uint256 public constant STAGE3_ALLOCATION =
        1_800_000 ether;

    // Stage 2 begins after Stage 1.
    uint256 public constant STAGE2_DURATION =
        30 days;

    // Stage 3 lasts 60 days after Stage 3 begins.
    uint256 public constant STAGE3_DURATION =
        60 days;

    IERC20 public RH;

    address public immutable creator;

    address public saleContract;

    bool public rhConfigured;
    bool public saleConfigured;

    bool public stage1Unlocked;
    bool public stage2Unlocked;
    bool public stage3Unlocked;

    uint256 public stage1UnlockedAt;
    uint256 public stage2UnlockedAt;
    uint256 public stage3UnlockedAt;

    uint256 public totalUnlocked;
    uint256 public totalClaimed;

    event RHConfigured(address indexed token);

    event SaleContractConfigured(
        address indexed sale
    );

    event StageUnlocked(
        uint256 indexed stage,
        uint256 amount
    );

    event CreatorClaimed(
        uint256 amount
    );

    event AutomaticClaimed(
        uint256 indexed stage,
        uint256 amount,
        address indexed caller
    );

    constructor(
        address initialOwner,
        address creatorAddress
    )
        Ownable(initialOwner)
    {
        require(
            initialOwner != address(0),
            "Invalid owner"
        );

        require(
            creatorAddress != address(0),
            "Invalid creator"
        );

        creator = creatorAddress;
    }

    // =========================================================
    // CONFIGURATION
    // =========================================================

    function setRH(
        address token
    )
        external
        onlyOwner
    {
        require(
            !rhConfigured,
            "RH already configured"
        );

        require(
            token != address(0),
            "Invalid RH address"
        );

        RH = IERC20(token);

        rhConfigured = true;

        emit RHConfigured(token);
    }

    function setSaleContract(
        address sale
    )
        external
        onlyOwner
    {
        require(
            !saleConfigured,
            "Sale already configured"
        );

        require(
            sale != address(0),
            "Invalid sale address"
        );

        saleContract = sale;

        saleConfigured = true;

        emit SaleContractConfigured(sale);
    }

    modifier onlySale() {
        require(
            msg.sender == saleContract,
            "Only sale contract"
        );

        _;
    }

    // =========================================================
    // STAGE 1
    // =========================================================

    function unlockStage1()
        external
        onlySale
    {
        require(
            rhConfigured,
            "RH not configured"
        );

        require(
            !stage1Unlocked,
            "Stage 1 already unlocked"
        );

        stage1Unlocked = true;

        stage1UnlockedAt =
            block.timestamp;

        totalUnlocked +=
            STAGE1_ALLOCATION;

        emit StageUnlocked(
            1,
            STAGE1_ALLOCATION
        );
    }

    // =========================================================
    // STAGE 2
    // =========================================================

    /*
        Sale contract calls this when the Stage 2 period
        has completed.

        This unlocks 3.6M RH and immediately sends all
        newly claimable RH to the creator.
    */
    function unlockAndClaimStage2()
        external
        onlySale
        nonReentrant
    {
        require(
            stage1Unlocked,
            "Stage 1 not unlocked"
        );

        require(
            !stage2Unlocked,
            "Stage 2 already unlocked"
        );

        require(
            block.timestamp >=
                stage1UnlockedAt +
                STAGE2_DURATION,
            "Stage 2 period not finished"
        );

        stage2Unlocked = true;

        stage2UnlockedAt =
            block.timestamp;

        totalUnlocked +=
            STAGE2_ALLOCATION;

        emit StageUnlocked(
            2,
            STAGE2_ALLOCATION
        );

        _claimToCreator(
            2,
            STAGE2_ALLOCATION,
            msg.sender
        );
    }

    // =========================================================
    // STAGE 3
    // =========================================================

    /*
        Sale contract calls this when the Stage 3 period
        has completed.

        This unlocks 1.8M RH and immediately sends it
        to the creator.
    */
    function unlockAndClaimStage3()
        external
        onlySale
        nonReentrant
    {
        require(
            stage2Unlocked,
            "Stage 2 not unlocked"
        );

        require(
            !stage3Unlocked,
            "Stage 3 already unlocked"
        );

        require(
            block.timestamp >=
                stage2UnlockedAt +
                STAGE3_DURATION,
            "Stage 3 period not finished"
        );

        stage3Unlocked = true;

        stage3UnlockedAt =
            block.timestamp;

        totalUnlocked +=
            STAGE3_ALLOCATION;

        emit StageUnlocked(
            3,
            STAGE3_ALLOCATION
        );

        _claimToCreator(
            3,
            STAGE3_ALLOCATION,
            msg.sender
        );
    }

    // =========================================================
    // INTERNAL CLAIM
    // =========================================================

    function _claimToCreator(
        uint256 stage,
        uint256 amount,
        address caller
    )
        internal
    {
        require(
            amount > 0,
            "Nothing to claim"
        );

        totalClaimed += amount;

        RH.safeTransfer(
            creator,
            amount
        );

        emit AutomaticClaimed(
            stage,
            amount,
            caller
        );

        emit CreatorClaimed(
            amount
        );
    }

    // =========================================================
    // MANUAL CLAIM
    // =========================================================

    /*
        This remains available for Stage 1 or any
        remaining claimable amount.

        Only the creator can call it.
    */
    function claim()
        external
        nonReentrant
    {
        require(
            msg.sender == creator,
            "Only creator"
        );

        uint256 amount =
            totalUnlocked -
            totalClaimed;

        require(
            amount > 0,
            "Nothing to claim"
        );

        totalClaimed += amount;

        RH.safeTransfer(
            creator,
            amount
        );

        emit CreatorClaimed(
            amount
        );
    }

    // =========================================================
    // VIEW FUNCTIONS
    // =========================================================

    function claimableAmount()
        external
        view
        returns (uint256)
    {
        return
            totalUnlocked -
            totalClaimed;
    }

    function claimedAmount()
        external
        view
        returns (uint256)
    {
        return totalClaimed;
    }

    function lockedAmount()
        external
        view
        returns (uint256)
    {
        return
            TOTAL_ALLOCATION -
            totalUnlocked;
    }

    function remainingCreatorAllocation()
        external
        view
        returns (uint256)
    {
        return
            TOTAL_ALLOCATION -
            totalClaimed;
    }

    function stage2ClaimAvailable()
        external
        view
        returns (bool)
    {
        return
            stage1Unlocked &&
            !stage2Unlocked &&
            block.timestamp >=
                stage1UnlockedAt +
                STAGE2_DURATION;
    }

    function stage3ClaimAvailable()
        external
        view
        returns (bool)
    {
        return
            stage2Unlocked &&
            !stage3Unlocked &&
            block.timestamp >=
                stage2UnlockedAt +
                STAGE3_DURATION;
    }

    function isFullyConfigured()
        external
        view
        returns (bool)
    {
        return
            rhConfigured &&
            saleConfigured;
    }

    // =========================================================
    // BNB PROTECTION
    // =========================================================

    receive()
        external
        payable
    {
        revert("No BNB accepted");
    }
    fallback() external payable
       {
        revert("Invalid function");
         }
     }