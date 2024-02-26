// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.20;

import { AccessManager } from "src/AccessManager.sol";
import { IAccessManager } from "src/interfaces/IAccessManager.sol";
import { Test } from "forge-std/Test.sol";

contract AddOperatorTest is Test {
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
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [ERROR] Should revert when trying to add an operator not as manager
     */
    function testCannotAddOperatorNotManager(address randomCaller, address randomAddress) public {
        vm.assume(randomCaller != owner);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.CallerIsNotManager.selector, randomCaller)
        );
        vm.prank(randomCaller);
        accessManager.addOperator(randomAddress);
    }

    /**
     * [ERROR] Should revert when trying to add an operator already added
     */
    function testCannotAddOperatorAlreadyAdded(address randomAddress) public {
        vm.startPrank(owner);
        accessManager.addOperator(randomAddress);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessManager.OperatorAlreadyAdded.selector, randomAddress)
        );
        accessManager.addOperator(randomAddress);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should add an operator as manager
     */
    function testAddOperator(address randomAddress) public {
        vm.prank(owner);
        accessManager.addOperator(randomAddress);
    }
}
