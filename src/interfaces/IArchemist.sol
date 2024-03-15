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
 *      @@@@@@         @@        @@  @@    @@@@@ @@@@@  @@@@@@
 *     .@@@@@          @@@      @@@@@@@@   @@    @@     @@  @@
 *     @@@@@(       (((((      @@@    @@@  @@    @@@@@  @@  @@
 *    @@@@@@   (((((((
 *    @@@@@#(((((((
 *    @@@@@(((((
 *      @@@((
 */
pragma solidity ^0.8.24;

interface IArchemist {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed sender, uint256 amount, uint256 feeAmount);

    event Withdraw(address indexed sender, uint256 amount, uint256 feeAmount);

    event PricePerShareUpdated(uint256 pricePerShare);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroRedeemAmount();

    error ZeroWithdrawAmount();

    error ZeroMintAmount();

    error ZeroDepositAmount();

    error ZeroTokenBalance();

    error InvalidArchemist();

    error ArchemistGodIsNotAContract();

    error ZeroPricePerShare();

    error InsufficientExchangeTokenBalance();

    error InsufficientBaseTokenBalance();

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the price per share of the Archemist. Operation can only be performed
     *         by an operator, manager or admin.
     *
     * @param _pricePerShare Address of the token to be withdrawn
     */
    function updatePricePerShare(uint256 _pricePerShare) external;

    /**
     * @notice  Preview the amount of base token needed to deposit to receive a given amount of exchange token
     *
     * @param _exchangeTokenAmount Amount of exchange token to be received
     * @return baseTokenAmount Amount of base token to be deposited
     */
    function previewMint(uint256 _exchangeTokenAmount)
        external
        view
        returns (uint256 baseTokenAmount);

    /**
     * @notice Preview the amount of exchange token to be received for a given amount of base token
     *
     * @param _baseTokenAmount Amount of base token to be deposited
     * @return exchangeTokenAmount Amount of exchange token to be received
     */
    function previewDeposit(uint256 _baseTokenAmount)
        external
        view
        returns (uint256 exchangeTokenAmount);

    /**
     * @notice Deposit base token to receive exchange token. Operation can only be performed
     *         when contract is not paused.
     *
     * @param _baseTokenAmount Amount of base token to be deposited
     * @return exchangeTokenAmount Amount of exchange token to be received
     */
    function deposit(uint256 _baseTokenAmount) external returns (uint256 exchangeTokenAmount);

    /**
     * @notice Preview the amount of exchange token needed to withdraw to receive a given amount of base token
     *
     * @param _baseTokenAmount Amount of base token to be received
     * @return exchangeTokenAmount Amount of exchange token to be withdrawn
     */
    function previewRedeem(uint256 _baseTokenAmount)
        external
        view
        returns (uint256 exchangeTokenAmount);

    /**
     * @notice Preview the amount of base token to be received for a given amount of exchange token
     *
     * @param _exchangeTokenAmount Amount of exchange token to be withdrawn
     * @return baseTokenAmount Amount of base token to be received
     */
    function previewWithdraw(uint256 _exchangeTokenAmount)
        external
        view
        returns (uint256 baseTokenAmount);

    /**
     * @notice Withdraw base token by providing exchange token. Operation can only be performed
     *         when contract is not paused.
     *
     * @param _exchangeTokenAmount Amount of exchange token to be withdrawn
     * @return baseTokenAmount Amount of base token to be received
     */
    function withdraw(uint256 _exchangeTokenAmount) external returns (uint256 baseTokenAmount);

    /**
     * @notice Transfer ERC20 token to the msg.sender . Operation can only be performed
     *         by a manager or admin.
     *
     * @param _tokenToWithdraw Address of the token to be withdrawn
     */
    function transferErc20ToManager(address _tokenToWithdraw) external;
}
