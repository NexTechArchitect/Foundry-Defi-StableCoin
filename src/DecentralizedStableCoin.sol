// SPDX-License-Identifier: MIT

//Layout of the contract:
//version
//imports
//errors
//interfaces, libraries, contracts
//Type declarations
//State variables
//Events
//Modifiers
//Functions

//Layout of the functions:
//constructor
//receive function (if exists)
//fallback function (if exists)
//external
//public
//internal
//private
//view / pure functions
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {
    ERC20Burnable
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity ^0.8.19;

/*
* @title Decentralized Stable Coin
* @author: Amit
* Collateral: Exogenous (ETH And BTC)
* Minting: Algorithmics
* Relative Stability: Soft Pegged to USD
* This is the contract meants to be governed by DSCEngine.This contract is just the ERC20 
  implementation of the stablecoin system
*
*/
contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    ////////////////////////////
    ////       Errors       ////
    ////////////////////////////
    error DecentralizedStableCoin_MustBeMoreThanZero();
    error DecentralizedStableCoin_BurnAmountExceedsBalance();
    error DecentralizedStableCoin_NotZeroAddress();

    constructor() ERC20("DSC Stablecoin", "DSC") Ownable(msg.sender) {}

    /**
     * @notice Burns a specific amount of tokens from the owner's account
     * @param _amount The amount of tokens to be burned
     * @dev Only the owner of the contract can call this function
     */

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);

        if (_amount == 0) {
            revert DecentralizedStableCoin_MustBeMoreThanZero();
        }

        if (balance < _amount) {
            revert DecentralizedStableCoin_BurnAmountExceedsBalance();
        }

        super.burn(_amount);
    }

    /**
     * @notice Mints a specific amount of tokens to a given address
     * @param _to The address to which the tokens will be minted
     * @param _amount The amount of tokens to be minte
     */

    function mint(
        address _to,
        uint256 _amount
    ) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin_NotZeroAddress();
        }
        _mint(_to, _amount);
        return true;
    }
}
