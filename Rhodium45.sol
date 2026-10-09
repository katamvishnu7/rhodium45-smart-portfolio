// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract Rhodium45 is ERC20, ERC20Permit {
    uint256 public constant TOTAL_SUPPLY = 45_000_000 ether;

    uint256 public constant PUBLIC_MARKET_ALLOCATION =
        30_000_000 ether;

    uint256 public constant CREATOR_ALLOCATION =
        9_000_000 ether;

    uint256 public constant LIQUIDITY_ALLOCATION =
        6_000_000 ether;

    constructor(
        address saleContract,
        address vestingContract,
        address liquidityContract
    )
        ERC20("Rhodium45", "RH")
        ERC20Permit("Rhodium45")
    {
        require(saleContract != address(0), "Invalid sale");
        require(vestingContract != address(0), "Invalid vesting");
        require(liquidityContract != address(0), "Invalid liquidity");

        _mint(saleContract, PUBLIC_MARKET_ALLOCATION);
        _mint(vestingContract, CREATOR_ALLOCATION);
        _mint(liquidityContract, LIQUIDITY_ALLOCATION);

        require(
            totalSupply() == TOTAL_SUPPLY,
            "Supply mismatch"
        );
    }

    function supplyIsFixed() external view returns (bool) {
        return totalSupply() == TOTAL_SUPPLY;
    }
}