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

    event Deposit(
        address indexed sender,
        uint256 amount
    );

    event Withdraw(
        address indexed sender,
        uint256 amount
    );

    event PricePerShareUpdated(
        uint256 pricePerShare
    );


    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroWithdrawAmount();

    error ZeroDepositAmount();

    error InvalidArchemist();

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function transferERC20ToOwner(address _tokenToWithdraw) external;

    function transferEthToOwner() external;

    function deposit(uint256 _tokenAmount) external returns (uint256 chamberAmount);

    function previewDeposit(uint256 _tokenAmount) external view returns (uint256 chamberAmount);

    function witdraw(uint256 _chamberAmount) external returns (uint256 tokenAmount);

    function previewWithdraw(uint256 _chamberAmount) external view returns (uint256 tokenAmount);

    function getPricePerShare() external view returns (uint256 pricePerShare);

    function updatePricePerShare(uint256 _pricePerShare) external;

    function activateArchemist() external;

    function deactivateArchemist() external;

}
