// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import {TradeIssuer} from "src/TradeIssuer.sol";
import {IChamber} from "chambers/interfaces/IChamber.sol";
import {IIssuerWizard} from "chambers/interfaces/IIssuerWizard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ExposedTradeIssuer is TradeIssuer {
    constructor(address payable _dexAggregator, address _wrappedNativeToken)
        TradeIssuer(_dexAggregator, _wrappedNativeToken)
    {}

    function redeemChamber(IssuanceParams memory _redeemParams)
        public
        returns (uint256 totalOutputTokenReturned)
    {
        return _redeemChamber(_redeemParams);
    }

    function mintChamber(IssuanceParams memory _mintParams)
        public
        returns (uint256 totalInputTokenUsed)
    {
        return (_mintChamber(_mintParams));
    }

    function checkParams(IssuanceParams memory _issuanceParams) public pure {
        _checkParams(_issuanceParams);
    }

    function buyAssetsInDex(
        bytes[] memory _dexQuotes,
        IERC20 _inputToken,
        address[] memory _components,
        uint256[] memory _componentsQuantities,
        uint256 swapProtectionPercentage
    ) public returns (uint256 totalInputTokensUsed) {
        return (
            _buyAssetsInDex(
                _dexQuotes,
                _inputToken,
                _components,
                _componentsQuantities,
                swapProtectionPercentage
            )
        );
    }

    function sellAssetsForTokenInDex(
        bytes[] memory _dexQuotes,
        IERC20 _baseToken,
        address[] memory _components,
        uint256[] memory _componentsQuantities,
        uint256 swapProtectionPercentage
    ) public returns (uint256 totalOutputTokenReturned) {
        return _sellAssetsForTokenInDex(
            _dexQuotes, _baseToken, _components, _componentsQuantities, swapProtectionPercentage
        );
    }

    function fillQuote(bytes memory _quote) public returns (bytes memory response) {
        return (_fillQuote(_quote));
    }

    function depositConstituentsInVault(
        address[] memory _vaults,
        address[] memory _vaultAssets,
        uint256[] memory _vaultQuantities,
        IChamber _chamber,
        uint256 _mintAmount
    ) public {
        _depositConstituentsInVault(_vaults, _vaultAssets, _vaultQuantities, _chamber, _mintAmount);
    }

    function withdrawConstituentsFromVault(
        address[] memory _vaults,
        address[] memory _vaultUnderlyingAssets,
        uint256[] memory _vaultQuantities,
        IChamber _chamber,
        uint256 _redeemAmount
    ) public {
        _withdrawConstituentsFromVault(
            _vaults, _vaultUnderlyingAssets, _vaultQuantities, _chamber, _redeemAmount
        );
    }

    function checkAndIncreaseAllowanceOfConstituents(
        IChamber _chamber,
        IIssuerWizard _issuerWizard,
        uint256 _mintAmount
    ) public {
        _checkAndIncreaseAllowanceOfConstituents(_chamber, _issuerWizard, _mintAmount);
    }

    function checkAndIncreaseAllowance(
        address _tokenAddress,
        address _target,
        uint256 _requiredAmount
    ) public {
        _checkAndIncreaseAllowance(_tokenAddress, _target, _requiredAmount);
    }
}
