// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {BaseStrategy, ERC20} from "@tokenized-strategy/BaseStrategy.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ShareValueHelper, IYearnVaultV2} from "src/ShareValueHelper.sol";

// FOR THIS STRATEGY: PULL IN LEARNING'S FROM V2 => V2 ROUTER, SCHLAG'S ROUTER, AND MY CRVUSD ROUTER (FOR SURE TESTING)
// also build new V2 => V3 and V2 => V2 routers while I'm doing this probably
// should replace ShareValueHelper lib with a version that can do ceiling rounding like on base: https://basescan.org/address/0x4d2ed72285206d2b4b59cda21ed0a979ad1f497f#code

contract RouterV2 is BaseStrategy {
    using SafeERC20 for ERC20;

    /// @notice The V2 yVault we are routing this strategy to.
    IYearnVaultV2 public immutable v2Vault;

    // no reason to deposit less than this, and helps us avoid any weird reverts from depositing 1 wei
    uint256 internal constant DUST = 1e6;

    constructor(
        address _asset,
        string memory _name,
        address _v2Vault
    ) BaseStrategy(_asset, _name) {
        v2Vault = IYearnVaultV2(_v2Vault);
        require(v2Vault.token() == _asset, "wrong asset");

        asset.forceApprove(_v2Vault, type(uint256).max);
    }

    /**
     * @dev Can deploy up to '_amount' of 'asset' in the yield source.
     *
     * This function is called at the end of a {deposit} or {mint}
     * call. Meaning that unless a whitelist is implemented it will
     * be entirely permissionless and thus can be sandwiched or otherwise
     * manipulated.
     *
     * @param _amount The amount of 'asset' that the strategy can attempt
     * to deposit in the yield source.
     */
    function _deployFunds(uint256 _amount) internal override {
        uint256 toDeposit = asset.balanceOf(address(this));

        if (toDeposit > DUST) {
            v2Vault.deposit(toDeposit);
        }
    }

    // EVERYTHING BELOW HERE IS PURE SCHLAB CODE (except for adding in Lib)

    /**
     * @dev Should attempt to free the '_amount' of 'asset'.
     *
     * NOTE: The amount of 'asset' that is already loose has already
     * been accounted for.
     *
     * This function is called during {withdraw} and {redeem} calls.
     * Meaning that unless a whitelist is implemented it will be
     * entirely permissionless and thus can be sandwiched or otherwise
     * manipulated.
     *
     * Should not rely on asset.balanceOf(address(this)) calls other than
     * for diff accounting purposes.
     *
     * Any difference between `_amount` and what is actually freed will be
     * counted as a loss and passed on to the withdrawer. This means
     * care should be taken in times of illiquidity. It may be better to revert
     * if withdraws are simply illiquid so not to realize incorrect losses.
     *
     * @param _amount, The amount of 'asset' to be freed.
     */
    function _freeFunds(uint256 _amount) internal override {
        // use share value helper for improved precision and round up
        uint256 shares = ShareValueHelper.amountToShares(
            address(v2Vault),
            _amount,
            true
        );
        uint256 balance = v2Vault.balanceOf(address(this));

        if (shares > balance) shares = balance;

        v2Vault.withdraw(shares);
    }

    /**
     * @dev Internal function to harvest all rewards, redeploy any idle
     * funds and return an accurate accounting of all funds currently
     * held by the Strategy.
     *
     * This should do any needed harvesting, rewards selling, accrual,
     * redepositing etc. to get the most accurate view of current assets.
     *
     * NOTE: All applicable assets including loose assets should be
     * accounted for in this function.
     *
     * Care should be taken when relying on oracles or swap values rather
     * than actual amounts as all Strategy profit/loss accounting will
     * be done based on this returned value.
     *
     * This can still be called post a shutdown, a strategist can check
     * `TokenizedStrategy.isShutdown()` to decide if funds should be
     * redeployed or simply realize any profits/losses.
     *
     * @return _totalAssets A trusted and accurate account for the total
     * amount of 'asset' the strategy currently holds including idle funds.
     */
    function _harvestAndReport()
        internal
        override
        returns (uint256 _totalAssets)
    {
        _totalAssets =
            asset.balanceOf(address(this)) +
            ShareValueHelper.sharesToAmount(
                address(v2Vault),
                v2Vault.balanceOf(address(this)),
                false
            );
    }

    function availableDepositLimit(
        address
    ) public view override returns (uint256) {
        uint256 limit = v2Vault.depositLimit();
        uint256 assets = v2Vault.totalAssets();

        if (limit > assets) {
            unchecked {
                return limit - assets;
            }
        }
    }

    function _emergencyWithdraw(uint256 _amount) internal override {
        _freeFunds(_amount);
    }
}
