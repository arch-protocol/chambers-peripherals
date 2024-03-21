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
 *     This is a modified code from Index Cooperative found at
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

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IArchNexus {
    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct ContractCallInstruction {
        address payable _target;
        address _allowanceTarget;
        IERC20 _sellToken;
        uint256 _sellAmount;
        IERC20 _buyToken;
        uint256 _minBuyAmount;
        bytes _callData;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event AllowedTargetAdded(address indexed _target);

    event AllowedTargetRemoved(address indexed _targer);

    event ExecutionSuccess(address _finalToken, uint256 _finalAmount);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error CannotAllowTarget();

    error CannotRemoveTarget();

    error InvalidTarget(address target);

    error LowLevelFunctionCallFailed();

    error TargetAlreadyAllowed();

    error UnderboughtAsset(IERC20 asset, uint256 buyAmount);

    error ZeroBalanceAsset();

    error ZeroBaseTokenSent();

    error ZeroNativeTokenSent();

    error ZeroRequiredAmount();

    error NoSameAddressAllowed();

    error ZeroAddressNotAllowed();

    error NoInstructionsProvided();

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getAllowedTargets() external returns (address[] memory);

    function isAllowedTarget(address _target) external returns (bool);

    function addTarget(address _target) external;

    function removeTarget(address _target) external;

    function transferERC20ToOwner(address _tokenToWithdraw) external;

    function transferNativeTokenToOwner() external;

    function executeCalls(
        ContractCallInstruction[] memory _contractCallInstructions,
        address _baseToken,
        uint256 _baseAmount,
        address _finalToken,
        uint256 _minFinalAmount
    ) external returns (uint256 finalAmountBought);

    function executeCallsWithNativeToken(
        ContractCallInstruction[] memory _contractCallInstructions,
        uint256 _nativeAmount,
        address _finalToken,
        uint256 _minFinalAmount
    ) external payable returns (uint256 finalAmountBought);
}
