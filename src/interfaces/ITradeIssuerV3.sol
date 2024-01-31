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
pragma solidity ^0.8.21;

import { IChamber } from "chambers/interfaces/IChamber.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IIssuerWizard } from "chambers/interfaces/IIssuerWizard.sol";

interface ITradeIssuerV3 {
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

    event TradeIssuerTokenMinted(
        address indexed chamber,
        address indexed recipient,
        address indexed inputToken,
        uint256 totalTokensUsed,
        uint256 mintAmount
    );

    event TradeIssuerTokenRedeemed(
        address indexed chamber,
        address indexed recipient,
        address indexed outputToken,
        uint256 totalTokensReturned,
        uint256 redeemAmount
    );

    event TradeIssuerTokenRedeemedAndMinted(
        address indexed recipient,
        address indexed chamberToRedeem,
        address indexed chamberToMint,
        uint256 redeemAmount,
        uint256 mintAmount
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error CannotAllowTarget();

    error CannotRemoveTarget();

    error InvalidTarget(address target);

    error LowLevelFunctionCallFailed();

    error OversoldBaseToken();

    error RedeemedForLessTokens();

    error TargetAlreadyAllowed();

    error UnderboughtAsset(IERC20 asset, uint256 buyAmount);

    error UnderboughtConstituent(IERC20 asset, uint256 buyAmount);

    error ZeroChamberAmount();

    error ZeroBalanceAsset();

    error ZeroNativeTokenSent();

    error ZeroBaseTokenSent();

    error ZeroRequiredAmount();

    error InvalidWizard();

    error InvalidChamber();

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getAllowedTargets() external returns (address[] memory);

    function isAllowedTarget(address _target) external returns (bool);

    function addTarget(address _target) external;

    function removeTarget(address _target) external;

    function transferERC20ToOwner(address _tokenToWithdraw) external;

    function transferEthToOwner() external;

    function mintFromToken(
        ContractCallInstruction[] memory _contractCallInstructions,
        IChamber _chamber,
        IIssuerWizard _issuerWizard,
        IERC20 _baseToken,
        uint256 _maxPayAmount,
        uint256 _chamberAmount
    ) external returns (uint256 baseTokenUsed);

    function mintFromNativeToken(
        ContractCallInstruction[] memory _contractCallInstructions,
        IChamber _chamber,
        IIssuerWizard _issuerWizard,
        uint256 _chamberAmount
    ) external payable returns (uint256 wrappedNativeTokenUsed);

    function redeemToToken(
        ContractCallInstruction[] memory _contractCallInstructions,
        IChamber _chamber,
        IIssuerWizard _issuerWizard,
        IERC20 _baseToken,
        uint256 _minReceiveAmount,
        uint256 _chamberAmount
    ) external returns (uint256 baseTokenReturned);

    function redeemToNativeToken(
        ContractCallInstruction[] memory _contractCallInstructions,
        IChamber _chamber,
        IIssuerWizard _issuerWizard,
        uint256 _minReceiveAmount,
        uint256 _chamberAmount
    ) external returns (uint256 wrappedNativeTokenReturned);

    function redeemAndMint(
        IChamber _chamberToRedeem,
        uint256 _redeemAmount,
        IChamber _chamberToMint,
        uint256 _mintAmount,
        IIssuerWizard _issuerWizard,
        ContractCallInstruction[] memory _contractCallInstructions
    ) external;
}
