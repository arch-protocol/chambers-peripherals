/**
 *     SPDX-License-Identifier: Apache License 2.0
 *
 *     Copyright 2021 Index Cooperative
 *     Copyright 2024 Smash Works Inc.
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
pragma solidity ^0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { WETH } from "solmate/tokens/WETH.sol";

import { IChamber } from "chambers/interfaces/IChamber.sol";
import { IChamberGod } from "chambers/interfaces/IChamberGod.sol";
import { IIssuerWizard } from "chambers/interfaces/IIssuerWizard.sol";

import { IArchNexus } from "./interfaces/IArchNexus.sol";

contract ArchNexus is IArchNexus, Ownable, ReentrancyGuard {
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
    WETH public immutable wrappedNativeToken;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param _wrappedNativeToken        Wrapped network native token
     */
    constructor(address _wrappedNativeToken) Ownable(msg.sender) {
        wrappedNativeToken = WETH(payable(_wrappedNativeToken));
    }

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
            revert InvalidTarget(_target);
        }
        if (isAllowedTarget(address(_target))) revert TargetAlreadyAllowed();

        if (!allowedTargets.add(_target)) revert CannotAllowTarget();

        emit AllowedTargetAdded(_target);
    }

    /**
     * Removes the ability to perform low level calls to the target
     *
     * @param _target    The address of the target to remove
     */
    function removeTarget(address _target) external onlyOwner nonReentrant {
        if (!isAllowedTarget(_target)) {
            revert InvalidTarget(_target);
        }

        if (!allowedTargets.remove(_target)) revert CannotRemoveTarget();

        emit AllowedTargetRemoved(_target);
    }

    /**
     * Transfer the total balance of the specified stucked token to the owner address
     *
     * @param _tokenToWithdraw     The ERC20 token address to withdraw
     */
    function transferERC20ToOwner(address _tokenToWithdraw) external onlyOwner nonReentrant {
        if (IERC20(_tokenToWithdraw).balanceOf(address(this)) < 1) revert ZeroBalanceAsset();

        IERC20(_tokenToWithdraw).safeTransfer(
            owner(), IERC20(_tokenToWithdraw).balanceOf(address(this))
        );
    }

    /**
     * Transfer all stuck native token to the owner of the contract
     */
    function transferNativeTokenToOwner() external onlyOwner nonReentrant {
        if (address(this).balance < 1) revert ZeroBalanceAsset();
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * Receives an initial base token, performs a series of low-level calls and returns the final token.
     *
     * @param _baseToken                    The token that will be used to get the underlying assets.
     * @param _baseAmount                   The amount of the baseToken to be used for the initial call.
     * @param _finalToken                   The token that will be sent to the msg.sender at the end of all the calls.
     * @param _contractCallInstructions     Instruction array that will be executed in order to get
     *                                      the underlying assets.
     *
     * @return finalAmountBought            Total amount of the final token bought.
     *
     */
    function executeCalls(
        ContractCallInstruction[] memory _contractCallInstructions,
        address _baseToken,
        uint256 _baseAmount,
        address _finalToken,
        uint256 _minFinalAmount
    ) external nonReentrant returns (uint256 finalAmountBought) {
        if (_baseAmount == 0) revert ZeroBaseTokenSent();
        if (_baseToken == _finalToken) revert NoSameAddressAllowed();
        if (_baseToken == address(0) || _finalToken == address(0)) revert ZeroAddressNotAllowed();
        if (_contractCallInstructions.length == 0) revert NoInstructionsProvided();

        IERC20 baseToken = IERC20(_baseToken);
        IERC20 finalToken = IERC20(_finalToken);

        baseToken.safeTransferFrom(msg.sender, address(this), _baseAmount);

        uint256 finalTokenBalanceBefore = finalToken.balanceOf(address(this));

        _executeInstructions(_contractCallInstructions);

        baseToken.safeTransfer(msg.sender, baseToken.balanceOf(address(this)));

        finalAmountBought = finalToken.balanceOf(address(this)) - finalTokenBalanceBefore;

        if (finalAmountBought < _minFinalAmount) {
            revert UnderboughtAsset(finalToken, _minFinalAmount);
        }

        finalToken.safeTransfer(msg.sender, finalAmountBought);

        emit ExecutionSuccess(_finalToken, finalAmountBought);
    }

    /**
     * Receives an initial amount of native token, performs a series of low-level calls and returns the final token.
     *
     * @param _nativeAmount                 The amount of the native token to be used for the initial call.
     * @param _finalToken                   The token that will be sent to the msg.sender at the end of all the calls.
     * @param _contractCallInstructions     Instruction array that will be executed in order to get
     *                                      the underlying assets.
     *
     * @return finalAmountBought            Total amount of the final token bought.
     *
     */
    function executeCallsWithNativeToken(
        ContractCallInstruction[] memory _contractCallInstructions,
        uint256 _nativeAmount,
        address _finalToken,
        uint256 _minFinalAmount
    ) external payable nonReentrant returns (uint256 finalAmountBought) {
        if (_nativeAmount == 0) revert ZeroNativeTokenSent();
        if (_finalToken == address(0)) revert ZeroAddressNotAllowed();
        if (_contractCallInstructions.length == 0) revert NoInstructionsProvided();

        wrappedNativeToken.deposit{ value: msg.value }();

        _executeInstructions(_contractCallInstructions);

        wrappedNativeToken.transfer(msg.sender, wrappedNativeToken.balanceOf(address(this)));

        IERC20 finalToken = IERC20(_finalToken);

        finalAmountBought = finalToken.balanceOf(address(this));

        if (finalAmountBought < _minFinalAmount) {
            revert UnderboughtAsset(finalToken, _minFinalAmount);
        }

        finalToken.safeTransfer(msg.sender, finalAmountBought);

        emit ExecutionSuccess(_finalToken, finalAmountBought);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * Executes the array of instructions and verifies that the correct amount of each token
     * from the instruction is purchased.
     *
     * @param _contractCallInstructions     Instruction array that will be executed in order to get
     *                                      the underlying assets.
     */
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
            if (currentInstruction._minBuyAmount > buyTokenAmountBought) {
                revert UnderboughtAsset(
                    currentInstruction._buyToken, currentInstruction._minBuyAmount
                );
            }
        }
    }

    /**
     * Execute a contract call
     *
     * @param _callData       CallData to be executed on a allowed Target
     *
     * @return response       Response from the low-level call
     */
    function _fillQuote(address _target, bytes memory _callData)
        internal
        returns (bytes memory response)
    {
        if (!isAllowedTarget(_target)) revert InvalidTarget(_target);
        response = _target.functionCall(_callData);
        if (response.length == 0) revert LowLevelFunctionCallFailed();
        return (response);
    }

    /**
     * For the specified token and amount, checks the allowance between the TraderIssuer and _target.
     * If not enough, it sets the maximum.
     *
     * @param _tokenAddress     Address of the token that will be used.
     * @param _target           Target address of the allowance.
     * @param _requiredAmount   Required allowance for the operation.
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
