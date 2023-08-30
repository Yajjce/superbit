// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract SRTToken is ERC20 ,Ownable{
    bool public launched;
    constructor(address receiver) ERC20("SRT", "SRT"){
        launched = false;
        _mint(receiver,600000000e18);
    }
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
    function launch() external onlyOwner{
        launched = true;
    }
    function _transfer(address from, address to, uint256 amount) internal override {
        require(launched,"Transaction not opened");
        super._transfer(from,to,amount);
    }


}
