// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.20;

import { AccessManager } from "src/AccessManager.sol";
import { Test } from "forge-std/Test.sol";

contract GetOperatorsTest is Test {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

    AccessManager public accessManager;
    address public owner = vm.addr(0x1);

    function setUp() public {
        vm.prank(owner);
        accessManager = new AccessManager();
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should return the operators in the contract
     */
    function testGetOperators(address randomAddress) public {
        vm.prank(owner);
        accessManager.addOperator(randomAddress);

        address[] memory operators = accessManager.getOperators();
        assertEq(operators.length, 1);
        assertEq(operators[0], randomAddress);
    }
}
