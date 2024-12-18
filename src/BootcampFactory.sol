// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./DepositHandler.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import {IBootcampFactoryErrors} from "./interfaces/ICustomErrors.sol";

/**
 * @title Bootcamp Factory contract.
 * @author @ohMySol, @nynko, @ok567, @kubko
 * @notice Contract create new bootcamps.
 * @dev Contract for creation new instances of the `DepositHandler` contract with a Factory pattern.
 * 
 * Roles:
 *  1. ADMIN - main role which is set up automatically for a deployer address. This role should potentialy
 *  manage all underlying roles like MANAGER role, and grant a roles to a new users.
 *  2. MANAGER - 2nd role which is responsible for creating new bootcamp instances once new bootcamp is launched.
 */
contract BootcampFactory is AccessControl, IBootcampFactoryErrors {
    bytes32 public constant ADMIN = keccak256("ADMIN"); // Main Role
    bytes32 public constant MANAGER = keccak256("MANAGER"); // 2nd Roles
    mapping (address => bool) public isBootcamp;

    
    event BootcampCreated (
        address indexed bootcampAddress
    );
    event AdminFundsWithdrawn(
        address indexed admin, 
        uint256 withdrawnAmount,
        uint256 remainedBalance
    );
        
    constructor() {
        _grantRole(ADMIN, msg.sender); // Grant the deployer the admin role
        _setRoleAdmin(MANAGER, ADMIN); // Set the `ADMIN` role as the administrator for the `MANAGER` role
    }

    /*//////////////////////////////////////////////////
                MANAGER FUNCTIONS
    /////////////////////////////////////////////////*/
    /**
     * @notice Managers are able to create a new bootcamp instance each time
     * they need to launch a new bootcamp.
     * @dev Create a new `DepositHandler` contract instance and set up a required 
     * bootcamp information in this instance: `_depositAmount` and `_depositToken`.
     * New bootcamp instance is stored in this factory contract in `bootcamp` mapping 
     * by unique bootcamp address.
     * Function restrictions:
     *  - `_depositToken` address can not be address(0).
     *  - `_bootcampStart` should be a future date.
     *  - `_bootcampDeadline` should be > `_bootcampStart`.
     *  - Can only be called by an address with `MANAGER` role.
     * 
     * Emits a {BootcampCreated} event.
     * 
     * @param _depositAmount - bootcamp deposit amount.
     * @param _depositToken  - token address which is used for deposit. 
     */
    function createBootcamp(
        uint256 _depositAmount, 
        address _depositToken, 
        uint256 _bootcampStart,
        uint256 _bootcampDeadline,
        uint256 _withdrawDuration,
        string memory _bootcampName
    )      
        external onlyRole(MANAGER) returns(address)
    {
        if (_depositToken == address(0)) {
            revert BootcampFactory__DepositTokenCanNotBeZeroAddress();
        }
        if (_bootcampStart > block.timestamp && _bootcampDeadline > _bootcampStart) { // bootcampStart should be in the future to have time for depositing, and deadline obviously should be > start time
            DepositHandler bootcamp = new DepositHandler(
                _depositAmount, 
                _depositToken, 
                msg.sender,
                _bootcampStart,
                _bootcampDeadline,
                _withdrawDuration,
                address(this),
                _bootcampName
            );
    
            isBootcamp[address(bootcamp)] = true;

            emit BootcampCreated(address(bootcamp));
            return address(bootcamp);
        } else {
            revert BootcampFactory__InvalidBootcampStartOrDedlineTime();
        }
    }

    /*//////////////////////////////////////////////////
                ADMIN FUNCTIONS
    /////////////////////////////////////////////////*/
    /**
     * @notice Set a role to user.
     * @dev Set `MANAGER` or `ADMIN` role to `_account` address.
     * Function restrictions:
     *  - Can only be called by an address with `ADMIN` role.
     *  - `_account` can not be address(0).
     *  - `_role` can only be `MANAGER` or `ADMIN`.
     * 
     * @param _role - bytes32 respresentation of the role.
     * @param _account - address of the user that will have an new role.
     */
    function grantRole(bytes32 _role, address _account) public override onlyRole(ADMIN) {
        if (_account == address(0)) {
            revert BootcampFactory__CanNotUpdateRoleForZeroAddress();
        }
        if (_role == ADMIN || _role == MANAGER) {
            _grantRole(_role, _account);
        } else {
            revert BootcampFactory__UpdateNonExistentRole(_role);
        }
        
    }

    /**
     * @notice Remove role from user.
     * @dev Remove `MANAGER` or `ADMIN` role from `_manager` address.
     * Function restrictions:
     *  - Can only be called by address with `ADMIN` role.
     *  - `_account` can not be address(0).
     *  - `_role` can be only `MANAGER` or `ADMIN`.
     *
     * @param _role - bytes32 respresentation of the role. 
     * @param _account - address of the user that has a `MANAGER` role.
     */
    function revokeRole(bytes32 _role, address _account) public override onlyRole(ADMIN) {
        if (_account == address(0)) {
            revert BootcampFactory__CanNotUpdateRoleForZeroAddress();
        }
        if (_role == ADMIN || _role == MANAGER) {
            _revokeRole(_role, _account);
        } else {
            revert BootcampFactory__UpdateNonExistentRole(_role);
        }
    }

    /**
     * @notice Admin can withdraw deposits of 'not passed' or 'donaters' users from the specific bootcamp.
     * @dev Admin is able to withdraw `_amount` from the `_bootcamp` contract which is already finished.
     * Function restrictions:
     *  - Can only be called by an address with `ADMIN` role.
     *  - `_bootcamp` parameter shouldn't be address(0)
     *  - `bootcampAddress` should be an address of existing bootcamp.
     * 
     * Emits a {AdminFundsWithdrawn} event.
     * 
     * @param _amount - amount to withdraw from the `DepositHandler`(bootcamp) contract. 
     * @param _bootcamp  - address of the bootcamp from which admin wants to withdraw.
     */
    function withdrawProfit(uint256 _amount, address _bootcamp) external onlyRole(ADMIN) {
        if (_bootcamp == address(0) || !isBootcamp[_bootcamp]) {
            revert BootcampFactory__InvalidBootcampAddress();
        }
        
        uint256 remainingBalance = DepositHandler(_bootcamp).withdrawAdmin(msg.sender, _amount);

        emit AdminFundsWithdrawn(msg.sender, _amount, remainingBalance);
    }
}