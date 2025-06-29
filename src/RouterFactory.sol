// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.28;

import {RouterV2, ERC20} from "src/RouterV2.sol";
import {IStrategyInterface} from "src/interfaces/IStrategyInterface.sol";

contract RouterFactory {
    event NewStrategy(address indexed strategy, address indexed asset);

    /// @notice Management role controls important setters on this factory and deployed strategies
    address public management;

    /// @notice This address receives any performance fees
    address public performanceFeeRecipient;

    /// @notice Keeper address is allowed to report and tend deployed strategies
    address public keeper;

    /// @notice Address authorized for emergency procedures (shutdown and withdraw) on strategy
    address public emergencyAdmin;

    /// @notice Track the deployments. asset => strategy
    mapping(address => address) public deployments;

    constructor(
        address _management,
        address _performanceFeeRecipient,
        address _keeper,
        address _emergencyAdmin
    ) {
        management = _management;
        performanceFeeRecipient = _performanceFeeRecipient;
        keeper = _keeper;
        emergencyAdmin = _emergencyAdmin;
    }

    /**
     * @notice Deploy a new V2 Router Strategy.
     * @dev Can only be called by management.
     * @param _name The name for the strategy to use.
     * @param _asset The underlying asset for the strategy to use.
     * @param _v2Vault The V2 yearn vault to target with this strategy.
     * @return strategy The address of the new strategy.
     */
    function newRouterStrategy(
        string calldata _name,
        address _asset,
        address _v2Vault
    ) external virtual returns (address strategy) {
        require(msg.sender == management, "!authorized");

        // make sure we don't already have a strategy deployed for this V2 vault
        require(deployments[_asset] == address(0), "strategy exists");

        // tokenized strategies available setters.
        IStrategyInterface _newStrategy = IStrategyInterface(
            address(new RouterV2(_asset, _name, _v2Vault))
        );

        _newStrategy.setPerformanceFeeRecipient(performanceFeeRecipient);

        _newStrategy.setKeeper(keeper);

        _newStrategy.setPendingManagement(management);

        _newStrategy.setEmergencyAdmin(emergencyAdmin);

        emit NewStrategy(address(_newStrategy), _asset);

        deployments[_asset] = address(_newStrategy);
        strategy = address(_newStrategy);
    }

    /**
     * @notice Check if a strategy has been deployed by this Factory
     * @param _strategy strategy address
     */
    function isDeployedStrategy(
        address _strategy
    ) external view returns (bool) {
        try IStrategyInterface(_strategy).asset() returns (address _asset) {
            return deployments[_asset] == _strategy;
        } catch {
            // If the call fails or reverts, return false
            return false;
        }
    }

    /**
     * @notice Set important addresses for this factory.
     * @param _management The address to set as the management address.
     * @param _performanceFeeRecipient The address to set as the performance fee recipient address.
     * @param _keeper The address to set as the keeper address.
     * @param _emergencyAdmin The address to set as the emergencyAdmin address.
     */
    function setAddresses(
        address _management,
        address _performanceFeeRecipient,
        address _keeper,
        address _emergencyAdmin
    ) external {
        require(msg.sender == management, "!management");
        require(
            _performanceFeeRecipient != address(0) &&
                _management != address(0) &&
                _emergencyAdmin != address(0),
            "ZERO_ADDRESS"
        );
        management = _management;
        performanceFeeRecipient = _performanceFeeRecipient;
        keeper = _keeper;
        emergencyAdmin = _emergencyAdmin;
    }
}
