// SPDX-License-Identifier: Apache License 2.0


pragma solidity ^0.8.24;


import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPolygonMigrator } from "./interfaces/IPolygonMigrator.sol";


contract PolMigrator {
    using Address for address;
    using SafeERC20 for IERC20;

    address public polygonMigrationContract;
    IERC20 public MATIC;
    IERC20 public POL;
    

    constructor(
      address _polygonMigrationContract,
      address _MATIC,
      address _POL
      ) {
        polygonMigrationContract = _polygonMigrationContract;
        MATIC = IERC20(_MATIC);
        POL = IERC20(_POL);
    }

    function migrate(uint256 _amount) external returns (uint256) {
        
        MATIC.safeTransferFrom(msg.sender, address(this), _amount);
        MATIC.safeIncreaseAllowance(polygonMigrationContract, _amount);
        IPolygonMigrator(polygonMigrationContract).migrate(_amount);

        require(POL.balanceOf(address(this)) == _amount, "UNDEBOUGHT");

        POL.safeTransfer(msg.sender, _amount);

        return (_amount);
    }

}