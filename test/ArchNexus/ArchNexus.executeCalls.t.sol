// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { ArchNexusTest } from "test/utils/ArchNexusTest.sol";
import { IArchNexus } from "src/interfaces/IArchNexus.sol";
import { IArchemist } from "src/interfaces/IArchemist.sol";

contract ExecuteCallsTest is ArchNexusTest {
    address carlos;

    function setUp() public override {
        super.setUp();

        carlos = vm.addr(0x3);

        vm.startPrank(admin);
        archNexus.addTarget(address(archemist));
        archNexus.addTarget(address(archemistAedyAddy));
        vm.stopPrank();

        deal(AEDY, address(archemist), 10000 ether);
        deal(WETH, address(archemist), 10000 ether);

        deal(AEDY, address(archemistAedyAddy), 10000 ether);
        deal(ADDY, address(archemistAedyAddy), 10000 ether);

        vm.startPrank(admin);
        archemist.updatePricePerShare(0.1 ether);
        archemistAedyAddy.updatePricePerShare(2.6 ether);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                               SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should swap from WETH to AEDY.
     */
    function test_executeCallsFromWETHToAEDY() public {
        IArchNexus.ContractCallInstruction[] memory calls =
            new IArchNexus.ContractCallInstruction[](1);

        IArchNexus.ContractCallInstruction memory swapWETHToAEDY = IArchNexus
            .ContractCallInstruction({
            _target: payable(address(archemist)),
            _allowanceTarget: address(archemist),
            _sellToken: IERC20(WETH),
            _buyToken: IERC20(AEDY),
            _sellAmount: 10 ether,
            _minBuyAmount: 90 ether,
            _callData: abi.encodeWithSelector(IArchemist.deposit.selector, 10 ether)
        });

        calls[0] = swapWETHToAEDY;

        deal(WETH, carlos, 100 ether);
        vm.startPrank(carlos);
        IERC20(WETH).approve(address(archNexus), 100 ether);
        archNexus.executeCalls(calls, WETH, 10 ether, AEDY, 90 ether, false);
        vm.stopPrank();

        assertEq(IERC20(AEDY).balanceOf(carlos), 90 ether);
    }

    /**
     * [SUCCESS] Should swap from WETH to ADDY, passing through AEDY.
     */
    function test_executeCallsFromWETHToADDY() public {
        IArchNexus.ContractCallInstruction[] memory calls =
            new IArchNexus.ContractCallInstruction[](2);

        IArchNexus.ContractCallInstruction memory swapWETHToAEDY = IArchNexus
            .ContractCallInstruction({
            _target: payable(address(archemist)),
            _allowanceTarget: address(archemist),
            _sellToken: IERC20(WETH),
            _buyToken: IERC20(AEDY),
            _sellAmount: 10 ether,
            _minBuyAmount: 90 ether,
            _callData: abi.encodeWithSelector(IArchemist.deposit.selector, 10 ether)
        });

        IArchNexus.ContractCallInstruction memory swapAEDYToADDY = IArchNexus
            .ContractCallInstruction({
            _target: payable(address(archemistAedyAddy)),
            _allowanceTarget: address(archemistAedyAddy),
            _sellToken: IERC20(AEDY),
            _buyToken: IERC20(ADDY),
            _sellAmount: 90 ether,
            _minBuyAmount: 210 ether,
            _callData: abi.encodeWithSelector(IArchemist.withdraw.selector, 90 ether)
        });

        calls[0] = swapWETHToAEDY;
        calls[1] = swapAEDYToADDY;

        deal(WETH, carlos, 100 ether);
        vm.startPrank(carlos);
        IERC20(WETH).approve(address(archNexus), 100 ether);
        archNexus.executeCalls(calls, WETH, 10 ether, ADDY, 210 ether, false);
        vm.stopPrank();

        assertGt(IERC20(ADDY).balanceOf(carlos), 210 ether);
    }

    /**
     * [SUCCESS] Should swap from ADDY to WETH, receiving native token.
     */
    function test_executeCallsFromADDYToNativeToken() public {
        IArchNexus.ContractCallInstruction[] memory calls =
            new IArchNexus.ContractCallInstruction[](2);

        IArchNexus.ContractCallInstruction memory swapADDYToAEDY = IArchNexus
            .ContractCallInstruction({
            _target: payable(address(archemistAedyAddy)),
            _allowanceTarget: address(archemistAedyAddy),
            _sellToken: IERC20(ADDY),
            _buyToken: IERC20(AEDY),
            _sellAmount: 210 ether,
            _minBuyAmount: 70 ether,
            _callData: abi.encodeWithSelector(IArchemist.deposit.selector, 210 ether)
        });

        IArchNexus.ContractCallInstruction memory swapAEDYToWETH = IArchNexus
            .ContractCallInstruction({
            _target: payable(address(archemist)),
            _allowanceTarget: address(archemist),
            _sellToken: IERC20(AEDY),
            _buyToken: IERC20(WETH),
            _sellAmount: 70 ether,
            _minBuyAmount: 6 ether,
            _callData: abi.encodeWithSelector(IArchemist.withdraw.selector, 70 ether)
        });

        calls[0] = swapADDYToAEDY;
        calls[1] = swapAEDYToWETH;

        deal(ADDY, carlos, 1000 ether);
        vm.startPrank(carlos);
        IERC20(ADDY).approve(address(archNexus), 210 ether);
        archNexus.executeCalls(calls, ADDY, 210 ether, WETH, 6 ether, true);
        vm.stopPrank();

        assertGt(carlos.balance, 6 ether);
    }
}
