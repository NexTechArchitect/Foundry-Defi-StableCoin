// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../../src/DSCEngine.sol";
import {
    DecentralizedStableCoin
} from "../../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "../../mocks/ERC20Mock.sol";

contract Handler is Test {
    DSCEngine public dscEngine;
    DecentralizedStableCoin public dsc;
    ERC20Mock public weth;

    address[] public users;
    uint256 public constant MAX_USERS = 50;
    uint256 public constant MAX_DEPOSIT = 1_000 ether;
    uint256 public constant MAX_MINT = 500 ether;

    constructor(
        DSCEngine _engine,
        DecentralizedStableCoin _dsc,
        ERC20Mock _weth
    ) {
        dscEngine = _engine;
        dsc = _dsc;
        weth = _weth;

        // Create deterministic users
        for (uint256 i = 0; i < MAX_USERS; i++) {
            address user = address(uint160(uint256(keccak256(abi.encode(i)))));
            users.push(user);

            vm.deal(user, 100 ether);
            weth.mint(user, 1_000 ether);

            vm.prank(user);
            weth.approve(address(dscEngine), type(uint256).max);
        }
    }

    // -------- HELPERS --------

    function _getUser(uint256 seed) internal view returns (address) {
        return users[seed % users.length];
    }

    // -------- ACTIONS (FUZZED) --------

    function deposit(uint256 userSeed, uint256 amount) public {
        address user = _getUser(userSeed);
        amount = bound(amount, 1 ether, MAX_DEPOSIT);

        vm.startPrank(user);
        dscEngine.depositCollateral(address(weth), amount);
        vm.stopPrank();
    }

    function mint(uint256 userSeed, uint256 amount) public {
        address user = _getUser(userSeed);
        amount = bound(amount, 1 ether, MAX_MINT);

        vm.startPrank(user);

        // 🔐 HARD SAFETY GATE
        try dscEngine.getHealthFactor(user) returns (uint256 hf) {
            if (hf > dscEngine.getMinHealthFactor()) {
                dscEngine.mintDsc(amount);
            }
        } catch {}
        vm.stopPrank();
    }

    function burn(uint256 userSeed, uint256 amount) public {
        address user = _getUser(userSeed);
        uint256 balance = dsc.balanceOf(user);
        if (balance == 0) return;

        amount = bound(amount, 1, balance);

        vm.prank(user);
        dscEngine.burnDsc(amount);
    }

    function redeem(uint256 userSeed, uint256 amount) public {
        address user = _getUser(userSeed);
        uint256 deposited = dscEngine.getCollateralBalanceOfUser(
            user,
            address(weth)
        );
        if (deposited == 0) return;

        amount = bound(amount, 1, deposited);

        vm.prank(user);
        dscEngine.redeemCollateral(address(weth), amount);
    }
}
