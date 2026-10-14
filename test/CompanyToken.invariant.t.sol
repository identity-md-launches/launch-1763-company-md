// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {CompanyToken} from "../src/CompanyToken.sol";

/// @dev Keeps all balances in a closed set of holders while varying operation order.
contract CompanyTokenHandler is Test {
    CompanyToken private immutable token;
    address[4] public actors;

    constructor(CompanyToken token_) {
        token = token_;
        actors[0] = makeAddr("holder0");
        actors[1] = makeAddr("holder1");
        actors[2] = makeAddr("holder2");
        actors[3] = makeAddr("holder3");
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        amount = bound(amount, 0, token.balanceOf(from));
        vm.prank(from);
        assertTrue(token.transfer(to, amount));
    }

    function approve(uint256 ownerSeed, uint256 spenderSeed, uint256 amount) external {
        address owner = actors[ownerSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        vm.prank(owner);
        assertTrue(token.approve(spender, amount));
        assertEq(token.allowance(owner, spender), amount);
    }

    function transferFrom(uint256 ownerSeed, uint256 spenderSeed, uint256 toSeed, uint256 amount) external {
        address owner = actors[ownerSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        address to = actors[toSeed % actors.length];
        uint256 beforeAllowance = token.allowance(owner, spender);
        uint256 balance = token.balanceOf(owner);
        uint256 limit = balance < beforeAllowance ? balance : beforeAllowance;
        amount = bound(amount, 0, limit);
        vm.prank(spender);
        assertTrue(token.transferFrom(owner, to, amount));
        assertEq(
            token.allowance(owner, spender),
            beforeAllowance == type(uint256).max ? beforeAllowance : beforeAllowance - amount
        );
    }
}

contract CompanyTokenInvariantTest is Test {
    uint256 private constant SUPPLY = 1_000_000_000_000_000_000_000_000_000;
    CompanyToken private token;
    CompanyTokenHandler private handler;

    function setUp() public {
        token = new CompanyToken();
        handler = new CompanyTokenHandler(token);
        token.transfer(handler.actors(0), SUPPLY);

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = CompanyTokenHandler.transfer.selector;
        selectors[1] = CompanyTokenHandler.approve.selector;
        selectors[2] = CompanyTokenHandler.transferFrom.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_supplyRemainsFixed() public view {
        assertEq(token.totalSupply(), SUPPLY);
    }

    function invariant_balancesConserveEntireSupply() public view {
        uint256 held;
        for (uint256 i; i < 4; ++i) {
            held += token.balanceOf(handler.actors(i));
        }
        assertEq(held, SUPPLY);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(handler)), 0);
        assertEq(token.balanceOf(address(0)), 0);
    }
}
