// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {BaseHealthCheck, ERC20} from "@periphery/Bases/HealthCheck/BaseHealthCheck.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ShareValueHelper, IYearnVaultV2} from "src/ShareValueHelper.sol";

contract RouterV2 is BaseHealthCheck {
    using SafeERC20 for ERC20;

    /// @notice The V2 yVault we are routing this strategy to.
    IYearnVaultV2 public immutable v2Vault;

    // no reason to deposit less than this, and helps us avoid any weird reverts from depositing 1 wei
    uint256 internal constant DUST = 1e6;

    /// @notice Max percentage loss we will take on withdrawals, in basis points. Default setting is zero.
    uint256 public maxLoss;

    ///@notice Mapping of addresses that are allowed to deposit.
    mapping(address depositor => bool isAllowed) public allowed;

    constructor(
        address _asset,
        string memory _name,
        address _v2Vault
    ) BaseHealthCheck(_asset, _name) {
        v2Vault = IYearnVaultV2(_v2Vault);
        require(v2Vault.token() == _asset, "wrong asset");

        asset.forceApprove(_v2Vault, type(uint256).max);
    }

    /* ========== VIEWS ========== */

    /**
     * @notice Return the current loose balance of this strategies `asset`.
     */
    function balanceOfAsset() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    /**
     * @notice Return the current balance of the strategies vault shares.
     */
    function balanceOfVault() public view returns (uint256) {
        return v2Vault.balanceOf(address(this));
    }

    /**
     * @notice The full value denominated in `asset` of the strategies vault
     *   tokens held in the contract.
     */
    function valueOfVault() public view returns (uint256) {
        return
            ShareValueHelper.sharesToAmount(
                address(v2Vault),
                balanceOfVault(),
                false
            );
    }

    /* ========== CORE STRATEGY FUNCTIONS ========== */

    function _deployFunds(uint256 _amount) internal override {
        if (_amount > DUST) {
            v2Vault.deposit(_amount);
        }
    }

    function _freeFunds(uint256 _amount) internal override {
        // check how many shares we need against what we have
        uint256 balance = balanceOfVault();
        uint256 shares;

        if (_amount == type(uint256).max) {
            shares = balance;
        } else {
            // use share value helper for improved precision and round up
            shares = ShareValueHelper.amountToShares(
                address(v2Vault),
                _amount,
                true
            );

            if (shares > balance) shares = balance;
        }

        // trying to withdraw 0 reverts
        if (shares > 0) {
            v2Vault.withdraw(shares, address(this), maxLoss);
        }
    }

    function _harvestAndReport()
        internal
        override
        returns (uint256 _totalAssets)
    {
        _totalAssets = balanceOfAsset() + valueOfVault();
    }

    function availableDepositLimit(
        address _depositor
    ) public view override returns (uint256 depositLimit) {
        // If the depositor is whitelisted, allow deposits.
        if (allowed[_depositor]) {
            uint256 limit = v2Vault.depositLimit();
            uint256 assets = v2Vault.totalAssets();

            if (limit > assets) {
                unchecked {
                    depositLimit = limit - assets;
                }
            }
        } else {
            return 0;
        }
    }

    function _emergencyWithdraw(uint256 _amount) internal override {
        _freeFunds(_amount);
    }

    /* ========== SETTERS ========== */

    /**
     * @notice Set the maximum loss we will accept (due to slippage or locked funds) on a vault withdrawal.
     * @dev Generally, this should be zero, and this function will only be used in special/emergency cases.
     * @param _maxLoss Max percentage loss we will take, in basis points (100% = 10_000).
     */
    function setMaxLoss(uint256 _maxLoss) external onlyManagement {
        require(_maxLoss <= 10_000, "!bps");
        maxLoss = _maxLoss;
    }

    /**
     * @notice Set or update an addresses whitelist status.
     * @param _address the address for which to change the whitelist status
     * @param _allowed the bool to set as whitelisted (true) or not (false)
     */
    function setAllowed(
        address _address,
        bool _allowed
    ) external onlyManagement {
        allowed[_address] = _allowed;
    }
}
