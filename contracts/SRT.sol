// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ISwapRouter.sol";
import "./interfaces/ISwapFactory.sol";


contract SRTToken is ERC20 ,Ownable{
    bool public launched;
    mapping(address => bool) public _swapPairList;
    ISwapRouter public _swapRouter;
    constructor(address receiver,address currency,address router) ERC20("SuperBit Reward Token", "SRT"){
        ISwapRouter swapRouter = ISwapRouter(router);
        launched = false;
        ISwapFactory swapFactory = ISwapFactory(swapRouter.factory());
        address swapPair = swapFactory.createPair(address(this), currency);
        _swapPairList[swapPair] = true;
        _swapRouter = swapRouter;
        _mint(receiver,700000000e18);
    }
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
    function launch() external onlyOwner{
        launched = true;
    }
     function setSwapPairList(address addr, bool enable) external onlyOwner {
        _swapPairList[addr] = enable;
    }
    function _transfer(address from, address to, uint256 amount) internal override {
        if (_swapPairList[from] || _swapPairList[to]) {
            require(launched,"Transaction not opened");
        }
        super._transfer(from,to,amount);
    }


}
