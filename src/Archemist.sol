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
pragma solidity ^0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Pausable } from "@openzeppelin/contracts/security/Pausable.sol";

import { ReentrancyGuard } from "solmate/utils/ReentrancyGuard.sol";


import { IArchemist } from "./interfaces/IArchemist.sol";
import { AccessManager } from "./AccessManager.sol";

contract Archemist is IArchemist, AccessManager, ReentrancyGuard, Pausable {

  /*//////////////////////////////////////////////////////////////
                                LIBRARIES
  //////////////////////////////////////////////////////////////*/

  using Address for address;
  using Address for address payable;
  using SafeERC20 for IERC20;

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
  uint24  immutable public EXCHANGE_FEE;  

  /**
   * @notice Address of the token to be given to the sender at every deposit or to be received by the sender at every withdrawal.
   */
  address immutable public EXCHANGE_TOKEN;

  /**
  * @notice Address of the token to be given by the sender at every deposit or to be sent to the sender at every withdrawal.
  */
  address immutable public BASE_TOKEN_ADDRESS;

  /**
  * @notice Address of the Archemist Factory
  */
  address immutable public ARCHEMIST_GOD;


  /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  /**
    * @notice Constructor for the Archemist contract. By default it is paused. Remind to set the pricePerShare before unpausing
    * @param _exchangeToken    Address of the exchange token to be given at every deposit or to receive at every withdrawal
    * @param _baseTokenAddress Address of the base token
    * @param _archemistGod     Address of the Archemist Factory
    * @param _exchangeFee      Fee to be charge for every deposit or withdrawal
   */
  constructor(
    address _exchangeToken,
    address _baseTokenAddress,
    address _archemistGod,
    uint24 _exchangeFee 
  ) AccessManager() {
    EXCHANGE_TOKEN = _exchangeToken;
    BASE_TOKEN_ADDRESS = _baseTokenAddress;
    ARCHEMIST_GOD = _archemistGod;
    EXCHANGE_FEE = _exchangeFee;
    _pause();
  }

  /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/


  /**
    * @notice Pauses the contract for some operations. Operation can only be performed
    *         by an operator, manager or admin.
  */
  function pause() public onlyCallerWithAccess() {
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
  function updatePricePerShare(uint256 _pricePerShare) external nonReentrant onlyCallerWithAccess {
    pricePerShare = _pricePerShare;

    emit PricePerShareUpdated(_pricePerShare);
  }

  /**
    * @notice Preview the amount of exchange token to be received for a given amount of base token
    *     
    * @param _baseTokenAmount Amount of base token to be deposited
    * @return chamberAmount Amount of exchange token to be received
  */
  function previewDeposit(uint256 _baseTokenAmount) external view returns (uint256 chamberAmount) {
    chamberAmount = _baseTokenAmount / pricePerShare;
  }

  /**
    * @notice Deposit base token to receive exchange token. Operation can only be performed
    *         when contract is not paused.
    *     
    * @param _baseTokenAmount Amount of base token to be deposited
    * @return chamberAmount Amount of exchange token to be received
  */
  function deposit(uint256 _baseTokenAmount) external nonReentrant whenNotPaused returns (uint256 chamberAmount) {
    if(_baseTokenAmount == 0) revert ZeroDepositAmount();

    IERC20(BASE_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), _baseTokenAmount);

    chamberAmount = _baseTokenAmount / pricePerShare;

    // TO-DO: Charge Fees

    IERC20(EXCHANGE_TOKEN).safeTransfer(msg.sender, chamberAmount);

    emit Deposit(msg.sender, _baseTokenAmount);
  }


  /**
    * @notice Preview the amount of base token to be received for a given amount of exchange token
    *     
    * @param _exchangeTokenAmount Amount of exchange token to be withdrawn
    * @return baseTokenAmount Amount of base token to be received
  */
  function previewWithdraw(uint256 _exchangeTokenAmount) external view returns (uint256 baseTokenAmount) {
    baseTokenAmount = _exchangeTokenAmount * pricePerShare;
  }


  /**
    * @notice Withdraw base token by providing exchange token. Operation can only be performed
    *         when contract is not paused.
    *     
    * @param _exchangeTokenAmount Amount of exchange token to be withdrawn
    * @return baseTokenAmount Amount of base token to be received
  */
  function withdraw(uint256 _exchangeTokenAmount) external nonReentrant whenNotPaused returns (uint256 baseTokenAmount) {
    if(_exchangeTokenAmount == 0) revert ZeroWithdrawAmount();

    IERC20(EXCHANGE_TOKEN).safeTransferFrom(msg.sender, address(this), _exchangeTokenAmount);

    baseTokenAmount = _exchangeTokenAmount * pricePerShare;

    // TO-DO: Charge Fees

    IERC20(BASE_TOKEN_ADDRESS).safeTransfer(msg.sender, baseTokenAmount);

    emit Withdraw(msg.sender, baseTokenAmount);
  }

  /**
    * @notice Transfer ERC20 token to the owner. Operation can only be performed
    *         by a manager or admin.
    *     
    * @param _tokenToWithdraw Address of the token to be withdrawn
  */
  function transferERC20ToOwner(address _tokenToWithdraw) external override onlyManager() {
       if (IERC20(_tokenToWithdraw).balanceOf(address(this)) == 0) {
            revert ZeroTokenBalance();
        }

        IERC20(_tokenToWithdraw).safeTransfer(msg.sender, IERC20(_tokenToWithdraw).balanceOf(address(this)));
  }

}