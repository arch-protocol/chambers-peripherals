// SPDX-License-Identifier: Apache License 2.0

pragma solidity ^0.8.24;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPolygonMigrator } from "./interfaces/IPolygonMigrator.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract ArchPolMigrator is Ownable, ReentrancyGuard {
    using Address for address;
    using SafeERC20 for IERC20;

    address public polygonMigrationContract;
    IERC20 public MATIC;
    IERC20 public POL;

    constructor(address _polygonMigrationContract, address _MATIC, address _POL)
        Ownable(msg.sender)
    {
        polygonMigrationContract = _polygonMigrationContract;
        MATIC = IERC20(_MATIC);
        POL = IERC20(_POL);
    }
    /**
     * Migrates the specified amount of ERC20 token from MATIC to POL and transfers the amount to the sender
     *
     * @param _amount     Token amount to migrate
     */

    function migrate(uint256 _amount) external nonReentrant returns (uint256) {
        MATIC.safeTransferFrom(msg.sender, address(this), _amount);
        MATIC.safeIncreaseAllowance(polygonMigrationContract, _amount);
        IPolygonMigrator(polygonMigrationContract).migrate(_amount);

        require(POL.balanceOf(address(this)) == _amount, "UNDERBOUGHT");

        POL.safeTransfer(msg.sender, _amount);

        require(POL.balanceOf(msg.sender) == _amount, "UNTRANSFERRED");

        return (_amount);
    }

    /**
     * Transfer the total balance of the specified stucked token to the owner address
     *
     * @param _tokenToWithdraw     The ERC20 token address to withdraw
     */
    function transferERC20ToOwner(address _tokenToWithdraw) external onlyOwner nonReentrant {
        require(IERC20(_tokenToWithdraw).balanceOf(address(this)) > 0, "NO_BALANCE");

        IERC20(_tokenToWithdraw).safeTransfer(
            owner(), IERC20(_tokenToWithdraw).balanceOf(address(this))
        );
    }

    /**
     * Transfer all stuck native token to the owner of the contract
     */
    function transferNativeTokenToOwner() external onlyOwner nonReentrant {
        require(address(this).balance > 0, "NO_BALANCE");

        payable(owner()).transfer(address(this).balance);
    }
}
