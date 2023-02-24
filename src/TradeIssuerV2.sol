/**
 *     SPDX-License-Identifier: Apache License 2.0
 *
 *     Copyright 2021 Index Cooperative
 *     Copyright 2023 Smash Works Inc.
 *
 *     Licensed under the Apache License, Version 2.0 (the "License");
 *     you may not use this file except in compliance with the License.
 *     You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 *     Unless required by applicable law or agreed to in writing, software
 *     distributed under the License is distributed on an "AS IS" BASIS,
 *     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *     See the License for the specific language governing permissions and
 *     limitations under the License.
 *
 *     NOTICE
 *
 *     This is a modified code from Index Cooperative Inc. found at
 *
 *     https://github.com/IndexCoop/index-coop-smart-contracts
 *
 *     All changes made by Smash Works Inc. are described and documented at
 *
 *     https://docs.arch.finance/chambers
 *
 *
 *             %@@@@@
 *          @@@@@@@@@@@
 *        #@@@@@     @@@           @@                   @@
 *       @@@@@@       @@@         @@@@                  @@
 *      @@@@@@         @@        @@  @@    @@@@@ @@@@@  @@@*@@
 *     .@@@@@          @@@      @@@@@@@@   @@    @@     @@  @@
 *     @@@@@(       (((((      @@@    @@@  @@    @@@@@  @@  @@
 *    @@@@@@   (((((((
 *    @@@@@#(((((((
 *    @@@@@(((((
 *      @@@((
 */

pragma solidity ^0.8.17.0;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IChamber} from "chambers/interfaces/IChamber.sol";
import {IChamberGod} from "chambers/interfaces/IChamberGod.sol";
import {IIssuerWizard} from "chambers/interfaces/IIssuerWizard.sol";
import {ITradeIssuerV2} from "./interfaces/ITradeIssuerV2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {WETH} from "solmate/tokens/WETH.sol";

contract TradeIssuerV2 is ITradeIssuerV2, Ownable, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                              LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using Address for address;
    using Address for address payable;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                  STORAGE
    //////////////////////////////////////////////////////////////*/

    EnumerableSet.AddressSet private allowedTargets;
    address public immutable wrappedNativeToken;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param _wrappedNativeToken        Wrapped network native token
     */
    constructor(address _wrappedNativeToken) {
        wrappedNativeToken = _wrappedNativeToken;
    }

    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * Returns an array of the allowed targets for the trade issuer
     *
     * @return address[]     An address array containing the allowed targets
     */
    function getAllowedTargets() external view returns (address[] memory) {
        return allowedTargets.values();
    }

    /**
     * Checks if the address is an allowed target
     *
     * @param _target    The address to check
     *
     * @return bool      True if the address is a valid target
     */
    function isAllowedTarget(address _target) public view returns (bool) {
        return allowedTargets.contains(_target);
    }

    /**
     * Allows the trade issuer to perform low level calls to the specified target
     *
     * @param _target    The address of the target to allow
     */
    function addTarget(address _target) external onlyOwner nonReentrant {
        if (_target == address(0)) {
            revert InvalidTarget();
        }
        if (isAllowedTarget(address(_target))) revert TargetAlreadyAllowed();

        if (allowedTargets.add(_target)) revert CannotAllowTarget();

        emit AllowedTargetAdded(_target);
    }

    /**
     * Removes the ability to perform low level calls to the target
     *
     * @param _target    The address of the target to remove
     */
    function removeTarget(address _target) external onlyOwner nonReentrant {
        if (!isAllowedTarget(_target)) {
            revert InvalidTarget();
        }

        if (allowedTargets.remove(_target)) revert CannotRemoveTarget();

        emit AllowedTargetRemoved(_target);
    }

    /**
     * Transfer the total balance of the specified stucked token to the owner address
     *
     * @param _tokenToWithdraw     The ERC20 token address to withdraw
     */
    function transferERC20ToOwner(address _tokenToWithdraw) external onlyOwner {
        if (IERC20(_tokenToWithdraw).balanceOf(address(this)) == 0) revert ZeroBalanceAsset();

        IERC20(_tokenToWithdraw).safeTransfer(
            owner(), IERC20(_tokenToWithdraw).balanceOf(address(this))
        );
    }

    /**
     * Transfer all stucked Ether to the owner of the contract
     */
    function transferEthToOwner() external onlyOwner {
        if (address(this).balance == 0) revert ZeroBalanceAsset();
        payable(owner()).transfer(address(this).balance);
    }

    function mintChamberFromToken(
        IChamber _chamber,
        IIssuerWizard _issuerWizard,
        IERC20 _baseToken,
        uint256 _baseTokenBounds,
        uint256 _chamberAmount,
        ContractCallInstruction[] memory _contractCallInstructions
    ) external nonReentrant returns (uint256 baseTokenUsed) {
        if (_chamberAmount == 0) revert ZeroChamberAmount();

        _baseToken.safeTransferFrom(msg.sender, address(this), _baseTokenBounds);

        baseTokenUsed = _mintChamber(
            _chamber,
            IERC20(wrappedNativeToken),
            _issuerWizard,
            _chamberAmount,
            _contractCallInstructions
        );

        if (_baseTokenBounds < baseTokenUsed) revert OversoldBaseToken(baseTokenUsed);

        _baseToken.safeTransfer(msg.sender, _baseTokenBounds - baseTokenUsed);

        IERC20(address(_chamber)).safeTransfer(msg.sender, _chamberAmount);

        emit TradeIssuerTokenMinted(
            address(_chamber), msg.sender, address(_baseToken), baseTokenUsed, _chamberAmount
            );

        return baseTokenUsed;
    }

    function mintChamberFromNativeToken(
        IChamber _chamber,
        IIssuerWizard _issuerWizard,
        uint256 _chamberAmount,
        ContractCallInstruction[] memory _contractCallInstructions
    ) external payable nonReentrant returns (uint256 wrappedNativeTokenUsed) {
        if (_chamberAmount == 0) revert ZeroChamberAmount();
        if (msg.value == 0) revert ZeroNativeTokenSent();
        WETH(payable(wrappedNativeToken)).deposit{value: msg.value}();

        wrappedNativeTokenUsed = _mintChamber(
            _chamber,
            IERC20(wrappedNativeToken),
            _issuerWizard,
            _chamberAmount,
            _contractCallInstructions
        );

        if (msg.value < wrappedNativeTokenUsed) revert OversoldBaseToken(wrappedNativeTokenUsed);
        WETH(payable(wrappedNativeToken)).withdraw(msg.value - wrappedNativeTokenUsed);
        payable(msg.sender).sendValue(msg.value - wrappedNativeTokenUsed);

        IERC20(address(_chamber)).safeTransfer(msg.sender, _chamberAmount);

        emit TradeIssuerTokenMinted(
            address(_chamber),
            msg.sender,
            address(wrappedNativeToken),
            wrappedNativeTokenUsed,
            _chamberAmount
            );

        return wrappedNativeTokenUsed;
    }

    function redeemChamberToToken(
        IChamber _chamber,
        IIssuerWizard _issuerWizard,
        IERC20 _baseToken,
        uint256 _baseTokenBounds,
        uint256 _chamberAmount,
        ContractCallInstruction[] memory _contractCallInstructions
    ) external nonReentrant returns (uint256 baseTokenReturned) {
        if (_chamberAmount == 0) revert ZeroChamberAmount();

        IERC20(address(_chamber)).safeTransferFrom(msg.sender, address(this), _chamberAmount);

        baseTokenReturned = _redeemChamber(
            _chamber, _baseToken, _issuerWizard, _chamberAmount, _contractCallInstructions
        );

        if (baseTokenReturned < _baseTokenBounds) {
            revert RedeemedForLessTokens(baseTokenReturned);
        }

        _baseToken.safeTransfer(msg.sender, baseTokenReturned);

        emit TradeIssuerTokenRedeemed(
            address(_chamber), msg.sender, address(_baseToken), baseTokenReturned, _chamberAmount
            );

        return baseTokenReturned;
    }

    function redeemChamberToNativeToken(
        IChamber _chamber,
        IIssuerWizard _issuerWizard,
        uint256 _baseTokenBounds,
        uint256 _chamberAmount,
        ContractCallInstruction[] memory _contractCallInstructions
    ) external nonReentrant returns (uint256 wrappedNativeTokenReturned) {
        if (_chamberAmount == 0) revert ZeroChamberAmount();

        IERC20(address(_chamber)).safeTransferFrom(msg.sender, address(this), _chamberAmount);

        wrappedNativeTokenReturned = _redeemChamber(
            _chamber,
            IERC20(wrappedNativeToken),
            _issuerWizard,
            _chamberAmount,
            _contractCallInstructions
        );

        if (wrappedNativeTokenReturned < _baseTokenBounds) {
            revert RedeemedForLessTokens(wrappedNativeTokenReturned);
        }

        WETH(payable(wrappedNativeToken)).withdraw(wrappedNativeTokenReturned);
        payable(msg.sender).sendValue(wrappedNativeTokenReturned);

        emit TradeIssuerTokenRedeemed(
            address(_chamber),
            msg.sender,
            address(wrappedNativeToken),
            wrappedNativeTokenReturned,
            _chamberAmount
            );

        return wrappedNativeTokenReturned;
    }
    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _mintChamber(
        IChamber _chamber,
        IERC20 _baseToken,
        IIssuerWizard _issuerWizard,
        uint256 _chamberAmount,
        ContractCallInstruction[] memory _contractCallInstructions
    ) internal returns (uint256 baseTokenUsed) {
        uint256 baseTokenBalanceBefore = _baseToken.balanceOf(address(this));

        _executeInstructions(_contractCallInstructions);

        _checkAndIncreaseAllowanceOfConstituents(_chamber, _issuerWizard, _chamberAmount);

        _issuerWizard.issue(_chamber, _chamberAmount);

        return (_baseToken.balanceOf(address(this)) - baseTokenBalanceBefore);
    }

    function _redeemChamber(
        IChamber _chamber,
        IERC20 _baseToken,
        IIssuerWizard _issuerWizard,
        uint256 _chamberAmount,
        ContractCallInstruction[] memory _contractCallInstructions
    ) internal returns (uint256 totalBaseTokenReturned) {
        uint256 baseTokenBalanceBefore = _baseToken.balanceOf(address(this));

        _issuerWizard.redeem(_chamber, _chamberAmount);

        _executeInstructions(_contractCallInstructions);

        return (_baseToken.balanceOf(address(this)) - baseTokenBalanceBefore);
    }

    function _executeInstructions(ContractCallInstruction[] memory _contractCallInstructions)
        internal
    {
        for (uint256 i = 0; i < _contractCallInstructions.length; i++) {
            ContractCallInstruction memory currentInstruction = _contractCallInstructions[i];

            uint256 buyTokenBalanceBefore = currentInstruction._buyToken.balanceOf(address(this));

            _checkAndIncreaseAllowance(
                address(currentInstruction._sellToken),
                currentInstruction._allowanceTarget,
                currentInstruction._sellAmount
            );

            _fillQuote(currentInstruction._target, currentInstruction._callData);

            uint256 buyTokenAmountBought =
                currentInstruction._buyToken.balanceOf(address(this)) - buyTokenBalanceBefore;
            if (currentInstruction._minBuyAmount < buyTokenAmountBought) {
                revert UnderboughtAsset(
                    currentInstruction._buyToken,
                    currentInstruction._minBuyAmount,
                    buyTokenAmountBought
                );
            }
        }
    }

    /**
     * Execute a contract call
     *
     * @param _callData       CallData to be executed on a allowed Target
     */
    function _fillQuote(address target, bytes memory _callData)
        internal
        returns (bytes memory response)
    {
        //check that the target contract is allowed
        response = target.functionCall(_callData);
        if (response.length == 0) revert LowLevelFunctionCallFailed();
        return (response);
    }

    /**
     * Checks the allowance for issuance of a chamberToken, if allowance is not enough it's increased to max.
     *
     * @param _chamber          Chamber token address for mint.
     * @param _issuerWizard     Issuer wizard used at _chamber.
     */
    function _checkAndIncreaseAllowanceOfConstituents(
        IChamber _chamber,
        IIssuerWizard _issuerWizard,
        uint256 _chamberAmount
    ) internal {
        (address[] memory requiredConstituents, uint256[] memory requiredConstituentsQuantities) =
            _issuerWizard.getConstituentsQuantitiesForIssuance(_chamber, _chamberAmount);

        for (uint256 i = 0; i < requiredConstituents.length; i++) {
            if (
                IERC20(requiredConstituents[i]).balanceOf(address(this))
                    < requiredConstituentsQuantities[i]
            ) {
                revert UnderboughtConstituent(
                    IERC20(requiredConstituents[i]),
                    requiredConstituentsQuantities[i],
                    IERC20(requiredConstituents[i]).balanceOf(address(this))
                );
            }
            _checkAndIncreaseAllowance(
                requiredConstituents[i], address(_issuerWizard), requiredConstituentsQuantities[i]
            );
        }
    }

    /**
     * For the specified token and amount, checks the allowance between the TraderIssuer and _target.
     * If not enough, it sets the maximum.
     */
    function _checkAndIncreaseAllowance(
        address _tokenAddress,
        address _target,
        uint256 _requiredAmount
    ) internal {
        if (_requiredAmount == 0) revert ZeroRequiredAmount();
        uint256 currentAllowance = IERC20(_tokenAddress).allowance(address(this), _target);
        if (currentAllowance < _requiredAmount) {
            IERC20(_tokenAddress).safeIncreaseAllowance(
                _target, type(uint256).max - currentAllowance
            );
        }
    }
}