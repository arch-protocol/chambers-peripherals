// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.20;

import { AccessManager } from "src/AccessManager.sol";
import { IAccessManager } from "src/interfaces/IAccessManager.sol";
import { Test } from "forge-std/Test.sol";

contract RemoveOperatorTest is Test {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

    AccessManager public accessManager;
    address public owner = vm.addr(0x1);

    function setUp() public {
        vm.prank(owner);
        accessManager = new AccessManager(owner);
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [ERROR] Should revert when trying to remove an operator not as manager
     */
    function testCannotRemoveOperatorNotManager(address randomCaller, address randomAddress)
        public
    {
        vm.assume(randomCaller != owner);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.CallerIsNotManager.selector, randomCaller)
        );
        vm.prank(randomCaller);
        accessManager.removeOperator(randomAddress);
    }

    /**
     * [ERROR] Should revert when trying to remove an operator not added
     */
    function testCannotRemoveOperatorNotAdded(address randomAddress) public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.OperatorNotAdded.selector, randomAddress)
        );
        vm.prank(owner);
        accessManager.removeOperator(randomAddress);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should remove an operator as manager
     */
    function testRemoveOperator(address randomAddress) public {
        vm.prank(owner);
        accessManager.addOperator(randomAddress);
        vm.prank(owner);
        accessManager.removeOperator(randomAddress);
    }
}
