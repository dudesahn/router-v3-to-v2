// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/console2.sol";
import {Setup, ERC20, IStrategyInterface} from "src/test/utils/Setup.sol";

contract FactoryTest is Setup {
    function setUp() public virtual override {
        super.setUp();
    }

    // no need for explicit factory testing since we use the factory to deploy strategies in Setup.sol
    function test_factory_status() public {
        // confirm our mapping works
        assertEq(
            strategyFactory.deployments(strategy.asset()),
            address(strategy)
        );
        assertEq(true, strategyFactory.isDeployedStrategy(address(strategy)));
        assertEq(false, strategyFactory.isDeployedStrategy(user));

        // shouldn't be able to deploy another strategy for the same gauge for curve factory
        vm.expectRevert("strategy exists");
        vm.prank(management);
        strategyFactory.newRouterStrategy(
            "DAI Vault V2 Router",
            address(asset),
            V2Vault
        );

        // make sure user can't deploy
        vm.expectRevert("!authorized");
        vm.prank(user);
        strategyFactory.newRouterStrategy(
            "DAI Vault V2 Router",
            address(asset),
            V2Vault
        );

        // now set operator address
        vm.prank(user);
        vm.expectRevert("!management");
        strategyFactory.setAddresses(
            management,
            performanceFeeRecipient,
            keeper,
            emergencyAdmin
        );
        vm.startPrank(management);
        vm.expectRevert("ZERO_ADDRESS");
        strategyFactory.setAddresses(
            address(0),
            performanceFeeRecipient,
            keeper,
            emergencyAdmin
        );
        vm.expectRevert("ZERO_ADDRESS");
        strategyFactory.setAddresses(
            management,
            address(0),
            keeper,
            emergencyAdmin
        );
        vm.expectRevert("ZERO_ADDRESS");
        strategyFactory.setAddresses(
            management,
            performanceFeeRecipient,
            keeper,
            address(0)
        );
        strategyFactory.setAddresses(
            management,
            performanceFeeRecipient,
            keeper,
            emergencyAdmin
        );
        vm.stopPrank();

        assertEq(strategy.management(), management);
        assertEq(strategy.pendingManagement(), address(0));
        assertEq(strategy.performanceFee(), 1000);
        assertEq(strategy.performanceFeeRecipient(), performanceFeeRecipient);
    }
}
