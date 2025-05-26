pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {Setup, ERC20, IStrategyInterface} from "./utils/Setup.sol";

contract ShutdownTest is Setup {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_shutdownCanWithdraw(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        // make sure there's not any currently unlocking profit in the V2 vault
        // otherwise we would need to report below for our vault assertion to hold true
        skip(strategy.profitMaxUnlockTime());

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // Earn Interest
        skip(1 days);

        // Shutdown the strategy
        vm.prank(management);
        strategy.shutdownStrategy();

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // Make sure we can still withdraw the full amount
        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertEq(strategy.totalAssets(), 0, "!zero");
        assertEq(strategy.balanceOfVault(), 0, "!vault");

        assertGe(
            asset.balanceOf(user) + 2, // add a 2 wei buffer since we convert between shares on deposit/withdraw
            balanceBefore + _amount,
            "!final balance"
        );
    }

    function test_emergencyWithdraw_maxUint(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        // make sure there's not any currently unlocking profit in the V2 vault
        skip(strategy.profitMaxUnlockTime());

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // Earn Interest
        skip(1 days);

        // Shutdown the strategy
        vm.prank(emergencyAdmin);
        strategy.shutdownStrategy();

        // assets shouldn't have gone anywhere
        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // balance of assets should be zero in strategy still
        assertEq(strategy.balanceOfAsset(), 0, "!assets");

        // value of vault should be positive
        uint256 valueOfVault = strategy.valueOfVault();
        assertGt(valueOfVault, 0, "!value");

        // emergency admin steps in to get funds out ASAP
        // should be able to pass uint 256 max and not revert.
        vm.prank(emergencyAdmin);
        strategy.emergencyWithdraw(type(uint256).max);

        // balance of assets should be greater than zero now
        uint256 balanceOfAssets = strategy.balanceOfAsset();
        assertGt(balanceOfAssets, 0, "!assets");

        // value of vault should be zero now
        assertEq(strategy.valueOfVault(), 0, "!value");

        // Make sure we can still withdraw the full amount
        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertEq(strategy.totalAssets(), 0, "!zero");

        assertGe(
            asset.balanceOf(user) + 2, // add a 2 wei buffer since we convert between shares on deposit/withdraw
            balanceBefore + _amount,
            "!final balance"
        );
    }

    function test_shutdownCanWithdrawMaxUint_fixed() public {
        uint256 _amount = 1_000_000e18;

        // make sure there's not any currently unlocking profit in the V2 vault
        skip(strategy.profitMaxUnlockTime());

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // Earn Interest
        skip(1 days);

        // Shutdown the strategy
        vm.prank(management);
        strategy.shutdownStrategy();

        // assets shouldn't have gone anywhere
        assertEq(strategy.totalAssets(), _amount, "!totalAssets");

        // balance of assets should be zero in strategy still
        assertEq(strategy.balanceOfAsset(), 0, "!assets");

        // value of vault should be positive
        uint256 valueOfVault = strategy.valueOfVault();
        assertGt(valueOfVault, 0, "!value");
        console2.log("Value of vault tokens:", valueOfVault, "LP tokens");

        // emergency admin steps in to get funds out ASAP
        // should be able to pass uint 256 max and not revert.
        vm.prank(management);
        strategy.emergencyWithdraw(type(uint256).max);

        // balance of assets should be greater than zero now
        uint256 balanceOfAssets = strategy.balanceOfAsset();
        assertGt(balanceOfAssets, 0, "!assets");
        console2.log("Balance of loose assets:", balanceOfAssets, "LP tokens");

        // value of vault should be zero now
        assertEq(strategy.valueOfVault(), 0, "!value");

        // Make sure we can still withdraw the full amount
        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertEq(strategy.totalAssets(), 0, "!zero");

        assertGe(
            asset.balanceOf(user) + 1, // add a 1 wei buffer since we convert between shares on deposit/withdraw
            balanceBefore + _amount,
            "!final balance"
        );
    }
}
