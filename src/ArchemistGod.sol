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
 *     NOTICE
 *
 *     All changes made by Smash Works Inc. are described and documented at
 *
 *     https://docs.arch.finance/chambers-peripherals
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

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IArchemistGod } from "./interfaces/IArchemistGod.sol";
import { Archemist } from "./Archemist.sol";
import { AccessManager } from "./AccessManager.sol";

contract ArchemistGod is IArchemistGod, AccessManager, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                              LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                              ARCHEMIST GOD STORAGE
    //////////////////////////////////////////////////////////////*/

    EnumerableSet.AddressSet private archemists;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() AccessManager(msg.sender) { }

    /*//////////////////////////////////////////////////////////////
                            ARCHEMIST GOD LOGIC
    //////////////////////////////////////////////////////////////*/
    /**
     * Creates a new Archemist and adds it to the list of Archemists.
     *
     * @param _exchangeTokenAddress  Address of the exchange token to be given at every deposit or to receive at every withdrawal.
     * @param _baseTokenAddress      Address of the base token.
     * @param _exchangeFee           Fee to be charged at every deposit or withdrawal (number is divided by 10.000 to get the percentage).
     *
     * @return archemist             The new archemist contract.
     */
    function createArchemist(
        address _exchangeTokenAddress,
        address _baseTokenAddress,
        uint24 _exchangeFee
    ) external onlyCallerWithAccess nonReentrant returns (Archemist archemist) {
        archemist = new Archemist(
            msg.sender, _exchangeTokenAddress, _baseTokenAddress, address(this), _exchangeFee
        );

        if (!archemists.add(address(archemist))) {
            revert ArchemistAlreadyExists();
        }

        emit ArchemistCreated(address(archemist));
    }

    /**
     * Returns the Archemists created by ArchemistGod.
     *
     * @return address[]      An address array containing the Archemists.
     */
    function getArchemists() external view returns (address[] memory) {
        return archemists.values();
    }

    /**
     * Checks if the address is a Archemist validated in ArchemistGod.
     *
     * @param _archemist    The address to check.
     *
     * @return bool         True if the address is a validated Archemist.
     */
    function isValidArchemist(address _archemist) public view returns (bool) {
        return archemists.contains(_archemist);
    }
}
