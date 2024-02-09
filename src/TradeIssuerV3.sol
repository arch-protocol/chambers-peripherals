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
pragma solidity ^0.8.21;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { IChamber } from "chambers/interfaces/IChamber.sol";
import { IChamberGod } from "chambers/interfaces/IChamberGod.sol";
import { IIssuerWizard } from "chambers/interfaces/IIssuerWizard.sol";

import { ReentrancyGuard } from "solmate/utils/ReentrancyGuard.sol";
import { WETH } from "solmate/tokens/WETH.sol";

import { ITradeIssuerV3 } from "./interfaces/ITradeIssuerV3.sol";

contract TradeIssuerV3 is ITradeIssuerV3, Ownable, ReentrancyGuard {
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
    IChamberGod public chamberGod;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param _wrappedNativeToken        Wrapped network native token
     */
    constructor(address _wrappedNativeToken, address _chamberGod) {
        wrappedNativeToken = _wrappedNativeToken;
        chamberGod = IChamberGod(_chamberGod);
    }

    receive() external payable { }

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
     * Transfer all stucked Ether to the owner of the contract
     */
    function transferEthToOwner() external onlyOwner nonReentrant {
        if (address(this).balance < 1) revert ZeroBalanceAsset();
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * Mints the specified amount of chamber token and sends them to the msg.sender using an ERC20
     * token as input. Unspent baseToken is also transferred back to the sender.
     *
     * @param _chamber                      Chamber address.
     * @param _issuerWizard                 Issuer wizard that'll be called for mint.
     * @param _baseToken                    The token that will be used to get the underlying assets.
     * @param _maxPayAmount                 The maximum amount of the baseToken to be used for the mint.
     * @param _mintAmount                   Chamber tokens amount to mint.
     * @param _contractCallInstructions     Instruction array that will be executed in order to get
     *                                      the underlying assets.
     *
     * @return baseTokenUsed                Total amount of the base token used for the mint.
     *
     */
    function mintFromToken(
        ContractCallInstruction[] memory _contractCallInstructions,
        IChamber _chamber,
        IIssuerWizard _issuerWizard,
        IERC20 _baseToken,
        uint256 _maxPayAmount,
        uint256 _mintAmount
    ) external nonReentrant returns (uint256 baseTokenUsed) {
        if (_mintAmount == 0) revert ZeroChamberAmount();
        if (_maxPayAmount == 0) revert ZeroBaseTokenSent();
        if (!chamberGod.isWizard(address(_issuerWizard))) revert InvalidWizard();
        if (!chamberGod.isChamber(address(_chamber))) revert InvalidChamber();

        _baseToken.safeTransferFrom(msg.sender, address(this), _maxPayAmount);

        baseTokenUsed = _mint(
            _chamber, IERC20(_baseToken), _issuerWizard, _mintAmount, _contractCallInstructions
        );

        if (_maxPayAmount < baseTokenUsed) revert OversoldBaseToken();

        uint256 remainingBaseToken = _maxPayAmount - baseTokenUsed;

        _baseToken.safeTransfer(msg.sender, remainingBaseToken);

        IERC20(address(_chamber)).safeTransfer(msg.sender, _mintAmount);

        emit TradeIssuerTokenMinted(
            address(_chamber), msg.sender, address(_baseToken), baseTokenUsed, _mintAmount
        );

        return baseTokenUsed;
    }

    /**
     * Mints the specified amount of chamber token and sends them to the msg.sender using the network
     * native token as input. Unspent native token is also transferred back to the sender.
     *
     * @param _chamber                      Chamber address.
     * @param _issuerWizard                 Issuer wizard that'll be called for mint.
     * @param _mintAmount                   Chamber tokens amount to mint.
     * @param _contractCallInstructions     Instruction array that will be executed in order to get
     *                                      the underlying assets.
     *
     * @return wrappedNativeTokenUsed       Total amount of the wrapped native token used for the mint.
     *
     */
    function mintFromNativeToken(
        ContractCallInstruction[] memory _contractCallInstructions,
        IChamber _chamber,
        IIssuerWizard _issuerWizard,
        uint256 _mintAmount
    ) external payable nonReentrant returns (uint256 wrappedNativeTokenUsed) {
        if (_mintAmount == 0) revert ZeroChamberAmount();
        if (msg.value == 0) revert ZeroNativeTokenSent();
        if (!chamberGod.isWizard(address(_issuerWizard))) revert InvalidWizard();
        if (!chamberGod.isChamber(address(_chamber))) revert InvalidChamber();

        WETH(payable(wrappedNativeToken)).deposit{ value: msg.value }();

        wrappedNativeTokenUsed = _mint(
            _chamber,
            IERC20(wrappedNativeToken),
            _issuerWizard,
            _mintAmount,
            _contractCallInstructions
        );

        if (msg.value < wrappedNativeTokenUsed) revert OversoldBaseToken();

        uint256 remainingWrappedNativeToken = msg.value - wrappedNativeTokenUsed;

        WETH(payable(wrappedNativeToken)).withdraw(remainingWrappedNativeToken);
        payable(msg.sender).sendValue(remainingWrappedNativeToken);

        IERC20(address(_chamber)).safeTransfer(msg.sender, _mintAmount);

        emit TradeIssuerTokenMinted(
            address(_chamber),
            msg.sender,
            address(wrappedNativeToken),
            wrappedNativeTokenUsed,
            _mintAmount
        );

        return wrappedNativeTokenUsed;
    }

    /**
     * Redeems the specified amount of chamber token for the required baseToken and sends it to the
     * msg.sender.
     *
     * @param _chamber                      Chamber address.
     * @param _issuerWizard                 Issuer wizard that'll be called for redeem.
     * @param _baseToken                    The token that it will be sent to the msg.sender.
     * @param _minReceiveAmount             The minimum amount of the baseToken to be received.
     * @param _redeemAmount                 Chamber tokens amount to redeem.
     * @param _contractCallInstructions     Instruction array that will be executed in order to get
     *                                      the underlying assets.
     *
     * @return baseTokenReturned            Total baseToken amount sent to the msg.sender.
     *
     */
    function redeemToToken(
        ContractCallInstruction[] memory _contractCallInstructions,
        IChamber _chamber,
        IIssuerWizard _issuerWizard,
        IERC20 _baseToken,
        uint256 _minReceiveAmount,
        uint256 _redeemAmount
    ) external nonReentrant returns (uint256 baseTokenReturned) {
        if (_redeemAmount == 0) revert ZeroChamberAmount();
        if (!chamberGod.isWizard(address(_issuerWizard))) revert InvalidWizard();
        if (!chamberGod.isChamber(address(_chamber))) revert InvalidChamber();

        IERC20(address(_chamber)).safeTransferFrom(msg.sender, address(this), _redeemAmount);

        baseTokenReturned =
            _redeem(_chamber, _baseToken, _issuerWizard, _redeemAmount, _contractCallInstructions);

        if (baseTokenReturned < _minReceiveAmount) {
            revert RedeemedForLessTokens();
        }

        _baseToken.safeTransfer(msg.sender, baseTokenReturned);

        emit TradeIssuerTokenRedeemed(
            address(_chamber), msg.sender, address(_baseToken), baseTokenReturned, _redeemAmount
        );

        return baseTokenReturned;
    }

    /**
     * Redeems the specified amount of chamber token for the network's native token and sends it to the
     * msg.sender.
     *
     * @param _chamber                      Chamber address.
     * @param _issuerWizard                 Issuer wizard that'll be called for redeem.
     * @param _minReceiveAmount             The minimum amount of the baseToken to be received.
     * @param _redeemAmount                 Chamber tokens amount to redeem.
     * @param _contractCallInstructions     Instruction array that will be executed in order to get
     *                                      the underlying assets.
     *
     * @return wrappedNativeTokenReturned   Total native token amount sent to the msg.sender.
     *
     */
    function redeemToNativeToken(
        ContractCallInstruction[] memory _contractCallInstructions,
        IChamber _chamber,
        IIssuerWizard _issuerWizard,
        uint256 _minReceiveAmount,
        uint256 _redeemAmount
    ) external nonReentrant returns (uint256 wrappedNativeTokenReturned) {
        if (_redeemAmount == 0) revert ZeroChamberAmount();
        if (!chamberGod.isWizard(address(_issuerWizard))) revert InvalidWizard();
        if (!chamberGod.isChamber(address(_chamber))) revert InvalidChamber();

        IERC20(address(_chamber)).safeTransferFrom(msg.sender, address(this), _redeemAmount);

        wrappedNativeTokenReturned = _redeem(
            _chamber,
            IERC20(wrappedNativeToken),
            _issuerWizard,
            _redeemAmount,
            _contractCallInstructions
        );

        if (wrappedNativeTokenReturned < _minReceiveAmount) {
            revert RedeemedForLessTokens();
        }

        WETH(payable(wrappedNativeToken)).withdraw(wrappedNativeTokenReturned);
        payable(msg.sender).sendValue(wrappedNativeTokenReturned);

        emit TradeIssuerTokenRedeemed(
            address(_chamber),
            msg.sender,
            address(wrappedNativeToken),
            wrappedNativeTokenReturned,
            _redeemAmount
        );

        return wrappedNativeTokenReturned;
    }

    /**
     * Redeems the specified amount of chamber token, performs the specified instructions and mints another chamber token
     *
     * @param _chamberToRedeem              Chamber address.
     * @param _chamberToMint                Chamber address.
     * @param _issuerWizard                 Issuer wizard that'll be called for redeem.
     * @param _redeemAmount                 Chamber tokens amount to redeem.
     * @param _mintAmount                   The amount of the chamber to mint to be received.
     * @param _contractCallInstructions     Instruction array that will be executed in order to get
     *                                      the underlying assets of the chamber token to mint.
     */
    function redeemAndMint(
        IChamber _chamberToRedeem,
        uint256 _redeemAmount,
        IChamber _chamberToMint,
        uint256 _mintAmount,
        IIssuerWizard _issuerWizard,
        ContractCallInstruction[] memory _contractCallInstructions
    ) external nonReentrant {
        if (_redeemAmount == 0) revert ZeroChamberAmount();
        if (_mintAmount == 0) revert ZeroChamberAmount();
        if (!chamberGod.isWizard(address(_issuerWizard))) revert InvalidWizard();
        if (!chamberGod.isChamber(address(_chamberToRedeem))) revert InvalidChamber();
        if (!chamberGod.isChamber(address(_chamberToMint))) revert InvalidChamber();

        IERC20(address(_chamberToRedeem)).safeTransferFrom(msg.sender, address(this), _redeemAmount);

        // (address[] memory redeemConstituents, uint256[] memory redeemConstituentsPreviousBalances) =
        //     _getCurrentRedeemConstituentsBalances(_chamberToRedeem);

        _redeemAndMint(
            _chamberToRedeem,
            _chamberToMint,
            _issuerWizard,
            _redeemAmount,
            _mintAmount,
            _contractCallInstructions
        );

        // _transferReminderConstituentsBalances(
        //     redeemConstituents, redeemConstituentsPreviousBalances
        // );

        IERC20(address(_chamberToMint)).safeTransfer(msg.sender, _mintAmount);

        emit TradeIssuerTokenRedeemedAndMinted(
            msg.sender,
            address(_chamberToRedeem),
            address(_chamberToMint),
            _redeemAmount,
            _mintAmount
        );
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * Internal function in charge of getting the current balances of the chamber constituents,
     * before a redeemAndMint operation.
     */
    function _getCurrentRedeemConstituentsBalances(IChamber _chamberToRedeem)
        internal
        returns (address[] memory constituents, uint256[] memory balances)
    {
        constituents = _chamberToRedeem.getConstituentsAddresses();
        balances = new uint256[](constituents.length);

        for (uint256 i = 0; i < constituents.length; i++) {
            balances[i] = IERC20(constituents[i]).balanceOf(address(this));
        }
    }

    /**
     * Internal function in charge of transferring the reminder of the constituents balances,
     * after a redeemAndMint operation.
     */
    function _transferReminderConstituentsBalances(
        address[] memory _constituents,
        uint256[] memory _previousBalances
    ) internal {
        for (uint256 i = 0; i < _constituents.length; i++) {
            uint256 currentBalance = IERC20(_constituents[i]).balanceOf(address(this));
            if (currentBalance > _previousBalances[i]) {
                IERC20(_constituents[i]).safeTransfer(
                    msg.sender, currentBalance - _previousBalances[i]
                );
            }
        }
    }

    /**
     * Internal function in charge of the generic mint. The main objective is to get the chamber tokens.
     *
     * @param _chamber                      Chamber address.
     * @param _baseToken                    The token that will be used to get the underlying assets.
     * @param _issuerWizard                 Issuer wizard that'll be called for mint.
     * @param _mintAmount                Chamber tokens amount to mint.
     * @param _contractCallInstructions     Instruction array that will be executed in order to get
     *                                      the underlying assets.
     *
     * @return baseTokenUsed                Total amount of the base token used for the mint.
     *
     */
    function _mint(
        IChamber _chamber,
        IERC20 _baseToken,
        IIssuerWizard _issuerWizard,
        uint256 _mintAmount,
        ContractCallInstruction[] memory _contractCallInstructions
    ) internal returns (uint256 baseTokenUsed) {
        uint256 baseTokenBalanceBefore = _baseToken.balanceOf(address(this));

        _executeInstructions(_contractCallInstructions);

        _checkAndIncreaseAllowanceOfConstituents(_chamber, _issuerWizard, _mintAmount);

        _issuerWizard.issue(_chamber, _mintAmount);

        baseTokenUsed = baseTokenBalanceBefore - _baseToken.balanceOf(address(this));

        return baseTokenUsed;
    }

    /**
     * Internal function in charge of the generic redeem. The main objective is to get the base token
     * from the chamber token.
     *
     * @param _chamber                      Chamber address.
     * @param _baseToken                    The token that will be used to get the underlying assets.
     * @param _issuerWizard                 Issuer wizard that'll be called for redeem.
     * @param _redeemAmount                 Chamber tokens amount to redeem.
     * @param _contractCallInstructions     Instruction array that will be executed in order to get
     *                                      the _baseToken assets.
     *
     * @return totalBaseTokenReturned       Total amount of the base that will be sent to the msg.sender.
     *
     */
    function _redeem(
        IChamber _chamber,
        IERC20 _baseToken,
        IIssuerWizard _issuerWizard,
        uint256 _redeemAmount,
        ContractCallInstruction[] memory _contractCallInstructions
    ) internal returns (uint256 totalBaseTokenReturned) {
        uint256 baseTokenBalanceBefore = _baseToken.balanceOf(address(this));

        _issuerWizard.redeem(_chamber, _redeemAmount);

        _executeInstructions(_contractCallInstructions);

        totalBaseTokenReturned = _baseToken.balanceOf(address(this)) - baseTokenBalanceBefore;

        return totalBaseTokenReturned;
    }

    /**
     * Internal function in charge of performing a redeem, execute instructions and mint. The main objective is to redeem a chamber
     * exchange its components and mint another chamber
     *
     * @param _chamberToRedeem              Chamber to redeem.
     * @param _chamberToMint                Chamber to mint.
     * @param _issuerWizard                 Issuer wizard that'll be called for redeem.
     * @param _redeemAmount                 Chamber tokens amount to redeem.
     * @param _minimumMintAmount            Chamber tokens amount to mint.
     * @param _contractCallInstructions     Instruction array that will be executed in order to get
     *                                      the mintChamber constituents.
     */
    function _redeemAndMint(
        IChamber _chamberToRedeem,
        IChamber _chamberToMint,
        IIssuerWizard _issuerWizard,
        uint256 _redeemAmount,
        uint256 _minimumMintAmount,
        ContractCallInstruction[] memory _contractCallInstructions
    ) internal {
        _issuerWizard.redeem(_chamberToRedeem, _redeemAmount);

        _executeInstructions(_contractCallInstructions);

        _checkAndIncreaseAllowanceOfConstituents(_chamberToMint, _issuerWizard, _minimumMintAmount);

        _issuerWizard.issue(_chamberToMint, _minimumMintAmount);
    }

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
     * Checks the allowance for issuance of a chamberToken, if allowance is not enough it's increased to max.
     *
     * @param _chamber          Chamber token address for mint.
     * @param _issuerWizard     Issuer wizard used at _chamber.
     * @param _mintAmount    Amount of the chamber token to mint.
     */
    function _checkAndIncreaseAllowanceOfConstituents(
        IChamber _chamber,
        IIssuerWizard _issuerWizard,
        uint256 _mintAmount
    ) internal {
        (address[] memory requiredConstituents, uint256[] memory requiredConstituentsQuantities) =
            _issuerWizard.getConstituentsQuantitiesForIssuance(_chamber, _mintAmount);

        for (uint256 i = 0; i < requiredConstituents.length; i++) {
            if (
                IERC20(requiredConstituents[i]).balanceOf(address(this))
                    < requiredConstituentsQuantities[i]
            ) {
                revert UnderboughtConstituent(
                    IERC20(requiredConstituents[i]), requiredConstituentsQuantities[i]
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
