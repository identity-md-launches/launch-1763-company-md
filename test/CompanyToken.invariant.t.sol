// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {CompanyToken} from "../src/CompanyToken.sol";

/// @dev Only the listed actions are targeted. All tokens stay within four funded actors.
/// Inputs and accounting use the call history, never a possibly incorrect token balance.
contract CompanyTokenHandler is Test {
    CompanyToken private immutable token;
    uint256 public immutable initialBalance;
    address[4] public actors;
    mapping(address => uint256) public sent;
    mapping(address => uint256) public received;
    mapping(address => mapping(address => uint256)) public expectedAllowance;

    constructor(CompanyToken token_, uint256 initialBalance_) {
        token = token_;
        initialBalance = initialBalance_;
        actors[0] = makeAddr("holder0");
        actors[1] = makeAddr("holder1");
        actors[2] = makeAddr("holder2");
        actors[3] = makeAddr("holder3");
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        amount = bound(amount, 0, expectedBalance(from));
        _transfer(from, to, amount);
    }

    function approve(uint256 ownerSeed, uint256 spenderSeed, uint256 amount) external {
        address owner = actors[ownerSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        _approve(owner, spender, amount);
    }

    function transferFrom(uint256 ownerSeed, uint256 spenderSeed, uint256 toSeed, uint256 amount) external {
        address owner = actors[ownerSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        address to = actors[toSeed % actors.length];
        uint256 beforeAllowance = expectedAllowance[owner][spender];
        uint256 balance = expectedBalance(owner);
        uint256 limit = balance < beforeAllowance ? balance : beforeAllowance;
        amount = bound(amount, 0, limit);
        vm.prank(spender);
        assertTrue(token.transferFrom(owner, to, amount));
        sent[owner] += amount;
        received[to] += amount;
        if (beforeAllowance != type(uint256).max) {
            expectedAllowance[owner][spender] = beforeAllowance - amount;
        }
    }

    function transferFullBalance(uint256 fromSeed, uint256 toSeed) external {
        address from = actors[fromSeed % actors.length];
        _transfer(from, actors[toSeed % actors.length], expectedBalance(from));
    }

    function approveInfinite(uint256 ownerSeed, uint256 spenderSeed) external {
        _approve(actors[ownerSeed % actors.length], actors[spenderSeed % actors.length], type(uint256).max);
    }

    function revoke(uint256 ownerSeed, uint256 spenderSeed) external {
        _approve(actors[ownerSeed % actors.length], actors[spenderSeed % actors.length], 0);
    }

    // Expected reverts leave every ghost unchanged. The invariants check every account
    // and allowance afterwards, including accounts unrelated to the attempted call.
    function transferAboveBalance(uint256 fromSeed, uint256 toSeed, uint256 excess) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        uint256 balance = expectedBalance(from);
        uint256 amount = balance + bound(excess, 1, type(uint256).max - balance);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, from, balance, amount));
        vm.prank(from);
        token.transfer(to, amount);
    }

    function transferFromOverLimit(uint256 ownerSeed, uint256 spenderSeed, uint256 toSeed, uint256 excess) external {
        address owner = actors[ownerSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        address to = actors[toSeed % actors.length];
        uint256 allowance = expectedAllowance[owner][spender];
        uint256 balance = expectedBalance(owner);
        uint256 limit = balance < allowance ? balance : allowance;
        uint256 amount = limit + bound(excess, 1, type(uint256).max - limit);

        // Both finite and unlimited approvals are reachable. A balance failure after
        // spending a finite allowance must roll that allowance change back as well.
        if (amount > allowance) {
            vm.expectRevert(
                abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, allowance, amount)
            );
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, owner, balance, amount)
            );
        }
        vm.prank(spender);
        token.transferFrom(owner, to, amount);
    }

    function transferToZero(uint256 fromSeed, uint256 amount) external {
        address from = actors[fromSeed % actors.length];
        amount = bound(amount, 0, expectedBalance(from));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(from);
        token.transfer(address(0), amount);
    }

    function transferFromToZero(uint256 ownerSeed, uint256 spenderSeed, uint256 amount) external {
        address owner = actors[ownerSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        amount = bound(amount, 0, expectedAllowance[owner][spender]);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(spender);
        token.transferFrom(owner, address(0), amount);
    }

    function approveZeroSpender(uint256 ownerSeed, uint256 amount) external {
        address owner = actors[ownerSeed % actors.length];
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        vm.prank(owner);
        token.approve(address(0), amount);
    }

    function expectedBalance(address actor) public view returns (uint256) {
        return initialBalance + received[actor] - sent[actor];
    }

    function _transfer(address from, address to, uint256 amount) private {
        vm.prank(from);
        assertTrue(token.transfer(to, amount));
        // Counting both legs also handles self-transfers without a special case.
        sent[from] += amount;
        received[to] += amount;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        vm.prank(owner);
        assertTrue(token.approve(spender, amount));
        expectedAllowance[owner][spender] = amount;
    }
}

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract CompanyTokenInvariantTest is Test {
    uint256 private constant SUPPLY = 1_000_000_000_000_000_000_000_000_000;
    CompanyToken private token;
    CompanyTokenHandler private handler;

    function setUp() public {
        token = new CompanyToken();
        handler = new CompanyTokenHandler(token, SUPPLY / 4);
        for (uint256 i; i < 4; ++i) {
            assertTrue(token.transfer(handler.actors(i), SUPPLY / 4));
        }

        bytes4[] memory selectors = new bytes4[](11);
        selectors[0] = CompanyTokenHandler.transfer.selector;
        selectors[1] = CompanyTokenHandler.approve.selector;
        selectors[2] = CompanyTokenHandler.transferFrom.selector;
        selectors[3] = CompanyTokenHandler.transferFullBalance.selector;
        selectors[4] = CompanyTokenHandler.approveInfinite.selector;
        selectors[5] = CompanyTokenHandler.revoke.selector;
        selectors[6] = CompanyTokenHandler.transferAboveBalance.selector;
        selectors[7] = CompanyTokenHandler.transferFromOverLimit.selector;
        selectors[8] = CompanyTokenHandler.transferToZero.selector;
        selectors[9] = CompanyTokenHandler.transferFromToZero.selector;
        selectors[10] = CompanyTokenHandler.approveZeroSpender.selector;
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
        assertEq(token.balanceOf(address(token)), 0);
    }

    function invariant_eachBalanceMatchesTransferHistory() public view {
        for (uint256 i; i < 4; ++i) {
            address actor = handler.actors(i);
            assertEq(
                token.balanceOf(actor) + handler.sent(actor),
                SUPPLY / 4 + handler.received(actor),
                "holder balance disagrees with authorized transfers"
            );
        }
    }

    function invariant_eachAllowanceMatchesAuthorizations() public view {
        for (uint256 i; i < 4; ++i) {
            address owner = handler.actors(i);
            assertEq(token.allowance(owner, address(0)), 0);
            for (uint256 j; j < 4; ++j) {
                address spender = handler.actors(j);
                assertEq(
                    token.allowance(owner, spender),
                    handler.expectedAllowance(owner, spender),
                    "allowance changed without authorization or successful spending"
                );
            }
        }
    }
}
