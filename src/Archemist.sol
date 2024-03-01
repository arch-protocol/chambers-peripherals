/**
 *     SPDX-License-Identifier: Apache License 2.0
 *
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

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { IArchemist } from "./interfaces/IArchemist.sol";
import { IArchemistGod } from "./interfaces/IArchemistGod.sol";
import { AccessManager } from "./AccessManager.sol";

contract Archemist is IArchemist, AccessManager, ReentrancyGuard, Pausable {
    /*//////////////////////////////////////////////////////////////
                                LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using Address for address;
    using Address for address payable;
    using SafeERC20 for ERC20;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Price per share of the Archemist. Amount of exchange token to be given at every deposit or to receive at every withdrawal in terms of the base token.
     */
    uint256 public pricePerShare;

    /**
     * @notice Fee to be charge for every deposit or withdrawal.
     */
    uint24 public immutable EXCHANGE_FEE;

    /**
     * @notice Address of the token to be given to the sender at every deposit or to be received by the sender at every withdrawal.
     */
    address public immutable EXCHANGE_TOKEN_ADDRESS;

    /**
     * @notice Address of the token to be given by the sender at every deposit or to be sent to the sender at every withdrawal.
     */
    address public immutable BASE_TOKEN_ADDRESS;

    /**
     * @notice Address of the Archemist Factory
     */
    IArchemistGod public immutable ARCHEMIST_GOD;

    /**
     * @notice Precision factor for deposit and withdrawal operations
     */
    uint256 private immutable PRECISION_FACTOR;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor for the Archemist contract. By default it is paused. Remind to set the pricePerShare before unpausing
     *
     * @param _adminAddress           Address of the admin of the contract
     * @param _exchangeTokenAddress    Address of the exchange token to be given at every deposit or to receive at every withdrawal
     * @param _baseTokenAddress        Address of the base token
     * @param _archemistGod            Address of the Archemist Factory
     * @param _exchangeFee             Fee to be charged at every deposit or withdrawal (number is divided by 10.000 to get the percentage)
     */
    constructor(
        address _adminAddress,
        address _exchangeTokenAddress,
        address _baseTokenAddress,
        address _archemistGod,
        uint24 _exchangeFee
    ) AccessManager(_adminAddress) {
        uint32 size;
        assembly {
            size := extcodesize(_archemistGod)
        }
        if (size == 0) revert ArchemistGodIsNotAContract();

        EXCHANGE_TOKEN_ADDRESS = _exchangeTokenAddress;
        BASE_TOKEN_ADDRESS = _baseTokenAddress;
        ARCHEMIST_GOD = IArchemistGod(_archemistGod);
        EXCHANGE_FEE = _exchangeFee;
        _pause();

        uint256 exchangeTokenDecimals = ERC20(EXCHANGE_TOKEN_ADDRESS).decimals();
        PRECISION_FACTOR = 10 ** (exchangeTokenDecimals);
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Pauses the contract for some operations. Operation can only be performed
     *         by an operator, manager or admin.
     */
    function pause() public onlyCallerWithAccess {
        _pause();
    }

    /**
     * @notice Pauses the contract for some operations. Operation can only be performed
     *         by an operator, manager or admin.
     */
    function unpause() public onlyCallerWithAccess {
        _unpause();
    }

    /**
     * @notice Updates the price per share of the Archemist. Operation can only be performed
     *         by an operator, manager or admin.
     *
     * @param _pricePerShare Address of the token to be withdrawn
     */
    function updatePricePerShare(uint256 _pricePerShare)
        external
        nonReentrant
        onlyCallerWithAccess
    {
        if (_pricePerShare == 0) revert ZeroPricePerShare();

        pricePerShare = _pricePerShare;

        emit PricePerShareUpdated(_pricePerShare);
    }

    /**
     * @notice Preview the amount of exchange token to be received for a given amount of base token
     *
     * @param _baseTokenAmount Amount of base token to be deposited
     * @return exchangeTokenAmount Amount of exchange token to be received
     */
    function previewDeposit(uint256 _baseTokenAmount)
        external
        view
        returns (uint256 exchangeTokenAmount)
    {
        if (_baseTokenAmount == 0) revert ZeroDepositAmount();

        if (pricePerShare == 0) revert ZeroPricePerShare();

        uint256 feeAmount = (_baseTokenAmount * EXCHANGE_FEE) / 10000;
        uint256 depositedAmount = _baseTokenAmount - feeAmount;

        exchangeTokenAmount = (depositedAmount * PRECISION_FACTOR) / pricePerShare;
    }

    /**
     * @notice Deposit base token to receive exchange token. Operation can only be performed
     *         when contract is not paused.
     *
     * @param _baseTokenAmount Amount of base token to be deposited
     * @return exchangeTokenAmount Amount of exchange token to be received
     */
    function deposit(uint256 _baseTokenAmount)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 exchangeTokenAmount)
    {
        if (_baseTokenAmount == 0) revert ZeroDepositAmount();

        if (pricePerShare == 0) revert ZeroPricePerShare();

        if (!ARCHEMIST_GOD.isValidArchemist(address(this))) revert InvalidArchemist();

        ERC20(BASE_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), _baseTokenAmount);

        uint256 feeAmount = (_baseTokenAmount * EXCHANGE_FEE) / 10000;
        uint256 depositedAmount = _baseTokenAmount - feeAmount;

        exchangeTokenAmount = (depositedAmount * PRECISION_FACTOR) / pricePerShare;

        ERC20(EXCHANGE_TOKEN_ADDRESS).safeTransfer(msg.sender, exchangeTokenAmount);

        emit Deposit(msg.sender, _baseTokenAmount, feeAmount);
    }

    /**
     * @notice Preview the amount of base token to be received for a given amount of exchange token
     *
     * @param _exchangeTokenAmount Amount of exchange token to be withdrawn
     * @return baseTokenAmount Amount of base token to be received
     */
    function previewWithdraw(uint256 _exchangeTokenAmount)
        external
        view
        returns (uint256 baseTokenAmount)
    {
        if (_exchangeTokenAmount == 0) revert ZeroWithdrawAmount();

        if (pricePerShare == 0) revert ZeroPricePerShare();

        baseTokenAmount = (_exchangeTokenAmount * pricePerShare) / PRECISION_FACTOR;

        uint256 feeAmount = (baseTokenAmount * EXCHANGE_FEE) / 10000;

        baseTokenAmount -= feeAmount;
    }

    /**
     * @notice Withdraw base token by providing exchange token. Operation can only be performed
     *         when contract is not paused.
     *
     * @param _exchangeTokenAmount Amount of exchange token to be withdrawn
     * @return baseTokenAmount Amount of base token to be received
     */
    function withdraw(uint256 _exchangeTokenAmount)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 baseTokenAmount)
    {
        if (_exchangeTokenAmount == 0) revert ZeroWithdrawAmount();

        if (pricePerShare == 0) revert ZeroPricePerShare();

        bool isValidArchemist = ARCHEMIST_GOD.isValidArchemist(address(this));
        if (!isValidArchemist) revert InvalidArchemist();

        ERC20(EXCHANGE_TOKEN_ADDRESS).safeTransferFrom(
            msg.sender, address(this), _exchangeTokenAmount
        );

        baseTokenAmount = (_exchangeTokenAmount * pricePerShare) / PRECISION_FACTOR;

        uint256 feeAmount = (baseTokenAmount * EXCHANGE_FEE) / 10000;

        baseTokenAmount -= feeAmount;

        ERC20(BASE_TOKEN_ADDRESS).safeTransfer(msg.sender, baseTokenAmount);

        emit Withdraw(msg.sender, baseTokenAmount, feeAmount);
    }

    /**
     * @notice Transfer ERC20 token to the manager or higher level role.
     *         Operation can only be performed by a manager or admin.
     *
     * @param _tokenToWithdraw Address of the token to be withdrawn
     */
    function transferErc20ToManager(address _tokenToWithdraw) external onlyManager {
        if (ERC20(_tokenToWithdraw).balanceOf(address(this)) == 0) {
            revert ZeroTokenBalance();
        }

        ERC20(_tokenToWithdraw).safeTransfer(
            msg.sender, ERC20(_tokenToWithdraw).balanceOf(address(this))
        );
    }
}
