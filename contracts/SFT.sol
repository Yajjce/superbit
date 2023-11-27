// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ISwapRouter.sol";
import "./interfaces/ISwapFactory.sol";


contract SFTToken is ERC20 ,Ownable{
    bool public launched;
    mapping(address => bool) public _swapPairList;
    mapping(address => bool) public whiteList;
    ISwapRouter public _swapRouter;
    constructor(address receiver,address currency,address router) ERC20("SuperBit Future Token", "SFT"){
        ISwapRouter swapRouter = ISwapRouter(router);
        launched = false;
        ISwapFactory swapFactory = ISwapFactory(swapRouter.factory());
        address swapPair = swapFactory.createPair(address(this), currency);
        _swapPairList[swapPair] = true;
        _swapRouter = swapRouter;
        _mint(receiver,2100000000e18);
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
    function setWhiteList(address addr, bool enable)  external onlyOwner {
        whiteList[addr] = enable;
    }
    function _transfer(address from, address to, uint256 amount) internal override {
        if (_swapPairList[from] || _swapPairList[to]) {
            if(!whiteList[from]){
                require(launched,"Transaction not opened");
            }
        }
        super._transfer(from,to,amount);
    }


}
