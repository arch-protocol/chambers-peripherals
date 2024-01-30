// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IChamber } from "chambers/interfaces/IChamber.sol";
import { IVault } from "src/interfaces/IVault.sol";
import { ExposedTradeIssuer } from "test/utils/ExposedTradeIssuer.sol";

contract TradeIssuerUnitInternalDepositConstituentsInVaultTest is Test {
    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/
    ExposedTradeIssuer public tradeIssuer;
    IChamber public chamber;
    address public tradeIssuerAddress;
    address payable public dexAgg = payable(address(0x1));
    address public chamberAddress = (address(chamber));
    address public wETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public uSDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public dAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public yUSDC = 0xa354F35829Ae975e850e23e9615b11Da1B3dC4DE;
    address public yDAI = 0xdA816459F1AB5631232FE5e97a05BBBb94970c95;
    address[] public vaults = new address[](2);
    address[] public vaultAssets = new address[](2);
    uint256[] public vaultQuantities = new uint256[](2);

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        tradeIssuer = new ExposedTradeIssuer(dexAgg, wETH);
        tradeIssuerAddress = address(tradeIssuer);
        vm.label(tradeIssuerAddress, "TradeIssuer");
        chamber = IChamber(chamberAddress);
        vaults[0] = yUSDC;
        vaults[1] = yDAI;
        vaultAssets[0] = uSDC;
        vaultAssets[1] = dAI;
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Should revert because required quantities are greater than zero
     * and there's no deposit amount
     */
    function testCannotDepositWithZeroDepositAmount(uint256 mintAmount) public {
        vm.assume(mintAmount > 0);
        vm.assume(mintAmount < type(uint160).max);

        vaultQuantities[0] = 0;
        vaultQuantities[1] = 0;

        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.getConstituentQuantity.selector, vaults[0]),
            abi.encode(1)
        );

        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(ERC20(address(chamber)).decimals.selector),
            abi.encode(18)
        );

        vm.expectRevert(bytes("Deposit amount cannot be zero"));
        tradeIssuer.depositConstituentsInVault(
            vaults, vaultAssets, vaultQuantities, IChamber(chamberAddress), mintAmount
        );
    }

    /**
     * [REVERT] Should revert because vaultQuantities array is empty
     */
    function testCannotDepositWithEmptyQuantitiesArray(uint256 mintAmount) public {
        vm.assume(mintAmount > 0);
        vm.assume(mintAmount < type(uint160).max);

        uint256[] memory vaultQuantitiesOneElement = new uint256[](0);

        vm.expectRevert(stdError.indexOOBError); //Index Out of bounds stdError
        tradeIssuer.depositConstituentsInVault(
            vaults, vaultAssets, vaultQuantitiesOneElement, IChamber(chamberAddress), mintAmount
        );
    }

    /**
     * [REVERT] Should revert because vaultAssets array is empty
     */
    function testCannotDepositWithEmptyVaultAssets(uint256 mintAmount, uint256 depositAmount0)
        public
    {
        vm.assume(mintAmount > 0);
        vm.assume(mintAmount < type(uint160).max);
        vm.assume(depositAmount0 > 0);
        vm.assume(depositAmount0 < type(uint64).max);

        vaultQuantities[0] = depositAmount0;

        address[] memory vaultAssetsEmptyArray = new address[](0);

        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.getConstituentQuantity.selector, vaults[0]),
            abi.encode(vaultQuantities[0])
        );

        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(ERC20(address(chamber)).decimals.selector),
            abi.encode(18)
        );

        vm.expectRevert(stdError.indexOOBError); //Index Out of bounds stdError
        tradeIssuer.depositConstituentsInVault(
            vaults, vaultAssetsEmptyArray, vaultQuantities, IChamber(chamberAddress), mintAmount
        );
    }

    /**
     * [REVERT] Should revert after the first iteration because no yTokens were
     * transfered since it's a mock call.
     */
    function testCannotReturnWithUnderboughtFirstAsset(
        uint256 mintAmount,
        uint256 depositAmount0,
        uint256 depositAmount1
    ) public {
        vm.assume(mintAmount > 0);
        vm.assume(mintAmount < type(uint160).max);
        vm.assume(depositAmount0 > 0);
        vm.assume(depositAmount0 < type(uint64).max);
        vm.assume(depositAmount1 > 0);
        vm.assume(depositAmount1 < type(uint64).max);

        vaultQuantities[0] = depositAmount0;
        vaultQuantities[1] = depositAmount1;

        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.getConstituentQuantity.selector, vaults[0]),
            abi.encode(1)
        );

        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(ERC20(address(chamber)).decimals.selector),
            abi.encode(18)
        );

        vm.expectCall(
            vaultAssets[0],
            abi.encodeCall(IERC20(vaultAssets[0]).approve, (vaults[0], type(uint256).max))
        );

        vm.mockCall(
            vaults[0],
            abi.encodeWithSelector(IVault(vaults[0]).deposit.selector, vaultQuantities[0]),
            abi.encode()
        );

        vm.expectRevert(bytes("Underbought vault constituent"));
        tradeIssuer.depositConstituentsInVault(
            vaults, vaultAssets, vaultQuantities, IChamber(chamberAddress), mintAmount
        );
    }

    /**
     * [REVERT] Should revert because required issue quantity is zero
     * for both components.
     */
    function testCannotDepositWithZeroIssueQuantities(
        uint256 mintAmount,
        uint256 depositAmount0,
        uint256 depositAmount1
    ) public {
        vm.assume(mintAmount > 0);
        vm.assume(mintAmount < type(uint160).max);
        vm.assume(depositAmount0 > 0);
        vm.assume(depositAmount0 < type(uint64).max);
        vm.assume(depositAmount1 > 0);
        vm.assume(depositAmount1 < type(uint64).max);

        vaultQuantities[0] = depositAmount0;
        vaultQuantities[1] = depositAmount1;

        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.getConstituentQuantity.selector, vaults[0]),
            abi.encode(0)
        );

        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(ERC20(address(chamber)).decimals.selector),
            abi.encode(18)
        );

        vm.expectRevert(bytes("Quantity is zero"));
        tradeIssuer.depositConstituentsInVault(
            vaults, vaultAssets, vaultQuantities, IChamber(chamberAddress), mintAmount
        );
    }

    /**
     * [REVERT] Should revert because mintAmount is zero. This shouldn't happen
     * because the main external functions check that the mintAmount is greater than zero.
     */
    function testCannotDepositWithZeroIssueQuantities(
        uint256 depositAmount0,
        uint256 depositAmount1
    ) public {
        uint256 mintAmount = 0;
        vm.assume(depositAmount0 > 0);
        vm.assume(depositAmount0 < type(uint64).max);
        vm.assume(depositAmount1 > 0);
        vm.assume(depositAmount1 < type(uint64).max);

        vaultQuantities[0] = depositAmount0;
        vaultQuantities[1] = depositAmount1;

        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.getConstituentQuantity.selector, vaults[0]),
            abi.encode(1)
        );

        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(ERC20(address(chamber)).decimals.selector),
            abi.encode(18)
        );

        vm.expectRevert(bytes("Quantity is zero"));
        tradeIssuer.depositConstituentsInVault(
            vaults, vaultAssets, vaultQuantities, IChamber(chamberAddress), mintAmount
        );
    }
}
