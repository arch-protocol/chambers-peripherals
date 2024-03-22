// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { ArchNexusTest } from "test/utils/ArchNexusTest.sol";

import { IArchNexus } from "src/interfaces/IArchNexus.sol";
import { IArchemist } from "src/interfaces/IArchemist.sol";

contract MaliciousContract is Ownable {
    constructor() Ownable(msg.sender) { }

    function drain(address token, address target, uint256 amount) external onlyOwner {
        IERC20(token).transferFrom(target, address(this), amount);
    }

    function withdraw(address token) external onlyOwner {
        IERC20(token).transfer(owner(), IERC20(token).balanceOf(address(this)));
    }
}

contract HackyWackyTests is ArchNexusTest {
    MaliciousContract malicious;

    address hacker;

    function setUp() public override {
        super.setUp();
        // setup
        hacker = vm.addr(0xD3Ad);
        deal(WETH, hacker, 100 ether);
        deal(ADDY, address(archNexus), 100 ether);
        deal(AEDY, address(archemist), 100 ether);
        deal(WETH, address(archemist), 100 ether);
        vm.prank(admin);
        archNexus.addTarget(address(archemist));
        vm.prank(admin);
        archemist.updatePricePerShare(15000000000);

        vm.prank(hacker);
        malicious = new MaliciousContract();
    }

    function test_shouldNotAllowMaliciousAllowanceTarget() public {
        // call instruction that does nothing
        IArchNexus.ContractCallInstruction memory callInstruction = IArchNexus
            .ContractCallInstruction({
            _target: payable(address(archemist)),
            _allowanceTarget: address(malicious), // malicious contract has allowance
            _sellToken: IERC20(ADDY),
            _buyToken: IERC20(USDC),
            _sellAmount: 100 ether,
            _minBuyAmount: 0,
            _callData: abi.encodeWithSelector(IArchemist.previewDeposit.selector, 100e6)
        });
        IArchNexus.ContractCallInstruction[] memory calls =
            new IArchNexus.ContractCallInstruction[](1);
        calls[0] = callInstruction;

        // execute
        vm.startPrank(hacker);
        IERC20(WETH).approve(address(archNexus), 100 ether);
        vm.expectRevert(
            abi.encodeWithSelector(IArchNexus.InvalidTarget.selector, address(malicious))
        );
        archNexus.executeCalls(calls, WETH, 1, ADDY, 0);
        vm.stopPrank();

        // validate that the hacker did not withdraw the balance
        assertEq(IERC20(ADDY).balanceOf(hacker), 0);
        assertEq(IERC20(ADDY).balanceOf(address(archNexus)), 100 ether);

        /**
         * With the fix now in place, the malicious contract
         * should not be able to drain the funds
         */
        vm.startPrank(hacker);
        vm.expectRevert();
        malicious.drain(ADDY, address(archNexus), 100 ether);
        malicious.withdraw(ADDY);
        vm.stopPrank();

        // validate that the hacker did not withdraw the balance
        assertEq(IERC20(ADDY).balanceOf(hacker), 0);
        assertEq(IERC20(ADDY).balanceOf(address(archNexus)), 100 ether);
    }

    function test_shouldNotWithdrawBalanceWhenInstructionsDoNotChangeBalance() public {
        // call instruction that does nothing
        IArchNexus.ContractCallInstruction memory callInstruction = IArchNexus
            .ContractCallInstruction({
            _target: payable(address(archemist)),
            _allowanceTarget: address(archemist),
            _sellToken: IERC20(ADDY),
            _buyToken: IERC20(USDC),
            _sellAmount: 100 ether,
            _minBuyAmount: 0,
            _callData: abi.encodeWithSelector(IArchemist.previewDeposit.selector, 100e6)
        });
        IArchNexus.ContractCallInstruction[] memory calls =
            new IArchNexus.ContractCallInstruction[](1);
        calls[0] = callInstruction;

        // execute
        vm.startPrank(hacker);
        IERC20(WETH).approve(address(archNexus), 100 ether);
        archNexus.executeCalls(calls, WETH, 1, ADDY, 0);
        vm.stopPrank();

        // validate that the hacker did not withdraw the balance
        assertEq(IERC20(ADDY).balanceOf(hacker), 0);
        assertEq(IERC20(ADDY).balanceOf(address(archNexus)), 100 ether);
    }
}
